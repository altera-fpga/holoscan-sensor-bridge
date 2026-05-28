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

# See README.md for detailed information.

import logging
import time

import hololink as hololink_module

# from . import agx5_imx678_mode as modes
from .agx5_imx678_mode import (
    AGX5_IMX678_TABLE_END,
    AGX5_IMX678_TABLE_WAIT_MS,
    AGX5_IMX678_WAIT_MS,
    agx_imx678_start,
    agx_imx678_stop,
    available_resolutions,
    imx678_base_settings,
)

######################################################################################
# Camera info
DRIVER_NAME = "Imx678-AGX5"

# Camera I2C address.
CAM_I2C_ADDRESS_0 = 0x37
CAM_I2C_ADDRESS_1 = 0x1A

######################################################################################


class FramosImx678:
    def __init__(
        self, hololink_channel, i2c_bus=hololink_module.CAM_I2C_BUS, camera_id=0
    ):
        print(f"Initializing FramosImx678 with camera_id={camera_id}")
        self.cam_id = camera_id
        self._hololink_channel = hololink_channel
        self._hololink = hololink_channel.hololink()
        self._i2c_bus = i2c_bus
        self._i2c = self._hololink.get_i2c(i2c_bus)
        if camera_id == 0:
            self._camera_i2c_address = CAM_I2C_ADDRESS_0
        elif camera_id == 1:
            self._camera_i2c_address = CAM_I2C_ADDRESS_1
        else:
            raise Exception(f"Unsupported camera_id={camera_id}")

    # Return the name of the sensor
    def get_name(self):
        return DRIVER_NAME

    # Returns the mode matching the given settings, or raises an exception if not found.
    def get_mode(self, height, frame_rate, bit_depth):
        logging.info(
            f"Getting mode for height={height}, frame_rate={frame_rate}, bit_depth={bit_depth}"
        )
        if bit_depth == 10:
            pixel_format = hololink_module.sensors.csi.PixelFormat.RAW_10
        elif bit_depth == 12:
            pixel_format = hololink_module.sensors.csi.PixelFormat.RAW_12
        else:
            raise Exception(f"Unsupported bit depth: {bit_depth}")

        for mode in available_resolutions:
            logging.debug(
                f"Checking mode: height={mode.height}, frame_rate={mode.framerate}, pixel_format={mode.pixel_format}"
            )
            if (
                mode.height == height
                and mode.framerate == frame_rate
                and mode.pixel_format == pixel_format
            ):
                return mode
        raise Exception(f"Unsupported mode: {height}p{frame_rate}fps{pixel_format}")

    def configure(self, mode):
        logging.info(
            f"Configuring camera with frame format: Width={mode.width}, Height={mode.height}, Framerate={mode.framerate}, Pixel Format={mode.pixel_format}"
        )
        self.set_mode(mode)
        self._initialize(mode.settings)

    def _initialize(self, settings):
        # Write the base settings for the sensor
        self.write_registers(imx678_base_settings)
        # Write the settings for the selected resolution
        self.write_registers(settings)

    def set_pattern(self):
        pass

    def start(self):
        logging.info("Starting camera")
        self.write_registers(agx_imx678_start)

    def stop(self):
        logging.info("Stopping camera")
        self.write_registers(agx_imx678_stop)

    def set_mode(self, mode):
        self._digital_black = 50  # 10bit value for digital black as per "Black Level Adjustment Function" in "IMX678 Software Reference Manual"

        self._mode = mode
        self._width = self._mode.width
        self._height = self._mode.height
        self._pixel_format = self._mode.pixel_format

    def set_analog_gain_reg(self, value=0x20):
        if value < 0x00:
            logging.warn(f"AG value {value} is lower than the minimum.")
            value = 0x00

        if value > 0xF0:
            logging.warn(f"AG value {value} is more than maximum.")
            value = 0xF0

        self.set_register(0x3070, (value & 0xFF))
        self.set_register(0x3071, (value & 0x300) >> 8)

        time.sleep(AGX5_IMX678_WAIT_MS / 1000)

    def configure_converter(self, converter):
        logging.info("configure_converter")

        # where do we find the first received byte?
        start_byte = converter.receiver_start_byte()

        # Calculate the number of bytes in the active line
        transmitted_line_bytes = converter.transmitted_line_bytes(
            self._pixel_format, self._width
        )
        received_line_bytes = converter.received_line_bytes(transmitted_line_bytes)

        trailing_bytes = 0

        converter.configure(
            start_byte,
            received_line_bytes,
            self._width,
            self._height,
            self._pixel_format,
            trailing_bytes,
        )

    def get_register(self, register):
        logging.debug("get_register(register=%d(0x%X))" % (register, register))
        write_bytes = bytearray(100)
        serializer = hololink_module.Serializer(write_bytes)
        serializer.append_uint16_be(register)
        read_byte_count = 1
        reply = self._i2c.i2c_transaction(
            self._camera_i2c_address,
            write_bytes[: serializer.length()],
            read_byte_count,
        )
        deserializer = hololink_module.Deserializer(reply)
        r = deserializer.next_uint8()
        logging.debug(
            "get_register(register=%d(0x%X))=%d(0x%X)" % (register, register, r, r)
        )
        return r

    def set_register(self, register, value, timeout=None):
        logging.debug(
            "set_register(register=%d(0x%X), value=%d(0x%X))"
            % (register, register, value, value)
        )
        write_bytes = bytearray(100)
        serializer = hololink_module.Serializer(write_bytes)
        serializer.append_uint16_be(register)
        serializer.append_uint8(value)
        read_byte_count = 0
        self._i2c.i2c_transaction(
            self._camera_i2c_address,
            write_bytes[: serializer.length()],
            read_byte_count,
            timeout=timeout,
        )

    def write_registers(self, regs):
        for reg, value in regs:
            if reg == AGX5_IMX678_TABLE_END:
                break
            elif reg == AGX5_IMX678_TABLE_WAIT_MS:
                time.sleep(value / 1000)
            else:
                self.set_register(reg, value)

    def pixel_format(self):
        return self._pixel_format

    def bayer_format(self):
        return hololink_module.sensors.csi.BayerFormat.RGGB

    def optical_black(self):
        if self._pixel_format == hololink_module.sensors.csi.PixelFormat.RAW_10:
            optical_black = self._digital_black
        else:
            optical_black = self._digital_black << (12 - 10)
        return optical_black
