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


class CameraStream:
    def __init__(self, cam_idx, cam_name, hololink_channel, camera):
        self._cam_idx = cam_idx
        self._cam_name = cam_name
        self._hololink_channel = hololink_channel
        self._camera = camera

class MicroApplication(holoscan.core.Application):
    def __init__(
        self,
        headless,
        fullscreen,
        cuda_context,
        cuda_device_ordinal,
        camera_streams,
        frame_limit,
        coe_interface,
        window_width,
        window_height,
        window_title,
    ):
        logging.info("__init__")
        super().__init__()
        self._headless = headless
        self._fullscreen = fullscreen
        self._cuda_context = cuda_context
        self._cuda_device_ordinal = cuda_device_ordinal
        self._camera_streams = camera_streams
        self._frame_limit = frame_limit
        self._coe_interface = coe_interface
        self._window_width = window_width
        self._window_height = window_height
        self._window_title = window_title

        # These are HSDK controls-- because we have stereo
        # camera paths going into the same visualizer, don't
        # raise an error when each path present metadata
        # with the same names.  Because we don't use that metadata,
        # it's easiest to just ignore new items with the same
        # names as existing items.
        self.is_metadata_enabled = True
        self.metadata_policy = holoscan.core.MetadataPolicy.REJECT

    def compose(self):
        logging.info("compose")

        for camera_stream in self._camera_streams.values():
            print(f"Configuring pipeline for camera {camera_stream._cam_name}")

            # Create a buffer pool for the CSI to Bayer operator, use the first camera stream for size
            camera_stream._csi_to_bayer_pool = holoscan.resources.BlockMemoryPool(
                self,
                name="pool",
                # storage_type of 1 is device memory
                storage_type=1,
                block_size=camera_stream._camera._width
                * ctypes.sizeof(ctypes.c_uint16)
                * camera_stream._camera._height,
                num_blocks=3,
            )

            # Create a buffer pool for the Bayer Demosaic operator, use the first camera stream for size
            rgba_components_per_pixel = 4
            camera_stream._bayer_pool = holoscan.resources.BlockMemoryPool(
                self,
                name="pool",
                # storage_type of 1 is device memory
                storage_type=1,
                block_size=camera_stream._camera._width
                * rgba_components_per_pixel
                * ctypes.sizeof(ctypes.c_uint16)
                * camera_stream._camera._height,
                num_blocks=3,
            )

            if self._frame_limit:
                self._count = holoscan.conditions.CountCondition(
                    self,
                    name=f"count-{camera_stream._cam_name}",
                    count=self._frame_limit,
                )
                camera_stream._condition = self._count
            else:
                self._ok = holoscan.conditions.BooleanCondition(
                    self, name=f"ok-{camera_stream._cam_name}", enable_tick=True
                )
                camera_stream._condition = self._ok

            camera_stream._csi_to_bayer_operator = hololink_module.operators.CsiToBayerOp(
                self,
                name=f"csi_to_bayer-{camera_stream._cam_name}",
                allocator=camera_stream._csi_to_bayer_pool,
                cuda_device_ordinal=self._cuda_device_ordinal,
                out_tensor_name = f"{camera_stream._cam_name}",
            )
            camera_stream._camera.configure_converter(camera_stream._csi_to_bayer_operator)

            frame_size = camera_stream._csi_to_bayer_operator.get_csi_length()

            frame_context = self._cuda_context

            if self._coe_interface:
                # Each camera sharing a network connection must use
                # a unique channel number from 0..63.
                coe_channel = 0
                pixel_width = camera_stream._camera._width
                camera_stream._receiver_operator = hololink_module.operators.LinuxCoeReceiverOp(
                    self,
                    camera_stream._condition,
                    name=f"receiver-{camera_stream._cam_name}",
                    frame_size=frame_size,
                    frame_context=frame_context,
                    hololink_channel=camera_stream._hololink_channel,
                    device=camera_stream._camera,
                    coe_interface=self._coe_interface,
                    pixel_width=pixel_width,
                    coe_channel=coe_channel,
                )
            else:
                self._ibv_name = None
                self._ibv_port = None
                if camera_stream._cam_idx == 0:
                    receiver_affinity = 2
                else:
                    receiver_affinity = 4

                infiniband_devices = hololink_module.infiniband_devices()
                # If we don't have any roce connectivity then the use linux receiver
                if len(infiniband_devices) == 0:
                    camera_stream._receiver_operator = hololink_module.operators.LinuxReceiverOperator(
                        self,
                        camera_stream._condition,
                        name=f"receiver-{camera_stream._cam_name}",
                        frame_size=frame_size,
                        frame_context=frame_context,
                        hololink_channel=camera_stream._hololink_channel,
                        device=camera_stream._camera,
                        receiver_affinity={receiver_affinity},
                    )
                else:
                    infiniband_devices = hololink_module.infiniband_devices()
                    self._ibv_name = infiniband_devices[0]
                    self._ibv_port = 1
                    camera_stream._receiver_operator = hololink_module.operators.RoceReceiverOp(
                        self,
                        camera_stream._condition,
                        name=f"receiver-{camera_stream._cam_name}",
                        frame_size=frame_size,
                        frame_context=frame_context,
                        ibv_name=self._ibv_name,
                        ibv_port=self._ibv_port,
                        hololink_channel=camera_stream._hololink_channel,
                        device=camera_stream._camera,
                    )

            pixel_format = camera_stream._camera.pixel_format()
            bayer_format = camera_stream._camera.bayer_format()
            camera_stream._image_processor_operator = hololink_module.operators.ImageProcessorOp(
                self,
                name=f"image_processor-{camera_stream._cam_name}",
                optical_black=camera_stream._camera.optical_black(),
                bayer_format=bayer_format.value,
                pixel_format=pixel_format.value,
            )

            print("bayer_format=", bayer_format)
            camera_stream._demosaic = holoscan.operators.BayerDemosaicOp(
                self,
                name=f"demosaic-{camera_stream._cam_name}",
                pool=camera_stream._bayer_pool,
                generate_alpha=True,
                alpha_value=65535,
                bayer_grid_pos=bayer_format.value,
                interpolation_mode=0,
                in_tensor_name = f"{camera_stream._cam_name}",
                out_tensor_name = f"{camera_stream._cam_name}",
            )

            camera_stream._spec = holoscan.operators.HolovizOp.InputSpec(
                f"{camera_stream._cam_name}", holoscan.operators.HolovizOp.InputType.COLOR
            )
            camera_stream._view = holoscan.operators.HolovizOp.InputSpec.View()
            camera_stream._view.width = 1 / len(self._camera_streams)
            camera_stream._view.height = 1.0
            camera_stream._view.offset_x = camera_stream._view.width * camera_stream._cam_idx
            camera_stream._view.offset_y = 0.0
            camera_stream._spec.views = [camera_stream._view]

            print(f"view=", camera_stream._view.width, camera_stream._view.height, camera_stream._view.offset_x, camera_stream._view.offset_y)
        tensors=[camera_stream._spec for camera_stream in self._camera_streams.values()]
        print("tensors=", tensors)
        visualizer = holoscan.operators.HolovizOp(
            self,
            name=f"holoviz",
            fullscreen=self._fullscreen,
            headless=self._headless,
            framebuffer_srgb=True,
            tensors=tensors,
            height = self._window_height,
            width = self._window_width,
            window_title = self._window_title,
        )
        
        for camera_stream in self._camera_streams.values():
            self.add_flow(camera_stream._receiver_operator, camera_stream._csi_to_bayer_operator, {("output", "input")})
            self.add_flow(
                camera_stream._csi_to_bayer_operator, camera_stream._image_processor_operator, {("output", "input")}
            )
            self.add_flow(camera_stream._image_processor_operator, camera_stream._demosaic, {("output", "receiver")})
            self.add_flow(camera_stream._demosaic, visualizer, {("transmitter", "receivers")})


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
    parser.add_argument(
        "--coe-interface",
        required=False,
        default=None,
        help="Name of interface connected to VETH 3276 (0xCCC).",
    )

    args = parser.parse_args()
    hololink_module.logging_level(args.log_level)
    logging.info("Initializing.")
    # Get a handle to the GPU
    (cu_result,) = cuda.cuInit(0)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS
    cu_device_ordinal = 0
    cu_result, cu_device = cuda.cuDeviceGet(cu_device_ordinal)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS
    cu_result, cu_context = cuda.cuDevicePrimaryCtxRetain(cu_device)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS

    uuid = "7b1fa8c7-31aa-44b6-abcc-eac134461fdc"
    metadata = hololink_module.Metadata(
        {
            "test-parameter": "agx5_imx678_example",
        }
    )
#    print(f"metadata={metadata}")
    uuid_strategy = hololink_module.BasicEnumerationStrategy(
        metadata,
        total_sensors=2,
        total_dataplanes=1,
        sifs_per_sensor=1
    )
    hololink_module.Enumerator.set_uuid_strategy(uuid, uuid_strategy)

    # Use HIF 0 for now    
    channel_metadata = hololink_module.Enumerator.find_channel(
        channel_ip="192.168.0.2"
    )

    # We don't want to enable "vsync_enable" as we do not have the VSYNC control logic on APB bus 6
    # Also not using ptp_enable
    metadata_overrides = hololink_module.Metadata({"vsync_enable": 0, "ptp_enable": 0})
    channel_metadata.update(metadata_overrides)

    # Create an array to hold the camera streams
    camera_streams = {}

    for cam_index in [0,1]:
        # Get a handle to the Hololink device
        camera_channel = hololink_module.Metadata(channel_metadata)
        hololink_module.DataChannel.use_sensor(camera_channel, cam_index)
        hololink_channel = hololink_module.DataChannel(camera_channel)

        # Get a handle to the camera
        camera = hololink_module.sensors.agx5_imx678.agx5_imx678.FramosImx678(
            hololink_channel, camera_id=cam_index
        )
        if cam_index == 0:
            cam_name = "left"
        else:
            cam_name = "right"
        camera_streams[cam_index] = CameraStream(cam_index, cam_name, hololink_channel, camera)

    # Set up the application
    application = MicroApplication(
        args.headless,
        args.fullscreen,
        cu_context,
        cu_device_ordinal,
        camera_streams,
        args.frame_limit,
        args.coe_interface,
        1920,   # window width
        1080,   # window height
        "AGX5 IMX678 Stereo Viewer"  # window title
    )

    # Run it.
    hololink = hololink_channel.hololink()
    hololink.start()
    try:
        hololink.reset()

        for camera_stream in camera_streams.values():
            camera = camera_stream._camera
            # Configures the camera for 3840x2160, 60fps, 10bits per pixel
            camera.configure(
                hololink_module.sensors.agx5_imx678.agx5_imx678_mode.agx5_imx678_1920_1080_60Hz_10BPP
            )

            camera.set_analog_gain_reg(args.gain)
        
        application.run()
    finally:
        hololink.stop()

    (cu_result,) = cuda.cuDevicePrimaryCtxRelease(cu_device)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS

if __name__ == "__main__":
    main()
