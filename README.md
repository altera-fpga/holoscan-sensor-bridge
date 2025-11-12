# 🚀 Altera FPGA-based NVIDIA Holoscan Sensor Bridge

## Introduction

This repository provides driver code and example applications for integrating Altera FPGAs with NVIDIA's Holoscan Sensor Bridge.

Holoscan Sensor Bridge enables low-latency sensor data processing with GPUs, using an FPGA to acquire peripheral device data and transmit it via UDP to the host system. ConnectX devices can write UDP data directly into GPU memory, facilitating seamless integration with Holoscan pipelines.

Example applications include video processing and inference using an IMX678 MIPI sensor with the  [Agilex™ 5 FPGA E-Series 065B Modular Development Kit](https://www.intel.com/content/www/us/en/products/details/fpga/development-kits/agilex/a5e065b-modular.html).

## Hardware Requirements

The following equipment is needed to test the MIPI Holoscan Sensor Bridge on the Agilex™ 5 FPGA E-Series 065B Modular Development Kit:

* [Agilex™ 5 FPGA E-Series 065B Modular Development Kit](https://www.intel.com/content/www/us/en/products/details/fpga/development-kits/agilex/a5e065b-modular.html).
* 1 [Framos FSM:GO IMX678C Camera Modules](https://www.framos.com/en/fsmgo), with either:
  * [Wide 110deg HFOV (Horizontal Field of View) Lens](https://www.mouser.co.uk/ProductDetail/FRAMOS/FSMGO-IMX678C-M12-L110A-PM-A1Q1?qs=%252BHhoWzUJg4KQkNyKsCEDHw%3D%3D).
  * [Medium 100deg HFOV Lens](https://www.mouser.co.uk/ProductDetail/FRAMOS/FSMGO-IMX678C-M12-L100A-PM-A1Q1?qs=%252BHhoWzUJg4IesSwD2ACIBQ%3D%3D).
  * [Narrow 54deg HFOV Lens](https://www.mouser.co.uk/ProductDetail/FRAMOS/FSMGO-IMX678C-M12-L54A-PM-A1Q1?qs=%252BHhoWzUJg4L5yHZulKgVGA%3D%3D).
  * [150mm flex-cable](https://www.mouser.co.uk/ProductDetail/FRAMOS/FMA-FC-150-60-V1A?qs=GedFDFLaBXGCmWApKt5QIQ%3D%3D&_gl=1*d93qim*_ga*MTkyOTE4MjMxNy4xNzQxMTcwMzQy*_ga_15W4STQT4T*MTc0MTE3MDM0Mi4xLjEuMTc0MTE3MDQ5OS40NS4wLjA.), or
  * [300mm micro-coax cable](https://www.mouser.co.uk/ProductDetail/FRAMOS/FFA-MC50-Kit-0.3m?qs=%252BHhoWzUJg4K3LtaE207mhw%3D%3D).
* USB Micro B JTAG Cable.
* [10GBase-T SFP+ to RJ45 module](https://nam10.safelinks.protection.outlook.com/?url=https%3A%2F%2Fwww.amazon.co.uk%2FWiitek-Transceiver-Compatible-SFP-10G-T-S-Supermicro%2Fdp%2FB07P39G4XJ%3Fth%3D1&data=05%7C02%7Crichard.davies%40altera.com%7Cb8be645a8b93498f5d2d08de156d78b6%7Cfbd72e03d4a54110adce614d51f2077a%7C0%7C0%7C638971757079472371%7CUnknown%7CTWFpbGZsb3d8eyJFbXB0eU1hcGkiOnRydWUsIlYiOiIwLjAuMDAwMCIsIlAiOiJXaW4zMiIsIkFOIjoiTWFpbCIsIldUIjoyfQ%3D%3D%7C0%7C%7C%7C&sdata=biFMyUvwx3fnAY%2B89YkOKKksHvibT1wwGMvvx0WXc6w%3D&reserved=0)
* Cat6 Ethernet Cable
* [nVidia Jetson Orin AGX Devkit](https://developer.nvidia.com/embedded/learn/jetson-agx-orin-devkit-user-guide/index.html)

## Agilex™ 5 FPGA E-Series 065B Modular Development Kit setup
Refer to the Agilex™ 5 FPGA E-Series 065B Modular Development Kit project documentation for FPGA setup instructions. *(Link TBD)*

## nVidia Host system setup
Follow nVidia Holoscan Sensor Bridge setup instructions [here](https://docs.nvidia.com/holoscan/sensor-bridge/latest/index.html).

When cloning the [Holoscan Sensor Bridge repository](https://docs.nvidia.com/holoscan/sensor-bridge/latest/build.html#building-the-holoscan-sensor-bridge-container), use the Altera mirror:

```
git clone -b altera-2.3.0 --single-branch https://github.com/altera-fpga/holoscan-sensor-bridge
```

## Demo Applications
The following example applications are available to demonstrate the holoscan sensor bridge working on an Agilex™ 5 FPGA E-Series 065B Modular Development Kit.

### Build the Demo Docker Container
```
cd <holoscan sensor bridge>
sh docker/build.sh
```

### To run a demo application, start the demo container
```
cd <holoscan sensor bridge>
sh docker/demo.sh
```

### From within the Demo container run one of the following demos:
  * Simple Playback Example
```
python examples/linux_agx5_player.py
```
* YOLOv8 Body Pose Example

[Follow instructions to download YOLOv8 ONNX Model](https://docs.nvidia.com/holoscan/sensor-bridge/latest/examples.html#running-the-imx274-body-pose-example)
```
python examples/linux_body_pose_estimation_agx5.py
```

* TOA PeopleNet Example

[Follow instructions to download toa-peoplenet model](https://docs.nvidia.com/holoscan/sensor-bridge/latest/examples.html#running-the-imx274-tao-peoplenet-example)
```
python examples/linux_tao_peoplenet_agx5.py
```