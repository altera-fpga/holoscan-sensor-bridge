/**
 * SPDX-FileCopyrightText: Copyright (c) 2025 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "jesd.hpp"
#include "logging_internal.hpp"
#include "timeout.hpp"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>

namespace hololink {

SpiDaemonThread::SpiDaemonThread(Hololink& hololink, JESDConfig& jesd_config)
    : hololink_(hololink)
    , jesd_config_(jesd_config)
    , running_(false)
{
}

void SpiDaemonThread::run()
{
    // Power on the HSB before starting the thread or configuring other components.
    jesd_config_.power_on();

    thread_ = std::thread(&SpiDaemonThread::thread_func, this);
    while (!running_.load(std::memory_order_relaxed)) {
        HSB_LOG_INFO("Waiting for SPI Daemon connection...");
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    HSB_LOG_INFO("SPI Daemon Connected");
}

void SpiDaemonThread::stop()
{
    running_.store(false, std::memory_order_release);
    thread_.join();
}

void SpiDaemonThread::thread_func()
{
    uint8_t buffer[300];

    struct sockaddr_in address;
    socklen_t addrlen = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(SPI_DAEMON_SERVER_PORT);

    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        HSB_LOG_ERROR("Failed to create server socket");
        return;
    }

    // Set REUSEADDR/PORT to ensure that a server can be launched again immediately after closing.
    int enable = 1;
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable)) < 0) {
        HSB_LOG_ERROR("Failed to set SO_REUSEADDR on server socket");
        return;
    }
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEPORT, &enable, sizeof(enable)) < 0) {
        HSB_LOG_ERROR("Failed to set SO_REUSEPORT on server socket");
        return;
    }

    if (bind(server_fd, (struct sockaddr*)&address, addrlen) < 0) {
        HSB_LOG_ERROR("Failed to bind server socket");
        return;
    }

    if (listen(server_fd, 1) < 0) {
        HSB_LOG_ERROR("Failed to listen for client connection");
        return;
    }

    HSB_LOG_INFO("Listening on port {} for SPI Daemon connection...", SPI_DAEMON_SERVER_PORT);

    int sock_fd = accept(server_fd, (struct sockaddr*)&address, &addrlen);
    if (sock_fd < 0) {
        HSB_LOG_ERROR("Failed to accept client connection");
        return;
    }

    std::shared_ptr<Hololink::Spi> spi[MAX_SPI_DEVICES];
    for (size_t i = 0; i < MAX_SPI_DEVICES; ++i) {
        spi[i] = hololink_.get_spi(/*bus_number*/ i,
            /*chip_select*/ 0, /*clock_divisor*/ 15,
            /*cpol*/ 1, /*cpha*/ 1, /*width*/ 1,
            /*spi_address*/ 0x03000000);
    }

    running_.store(true, std::memory_order_release);
    while (running_.load(std::memory_order_relaxed)) {
        // Read message from the daemon.
        int bytes_read = recv(sock_fd, buffer, sizeof(buffer), 0);
        if (bytes_read == 0) {
            break;
        }

        // Parse/execute the message.
        struct hsb_spi_message* msg = (struct hsb_spi_message*)buffer;
        size_t data_size = bytes_read - sizeof(*msg);
        std::vector<uint8_t> read_bytes;
        if (msg->type == HSB_SPI_MSG_TYPE_SPI) {
            // Gather the SPI parameters/bytes.
            uint8_t id = (msg->u.spi.id_cs >> 4) & 0xF;
            uint8_t cs = msg->u.spi.id_cs & 0xF;
            uint8_t* cmd_bytes_base = ((uint8_t*)buffer) + sizeof(*msg);
            std::vector<uint8_t> cmd_bytes(cmd_bytes_base, cmd_bytes_base + msg->u.spi.cmd_bytes);
            uint8_t* wr_bytes_base = cmd_bytes_base + msg->u.spi.cmd_bytes;
            size_t wr_byte_count = msg->u.spi.wr_bytes - msg->u.spi.cmd_bytes;
            std::vector<uint8_t> wr_bytes(wr_bytes_base, wr_bytes_base + wr_byte_count);

            // Dispatch the SPI command.
            read_bytes = spi[id]->spi_transaction(cmd_bytes, wr_bytes, msg->u.spi.rd_bytes);
            HSB_LOG_DEBUG("id={} cs={} cmd=[{:02x}] wr=[{:02x}] rd=[{:02x}]", id, cs,
                fmt::join(cmd_bytes, " "),
                fmt::join(wr_bytes, " "),
                fmt::join(read_bytes, " "));
        } else if (msg->type == HSB_SPI_MSG_TYPE_JESD) {
            if (data_size > 0) {
                HSB_LOG_DEBUG("Extra data received with JESD command ({} bytes)", data_size);
            }

            // Execute the JESD transition.
            int result = execute_jesd(msg->u.jesd.id);
            read_bytes.push_back(result);
        } else {
            throw std::runtime_error(fmt::format("Invalid message type: {}", msg->type));
        }

        // Write the read bytes back to the buffer.
        *((uint16_t*)buffer) = htons(read_bytes.size());
        memcpy(buffer + sizeof(uint16_t), read_bytes.data(), read_bytes.size());

        // Send the response.
        size_t response_size = read_bytes.size() + sizeof(uint16_t);
        send(sock_fd, buffer, response_size, 0);
    }

    close(sock_fd);
    close(server_fd);
}

static const char* jesd_state_names[] = {
    "JESD204_OP_DEVICE_INIT",
    "JESD204_OP_LINK_INIT",
    "JESD204_OP_LINK_SUPPORTED",
    "JESD204_OP_LINK_PRE_SETUP",
    "JESD204_OP_CLK_SYNC_STAGE1",
    "JESD204_OP_CLK_SYNC_STAGE2",
    "JESD204_OP_CLK_SYNC_STAGE3",
    "JESD204_OP_LINK_SETUP",
    "JESD204_OP_OPT_SETUP_STAGE1",
    "JESD204_OP_OPT_SETUP_STAGE2",
    "JESD204_OP_OPT_SETUP_STAGE3",
    "JESD204_OP_OPT_SETUP_STAGE4",
    "JESD204_OP_OPT_SETUP_STAGE5",
    "JESD204_OP_CLOCKS_ENABLE",
    "JESD204_OP_LINK_ENABLE",
    "JESD204_OP_LINK_RUNNING",
    "JESD204_OP_OPT_POST_RUNNING_STAGE"
};
#define ARRAY_SIZE(arr) (sizeof(arr)/sizeof(arr[0]))

inline const char* get_jesd_state_name(const uint32_t jesd_state)
{
    if( jesd_state < ARRAY_SIZE(jesd_state_names) )
    {   
        return jesd_state_names[jesd_state];
    }
    return "JESD204_OP_UNKNOWN";
}

int SpiDaemonThread::execute_jesd(int jesd_state)
{
    HSB_LOG_INFO("JESD Transitioning to state {} - {}", jesd_state, get_jesd_state_name(jesd_state));

    switch (jesd_state) {
    case JESD204_OP_LINK_PRE_SETUP:
        jesd_config_.setup_clocks();
        break;
    case JESD204_OP_LINK_SETUP:
        jesd_config_.configure();
        break;
    case JESD204_OP_LINK_ENABLE:
        jesd_config_.run();
        break;
    default:
        // Currently ignore other state transitions.
        break;
    }

    // Return JESD204_STATE_CHANGE_DONE
    return 1;
}

//##########################################################
AD9986Config::AD9986Config(Hololink& hololink, const std::string &uuid)
    : hololink_(hololink)
    , jesd_configured_(false)
    , etile_(hololink)
    , altera_jesd_(false)
{
    // Determine which FPGA/Board we are running on
    if ( uuid == TERASIC_HOLOLINK_100G_UUID )
    {
        HSB_LOG_INFO("Altera JESD core.");
        // We are using the Altera JESD Core
        altera_jesd_ = true;
        // Base address of the ETILE Phy on the Altera JESD Implementation
        etile_.configure(0x80000000, 0x00080000, 8);
    }
    else
    {
        HSB_LOG_INFO("nVidia JESD core.");
        etile_.configure(0x05100000, 0x00010000 >> 2, 8);
    }
}

void AD9986Config::apply(void)
{
    spi_daemon_thread_.reset(new SpiDaemonThread(hololink_, *this));
    spi_daemon_thread_->run();

    while (!jesd_configured_.load(std::memory_order_relaxed)) {
        HSB_LOG_INFO("Waiting for JESD configuration to complete...");
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    HSB_LOG_INFO("JESD configuration complete");
}

void AD9986Config::host_pause_mapping(uint32_t mask)
{
    host_pause_mapping_mask_ = mask;
}

// Register defintions for Reset Sequence Controller used by the Altera JESD Core
#define ALTERA_JESD_RX_TX_AVS_RST   (0x0001<<0)
#define ALTERA_JESD_TX_PHY          (0x0001<<1)
#define ALTERA_JESD_TX_CORE         (0x0001<<2)

#define ALTERA_JESD_RX_PHY          (0x0001<<3)
#define ALTERA_JESD_RX_CORE         (0x0001<<4)
#define ALTERA_JESD_IO_PLL          (0x0001<<5)

// Mask of all the reset bits
#define ALTERA_JESD_RST_MASK        (ALTERA_JESD_RX_TX_AVS_RST | ALTERA_JESD_TX_PHY | ALTERA_JESD_TX_CORE | ALTERA_JESD_RX_PHY | ALTERA_JESD_RX_CORE | ALTERA_JESD_IO_PLL)

// Mask of all the reset bits except the IOPLL
#define ALTERA_JESD_ALL_RST        (ALTERA_JESD_RX_TX_AVS_RST | ALTERA_JESD_TX_PHY | ALTERA_JESD_TX_CORE | ALTERA_JESD_RX_PHY | ALTERA_JESD_RX_CORE)

// Register map for the Altera Reset Sequence Controller used by the Altera JESD Core
#define ALTERA_JESD_RST_REG           (0x60000014)

// Regsiter map for the Altera IOPLL Reconfig
#define ALTERA_JESD_IOPLL_RECONFIG    (0x80000000 + (0x400000<<2))

void AD9986Config::altera_jesd_reset(const uint32_t AssertRsts)
{
    // Create the reset value to write to the Altera JESD Reset Register
    // Upper 16 bits are the reset override (active high)
    // Lower 16 bits are the reset assert (active high)
    uint32_t rst = (ALTERA_JESD_RST_MASK<<16) | (AssertRsts & ALTERA_JESD_RST_MASK);

    hololink_.write_uint32(ALTERA_JESD_RST_REG, rst);
    HSB_LOG_DEBUG("Altera Tx Reset: {:08x} - {:08x}", ALTERA_JESD_RST_REG, rst);
}

void AD9986Config::power_on()
{
    HSB_LOG_INFO("JESD::power_on");

    // First check the XCVR's refclk. Switch back if not on refclk 1 before starting config.
    // Only check the first XCVR b/c that should indicate which clock all XCVRs are using.
    // This is a generic function that is associated with the Stratix 10 FPGA E-Tile Transceiver.
    auto refclk = etile_.read_refclk(0);

    if (refclk != 1) {
        HSB_LOG_INFO("Switching XCVRs back to refclk 1");
        for (size_t i = 0; i < 8; ++i) {
            etile_.task_refclk_sw(i, 1, 0);
        }
    }

    if ( altera_jesd_ )
    { 
        // Let's reset the Altera JESD Core
        HSB_LOG_INFO("Resetting Altera JESD core");
        // Assert all resets to the Altera JESD Core
        altera_jesd_reset(ALTERA_JESD_ALL_RST);
        // Bring the AVS interface out of reset
        altera_jesd_reset(ALTERA_JESD_RX_PHY | ALTERA_JESD_TX_PHY | ALTERA_JESD_RX_CORE | ALTERA_JESD_TX_CORE);
    }

    // Cycle the MxFE power signals
    //  - These signals are connected to circuits/chips on the ADI board.
    //  - The time delays are here to cover a worst-case power ramp down/up
    HSB_LOG_INFO("Cycling MxFE Power Signals");

    hololink_.write_uint32(0x0000000C, 0x0);
    std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    hololink_.write_uint32(0x0000000C, 0xF);
    std::this_thread::sleep_for(std::chrono::milliseconds(1000));
}

void AD9986Config::setup_clocks()
{
    HSB_LOG_INFO("JESD::setup_clocks");

    if( altera_jesd_ )
    {
        // Assert all resets to the Altera JESD Core
        altera_jesd_reset(ALTERA_JESD_ALL_RST);
        // Release AVS reset
        altera_jesd_reset(ALTERA_JESD_RX_PHY | ALTERA_JESD_TX_PHY | ALTERA_JESD_RX_CORE | ALTERA_JESD_TX_CORE);

        // Release Phy resets
        altera_jesd_reset(ALTERA_JESD_RX_CORE | ALTERA_JESD_TX_CORE);
    }

    // Switch refeclks over to GBTCLK0
    //  - This switches the JESD XCVR reference clock input to the clock from the HMC7044
    //    This is a generic function that is associated with the Stratix 10 FPGA E-Tile Transceiver.
    for (int i = 0; i < 8; i++) {
        if (!etile_.task_refclk_sw(i, 2, 0)) {
            HSB_LOG_INFO("RefClk Switch FAILED for channel:{}", i);
            return;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(200));
    }

    if( altera_jesd_ )
    {
        // Force a IOPLL recalibration
        hololink_.write_uint32(ALTERA_JESD_IOPLL_RECONFIG, 0x0); 
    }
    else
    {
        // Reset the JESD
        //- This is to ensure the nvidia JESD IP is reset after clocks have been stabilized
        hololink_.write_uint32(0x05300000, 0x1);
        hololink_.write_uint32(0x05300000, 0x0);
    }
}

void AD9986Config::configure()
{
    HSB_LOG_INFO("JESD::configure");

    if ( !altera_jesd_ ) // nvidia jesd core requires the packetizer
    {
        // Packetizer Programming
        hololink_.write_uint32(0x0100000C, 0x10000001);
        hololink_.write_uint32(0x01000004, 0x00000000);
        hololink_.write_uint32(0x01000008, 0xFFFFFFFF);
        hololink_.write_uint32(0x01000004, 0x00000070);
        hololink_.write_uint32(0x01000008, 0x00000001);
    }

    // Map Pause to ethernet interface
    hololink_.write_uint32(0x0120000C, host_pause_mapping_mask_);

    if( !altera_jesd_ )
    {
        // Configure the JESD IP
        //- This configures the nvidia JESD IP in the specific mode that the original MxFE demo was configured for.
        //- I would imagine these functions would be made more generic to support different JESD modes in the future.
        configure_nvda_jesd_tx();
        configure_nvda_jesd_rx();
    }
    else
    {
        // Clocks are stable at this point
        // Reset the JSED core to cleanly bring it up
        HSB_LOG_INFO("JESD::Reset Altera JESD");
        altera_jesd_reset(ALTERA_JESD_ALL_RST);
    
        // Release AVS reset
        HSB_LOG_DEBUG("JESD::release avs");
        altera_jesd_reset(ALTERA_JESD_RX_PHY | ALTERA_JESD_TX_PHY | ALTERA_JESD_RX_CORE | ALTERA_JESD_TX_CORE);
        
        // Release Phy resets
        HSB_LOG_DEBUG("JESD::release PHYs");
        altera_jesd_reset(ALTERA_JESD_RX_CORE | ALTERA_JESD_TX_CORE);

        // Bring the Rx and Tx out of reset
        HSB_LOG_DEBUG("JESD::release protocol cores");
        altera_jesd_reset(0);
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(1000));

    if ( altera_jesd_ )
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    }
    else
    {
        // Enable the TX data (input to the JESD IP) and the RX data (output from the JESD IP)
        hololink_.write_uint32(0x05300000, 0x10);
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    }
}

void AD9986Config::run()
{
    HSB_LOG_INFO("JESD::run");

    if ( altera_jesd_ )
    {
        // // Cycle the RX Link
        // altera_jesd_reset(ALTERA_JESD_RX_CORE);
        // std::this_thread::sleep_for(std::chrono::milliseconds(1000));
        // altera_jesd_reset(0);
        // std::this_thread::sleep_for(std::chrono::milliseconds(1000));
    }
    else
    {
        // Cycle the RX Link
        //  - This cycles the RX link on the nvidia JESD IP. It's kinda like a reset but not completely.
        //  - TODO: Determine if sleeps are needed here.
        hololink_.write_uint32(0x05039000, 0x0);
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
        hololink_.write_uint32(0x05039000, 0x1);
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));

        // Write the rx lane status to clear errors
        //  - Clears some RX lane status that we are interested in.
        for (int i = 0x0; i < 0x800; i += 0x100) {
            uint32_t address = 0x0503C008 + i;
            hololink_.write_uint32(address, 0xff);
        }

        // Read the status back
        //  - Reads back lane 64B66B status.
        //  - Used to check SH/EMB/User lock status of JESD lanes.
        //  - Read the gearbox status to check any overflow conditions.
        //  - TODO: Intelligently assess the status based on what we read back...
        HSB_LOG_DEBUG("LANE 64B66B Status:");
        for (int i = 0x0; i < 0x800; i += 0x100) {
            uint32_t address = 0x0503C008 + i;
            HSB_LOG_DEBUG("address:{:#x}, value:{:#x}", address, hololink_.read_uint32(address));
        }
        HSB_LOG_DEBUG("UPHY OVERFLOW Status:");
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x0502102C));
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x05021448));
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x05021864));
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x05021C80));
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x0502209C));
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x050224B8));
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x050228D4));
        HSB_LOG_DEBUG("value:{:#x}", hololink_.read_uint32(0x05022CF0));

        hololink_.write_uint32(0x05300000, 0x30); // Enable RX
    }
    hololink_.write_uint32(0x01200000, 0x3); // Enable TX

    jesd_configured_.store(true, std::memory_order_release);
}

void AD9986Config::configure_nvda_jesd_tx(void)
{
    if( altera_jesd_ )
    {
        return;
    }

    uint32_t tx_base = 0x05040000;

    // Configure TX link parameters
    hololink_.write_uint32(tx_base + 0x39028, 0x0000A802); // CNTRL3

    // Configure 64B66B
    hololink_.write_uint32(tx_base + 0x39030, 0x00000022);

    // Configure sysref control
    hololink_.write_uint32(tx_base + 0x11014, 0x0003C032);

    // Configure TX lane active
    hololink_.write_uint32(tx_base + 0x10018, 0x000000FF); // All lanes active

    // Enable the link
    hololink_.write_uint32(tx_base + 0x39000, 0x00000001);
}

void AD9986Config::configure_nvda_jesd_rx(void)
{
    if( altera_jesd_ )
    {
        return;
    }
    uint32_t rx_base = 0x05000000;

    // Configure RBD per-lane
    hololink_.write_uint32(rx_base + 0x13008, 0x0000003f); // Calculated from sequence

    // Configure RX lane active
    hololink_.write_uint32(rx_base + 0x10018, 0x000000FF); // All lanes active

    // Configure sysref control
    hololink_.write_uint32(rx_base + 0x11014, 0x0003C032);

    // Configure RX link parameters
    hololink_.write_uint32(rx_base + 0x39028, 0x0000A802); // CNTRL3

    // Configure 64B66B
    hololink_.write_uint32(rx_base + 0x39030, 0x00000022);

    // Enable the link
    hololink_.write_uint32(rx_base + 0x39000, 0x00000001);
}

} // namespace hololink
