# Holoscan Sensor Bridge 100GbE System Example Design for Agilex™ 7 I-Series Transceiver-SoC Development Kit (4x F-Tile)

## Overview

The Holoscan Sensor Bridge 100GbE System Example Design for Agilex™ 7 I-Series Transceiver-SoC Development Kit (4x F-Tile) demonstrates
an implementation of the [NVIDIA Holoscan Sensor Bridge](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/)
over a 100 Gb/s Ethernet link on an Agilex™ 7 I-Series Transceiver-SoC Development Kit (4x F-Tile) FPGA.

The FPGA connects to an NVIDIA host system over a 100GbE QSFP interface using the Altera® F-Tile
Ethernet Hard IP (100G-4, four FGT serial lanes). Sensor data is transported through the NVIDIA
Holoscan Sensor Bridge (HSB) IP at a 512-bit datapath width, enabling low-latency sensor-to-host
data transfer for Holoscan AI processing pipelines.

An instrumentation subsystem (`nvqlink_subsystem`) is included on the Sensor Interface (SIF) path.
The design demonstrates operating a packet generator inside the `nvqlink_subsystem`, which uses PTP
from the Holoscan Sensor Bridge IP to measure round-trip latency of RoCE packets from GPU memory. 
This design has been built using Altera® Quartus® Prime Pro Edition version **26.1** targeting
device **AGIB027R31B1E1V** (Agilex™ 7 I-Series Transceiver-SoC Development Kit (4x F-Tile)). 

<p align="center">
<img src="./assets/HSB_100GbE_Overview.png" alt="Block diagram showing the HSB 100GbE system architecture with NVIDIA host connected through 100GbE QSFP to the FPGA fabric, then through F-Tile Ethernet and protocol shims to the Holoscan Sensor Bridge IP and NVQLink instrumentation subsystem"><br>
<strong>High-Level Block Diagram of the Holoscan Sensor Bridge 100GbE System Example Design</strong>
</p>

The software component for host-side control and demonstrations is provided separately by the
[NVIDIA Holoscan Sensor Bridge SDK](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/). The block diagram below shows the software
view of the application.


<p align="center">
<img src="./assets/gpu_roce_loopback_sw.png" alt="Block diagram showing SW API" width="75%"><br>
<strong>High-Level Software block diagram of the gpu_roce_loopback.py application</strong>
</p>

---

## Table of Contents

- [Overview](#overview)
- [RTL Design](#rtl-design)
  - [Design Overview](#design-overview)
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
    - [Script Build](#script-build)
    - [Quartus® GUI Build](#quartus-gui-build)
- [Hardware Requirements](#hardware-requirements)
- [Hardware Setup](#hardware-setup)
  - [Setting Up your I-Series Transceiver-SoC Development Kit (4x F-Tile)](#setting-up-your-i-series-transceiver-soc-development-kit-4x-f-tile)
  - [Board and NVIDIA Host System Setup](#board-and-nvidia-host-system-setup)
- [Programming the FPGA](#programming-the-fpga)
  - [Pre-Built Binaries](#pre-built-binaries)
  - [Program the FPGA SOF](#program-the-fpga-sof)
- [Running the Demonstrations](#running-the-demonstrations)
  - [System Setup](#system-setup)
  - [Demo Applications](#demo-applications)
    - [GPU RoCE Loopback Demo](#gpu-roce-loopback-demo)
    - [Build the Demo Docker Container](#build-the-demo-docker-container)
    - [Start the Demo Container](#start-the-demo-container)
    - [Run the 100GbE RoCE Loopback Example](#run-the-100gbe-roce-loopback-example)
  - [Latency Measurement](#latency-measurement)
- [Known Issues](#known-issues)

---

## RTL Design

### Design Overview

This project contains the necessary files and collateral to build the Holoscan Sensor Bridge
100GbE System Example Design for Agilex™ 7 I-Series Transceiver-SoC Development Kit (4x F-Tile). It has been built using
Altera® Quartus® Prime Pro Edition version **26.1**.

For build instructions refer to [Building the Design](#building-the-design).

The block diagram below shows the data flow through the top-level Platform Designer design;
clock and reset systems are not shown.

<p align="center">
<img src="assets/pd_top.png" alt="Platform Designer datapath block diagram"><br>
<strong>Data Path Diagram of the Holoscan Sensor Bridge 100GbE System Example Design</strong>
</p>

### NVIDIA Holoscan Sensor Bridge IP Requirements

The Holoscan Sensor Bridge IP must be downloaded and its location set via the `NV_HSB_IP_DIR`
environment variable. If this variable is not set the design defaults to the expected relative
location as per the `holoscan-sensor-bridge` repository structure:

```
holoscan-sensor-bridge
└── fpga
    ├── nv_hsb_ip
    └── altera
        └── AGX_FM87_Devkit_HSB_NVQLINK_100GbE
```

For detailed information about the NVIDIA HSB IP please refer to the
[NVIDIA documentation](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/fpga_index.html).

### Platform Designer HSB IP Component

Altera® has created a Platform Designer component to facilitate easy configuration and integration
of the NVIDIA HSB IP. The component allows the user to set all the macros defined in the IP
Integration section of the HSB IP documentation and auto-generates the header file used by the IP.
See: <https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/ip_integration.html>

When generated the PD component outputs a SystemVerilog wrapper which instantiates the NVIDIA
`HOLOLINK_top` entity. This wrapper only instantiates interfaces that are enabled and safe-states
any that require it.

#### Key Platform Designer Component Features

##### Register Initialisation File

The HSB IP header file allows registers to be initialised through an array of addresses and data.
The PD component provides the ability to select an initialisation file in either text or Intel Hex
format. In this example design the `nv_hsb_ip_reginit.txt` file is at the top level of the
project and can be referenced as an example.

##### Mixed Data Path Widths

The HSB IP allows the user to specify different data widths for individual SIFs. In this design
both the datapath and all SIF RX/TX widths are set to **512 bits**.

The generated wrapper automatically ties off any unused signals.

##### SPI0 Instantiation

The HSB SW drivers require SPI0 to be instantiated inside the HSB IP. When SPI quantity is set
to 0 the component sets the header value to 1 and safe-states the bus in the wrapper.

##### Enumeration Settings

The HSB IP supports external enumeration via EEPROM or through RTL port pins. The PD component
allows the values to be hard-coded into the wrapper (useful for prototyping) or exported as a
conduit.

##### BUILD_REV

The wrapper allows the user to enter a build revision manually or use the automatically-generated
epoch time from the Platform Designer generation step.

### Project Structure

This example design was generated using the Modular Design Toolkit (MDT) flow. This flow defines
two types of subsystems: **shell** (core MDT subsystems shared across designs) and **user**
(design-specific subsystems). Directories are commonly subdivided into these two categories.

| Folder | Content Description |
|:---|:---|
| `non_qpds_ip` | Non-Quartus IP source used in the design (HSB shims, NVQLink analyser) |
| `rtl` | Design source files (`*.v`, `*.qsys`, `*.ip`), subdivided into `shell` and `user` |
| `sdc` | Design constraint files for both shell and user subsystems |
| `scripts` | Build scripts from the MDT flow |
| `quartus` | Quartus project (`*.qpf`) and settings (`*.qsf`) files |
| `quartus/shell` | QSF files specific to shell subsystems |
| `quartus/user` | QSF files specific to user subsystems |
| `quartus/output_files` | Location of built SOF and all outputs generated by the build flow |

### QSF Overview

The MDT flow produces QSF files per subsystem, resulting in several files in the following
structure:

```
quartus
├── AGX_FM87_Devkit_HSB_NVQLINK_100GbE.qpf                          # Quartus project file
├── AGX_FM87_Devkit_HSB_NVQLINK_100GbE.qsf                          # Main project QSF, calls all sub-QSFs
├── shell
│   ├── top_supplemental.qsf         # Additional project settings (output dir, top-level RTL)
│   ├── board_subsystem.qsf          # Board subsystem IO and source assignments
│   ├── clock_subsystem.qsf          # Clock subsystem source assignments
│   └── design.qsf                   # Additional design-level assignments
└── user
    ├── eth.qsf                      # F-Tile Ethernet subsystem IO (QSFP pins)
    ├── ftile_eth_subsystem.qsf      # F-Tile Ethernet subsystem source assignments
    ├── hsb.qsf                      # HSB subsystem IO assignments
    ├── hsb_subsystem.qsf            # HSB subsystem source assignments
    └── nvqlink_subsystem.qsf        # NVQLink subsystem source assignments
```

If a user is modifying the design for their own purposes these QSFs can be combined into a single
file if desired.

### Design Hierarchy

```
AGX_FM87_Devkit_HSB_NVQLINK_100GbE.v  (Project top-level Verilog)
└── AGX_FM87_Devkit_HSB_NVQLINK_100GbE_qsys.qsys  (Top-level Platform Designer system)
    ├── board_subsystem.qsys      (shell)
    ├── clock_subsystem.qsys      (shell)
    ├── ftile_eth_subsystem.qsys  (user)
    ├── hsb_subsystem.qsys        (user)
    └── nvqlink_subsystem.qsys    (user)
```

### Clock Domains

This design operates in the following primary clock domains:

| Clock Name | Source | Frequency | Usage |
|:---:|:---:|:---:|:---:|
| Board Clock | Board reference oscillator (`clk_100_mhz`) | 100 MHz | Control and Status Registers (APB/Avalon-MM) |
| FGT Reference | External QSFP reference clock (`refclk_eth_fgt`) | 156.25 MHz | F-Tile PMA reference |
| Core / SIF Clock | IOPLL (driven from board 100 MHz) | 400 MHz | Sensor Interface (SIF) path and general user logic |
| HIF / AVST Clock | F-Tile Ethernet Hard IP (`rx_clkout` / AVST) | 402.83203125 MHz | Host Interface (HIF) datapath |
| F-Tile TX Clock | F-Tile Ethernet Hard IP PCS output (`tx_clkout`) | 415.0390625 MHz | F-Tile Ethernet TX PCS |

The Holoscan Sensor Bridge IP synchronises SIF data into the HIF domain internally.
Clock domain crossings within the NVIDIA HSB IP are constrained by `sdc/user/hsb_subsystem.sdc`.

### Design Subsystems

#### `board_subsystem` (shell)

**Role:** Board-level integration — entry for the board clock and asynchronous reset, provides
structured reset sequencing for the rest of the design.

**Functions:**

- Clock bridge from the board 100 MHz domain.
- Push-button reset handling and reset generators.
- Board initialisation logic and reset bridges feeding a board reset controller.
- SGPIO interface (`fpga_sgpio_sync`, `fpga_sgpio_clk`, `fpga_sgpi`, `fpga_sgpo`).

**Top-level I/O:** `clk_100_mhz` and `rst_pb_n`

#### `clock_subsystem` (shell)

**Role:** Clock generation and reset distribution for the design.

**Functions:**

- Input clock and reset bridges plus reset control.
- **IOPLL** generating a 400 MHz core clock from the 100 MHz board reference.
- PLL lock / reference-clock reset synchronisation, reset extenders, and general reset-sync logic.

**Top-level I/O:** none

#### `ftile_eth_subsystem` (user)

**Role:** 100 Gb/s Ethernet using the Altera® **F-Tile** Hard IP (100G-4, four FGT serial lanes).

**Functions:**

- F-Tile Ethernet Hard IP (`eth_f`) configured for 100GbE over four FGT lanes.
- F-Tile system clock bridge and interface reset synchroniser.
- CSR clock and reset bridges for Avalon-MM access.
- Exports TX/RX serial differential pairs, QSFP low-power and reset controls.

**Top-level I/O:** `serial_o_tx_serial[0:3]` / `serial_i_rx_serial[0:3]` (4-lane QSFP),
`refclk_eth_fgt`, `qsfp_lowpwr`, `qsfp_rstn`

#### `hsb_subsystem` (user)

**Role:** NVIDIA Holoscan Sensor Bridge subsystem — instantiates the HSB IP component and provides
clock and format adapters for interfacing with the Altera® F-Tile Ethernet IP.

> [!NOTE]
> The NVIDIA HSB IP source location is set via the `NV_HSB_IP_DIR` environment variable; see
> [NVIDIA Holoscan Sensor Bridge IP Requirements](#nvidia-holoscan-sensor-bridge-ip-requirements).

**Functions:**

- Core **HSB IP** (`HOLOLINK_top`) instantiation at 512-bit datapath width.
- Host Interface Avalon Streaming ↔ AXI-Streaming converters (`hsb_avst_axis_shim`,
  `hsb_axis_avst_shim`) at 512 bits.
- **Avalon-MM bridges** (`hsb_mm_bridge_0`, `hsb_mm_bridge_1`) for APB register access.
- CPU-side and Host Interface clock/reset bridges.
- **System ID** for design-generation timestamping.
- SIF export for the `nvqlink_subsystem`.

**Top-level I/O:** none (all connectivity is via Platform Designer internal buses)

#### `nvqlink_subsystem` (user)

**Role:** Instrumentation subsystem — NVQLink analyser on the SIF data path for PTP capture,
SIF monitoring, and RAM-based self-test.

**Functions:**

- `nvqlink_instrumentation_analyzer` core with 5 APB slave windows.
- PTP capture and self-test RAM player on the SIF path.
- Clocked from the 400 MHz core clock and HIF clock; PTP clock domain also supported.

**Top-level I/O:** none (all connectivity is via Platform Designer internal buses)

> [!NOTE]
> The MIPI CSI packer and MIPI shim source files present under `non_qpds_ip/` are
> **not instantiated** in this 100GbE variant.

### Register Map

The HSB IP is built with `REG_INST = 5`, giving it five APB master interfaces. Two are consumed
inside `hsb_subsystem` and converted to Avalon-MM; the remaining three are exported and drive the
`nvqlink_subsystem` analyser. The APB window base addresses are fixed by the address decode inside the HSB IP.
| APB Master | Base Address | Consumer | IP / Function |
|:---:|:---:|:---:|:---:|
| — | `0x0000_0000`–`0x0FFF_FFFF` | HSB IP internal | Global / Sensor / Host / Peripheral register banks |
| `hsb.apb_0` | `0x1000_0000` | `hsb_mm_bridge_0` → exported as `mm_ctrl_out` | Avalon-MM master for downstream user logic (16-bit address, 32-bit data) - Unused |
| `hsb.apb_1` | `0x2000_0000` | `hsb_mm_bridge_1` → `system_id.control_slave` | Avalon System ID (8-bit address, 32-bit data) |
| `hsb.apb_2` | `0x3000_0000` | `nvqlink_subsystem.apb_2` | `u_apb_ila` — PTP / latency ILA (256-bit × 16384) |
| `hsb.apb_3` | `0x4000_0000` | `nvqlink_subsystem.apb_3` | `u_apb_sif_ila` — SIF raw-bus ILA (`SIF_ILA_DATA_WIDTH` × 8192) |
| `hsb.apb_4` | `0x5000_0000` | `nvqlink_subsystem.apb_4` | `u_ram_player` — synthetic data generator |
 
 
`ram_player` register offsets, relative to `0x5000_0000`:
| Offset | Register |
|:---:|:---:|
| `0x0004` | Enable (bit 0 `ram_ena`, bit 1 `ptp_ena`) |
| `0x0008` | Inter-frame timer (SIF clock cycles) |
| `0x000C` | Window size (bytes) |
| `0x0010` | Window number |

### Top Level IO

| Port | Description | `.qsf` file | Pin(s) | Notes |
|:---|:---|:---|:---|:---|
| `clk_100_mhz` | 100 MHz board reference clock | `board_subsystem.qsf` | PIN_CM29 | SI5332E-D-GM2 OUT6 |
| `rst_pb_n` | Active-low push-button reset | `board_subsystem.qsf` | PIN_AB53 | `FPGA_RESETn` |
| `user_pb_n[0]` | User push-button 0 | `board_subsystem.qsf` | PIN_CY47 | `f_gpio0` |
| `user_pb_n[1]` | User push-button 1 | `board_subsystem.qsf` | PIN_CW48 | `f_gpio1` |
| `fpga_sgpio_sync` | SGPIO sync | `board_subsystem.qsf` | PIN_Y49 | |
| `fpga_sgpio_clk` | SGPIO clock | `board_subsystem.qsf` | PIN_W48 | |
| `fpga_sgpi` | SGPIO serial data in | `board_subsystem.qsf` | PIN_T49 | |
| `fpga_sgpo` | SGPIO serial data out | `board_subsystem.qsf` | PIN_U48 | |
| `refclk_eth_fgt` | 100GbE FGT reference clock (156.25 MHz) | `eth.qsf` | PIN_R14 | |
| `qsfp_lowpwr` | QSFP cage low-power signal | `eth.qsf` | PIN_CP23 | `IO_STANDARD` 1.2 V |
| `qsfp_rstn` | QSFP cage reset (active-low) | `eth.qsf` | PIN_CM23 | `IO_STANDARD` 1.2 V |
| `serial_o_tx_serial[0:3]` | 100G QSFP TX serial lanes (4) | `eth.qsf` | AC10, Y7, W10, T7 | `HIGH SPEED DIFFERENTIAL I/O` |
| `serial_o_tx_serial_n[0:3]` | 100G QSFP TX serial lane complements | `eth.qsf` | AB11, AA8, V11, U8 | |
| `serial_i_rx_serial[0:3]` | 100G QSFP RX serial lanes (4) | `eth.qsf` | AC4, T1, W4, M1 | `HIGH SPEED DIFFERENTIAL I/O` |
| `serial_i_rx_serial_n[0:3]` | 100G QSFP RX serial lane complements | `eth.qsf` | AB5, U2, V5, N2 | |

### Resource Utilisation

Figures below are from a Quartus® Prime Pro 26.1 compilation of this design (`AGX_FM87_Devkit_HSB_NVQLINK_100GbE.fit.rpt`,
2026-08-24). ALMs are **ALMs needed**; registers are **Dedicated Logic Registers**.

| Subsystem | ALMs | Registers | RAM Blocks (M20K) | DSPs |
|:---:|:---:|:---:|:---:|:---:|
| Board | 16 | 32 | 0 | 0 |
| Clock | 9 | 16 | 0 | 0 |
| F-Tile Ethernet | 3,812 | 5,749 | 0 | 0 |
| HSB | 19,892 | 48,554 | 105 | 4 |
| NVQLink | 4,869 | 6,964 | 578 | 0 |
| F-Tile Hard IP (auto\_tiles) | 8,120 | 12,513 | 16 | 0 |
| ***Total*** | ***36,734*** | ***73,863*** | ***699*** | ***4*** |

Total ALM utilisation is **36,734 / 912,800 (~4%)** of device capacity. Timing closed (worst-case
setup slack 0.149 ns; 0 failing endpoints).

### Building the Design

The example design can be built using a script or via the Quartus® Prime Pro GUI. The built FPGA
bitstream `AGX_FM87_Devkit_HSB_NVQLINK_100GbE.sof` is located in the `quartus/output_files` directory.

#### Script Build

Navigate to the `scripts` directory and run:

```bash
quartus_sh -t build_shell.tcl -hw_compile
```

To also regenerate Platform Designer systems before compilation:

```bash
quartus_sh -t build_shell.tcl -qsys_gen -hw_compile
```

#### Quartus® GUI Build

1. Open `quartus/AGX_FM87_Devkit_HSB_NVQLINK_100GbE.qpf` in Quartus® Prime Pro Edition 26.1.
2. On the Compilation Dashboard select **"Compile Design"**.


---

## Hardware Requirements

- [Agilex™ 7 FPGA I-Series SoC Development Kit](https://www.altera.com/products/devkit/po-3248/agilex-7-fpga-i-series-transceiver-soc-development-kit-4x-f-tile)
- [3 m 100G QSFP28 AOC](https://www.fs.com/uk/products/50176.html)
- [NVIDIA IGX Thor Developer Kit](https://www.nvidia.com/en-eu/edge-computing/products/igx/).

---

## Hardware Setup

### Setting Up your I-Series Transceiver-SoC Development Kit (4x F-Tile)

1. Confirm board switch positions for JTAG mode — consult the I-Series Transceiver-SoC Development Kit (4x F-Tile) [User Guide](https://docs.altera.com/r/docs/721605/current/agilextm-7-fpga-i-series-transceiver-soc-development-kit-user-guide/overview). The Factory default setting mentioned in the devkit user guide should be used for this design. 

| Switch | Default Position | Default Function |
|:---|:---|:---|
| `S19[1:4]` | OFF/OFF/ON/ON | System MAX® 10 and FPGA selected in the JTAG chain. |
| `S20[1:4]` | ON/ON/ON/ON | Mode 1: onboard Altera® download circuit acts as the only JTAG master.<br>Chained HPS with SDM nodes internally. |
| `S9[1:4]` | ON/OFF/OFF/X | Configuration mode setting bits: AS — Fast mode |
| `S10[1:4]` | ON/ON/ON/ON | `SYS_SW[0:3]`<br>`SYS_SW[0]` — Factory Loadn: `'0'` — load image from Page 0 of the QSPI<br>`SYS_SW[1]` — `MUX_SEL1`<br>`SYS_SW[2]` — `MUX_SEL7`<br>`SYS_SW[3]` — `MUX_SEL9` |
| `S15[1:4]` | ON/ON/ON/OFF | `SYS_SW[4:7]`<br>`SYS_SW[4]` — `MUX_SEL_ZL`<br>`SYS_SW[5]` — FMC-A PCIe® RP/EP select: `"0"` RP (default), `"1"` EP<br>`SYS_SW[6]` — FMC-B PCIe® RP/EP select: `"0"` RP (default), `"1"` EP<br>`SYS_SW[7]` — MCIO PCIe® RP/EP select: `"0"` RP, `"1"` EP (default) |
| `S1[1:4]` | OFF/OFF/OFF/OFF | User Switch `[0:3]` |
| `S6[1:4]` | OFF/OFF/OFF/OFF | User Switch `[4:7]` |
| `S22[1:4]` | ON/ON/ON/ON | `MUX_DIP_SW[0:3]`<br>`MUX_DIP_SW0` — `MUX_SEL2`<br>`MUX_DIP_SW1` — `MUX_SEL3`<br>`MUX_DIP_SW2` — `MUX_SEL4`<br>`MUX_DIP_SW3` — `MUX_SEL5`<br>Set to `"ON"` by default to select onboard clock as input. |
| `S23[1:4]` | ON/ON/ON/ON | `MUX_DIP_SW[4:7]`<br>`MUX_DIP_SW4` — `MUX_SEL10`<br>`MUX_DIP_SW5` — `MUX_SEL11`<br>`MUX_DIP_SW6` — `MUX_SEL12`<br>`MUX_DIP_SW7` — `MUX_SEL14`<br>Set `"0"` / closed by default for onboard clock as input. |
| `S4[1:4]` | ON/ON/ON/ON | `MUX_DIP_SW[8:11]`<br>`MUX_DIP_SW8` — `MUX_SEL13`<br>`MUX_DIP_SW9` — `MUX_SEL6`<br>`MUX_DIP_SW10` — `MUX_SEL0`<br>`MUX_DIP_SW11` — `MUX_SEL8`<br>Set `"0"` / closed by default for onboard clock as input. |

2. Connect a USB JTAG cable between the carrier board and the Host PC.
3. Confirm the board powers on correctly before programming.

### Board and NVIDIA Host System Setup

> [!IMPORTANT]
> Setup the NVIDIA Host System following the [NVIDIA Host setup instructions](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/setup.html).

1. Connect the 3 m 100G QSFP28 AOC (4 × 25G NRZ) between the I-Series Transceiver-SoC Development Kit (4x F-Tile) QSFP port
   and the NVIDIA host 100GbE interface.
2. Ensure the NVIDIA host system has the Holoscan Sensor Bridge SDK installed and configured
   per [NVIDIA HSB SDK documentation](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/).
3. [Program the FPGA](#programming-the-fpga) before starting host-side software.

<p align="center">
<img src="./assets/HW_setup.png" alt="Lab hardware setup showing the Agilex 7 I-Series Transceiver-SoC Development Kit (4x F-Tile) with JTAG programmer, 100GbE QSFP cable to the NVIDIA host, and supporting connections"><br>
<strong>Lab Hardware Setup — I-Series Transceiver-SoC Development Kit (4x F-Tile), JTAG Programmer, and NVIDIA Host over 100GbE QSFP</strong>
</p>

---

## Programming the FPGA

### Pre-Built Binaries

Pre-built `SOF` and `JIC` binaries can be found as assets in this repository under the release tag:
https://github.com/altera-fpga/holoscan-sensor-bridge/releases/tag/altera-release-2.6.0-4

| Product | Type | Description |
|:-----:|:-----:|:-----:|
| `.sof` | SRAM Object File | Volatile FPGA bitstream to be loaded over JTAG |
| `.jic` | JTAG Indirect Communications File | FPGA bitstream to be loaded into QSPI flash over JTAG |

### Program the FPGA SOF

- To program the FPGA using the SOF:

  - Power up the board.

  - Either use your own or download a pre-built `SOF` image, then program the FPGA:

    ```bash
    quartus_pgm -c 1 -m jtag -o "p;AGX_FM87_Devkit_HSB_NVQLINK_100GbE.sof"
    ```

  - Or, use the Quartus® Programmer GUI:

    - Launch the Quartus® Programmer and configure the **"Hardware Setup..."**
      settings as follows:

    <p align="center">
    <img src="./assets/programmer-setup.png" alt="jtag-setup"><br>
    <strong>Programmer GUI Hardware Settings</strong>
    </p>
    <br/>

    - Click **"Auto Detect"**, select the device `AGIB027R31B` and press **"Change File..."**

    <br>
    <p align="center">
    <img src="./assets/programmer-chain.png" alt="Programmer chain with Agilex 7"><br>
    <strong>Programmer after "Auto Detect"</strong>
    </p>
    <br/>

    - Select your `AGX_FM87_Devkit_HSB_NVQLINK_100GbE.sof` file. Check the **"Program/Configure"** box and press the **"Start"**
      button (see below). Wait until the programming has been completed.

  <p align="center">
  <img src="./assets/programmer-sof.png" alt="Program Agilex 7 with SOF"><br>
  <strong>Programming the FPGA with SOF file</strong>
  </p>
  <br/>

---

## Running the Demonstrations

### System Setup

Before running the demonstrations ensure that you have:

- [Set up the Agilex™ 7 I-Series Transceiver-SoC Development Kit (4x F-Tile)](#setting-up-your-i-series-transceiver-soc-development-kit-4x-f-tile).
- [Set up the NVIDIA host system](#board-and-nvidia-host-system-setup).
- [Programmed the FPGA](#programming-the-fpga).

### Demo Applications

#### GPU RoCE Loopback Demo

The primary host-side demonstration for this 100GbE example design is the NVIDIA
**GPU RoCE loopback** example, which exercises the Holoscan Sensor Bridge datapath over
100GbE RoCE between the FPGA and the NVIDIA host.

#### Build the Demo Docker Container

Build the Holoscan Sensor Bridge demonstration container per the
[NVIDIA HSB SDK build instructions](https://archive.docs.nvidia.com/holoscan/sensor-bridge/2.6.0/).

For systems with a discrete GPU (dGPU):

```bash
cd <holoscan-sensor-bridge>
sh docker/build.sh --dgpu
```

For systems with an integrated GPU (iGPU):

```bash
cd <holoscan-sensor-bridge>
sh docker/build.sh --igpu
```

#### Start the Demo Container

```bash
cd <holoscan-sensor-bridge>
sh docker/demo.sh
```

#### Run the 100GbE RoCE Loopback Example

From inside the demo container:

```bash
python3 examples/gpu_roce_loopback.py \
  --hololink 192.168.0.2 \
  --frame-size 32 \
  --mtu 256
```

Replace `192.168.0.2` with the Hololink IP address of your FPGA if it differs from the default,
and adjust `--frame-size` and `--mtu` to suit the traffic pattern you want to measure.

> [!NOTE]
> The loopback demo blocks its terminal while running. Use a second host terminal for
> latency measurement — see [Latency Measurement](#latency-measurement).

### Latency Measurement

Round-trip FPGA PTP latency on the SIF path is measured using the on-chip NVQLink ILA
while the RoCE loopback demo runs. This is separate from the loopback application itself:
the demo generates traffic; the ILA scripts capture and analyse timestamps.

For the full step-by-step procedure (two-terminal workflow, ILA capture, expected results,
and troubleshooting), see:

**[LATENCY_MEASUREMENT.md](./LATENCY_MEASUREMENT.md)**

---

## Known Issues

None documented yet.
