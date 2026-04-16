# Holoscan Sensor Bridge IMX678 MIPI to 10GbE System Example Design for Agilex™ 5 Devices

## Overview

The Holoscan Sensor Bridge IMX678 MIPI to 10GbE System Example Design for Agilex™ 5 Devices demonstrates an implementation of using industry-standard Mobile Industry Processor Interface (MIPI) D-PHY and MIPI CSI-2 interface on Agilex™ 5 FPGAs to integrate to a Holoscan processing flow.

The MIPI interface supports up to 2.5Gbps per lane and up to 8x lanes per MIPI
interface, enabling seamless data reception from multiple 4K image sensors to
the FPGA fabric for further processing. Each MIPI CSI-2 IP instance converts
pixel data to AXI4-Streaming outputs, enabling connectivity to other IP cores
within the Altera® Video and Vision Processing (VVP) Suite.

The FPGA design comprises a MIPI D-PHY and two MIPI CSI-2 interfaces connected to the NVIDIA Holoscan Sensor Bridge IP and the Altera® GTS Ethernet Hard IP.

A loopback channel has been implemented to allow the user to experiment with data transfer without requiring MIPI cameras.

The software comprises a number of demonstration applications running within [NVIDIA Holoscan Sensor Bridge SDK](https://docs.nvidia.com/holoscan/sensor-bridge/latest/index.html).

<p align="center">
<img src="./assets/HSB_MIPI_10GbE_Overview.png" alt="Block diagram showing the HSB MIPI to 10GbE system architecture with MIPI camera inputs connecting through D-PHY and CSI-2 interfaces to FPGA fabric, then through Holoscan Sensor Bridge IP and Low Latency Ethernet 10G MAC IP to network output"><br>
<strong>High-Level Block Diagram of the Holoscan Sensor Bridge System Example Design</strong>
</p>

---

## Table of Contents

- [Overview](#overview)
- [Running the Demonstrations](#running-the-demonstrations)
  - [System Setup](#system-setup)
  - [Demo Applications](#demo-applications)
- [RTL Design](#rtl-design)
  - [Design Overview](#design-overview)
  - [Camera Over Ethernet](#camera-over-ethernet)
  - [License Requirements](#license-requirements)
  - [NVIDIA Holoscan Sensor Bridge IP Requirements](#nvidia-holoscan-sensor-bridge-ip-requirements)
  - [Platform Designer HSB IP Component](#platform-designer-hsb-ip-component)
  - [Project Structure](#project-structure)
  - [QSF Overview](#qsf-overview)
  - [Design Hierarchy](#design-hierarchy)
  - [Clock Domains](#clock-domains)
  - [Design Subsystems](#design-subsystems)
  - [Register Map](#register-map)
  - [Top Level IO](#top-level-io)
  - [Resource Utilisation](#resource-utilisation)
  - [Building the Design](#building-the-design)
- [Hardware Requirements](#hardware-requirements)
- [Hardware Setup](#hardware-setup)
  - [Setting Up your Modular Development Board](#setting-up-your-modular-development-board)
  - [Board and NVIDIA Host System Setup](#board-and-nvidia-host-system-setup)
- [Programming the FPGA](#programming-the-fpga)
  - [Pre-Built Binaries](#pre-built-binaries)
  - [Program the FPGA SOF](#program-the-fpga-sof)
  - [Program the FPGA JIC](#program-the-fpga-jic)

---

## Running the Demonstrations

### System Setup

Before running the demonstrations ensure that you have

- [Set up the Agilex™ 5 Development Kit](#setting-up-your-modular-development-board).
- [Set up the NVIDIA host system](#board-and-nvidia-host-system-setup).
- [Programmed the FPGA](#programming-the-fpga).

### Demo Applications

The following example applications are available to demonstrate the Holoscan Sensor Bridge IMX678 MIPI to 10GbE System Example Design for Agilex™ 5 Devices.

#### Build the Demo Docker Container
Build the holoscan sensor bridge demonstration container. 

For systems with dGPU, such as IGX Orin with a discreate GPU and OS configured as dGPU,

```bash
cd <holoscan sensor bridge>
sh docker/build.sh --dgpu
```

For systems with iGPU,
```bash
cd <holoscan sensor bridge>
sh docker/build.sh --igpu
```

#### To run a demo application, start the demo container
```bash
cd <holoscan sensor bridge>
sh docker/demo.sh
```

#### From within the Demo container run one of the following demos:
* Simple Playback Example
```bash
python3 examples/linux_agx5_player.py
```

* Stereo Playback Example

```bash
python3 examples/linux_agx5_player_stereo.py
```

* YOLOv8 Body Pose Example

[Follow instructions to download YOLOv8 ONNX Model](https://docs.nvidia.com/holoscan/sensor-bridge/latest/examples.html#running-the-imx274-body-pose-example)
```bash
python3 examples/linux_body_pose_estimation_agx5.py
```

* TAO PeopleNet Example

[Follow instructions to download TAO PeopleNet Model](https://docs.nvidia.com/holoscan/sensor-bridge/latest/examples.html#running-the-imx274-tao-peoplenet-example)
```bash
python3 examples/linux_tao_peoplenet_agx5.py
```

---

## RTL Design

### Design Overview

This project contains the necessary files and collateral to build the Holoscan IMX678 Sensor Bridge MIPI to 10GbE System Example Design for Agilex™ 5 Devices. It has been built using Altera® Quartus® Prime Pro Edition version 26.1.

For build instructions refer to [Building the Design](#building-the-design).

The below block diagram shows the data flow through the top level Platform Designer design, clock and reset systems are not shown.

<p align="center">
<img src="assets/pd_top.png" alt="Dual MIPI Ingest Block Diagram"><br>
<strong>Data Path Diagram of the Holoscan Sensor Bridge System Example Design</strong>
</p>

---

### Camera Over Ethernet

The Thor AGX system supports Camera Over Ethernet hardware acceleration and a hardened ISP. The FPGA design supports these features however they are currently untested.

To support the hardware ISP using COE on Thor the HSB IP video SIFs have been configured with the packetizer enabled and the following settings:

```
SIF_RX_PACKETIZER_EN   1
SIF_RX_SORT_RESOLUTION 2
SIF_RX_VP_COUNT        1
SIF_RX_VP_SIZE         64
SIF_RX_NUM_CYCLES      3
```

> [!NOTE]
> This packetizer configuration increases the [logic utilisation](#resource-utilisation) by approximately 7k ALMs for each SIF with this configuration.

---

### License Requirements

Free licenses for MIPI D-PHY IP and MIPI CSI-2 IP must be downloaded and installed.

---

### NVIDIA Holoscan Sensor Bridge IP Requirements

The Holoscan Sensor Bridge IP must be downloaded and its location set to the NV_HSB_IP_DIR environment variable. If this variable is not set the design will default to an expected, relative location. This expected location is as per the holoscan-sensor-bridge repository structure:

```
holoscan-sensor-bridge
└── fpga
    ├── nv_hsb_ip 
    └── altera
        └── AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE
```

For detailed information about the NVIDIA HSB IP please refer to the [NVIDIA documentation](https://docs.nvidia.com/holoscan/sensor-bridge/latest/fpga_index.html).

---

### Platform Designer HSB IP Component

Altera® has created a Platform Designer component to facilitate easy configuration and integration of the NVIDIA HSB IP. The component allows the user to set all the macros defined in the IP Integration section of the HSB IP documentation and auto-generates the header file that is used by the IP. https://docs.nvidia.com/holoscan/sensor-bridge/latest/ip_integration.html. The values that can be selected are limited to what's specified in the documentation.

When generated the PD component outputs a SystemVerilog wrapper which instantiates the NVIDIA HOLOLINK_top entity. This wrapper only instantiates interfaces that are enabled and safe states any that require it.

#### Key Platform Designer Component Features

##### Register Initialisation File

The HSB IP header file allows registers to be initialised through an array of addresses and data. As the header is generated by the PD component it provides the user with the ability to select an initialisation file in either text or Intel Hex format. The contents of this initialisation file are incorporated into the HSB IP header file. In this example design the nv_hsb_ip_reginit.txt file is found in the top level of the project and can be referenced as an example.

##### Mixed Data Path Widths

The HSB IP allows the user to specify different data widths for individual SIFs with a requirement to tie off the unused tdata and tkeep bits. For example:

`DATAPATH WIDTH = 128, SIF_RX_WIDTH[0] = 64 and SIF_RX_WIDTH[1] = 128`

The generated wrapper automatically ties off the unused signals and the user is presented with a bus that does not need further manipulation.

##### SPI0 Instantiation

The HSB SW drivers require SPI0 to be instantiated inside the HSB IP however the user may not have any SPI peripherals. When SPI quantity is set to 0 the component sets the header value to 1 and safe states the bus in the wrapper. The user does not see the SPI bus but the driver will find the instantiated controller.

##### Enumeration Settings

The HSB IP allows the user to select between an external enumeration EEPROM or through RTL port pins. The PD component provides some further configurability. Given that no external EEPROM is selected the user can choose to export the ID pins from the wrapper as a single conduit or as separate fields. Alternatively, the user can choose to set the values in the component directly and these are hard coded into the wrapper - this feature is useful for prototyping but does not allow for uniquification of MAC and Serial Numbers.

Note that if an external enumeration EEPROM is selected, this device is expected to be on I2C bus 0.

---

### Project Structure

This example design was generated using the Modular Design Toolkit (MDT) flow. This flow defines two types of subsystems, "shell" and "user". Shell subsystems are core MDT subsystems that can be found in the GitHub repository, user subystems are created by end users. Directories are commonly subdivided into these two categories. The following table contains an overview of the committed directory structure:

|Folder|Content Description|
|:-----:|:-----:|
|non_qpds_ip|Non Quartus IP source that is used in the design |
|rtl| Design source files, *.v, *.qsys and *.ip, subdivided into shell and user |
|sdc| Design constraints files for both shell and user subsystems |
|scripts| Build scripts from the MDT flow |
|quartus| Quartus project (QPF) and settings (QSF) files |
|quartus/shell| QSF files specific to shell subsystems |
|quartus/user| QSF files specific to user subsystems |
|quartus/output_files| location of built sof as well as all outputs generated by build flow e.g. reports |

---

### QSF Overview

The MDT flow produces QSFs per subsystem, the result is that there are several in the design in the following structure.

```
quartus
├── AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.qsf                   # Main project QSF, calls submodule QSFs
├── shell
│   ├── AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE_supplemental.qsf  # Additional project settings
│   ├── board_subsystem.qsf                                         # Board subsystem IO and source assignments
│   └── clock_subsystem.qsf                                         # Clock subsystem IO and source assignments
└── user
    ├── eth.qsf                                                     # GTS Ethernet subsystem IO assignments
    ├── gts_eth_subsystem.qsf                                       # GTS Ethernet subsystem source assignments
    ├── hsb.qsf                                                     # HSB subsystem IO assignments
    ├── hsb_subsystem.qsf                                           # HSB subsystem source assignments
    ├── mipi.qsf                                                    # MIPI subsystem IO assignments
    └── mipi_subsystem.qsf                                          # MIPI subsystem source assignments
```

If a user is modifying the design for their own purposes these QSFs could be combined into a single file if desired.

---

### Design Hierarchy
```
AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.v (Project Top Level)
    └── AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE_qsys.qsys (Top Level Platform Designer)
            ├── board_subsystem.qsys
            ├── clock_subsystem.qsys
            ├── gts_eth_subsystem.qsys
            ├── hsb_subsystem.qsys
            └── mipi_subsystem.qsys
```

---

### Clock Domains

This design operates primarily in three clock domains:

|Clock Name|Source|Frequency (MHz)|Usage|
|:-----:|:-----:|:-----:|:-----:|
| Board Clock | Board reference clock| 100 | Control and Status Registers | 
| GTS Ethernet Clock | GTS IP | 161.1328125 | Host Interface | 
| Core Video Clock | IOPLL (Board clock source) | 300 | Video pipeline and Sensor Interface | 

The MIPI inputs are synchronised onto the core video clock domain within the MIPI CSI-2 IP cores. The Holoscan Sensor Bridge IP synchronises the SIF inputs onto the HIF domain.

---

### Design Subsystems

#### `board_subsystem` (shell)

**Role:** Board-level integration: entry for the board clock and asynchronous reset, provides structured reset sequencing for the rest of the design.

**Functions:**

- Clock bridge from the board clock domain.
- Push-button reset handling and related reset generators.
- Board initialization logic and reset bridges feeding a **board reset controller**.

**Top-level I/O:** `clk_100_mhz` and `rst_pb_n`


#### `clock_subsystem` (shell)

**Role:** **Clock generation and reset distribution** for the design.

**Functions:**

- Input clock and reset bridges and reset control.
- **IOPLL** for on-chip generated clocks.
- Locked-status shims, PLL lock / reference-clock reset synchronization, **reset extenders**, and general reset sync logic providing clean, timed resets.

**Top-level I/O:** `none`

#### `gts_eth_subsystem` (user)

**Role:** **10 Gb Ethernet** using **GTS** transceiver IP and related support logic.

**Functions:**

- Ethernet **GTS** MAC/PHY stack.
- Supporting **GTS Reset Sequencer** and **GTS System PLL** IP.
- Ethernet Clock reset synchronization for user logic.
- Exported status and control signals for PLL lock, lane stability, PCS ready, pause/PFC, etc.

**Top-level I/O:** SFP **serial TX/RX** differential pairs, `refclk_eth`, and `sfp_tx_disable` (tied `low`)


#### `hsb_subsystem` (user)

**Role:** **Holoscan Sensor Bridge subsystem** — instantiates HSB IP component and provides clocking and format adapters where necessary.

> [!NOTE]
> The NVIDIA HSB IP source location is set via `NV_HSB_IP_DIR` environment variable, see [NVIDIA Holoscan Sensor Bridge IP Requirements](#nvidia-holoscan-sensor-bridge-ip-requirements).

**Functions:**

- Core **HSB** IP instantiation
- Host Interface Avalon Streaming <-> AXI-Streaming converters **(AVST/AXIS shims)**.
- Sensor Interface adaptation - **CSI packers** for aligned data packing, AXIS shims for tuser/tkeep deltas
- **VVP** FIFOs and shims for pipeline buffering.
- **Avalon-MM bridges** for register/control access to design logic.
- Clock/reset bridges for CPU-side, HIF, and **SIF** RX/TX clock domains.
- **System ID** for design generation timestamping


**Top-level I/O:** 2x I2C master interfaces (open-drain handling in the top-level Verilog).


#### `mipi_subsystem` (user)

**Role:** **MIPI CSI-2** receive — two independent links using a single **D-PHY**.

**Functions:**

- Single **MIPI D-PHY** instance configured to support two 4 lane Rx interfaces.
- Two **MIPI CSI-2** instances configured to support RAW8, RAW10 and RAW12, outputting 4 Pixels in Parallel.
- **PIO** for external side-band connectivity (unused in this design).

**Top-level I/O:** Per-link D-PHY **data and clock** lanes, `mipi_ref_clk_0`, and **RZQ** calibration pin to the D-PHY IP.

---

### Register Map

Two Peripheral Buses are used in this design, each is converted to Avalon-MM using bridges within the hsb_subsystem. Though this access exists, the control SW does not write or read any of these registers in the provided examples.

|APB Bus| HW Address|Address Offset|IP|
|:-----:|:-----:|:-----:|:-----:|
|0|0x1000_0000|0x0000|MIPI CSI-2 Receiver 0|
|0|0x1000_0000|0x1000|MIPI CSI-2 Receiver 1|
|0|0x1000_0000|0x8000|MIPI D-PHY|
|0|0x1000_0000|0x9000|MIPI Control PIO|
|1|0x2000_0000|0x0000|System ID|

---

### Top Level IO

| Port | Description | `.qsf` file | Pin(s) | Assignments |
|------|-------------|-------------|--------|-------------|
| `clk_100_mhz` | 100 MHz board reference clock | `board_subsystem.qsf` | PIN_BK31 | `GLOBAL_SIGNAL ON` (entity `top`); `IO_STANDARD` 3.3-V LVCMOS |
| `rst_pb_n` | Active-low board reset (push-button) | `board_subsystem.qsf` | PIN_BU28 | `IO_STANDARD` 3.3-V LVCMOS |
| `user_pb_n` | User push-button input (unused) | `board_subsystem.qsf` | PIN_BW19 | `IO_STANDARD` 3.3-V LVCMOS |
| `refclk_eth` | GTS Ethernet reference clock | `eth.qsf` | PIN_AY120 | `IO_STANDARD` CURRENT MODE LOGIC (CML) |
| `serial_i_rx_serial_data` | SFP RX serial data | `eth.qsf` | PIN_AK135 | `IO_STANDARD` HIGH SPEED DIFFERENTIAL I/O |
| `serial_i_rx_serial_data_n` |  SFP RX serial data complement | `eth.qsf` | PIN_AK133 | `IO_STANDARD` HIGH SPEED DIFFERENTIAL I/O |
| `serial_o_tx_serial_data` | SFP TX serial data | `eth.qsf` | PIN_AL129 | `IO_STANDARD` HIGH SPEED DIFFERENTIAL I/O |
| `serial_o_tx_serial_data_n` | SFP TX serial data complement | `eth.qsf` | PIN_AL126 | `IO_STANDARD` HIGH SPEED DIFFERENTIAL I/O |
| `sfp_tx_disable` | SFP cage TX disable (tied low) | `eth.qsf` | PIN_BE29 | `IO_STANDARD` 3.3-V LVCMOS; `TERMINATION` OFF |
| `i2c_0_scl` | HSB I2C bus 0 clock (open-drain) | `hsb.qsf` | PIN_BU109 | `IO_STANDARD` 3.3-V LVCMOS; `AUTO_OPEN_DRAIN_PINS` ON; `TERMINATION` OFF |
| `i2c_0_sda` | HSB I2C bus 0 data (open-drain) | `hsb.qsf` | PIN_BK109 | `IO_STANDARD` 3.3-V LVCMOS; `AUTO_OPEN_DRAIN_PINS` ON; `TERMINATION` OFF |
| `i2c_1_scl` | HSB I2C bus 1 clock (open-drain) | `hsb.qsf` | PIN_CL130 | `IO_STANDARD` 1.8-V LVCMOS; `TERMINATION` OFF |
| `i2c_1_sda` | HSB I2C bus 1 data (open-drain) | `hsb.qsf` | PIN_CL128 | `IO_STANDARD` 1.8-V LVCMOS; `TERMINATION` OFF |
| `LINK0_dphy_io_dphy_link_d_p` | MIPI D-PHY link 0 data lanes (4 lanes) | `mipi.qsf` | [0] CC92; [1] CF92; [2] CF81; [3] CA81 | `IO_STANDARD` DPHY (per bit) |
| `LINK0_dphy_io_dphy_link_d_n` | MIPI D-PHY link 0 data lane complements | `mipi.qsf` | [0] CA92; [1] CH92; [2] CH81; [3] CC81 | `IO_STANDARD` DPHY (per bit) |
| `LINK0_dphy_io_dphy_link_c_p` | MIPI D-PHY link 0 clock | `mipi.qsf` | PIN_CH89 | `IO_STANDARD` DPHY |
| `LINK0_dphy_io_dphy_link_c_n` | MIPI D-PHY link 0 clock complement | `mipi.qsf` | PIN_CF89 | `IO_STANDARD` DPHY |
| `LINK1_dphy_io_dphy_link_d_p` | MIPI D-PHY link 1 data lanes (4 lanes) | `mipi.qsf` | [0] BR89; [1] BR92; [2] BR81; [3] BR78 | `IO_STANDARD` DPHY (per bit) |
| `LINK1_dphy_io_dphy_link_d_n` | MIPI D-PHY link 1 data lane complements | `mipi.qsf` | [0] BU89; [1] BU92; [2] BU81; [3] BU78 | `IO_STANDARD` DPHY (per bit) |
| `LINK1_dphy_io_dphy_link_c_p` | MIPI D-PHY link 1 clock | `mipi.qsf` | PIN_BW89 | `IO_STANDARD` DPHY |
| `LINK1_dphy_io_dphy_link_c_n` | MIPI D-PHY link 1 clock complement | `mipi.qsf` | PIN_CA89 | `IO_STANDARD` DPHY |
| `mipi_ref_clk_0` | Reference clock for MIPI CSI-2 / D-PHY IP | `mipi.qsf` | PIN_BM71 (comment IOBANK_3B_B) | `IO_STANDARD` 1.2V TRUE DIFFERENTIAL SIGNALING |
| `mipi_rzq` | External RZQ calibration resistor for the MIPI I/O bank | `mipi.qsf` | PIN_BH69 | `IO_STANDARD` 1.2 V |

---

### Resource Utilisation

The built resource utilisation for this design is below and includes breakdown per subsystem. This could be reduced by approximately 14k ALMs should [COE](#camera-over-ethernet) with hardware ISP not be required:

|Subsystem| ALMs|Registers|M20ks|DSPs|
|:-----:|:-----:|:-----:|:-----:|:-----:|
|Board|16|32|0|0|
|Clock|12|73|0|0|
|GTS Ethernet|1024|1455|1|0|
|HSB|27087|84878|52|4|
|MIPI|9920|22673|23|0|
|***Total***|***38059***|***109111***|***76***|***4***|

---

### Building the Design

The example design can be built in two ways, using a build script or opening the project in Quartus® and building using the GUI. Under both methods the built FPGA bitstream `AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.sof` is located in the `quartus/output_files` directory.
<br>

#### Script build

- Navigate to the `AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE/scripts` directory:

```bash
quartus_sh -t build_shell.tcl -hw_compile
```

#### Quartus® GUI Build

- Open the project in Quartus® Prime Pro
- On the Compilation Dashboard select "Compile Design"

#### JIC Generation

The SOF file can be converted to a non-volatile JIC to be programmed into the QSPI flash.

- Navigate to the `AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE/quartus/output_files` directory:

```bash
quartus_pfg -c -o device=QSPI02G -o mode=ASX4 -o flash_loader=A5ED065BB32AE6SR0 AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.sof AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.jic
```

---

## Hardware Requirements

* [Agilex™ 5 FPGA E-Series 065B Modular Development Kit (ES) - MK-A5E065BB32AES1](https://www.altera.com/products/devkit/po-3001/agilex-5-fpga-and-soc-e-series-modular-development-kit-es)

> [!IMPORTANT]
> The MK-A5E065BB32AES1 has been discontinued per [PDN2513](https://docs.altera.com/v/u/docs/869016/pdn2513-product-discontinuance-of-selected-fpga-development-kit-ordering-codes), replaced by MK-A5E065BB32AEA.

<br>

<p align="center">
<img src="assets/Agx5-MDK.png" alt="Agx5-MDK"><br>
<strong>Agilex™ 5 FPGA E-Series 065B Modular Development Kit</strong>
</p>

* 1 or 2 [Framos FSM:GO IMX678C Camera Modules](https://www.framos.com/en/fsmgo), with:
  * [Wide 110deg HFOV Lens](https://www.mouser.co.uk/ProductDetail/FRAMOS/FSMGO-IMX678C-M12-L110A-PM-A1Q1?qs=%252BHhoWzUJg4KQkNyKsCEDHw%3D%3D), or
  * [Medium 100deg HFOV Lens](https://www.mouser.co.uk/ProductDetail/FRAMOS/FSMGO-IMX678C-M12-L100A-PM-A1Q1?qs=%252BHhoWzUJg4IesSwD2ACIBQ%3D%3D), or
  * [Narrow 54deg HFOV Lens](https://www.mouser.co.uk/ProductDetail/FRAMOS/FSMGO-IMX678C-M12-L54A-PM-A1Q1?qs=%252BHhoWzUJg4L5yHZulKgVGA%3D%3D).
* Mount/Tripod:
  * [Framos Tripod Mount Adapter](https://www.framos.com/en/products/fma-mnt-trp1-4-v1c-26333).
  * [Tripod](https://thepihut.com/products/small-tripod-for-raspberry-pi-hq-camera).
* A Framos cable for PixelMate MIPI-CSI-2 for each Camera Module:
  * [150mm flex-cable](https://www.mouser.co.uk/ProductDetail/FRAMOS/FMA-FC-150-60-V1A?qs=GedFDFLaBXGCmWApKt5QIQ%3D%3D).
* USB Micro B JTAG Cable (for JTAG programming).
* [10GBase-T SFP+ to QSFP+ Direct Attach cable](https://www.mouser.co.uk/ProductDetail/TE-Connectivity-AMP/2053453-4?qs=kAqyOuzYGe%252BmE8AFL1fLzw%3D%3D).
* NVIDIA Platform:
  * [NVIDIA Jetson Thor](https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-thor/).
  * [NVIDIA DGX Spark](https://www.nvidia.com/en-us/products/workstations/dgx-spark/).

---

## Hardware Setup

### Setting Up your Modular Development Board

> [!WARNING]
> Handle ESD-sensitive equipment (boards, microSD cards, Camera sensors, etc.) only when properly grounded and at an ESD-safe workstation

* Configure the board switches as shown:

<br>

<p align="center">
<img src="./assets/board-1.png" alt="board-1"><br>
<strong>Modular Development Board - Default Switch Positions</strong>
</p>
<br>

* Connect micro USB cable between the carrier board (`J35`) and the Host PC.
  This will be used for JTAG communication. Look at what ports are enumerated
  on your Host computer. There should be a series of four.

<br>

<p align="center">
<img src="./assets/Agx5-MDK-Conn.png" alt="Agx-MDK-Conn"><br>
<strong>Board Connections</strong>
</p>
<br>

---

### Board and NVIDIA Host System Setup

> [!WARNING]
> Handle ESD-sensitive equipment (boards, microSD Cards, Camera sensors, etc.) only when properly grounded and at an ESD-safe workstation

Make the required connections between the NVIDIA Host System and the Modular Development
board as shown in the following diagram:

<br/>

<p align="center">
<img src="./assets/ed-conn.png" alt="ed-conn"><br>
<strong>Development Kit and Host System Connection Diagram</strong>
</p>
<br/>

* Connect the Framos cable(s) between the Framos Camera Module(s) and the Modular
  Development board taking care to align the cable(s) correctly with the
  connectors (pin 1 to pin 1).

<p align="center">
<img src="./assets/Agx5-MDK-MIPI.png" alt="board-mipi"><br>
<strong>Board MIPI connections</strong>
</p>
<br/>

<p align="center">
<img src="./assets/mipi-ribbon-connection.png" alt="mipi-ribbon"><br>
<strong>Board MIPI and Ribbon Cable</strong>
</p>

<br/>

<p align="center">
<img src="./assets/camera-ribbon-connection.png" alt="camera-ribbon"><br>
<strong>Camera and Ribbon Cable</strong>
</p>
<br/>

---

## Programming the FPGA

### Pre-Built Binaries

Pre-built `SOF` and `JIC` binaries can be found as assets in this repository under the latest tag in the format:
`altera-2.6.0-EA.X`

|Product|Type|Description|
|:-----:|:-----:|:-----:|
|.sof|SRAM Object File|Volatile FPGA bitstream to be loaded over JTAG|
|.jic|JTAG Indirect Communications File|FPGA bitstream to be loaded into QSPI flash over JTAG|

---

### Program the FPGA SOF

* To program the FPGA using SOF:

  * Power down the board. Set MSEL=JTAG by setting the **S4** dip switch
    on the SOM to **OFF-OFF**.
    * This prevents the starting of any bootloader and FPGA configuration after
      power up and until the SOF is programmed over JTAG.

  * Power up the board.

  * Either use your own or download the pre-built `SOF` image, and program
    the FPGA with either the command:

    ```bash
    quartus_pgm -c 1 -m jtag -o "p;AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.sof"
    ```

  * or, optionally use the Quartus® Programmer GUI:

    * Launch the Quartus® Programmer and Configure the **"Hardware Setup..."**
      settings as follows:


    <p align="center">
    <img src="./assets/hw-setup-set.png" alt="hw-setup-set"><br>
    <strong>Programmer GUI Hardware Settings</strong>
    </p>
    <br/>

    * Click "Auto Detect", select the device `A5EC065BB32AR0` and press **"Change File..."**

    <br>
    <p align="center">
    <img src="./assets/programmer-agx5.png" alt="programmer-agx5"><br>
    <strong>Programmer after "Auto Detect"</strong>
    </p>
    <br/>

    * Select your `AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.sof` file. Check the **"Program/Configure"** box and press the **"Start"** button (see below). Wait until the programming has been completed.

  <p align="center">
  <img src="./assets/programmer-agx5-3.png" alt="programmer-agx5-3"><br>
  <strong>Programming the FPGA with SOF file</strong>
  </p>
  <br/>

---

### Program the FPGA JIC

> [!IMPORTANT]
> Once the JIC is programmed the FPGA MSEL pins must be set to Fast Active Serial mode to allow configuration from the QSPI flash on power up.
> Power down the board. Set MSEL=AS Fast Mode by setting the **S4** dip switch on the SOM to **ON-ON**.
> If Fast Active Serial Mode is enabled the QSPI will appear in the JTAG chain on Auto Detect.

* To program the QSPI flash using JIC:

  * If the QSPI state is unknown, power down the board. Set MSEL=JTAG by setting the **S4** dip switch
    on the SOM to **OFF-OFF**.
    * This prevents the starting of any bootloader and FPGA configuration after
      power up and until the JIC is programmed over JTAG.

  * Power up the board.

  * Either use your own or download the pre-built `JIC` image, and program
    the FPGA with either the command:

    ```bash
    quartus_pgm -c 1 -m jtag -o "pvi;AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.jic"
    ```

  * or, optionally use the Quartus® Programmer GUI:

    * Launch the Quartus® Programmer and follow the setup steps from [Program the FPGA SOF](#program-the-fpga-sof)

    * Select your `AGX_5E_065B_Modular_DevKit_HSB_MIPI_10GbE.jic` file. Note that a QSPI device may have newly appeared in the chain.

    * Check the **"Program/Configure"** box ***for the QSPI***, when selected an *SDM helper image* will be shown the FPGA.
    
    * Press the **"Start"** button (see below). Wait until the programming has been completed.

  <p align="center">
  <img src="./assets/programmer-agx5-jic.png" alt="programmer-agx5-jic"><br>
  <strong>Programming the QSPI with JIC file</strong>
  </p>
  <br/>

  * Power cycle the board to use the newly flashed image
