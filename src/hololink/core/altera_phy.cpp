/**
 * SPDX-FileCopyrightText: Copyright (c) Altera Corporation
 * SPDX-License-Identifier: Apache-2.0
 */
#include "altera_phy.hpp"
#include "logging_internal.hpp"

namespace hololink {
AlteraETile::AlteraETile(Hololink& hololink)
    : hololink_(hololink)
{
    
}

void AlteraETile::configure(const uint32_t base_addr, const uint32_t channel_offset, const uint32_t max_channels)
{
    etile_base_ = base_addr;
    etile_channel_offset_ = channel_offset;
    max_channels_ = max_channels;
}

uint8_t AlteraETile::read_refclk(const uint32_t channel)
{
    if( channel < max_channels_ )
    {
        return read_uint8(channel, 0xEC) & 0xF;
    }
    else
    {
        return 0;
    }
}

bool AlteraETile::task_refclk_sw(const uint32_t channel, const uint32_t refclk, const uint32_t hwseq)
{
    HSB_LOG_DEBUG("SWITCHING TO REFCLK: {},ON CHANNEL: {}", refclk, channel);
    
    bool loop_status = false;
    uint32_t retry_cnt = 0;
    uint32_t ch_offset = channel * 0x00010000 + 0x05100000;
    uint32_t data = refclk;

    // Put a retry around this for when the refclk sw fails.
    // Typically a PMA analog reset will fix it.
    while (!loop_status && retry_cnt < 2) {
        if (!task_set_pma_attribute(channel, 0x0030, 0x0003)) { // Switch to refclkB
            HSB_LOG_INFO("Set PMA Attribute Switch to RefClk B FAILED in RefClk Switch");
            HSB_LOG_INFO("Trying PMA Analog Reset");
            task_pma_analog_reset(channel);
            retry_cnt++;
            std::this_thread::sleep_for(std::chrono::milliseconds(1000));
            continue;
        }

        // Switch the Phy clock
        write_uint8(channel, 0xec, (uint8_t)data);

        if (!task_set_pma_attribute(channel, 0x0030, 0x0000)) { // Switch to refclkA
            HSB_LOG_INFO("Set PMA Attribute Switch to RefClk A FAILED in RefClk Switch");
            HSB_LOG_INFO("Trying PMA Analog Reset");
            task_pma_analog_reset(channel);
            retry_cnt++;
            std::this_thread::sleep_for(std::chrono::milliseconds(1000));
            continue;
        }

        task_pma_analog_reset(channel);
        loop_status = true;
    }

    return loop_status;
}

bool AlteraETile::task_set_pma_attribute(const uint32_t channel, const uint32_t code, const uint32_t data)
{
    bool failed = false;
    uint32_t tries = 0;
    uint32_t rd_data;

    // Added retry method based on PMA_functions_ETILE.c from:
    //  https://community.intel.com/t5/FPGA-Wiki/High-Speed-Transceiver-Demo-Designs-Intel-Stratix-10-TX-Series/ta-p/735133
    //  See PMA_functions_ETILE.zip
    while (tries < 5) {
        HSB_LOG_DEBUG("Setting PMA Attribute:{:#} to:{:#} for channel{}", code, data, channel);

        failed = false;
        uint32_t attribute = ((code & 0xffff) << 16) | (data & 0xffff);

        // Write offset 0x8A to 0x80 to clear the bit indicating successful PMA attribute transmission
        write_uint8(channel, 0x8A, 0x80);

        // Write the attribute to 0x84, 0x85, 0x86, 0x87
        write_uint32(channel, 0x84, attribute);

        // Write offset 0x90 to issue the PMA attribute
        write_uint8(channel, 0x90, 0x01);
        
        std::shared_ptr<Timeout> timeout = std::make_shared<Timeout>(1.f);

        while( !failed ) {
            // Read the value of offset 0x8A and mask bit 7
            rd_data = read_uint8(channel, 0x8a) & 0x80;
            if( rd_data == 0x80 ) {
                break;
            } else if ( !timeout->retry() ) {
                failed = true;
            }
        }

        timeout = std::make_shared<Timeout>(1.f);
        while( !failed ) {
            rd_data = read_uint8(channel, 0x8B) & 0x1; 
            if( rd_data == 0x0 ){
                break;
            }
            else if (!timeout->retry() ){
                failed = true;
            }
        }

        uint32_t result = read_uint32(channel, 0x88);

        if (failed) {
            HSB_LOG_DEBUG("Retrying PMA Attribute due to error.");
            tries++;
        } else {
            HSB_LOG_DEBUG("Retry Count for PMA code:{:#} with data:{:#} :{}", code, data, tries);
            break;
        }
    }

    if (failed) {
        HSB_LOG_ERROR("\tSet PMA attribute failed after{} attempts.", tries);
        return false;
    } else {
        return true;
    }
}

void AlteraETile::task_pma_analog_reset(const uint32_t channel)
{
    uint32_t rd_data = 0;

    HSB_LOG_INFO("Issuing PMA Analog Reset for Channel:{}", channel);

    for (uint32_t i = 0; i < 3; i++) {
        uint32_t addr = (0x200 + i);
        write_uint8(channel, addr, 0x00);
    }

    write_uint8(channel, 0x200 + 0x3, 0x81);

    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    rd_data = read_uint8(channel, 0x200+7) & 0xFF;

    // Check 0x207 is 0x80; if so, return
    if (rd_data != 0x80)
        return;

    rd_data = read_uint8(channel, 0x95) | 0x20;
    write_uint8(channel, 0x95, rd_data);

    write_uint8(channel, 0x91, 0x01);
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
}

// Private Functions
#define ADDR(channel, reg) (etile_base_ + (((etile_channel_offset_*channel)+reg)*4))
uint8_t AlteraETile::read_uint8(const uint32_t channel, const uint32_t reg)
{
    // Altera implementation has DWORD access only to ETile/PMA
    uint32_t addr = ADDR(channel, reg);
    uint32_t value = hololink_.read_uint32(addr);
    return value & 0xff;
}

void AlteraETile::write_uint8(const uint32_t channel, const uint32_t reg, const uint8_t value)
{
    uint32_t addr = ADDR(channel, reg);
    uint32_t current = (uint32_t)value;
    hololink_.write_uint32(addr, current);
}

uint32_t AlteraETile::read_uint32(const uint32_t channel, const uint32_t reg)
{
    uint32_t result = 0;
    for( uint32_t i=0; i<4; i++ )
    {
        uint8_t value = read_uint8(channel, reg+i);
        result = result | (value << (8*i));
    }
    return result;
}

void AlteraETile::write_uint32(const uint32_t channel, const uint32_t reg, const uint32_t value)
{
    for( uint32_t i=0; i<4; i++ )
    {
        write_uint8(channel, reg+i, (value >> (8*i))&0xff);
    }
}

} // namespace hololink
