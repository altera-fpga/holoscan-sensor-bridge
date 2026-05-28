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
import os

import cuda.bindings.driver as cuda
import holoscan
from body_pose_estimation import FormatInferenceInputOp, PostprocessorOp
from colorizeOp import ColorizeOperator

import hololink as hololink_module


class CameraStream:
    def __init__(self, cam_idx, cam_name, hololink_channel, camera, layout):
        self._cam_idx = cam_idx
        self._cam_name = cam_name
        self._hololink_channel = hololink_channel
        self._camera = camera
        self._layout = layout


class ReplicatedCamera:
    def __init__(self, hololink_channel, camera_id, parent_camera):
        self._camera_id = camera_id
        self._hololink_channel = hololink_channel
        self._parent_camera = parent_camera

    def start(self):
        # Nothing to do
        pass

    def stop(self):
        # Nothing to do
        pass

    def configure(self, mode):
        self._width = mode.width
        self._height = mode.height

    def configure_converter(self, converter_operator):
        # Pass through to the parent camera
        self._parent_camera.configure_converter(converter_operator)

    def pixel_format(self):
        return self._parent_camera.pixel_format()

    def bayer_format(self):
        return self._parent_camera.bayer_format()

    def optical_black(self):
        return self._parent_camera.optical_black()

    def set_analog_gain(self, gain):
        # Nothing to do
        pass

    def set_analog_gain_reg(self, gain):
        # Nothing to do
        pass

    def set_exposure_reg(self, exposure):
        # Nothing to do
        pass

    def set_digital_gain_reg(self, gain):
        # Nothing to do
        pass


def make_line(view, name, type, line_width, color, opacity):
    spec = holoscan.operators.HolovizOp.InputSpec(
        name,
        type,
    )
    spec.line_width = line_width
    spec.color = color
    spec.opacity = opacity
    spec.line_width = line_width
    spec.views = [view]
    return spec


def make_point(view, name, type, point_size, color, opacity):
    spec = holoscan.operators.HolovizOp.InputSpec(
        name,
        type,
    )
    spec.line_width = 0
    spec.color = color
    spec.opacity = opacity
    spec.point_size = point_size
    spec.views = [view]
    return spec


def add_body_pose_specs(specs, view, name):
    # Add additional specs for body pose estimation output
    specs.append(
        make_line(
            view,
            f"boxes-{name}",
            "rectangles",
            line_width=4,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_line(
            view,
            f"segments-{name}",
            "lines",
            line_width=4,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"noses-{name}",
            "points",
            point_size=10,
            color=[1.0, 0.0, 0.0, 1.0],
            opacity=0.0,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_eyes-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_eyes-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_ears-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_ears-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_shoulders-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_shoulders-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_elbows-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_elbows-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_wrists-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_wrists-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_hips-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_hips-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_knees-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_knees-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"left_ankles-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_point(
            view,
            f"right_ankles-{name}",
            "points",
            point_size=10,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )
    specs.append(
        make_line(
            view,
            f"segments-{name}",
            "lines",
            line_width=4,
            color=[0.0, 1.0, 0.0, 1.0],
            opacity=0.5,
        )
    )


def select_receiver_operator(
    application, camera_stream, frame_size, frame_context, interface
):
    logging.info(
        f"Select Receiver: interface={interface} receiver_type={application._receiver_type}"
    )
    receiver_operator = None

    # Initially try CoE Capture
    if application._receiver_type == "auto" or application._receiver_type == "coe":
        logging.info("Trying CoE Capture")
        metadata = camera_stream._hololink_channel.enumeration_metadata()
        hsb_mac = metadata.get("mac_id")
        hsb_mac_bytes = list(bytes.fromhex(hsb_mac.replace(":", "")))

        # Is the Fusa CoE capture operator available?
        try:
            has_fusa_coe_capture_op = hasattr(
                hololink_module.operators, "FusaCoeCaptureOp"
            )
        except ModuleNotFoundError:
            has_fusa_coe_capture_op = False

        if has_fusa_coe_capture_op:
            # Capture from Fusa.
            receiver_operator = hololink_module.operators.FusaCoeCaptureOp(
                application,
                camera_stream._condition,
                name=f"fusa_coe_capture_{camera_stream._cam_name}",
                interface=interface,
                mac_addr=hsb_mac_bytes,
                hololink_channel=camera_stream._hololink_channel,
                timeout=application._timeout,
                device=camera_stream._camera,
            )
            camera_stream._camera.configure_converter(receiver_operator)

            # Convert packed RAW to 16-bit Bayer.
            packed_format_converter_pool = holoscan.resources.BlockMemoryPool(
                application,
                name=f"packed_format_converter_pool_{camera_stream._cam_name}",
                # storage_type of 1 is device memory
                storage_type=1,
                block_size=camera_stream._camera._width
                * ctypes.sizeof(ctypes.c_uint16)
                * camera_stream._camera._height,
                num_blocks=4,
            )
            packed_format_converter = hololink_module.operators.PackedFormatConverterOp(
                application,
                name=f"packed_format_converter_{camera_stream._cam_name}",
                allocator=packed_format_converter_pool,
                out_tensor_name=f"{camera_stream._cam_name}",
            )
            receiver_operator.configure_converter(packed_format_converter)
            camera_stream._csi_to_bayer_operator = packed_format_converter

        if receiver_operator is not None:
            logging.info(f"Selected CoE capture receiver operator")
            return receiver_operator
        elif application._receiver_type != "auto":
            raise ValueError(
                f"Failed to create COE receiver operator for {application._receiver_type}"
            )

    # Try RoCE capture next
    if application._receiver_type == "auto" or application._receiver_type == "roce":
        logging.info("Trying RoCE Capture")
        infiniband_devices = hololink_module.infiniband_devices()
        receiver_operator = None
        if len(infiniband_devices) != 0:
            infiniband_devices = hololink_module.infiniband_devices()
            application._ibv_name = infiniband_devices[0]
            application._ibv_port = 1
            receiver_operator = hololink_module.operators.RoceReceiverOp(
                application,
                camera_stream._condition,
                name=f"receiver-{camera_stream._cam_name}",
                frame_size=frame_size,
                frame_context=frame_context,
                ibv_name=application._ibv_name,
                ibv_port=application._ibv_port,
                hololink_channel=camera_stream._hololink_channel,
                device=camera_stream._camera,
            )
        if receiver_operator is not None:
            logging.info(f"Selected RoCE receiver operator")
            return receiver_operator
        elif application._receiver_type != "auto":
            raise ValueError(
                f"Failed to create RoCE receiver operator for {application._receiver_type}"
            )

    # Fallback to linux receiver
    if camera_stream._cam_idx == 0:
        receiver_affinity = 2
    else:
        receiver_affinity = 4
    logging.info(f"Using Linux receiver with affinity {receiver_affinity}")
    receiver_operator = hololink_module.operators.LinuxReceiverOperator(
        application,
        camera_stream._condition,
        name=f"receiver-{camera_stream._cam_name}",
        frame_size=frame_size,
        frame_context=frame_context,
        hololink_channel=camera_stream._hololink_channel,
        device=camera_stream._camera,
        receiver_affinity={receiver_affinity},
    )
    logging.info(f"Selected Linux receiver operator")
    return receiver_operator


# Composer a simple pipeline to display the bayer stream
def compose_display_pipeline(application, camera_stream, interface):
    camera_stream._preprocessor = None

    # Create a buffer pool for the CSI to Bayer operator, use the first camera stream for size
    camera_stream._csi_to_bayer_pool = holoscan.resources.BlockMemoryPool(
        application,
        name="pool",
        # storage_type of 1 is device memory
        storage_type=1,
        block_size=camera_stream._camera._width
        * ctypes.sizeof(ctypes.c_uint16)
        * camera_stream._camera._height,
        num_blocks=3,
    )

    # Create a buffer pool for the Bayer Demosaic operator, use the first camera stream for size
    rgba_components_per_pixel = 3
    camera_stream._bayer_pool = holoscan.resources.BlockMemoryPool(
        application,
        name="pool",
        # storage_type of 1 is device memory
        storage_type=1,
        block_size=camera_stream._camera._width
        * rgba_components_per_pixel
        * ctypes.sizeof(ctypes.c_uint16)
        * camera_stream._camera._height,
        num_blocks=3,
    )

    if application._frame_limit:
        count = holoscan.conditions.CountCondition(
            application,
            name=f"count-{camera_stream._cam_name}",
            count=application._frame_limit,
        )
        camera_stream._condition = count
    else:
        ok = holoscan.conditions.BooleanCondition(
            application, name=f"ok-{camera_stream._cam_name}", enable_tick=True
        )
        camera_stream._condition = ok

    camera_stream._csi_to_bayer_operator = hololink_module.operators.CsiToBayerOp(
        application,
        name=f"csi_to_bayer-{camera_stream._cam_name}",
        allocator=camera_stream._csi_to_bayer_pool,
        cuda_device_ordinal=application._cuda_device_ordinal,
        out_tensor_name=f"{camera_stream._cam_name}",
    )
    camera_stream._camera.configure_converter(camera_stream._csi_to_bayer_operator)

    frame_size = camera_stream._csi_to_bayer_operator.get_csi_length()

    frame_context = application._cuda_context

    # Create the receiver operator
    camera_stream._receiver_operator = select_receiver_operator(
        application, camera_stream, frame_size, frame_context, interface
    )

    pixel_format = camera_stream._camera.pixel_format()
    bayer_format = camera_stream._camera.bayer_format()
    camera_stream._image_processor_operator = (
        hololink_module.operators.ImageProcessorOp(
            application,
            name=f"image_processor-{camera_stream._cam_name}",
            optical_black=camera_stream._camera.optical_black(),
            bayer_format=bayer_format.value,
            pixel_format=pixel_format.value,
        )
    )

    logging.info("bayer_format=%s", bayer_format)
    camera_stream._demosaic = holoscan.operators.BayerDemosaicOp(
        application,
        name=f"demosaic-{camera_stream._cam_name}",
        pool=camera_stream._bayer_pool,
        generate_alpha=False,
        alpha_value=65535,
        bayer_grid_pos=bayer_format.value,
        interpolation_mode=0,
        in_tensor_name=f"{camera_stream._cam_name}",
        out_tensor_name=f"{camera_stream._cam_name}",
    )

    camera_stream._specs = []
    spec = holoscan.operators.HolovizOp.InputSpec(
        f"{camera_stream._cam_name}",
        holoscan.operators.HolovizOp.InputType.COLOR,
    )
    rows, cols, window_width, window_height = application._camera_streams[0]._layout

    camera_stream._view = holoscan.operators.HolovizOp.InputSpec.View()
    camera_stream._view.width = 1 / cols
    camera_stream._view.height = 1.0 / rows
    camera_stream._view.offset_x = camera_stream._view.width * (
        camera_stream._cam_idx % cols
    )
    camera_stream._view.offset_y = camera_stream._view.height * (
        camera_stream._cam_idx // cols
    )
    spec.views = [camera_stream._view]
    camera_stream._specs.append(spec)

    logging.info(
        f"view {camera_stream._view.width} {camera_stream._view.height} {camera_stream._view.offset_x} {camera_stream._view.offset_y}"
    )
    if (camera_stream._cam_idx != 0) and isinstance(
        camera_stream._camera, ReplicatedCamera
    ):
        red = 0
        green = 0
        blue = 0

        if camera_stream._cam_idx & 0x1:
            red = 0xFFFF
        if camera_stream._cam_idx & 0x2:
            green = 0xFFFF
        if camera_stream._cam_idx & 0x4:
            blue = 0xFFFF

        camera_stream._colorize_operator = ColorizeOperator(
            application,
            name=f"colorize-{camera_stream._cam_name}",
            width=camera_stream._camera._width,
            height=camera_stream._camera._height,
            in_tensor_name=f"{camera_stream._cam_name}",
            out_tensor_name=f"{camera_stream._cam_name}",
            red=red,
            green=green,
            blue=blue,
            opacity=application._colorize_opacity,
        )
    else:
        camera_stream._colorize_operator = None

    if True:
        camera_stream._image_shift = (
            hololink_module.operators.ImageShiftToUint8Operator(
                application,
                name=f"image_shift-{camera_stream._cam_name}",
                shift=8,
                in_tensor_name=f"{camera_stream._cam_name}",
                out_tensor_name=f"{camera_stream._cam_name}",
            )
        )
    else:
        camera_stream._image_shift = None


def compose_body_pose_pipeline(application, camera_stream, interface):
    # Create a display
    compose_display_pipeline(application, camera_stream, interface)

    # Add the body pose estimation pipeline
    pool = holoscan.resources.UnboundedAllocator(application)
    preprocessor_args = application.kwargs("preprocessor")
    camera_stream._preprocessor = holoscan.operators.FormatConverterOp(
        application,
        name=f"preprocessor-{camera_stream._cam_name}",
        pool=pool,
        **preprocessor_args,
        in_tensor_name=f"{camera_stream._cam_name}",
    )
    camera_stream._format_input = FormatInferenceInputOp(
        application,
        name=f"transpose-{camera_stream._cam_name}",
        pool=pool,
    )
    inference_args = application.kwargs("inference")
    camera_stream._inference = holoscan.operators.InferenceOp(
        application,
        name=f"inference-{camera_stream._cam_name}",
        allocator=pool,
        model_path_map={
            "yolo_pose": application._engine,
        },
        **inference_args,
    )
    postprocessor_args = application.kwargs("postprocessor")
    postprocessor_args["image_width"] = preprocessor_args["resize_width"]
    postprocessor_args["image_height"] = preprocessor_args["resize_height"]
    postprocessor_args["out_tensor_name"] = f"-{camera_stream._cam_name}"
    camera_stream._postprocessor = PostprocessorOp(
        application,
        name=f"postprocessor-{camera_stream._cam_name}",
        allocator=pool,
        **postprocessor_args,
    )
    add_body_pose_specs(
        camera_stream._specs, camera_stream._view, camera_stream._cam_name
    )


class MicroApplication(holoscan.core.Application):
    def __init__(
        self,
        headless,
        fullscreen,
        cuda_context,
        cuda_device_ordinal,
        camera_streams,
        frame_limit,
        window_width,
        window_height,
        window_title,
        engine,
        colorize_opacity=0.90,
        enable_body_pose_estimation=False,
        timeout=1500,
        receiver_type="auto",
    ):
        logging.info("__init__")
        super().__init__()
        self._headless = headless
        self._fullscreen = fullscreen
        self._cuda_context = cuda_context
        self._cuda_device_ordinal = cuda_device_ordinal
        self._camera_streams = camera_streams
        self._frame_limit = frame_limit
        self._window_width = window_width
        self._window_height = window_height
        self._window_title = window_title
        self._engine = engine
        self._colorize_opacity = colorize_opacity
        self._enable_body_pose_estimation = enable_body_pose_estimation
        self._timeout = timeout
        self._receiver_type = receiver_type
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
        metadata = self._camera_streams[0]._hololink_channel.enumeration_metadata()
        interface = metadata.get("interface")
        local_ip = metadata.get("interface_address")
        hsb_ip = metadata.get("client_ip_address")
        hsb_mac = metadata.get("mac_id")
        hsb_mac_bytes = list(bytes.fromhex(hsb_mac.replace(":", "")))
        board_uuid = metadata.get("fpga_uuid")
        logging.info("Using AGX5 E Multiviewer:")
        logging.info(f"  Board UUID: {board_uuid}")
        logging.info(f"  Interface: {interface}")
        logging.info(f"  Local IP:  {local_ip}")
        logging.info(f"  HSB IP:    {hsb_ip}")
        logging.info(f"  HSB MAC:   {hsb_mac}")

        for camera_stream in self._camera_streams.values():
            logging.info(f"Configuring pipeline for camera {camera_stream._cam_name}")
            if camera_stream._cam_idx == 0 and self._enable_body_pose_estimation:
                compose_body_pose_pipeline(self, camera_stream, interface)
            else:
                compose_display_pipeline(self, camera_stream, interface)

        tensors = []
        for camera_stream in self._camera_streams.values():
            for spec in camera_stream._specs:
                tensors.append(spec)

        visualizer = holoscan.operators.HolovizOp(
            self,
            name=f"holoviz",
            fullscreen=self._fullscreen,
            headless=self._headless,
            framebuffer_srgb=True,
            tensors=tensors,
            height=self._window_height,
            width=self._window_width,
            window_title=self._window_title,
        )

        # Add the flows to the Holoviz Display Operator
        for camera_stream in self._camera_streams.values():
            self.add_flow(
                camera_stream._receiver_operator,
                camera_stream._csi_to_bayer_operator,
                {("output", "input")},
            )
            self.add_flow(
                camera_stream._csi_to_bayer_operator,
                camera_stream._image_processor_operator,
                {("output", "input")},
            )
            self.add_flow(
                camera_stream._image_processor_operator,
                camera_stream._demosaic,
                {("output", "receiver")},
            )

            # If we added a colorize operator, use it, otherwise just use the image shift
            if camera_stream._colorize_operator:
                self.add_flow(
                    camera_stream._demosaic,
                    camera_stream._colorize_operator,
                    {("transmitter", "input")},
                )
                self.add_flow(
                    camera_stream._colorize_operator,
                    camera_stream._image_shift,
                    {("output", "input")},
                )
            else:
                self.add_flow(
                    camera_stream._demosaic,
                    camera_stream._image_shift,
                    {("transmitter", "input")},
                )
            self.add_flow(
                camera_stream._image_shift, visualizer, {("output", "receivers")}
            )

            # If we're doing pose then there will be a preprocessor operator and pipeline
            if camera_stream._preprocessor:
                self.add_flow(
                    camera_stream._image_shift,
                    camera_stream._preprocessor,
                    {("output", "")},
                )
                self.add_flow(camera_stream._preprocessor, camera_stream._format_input)
                self.add_flow(
                    camera_stream._format_input,
                    camera_stream._inference,
                    {("", "receivers")},
                )
                self.add_flow(
                    camera_stream._inference,
                    camera_stream._postprocessor,
                    {("transmitter", "in")},
                )
                self.add_flow(
                    camera_stream._postprocessor, visualizer, {("out", "receivers")}
                )

        # Not using metadata
        self.enable_metadata(False)


import math


def grid_dims(n: int) -> tuple[int, int, float, float]:
    r = int(math.sqrt(n))
    while r and math.ceil(n / r) < r:
        r -= 1
    c = math.ceil(n / r) if r else 0
    # rows, cols, window width, window height
    return r, c, 1.0, r / c


def get_bit_depth(pixel_format):
    if pixel_format == hololink_module.sensors.csi.PixelFormat.RAW_8:
        return 8
    elif pixel_format == hololink_module.sensors.csi.PixelFormat.RAW_10:
        return 10
    elif pixel_format == hololink_module.sensors.csi.PixelFormat.RAW_12:
        return 12
    else:
        return "unknown"


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
        default=1,
        help="Number of cameras to stream and visualize. Default is 1.",
    )
    parser.add_argument(
        "--gain",
        type=int,
        default=32,
        help="Set Analog Gain, RANGE(0 to 240). Default is 32",
    )

    default_configuration = os.path.join(
        os.path.dirname(__file__), "body_pose_estimation.yaml"
    )
    parser.add_argument(
        "--configuration", default=default_configuration, help="Configuration file"
    )
    default_engine = os.path.join(os.path.dirname(__file__), "yolov8n-pose.engine.fp32")
    parser.add_argument(
        "--engine",
        default=default_engine,
        help="TRT engine model",
    )
    parser.add_argument(
        "--receiver-type",
        default="auto",
        choices=["auto", "linux", "coe", "roce"],
        help="Set the receiver type, default is auto, will try and pick the most efficient receiver type",
    )
    parser.add_argument(
        "--enable-body-pose",
        action="store_true",
        help="Enable body pose estimation on camera 0 using the provided engine and configuration file",
    )
    parser.add_argument(
        "--colorize-opacity",
        type=float,
        default=0.9,
        help="Opacity for the colorize operator. Default is 0.9. Range is 0.0 to 1.0",
    )
    parser.add_argument(
        "--lines",
        type=int,
        choices=(720, 1080, 2160),
        help="Set lines, default is 2160",
    )
    parser.add_argument(
        "--frame-rate",
        type=int,
        default=60,
        choices=(30, 60),
        help="Set frame rate, default is 60",
    )
    parser.add_argument(
        "--bit-depth",
        type=int,
        default=10,
        choices=(10, 12),
        help="Set bit depth, default is 10",
    )
    parser.add_argument(
        "--max-streams",
        type=int,
        help="Set the max streams available, AGX5 GrpA default=8, AgX5 GrpB default=2",
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

    # Set AGX5 Grp B design to 2 cameras
    b_mdk_uuid = "7b1fa8c7-31aa-44b6-abcc-eac134461fdc"
    b_uuid_strategy = hololink_module.BasicEnumerationStrategy(
        total_sensors=args.max_streams if args.max_streams else 2,
        total_dataplanes=1,
        sifs_per_sensor=1,
    )
    hololink_module.Enumerator.set_uuid_strategy(b_mdk_uuid, b_uuid_strategy)

    # Set AGX5 Grp A design to "max-streams"
    a_mdk_uuid = "b26763ac-af25-44f6-850e-dce30f33f4e3"
    a_uuid_strategy = hololink_module.BasicEnumerationStrategy(
        total_sensors=args.max_streams if args.max_streams else 8,
        total_dataplanes=1,
        sifs_per_sensor=1,
    )
    hololink_module.Enumerator.set_uuid_strategy(a_mdk_uuid, a_uuid_strategy)

    # Use HIF 0 for now
    channel_metadata = hololink_module.Enumerator.find_channel(channel_ip="192.168.0.2")

    # We don't want to enable "vsync_enable" as we do not have the VSYNC control logic on APB bus 6
    # Also not using ptp_enable
    metadata_overrides = hololink_module.Metadata({"vsync_enable": 0, "ptp_enable": 0})
    channel_metadata.update(metadata_overrides)

    # Get the screen dimensions for the visualizer window
    layout = grid_dims(args.cam)

    # Create an array to hold the camera streams
    camera_streams = {}

    # Get the board UUID
    board_is_mdk = False
    uuid = channel_metadata["fpga_uuid"]
    logging.info(f"Board UUID: {uuid}")
    real_cameras = 2
    if uuid == b_mdk_uuid:
        board_name = "B-Group MDK"
        if args.max_streams:
            max_available_streams = args.max_streams
        else:
            max_available_streams = 2
        default_lines = 1080
    elif uuid == a_mdk_uuid:
        board_name = "A-Group MDK"
        if args.max_streams:
            max_available_streams = args.max_streams
        else:
            max_available_streams = 8
        default_lines = 2160
    else:
        raise Exception(f"Board UUID {uuid} does not match expected MDK or PDK UUIDs")

    # If the user hasn't specified the lines use the board specific defaults
    if args.lines is None:
        args.lines = default_lines

    if args.cam > max_available_streams:
        raise Exception(
            f"Too many cameras [{args.cam}] request for system. Max available streams: {max_available_streams}"
        )

    parent_camera = None

    for cam_index in range(0, args.cam):
        # Get a handle to the Hololink device
        camera_channel = hololink_module.Metadata(channel_metadata)
        hololink_module.DataChannel.use_sensor(camera_channel, cam_index)
        hololink_channel = hololink_module.DataChannel(camera_channel)

        # Get a handle to the camera
        if cam_index < real_cameras:
            camera = hololink_module.sensors.agx5_imx678.agx5_imx678.FramosImx678(
                hololink_channel=hololink_channel, camera_id=cam_index % real_cameras
            )
            if cam_index == 0:
                parent_camera = camera
        else:
            camera = ReplicatedCamera(hololink_channel, cam_index, parent_camera)
        cam_name = f"cam{cam_index}"
        camera_streams[cam_index] = CameraStream(
            cam_index, cam_name, hololink_channel, camera, layout=layout
        )

    sensor_name = parent_camera.get_name()

    rows, cols, window_width, window_height = layout
    logging.info(
        f"Arranging {args.cam} cameras in {rows} rows and {cols} columns, window width factor {window_width}, window height factor {window_height}"
    )

    # Get the pixel format, width, and height from the first camera stream
    first_camera_stream = camera_streams[0]
    # Get a mode from the first camera
    mode = first_camera_stream._camera.get_mode(
        args.lines, args.frame_rate, args.bit_depth
    )

    pixel_format = mode.pixel_format
    width = mode.width
    height = mode.height
    frame_rate = mode.framerate
    camera_bitrate = 0
    logging.info(
        f"Camera pixel format is {pixel_format}, width is {width}, height is {height}, frame rate is {frame_rate}fps"
    )

    app_name = f"AGX5E {board_name} {sensor_name} Multi-Viewer : {len(camera_streams)} Camera(s), {width} x {height} @ {frame_rate:.2f}fps [{get_bit_depth(pixel_format)}bits]"

    try:
        import screeninfo

        screen_info = screeninfo.get_monitors()[0]
        logging.info(
            f"Screen resolution detected as {screen_info.width}x{screen_info.height}"
        )
    except Exception as e:
        logging.warning(
            f"Could not get screen resolution, defaulting to 3840x2160: {e}"
        )
        screen_info = type("ScreenInfo", (object,), {"width": 1920, "height": 1080})()

    # Set up the application
    application = MicroApplication(
        args.headless,
        args.fullscreen,
        cu_context,
        cu_device_ordinal,
        camera_streams,
        args.frame_limit,
        int(screen_info.width * layout[2]),  # window width
        int(screen_info.height * layout[3]),  # window height
        app_name,
        args.engine,
        args.colorize_opacity,
        args.enable_body_pose,
        receiver_type=args.receiver_type,
    )

    application.config(args.configuration)

    # Run it.
    hololink = hololink_channel.hololink()
    hololink.start()
    try:
        hololink.reset()

        for camera_stream in camera_streams.values():
            camera = camera_stream._camera
            camera.configure(mode)
            camera.set_analog_gain_reg(args.gain)

        application.run()
    finally:
        hololink.stop()

    (cu_result,) = cuda.cuDevicePrimaryCtxRelease(cu_device)
    assert cu_result == cuda.CUresult.CUDA_SUCCESS


if __name__ == "__main__":
    main()
