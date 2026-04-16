# SPDX-FileCopyrightText: Copyright (c) 2024 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-FileCopyrightText: Copyright (c) Altera. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This example application demonstrates real-time camera streaming and visualization
# using the Agilex 5 (AGX5) Modular Development Kit with an IMX678 MIPI camera.
# It showcases the integration of Altera's Hololink sensor bridge technology with
# NVIDIA's Holoscan SDK for low-latency, high-performance camera applications.
# See README.md for detailed information.

import argparse
import ctypes
import logging

import cuda.bindings.driver as cuda
import holoscan

import hololink as hololink_module


class MicroApplication(holoscan.core.Application):
    def __init__(
        self,
        headless,
        fullscreen,
        cuda_context,
        cuda_device_ordinal,
        hololink_channel,
        camera,
        frame_limit,
    ):
        logging.info("__init__")
        super().__init__()
        self._headless = headless
        self._fullscreen = fullscreen
        self._cuda_context = cuda_context
        self._cuda_device_ordinal = cuda_device_ordinal
        self._hololink_channel = hololink_channel
        self._camera = camera
        self._frame_limit = frame_limit

    def compose(self):
        logging.info("compose")
        if self._frame_limit:
            self._count = holoscan.conditions.CountCondition(
                self,
                name="count",
                count=self._frame_limit,
            )
            condition = self._count
        else:
            self._ok = holoscan.conditions.BooleanCondition(
                self, name="ok", enable_tick=True
            )
            condition = self._ok

        csi_to_bayer_pool = holoscan.resources.BlockMemoryPool(
            self,
            name="pool",
            # storage_type of 1 is device memory
            storage_type=1,
            block_size=self._camera._width
            * ctypes.sizeof(ctypes.c_uint16)
            * self._camera._height,
            num_blocks=2,
        )
        csi_to_bayer_operator = hololink_module.operators.CsiToBayerOp(
            self,
            name="csi_to_bayer",
            allocator=csi_to_bayer_pool,
            cuda_device_ordinal=self._cuda_device_ordinal,
        )
        self._camera.configure_converter(csi_to_bayer_operator)

        frame_size = csi_to_bayer_operator.get_csi_length()

        frame_context = self._cuda_context

        infiniband_devices = hololink_module.infiniband_devices()
        # If we don't have any roce connectivity then the use linux receiver
        if len(infiniband_devices) == 0:
            receiver_operator = hololink_module.operators.LinuxReceiverOperator(
                self,
                condition,
                name="receiver",
                frame_size=frame_size,
                frame_context=frame_context,
                hololink_channel=self._hololink_channel,
                device=self._camera,
            )
        else:
            infiniband_devices = hololink_module.infiniband_devices()
            self._ibv_name = infiniband_devices[0]
            self._ibv_port = 1
            receiver_operator = hololink_module.operators.RoceReceiverOp(
                self,
                condition,
                name="receiver",
                frame_size=frame_size,
                frame_context=frame_context,
                ibv_name=self._ibv_name,
                ibv_port=self._ibv_port,
                hololink_channel=self._hololink_channel,
                device=self._camera,
            )

        pixel_format = self._camera.pixel_format()
        bayer_format = self._camera.bayer_format()
        image_processor_operator = hololink_module.operators.ImageProcessorOp(
            self,
            name="image_processor",
            optical_black=self._camera.optical_black(),
            bayer_format=bayer_format.value,
            pixel_format=pixel_format.value,
        )

        rgba_components_per_pixel = 4
        bayer_pool = holoscan.resources.BlockMemoryPool(
            self,
            name="pool",
            # storage_type of 1 is device memory
            storage_type=1,
            block_size=self._camera._width
            * rgba_components_per_pixel
            * ctypes.sizeof(ctypes.c_uint16)
            * self._camera._height,
            num_blocks=2,
        )
        demosaic = holoscan.operators.BayerDemosaicOp(
            self,
            name="demosaic",
            pool=bayer_pool,
            generate_alpha=True,
            alpha_value=65535,
            bayer_grid_pos=bayer_format.value,
            interpolation_mode=0,
        )

        visualizer = holoscan.operators.HolovizOp(
            self,
            name="holoviz",
            fullscreen=self._fullscreen,
            headless=self._headless,
            framebuffer_srgb=True,
        )

        #
        self.add_flow(receiver_operator, csi_to_bayer_operator, {("output", "input")})
        self.add_flow(
            csi_to_bayer_operator, image_processor_operator, {("output", "input")}
        )
        self.add_flow(image_processor_operator, demosaic, {("output", "receiver")})
        self.add_flow(demosaic, visualizer, {("transmitter", "receivers")})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--headless", action="store_true", help="Run in headless mode")
    parser.add_argument(
        "--fullscreen", action="store_true", help="Run in fullscreen mode"
    )
    parser.add_argument(
        "--frame-limit",
        type=int,
        default=None,
        help="Exit after receiving this many frames",
    )

    parser.add_argument(
        "--log-level",
        type=int,
        default=20,
        help="Logging level to display",
    )
    parser.add_argument(
        "--cam",
        type=int,
        default=0,
        choices=(0, 1),
        help="which camera to stream: 0 to stream camera connected to j14 or 1 to stream camera connected to j17 (default is 0)",
    )
    parser.add_argument(
        "--gain",
        type=int,
        default=32,
        help="Set Analog Gain, RANGE(0 to 240). Default is 32",
    )

    args = parser.parse_args()
    hololink_module.logging_level(args.log_level)
#    hololink_module.set_hsb_log_level(hololink_module.HSB_LOG_LEVEL_DEBUG)
    logging.info("Initializing.")
    # Get a handle to the GPU
    (cu_result,) = cuda.cuInit(0)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS
    cu_device_ordinal = 0
    cu_result, cu_device = cuda.cuDeviceGet(cu_device_ordinal)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS
    cu_result, cu_context = cuda.cuDevicePrimaryCtxRetain(cu_device)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS

    # Update the default metadata to support 2 cameras on the AGX5
    uuid = "7b1fa8c7-31aa-44b6-abcc-eac134461fdc"
    metadata = hololink_module.Metadata()
    uuid_strategy = hololink_module.BasicEnumerationStrategy(
        metadata,
        total_sensors=2,
        total_dataplanes=1,
        sifs_per_sensor=1
    )
    hololink_module.Enumerator.set_uuid_strategy(uuid, uuid_strategy)

    # Get a handle to the Hololink device
    channel_metadata = hololink_module.Enumerator.find_channel(
        channel_ip="192.168.0.2"
    )

    # We don't want to enable "vsync_enable" as we do not have the VSYNC control logic on APB bus 6
    # Also not using ptp_enable
    metadata_overrides = hololink_module.Metadata({"vsync_enable": 0, "ptp_enable": 0})
    channel_metadata.update(metadata_overrides)

    # Select the camera based on the command line argument
    camera_channel = hololink_module.Metadata(channel_metadata)
    hololink_module.DataChannel.use_sensor(camera_channel, args.cam)
    hololink_channel = hololink_module.DataChannel(camera_channel)

    # Get a handle to the camera
    camera = hololink_module.sensors.agx5_imx678.agx5_imx678.FramosImx678(
        hololink_channel, camera_id=args.cam
    )

    # Set up the application
    application = MicroApplication(
        args.headless,
        args.fullscreen,
        cu_context,
        cu_device_ordinal,
        hololink_channel,
        camera,
        args.frame_limit,
    )

    # Run it.
    hololink = hololink_channel.hololink()
    hololink.start()
    try:
        hololink.reset()
        # Configures the camera for 3840x2160, 60fps, 10bits per pixel
        camera.configure(
            hololink_module.sensors.agx5_imx678.agx5_imx678_mode.agx5_imx678_3840_2160_60Hz_10BPP
        )

        # Set a default analog gain
        camera.set_analog_gain_reg(args.gain)
        
        application.run()
    finally:
        hololink.stop()

    (cu_result,) = cuda.cuDevicePrimaryCtxRelease(cu_device)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS

if __name__ == "__main__":
    main()
