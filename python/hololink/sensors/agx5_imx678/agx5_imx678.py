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

from .agx5_imx678_mode import (
    AGX5_IMX678_TABLE_END,
    AGX5_IMX678_TABLE_WAIT_MS,
    agx_imx678_start,
    agx_imx678_stop,
)

######################################################################################
# Camera info
DRIVER_NAME = "FramosImx678"

# Camera I2C address.
CAM_I2C_ADDRESS = 0x37

######################################################################################


class FramosImx678:
    def __init__(
        self, hololink_channel, i2c_bus=hololink_module.CAM_I2C_BUS, camera_id=0
    ):

        self.cam_id = camera_id
        self._hololink_channel = hololink_channel
        self._hololink = hololink_channel.hololink()
        self._i2c_bus = i2c_bus
        self._i2c = self._hololink.get_i2c(i2c_bus)

    def configure(self, frame_format):
        print(
            f"Configuring camera with frame format: Width={frame_format.width}, Height={frame_format.height}, Framerate={frame_format.framerate}, Pixel Format={frame_format.pixel_format}"
        )
        self.set_mode(frame_format)
        self._initialize(frame_format.settings)

    def _initialize(self, settings):
        self.write_registers(settings)

    def set_pattern(self):
        pass

    def start(self):
        print("Starting camera")
        self.write_registers(agx_imx678_start)

    def stop(self):
        self.write_registers(agx_imx678_stop)

    def set_mode(self, frame_format):
        self._digital_black = 50  # 10bit value for digital black as per "Black Level Adjustment Function" in "IMX678 Software Reference Manual"

        self._frame_format = frame_format
        self._width = self._frame_format.width
        self._height = self._frame_format.height
        self._pixel_format = self._frame_format.pixel_format

    def configure_converter(self, converter):
        print("configure_converter")

        # Calculate the number of bytes in the active line
        transmitted_line_bytes = converter.transmitted_line_bytes(
            self._frame_format.pixel_format, self._width
        )
        # received bytes per line = RAW12 Header (4) + transmitted_line_bytes + Footer (4)
        received_line_bytes = 4 + transmitted_line_bytes + 4

        # start_byte = Frame Start (8) + 1 embedded data line + RAW12(4). RAW12 is to align to the active pixel data
        start_byte = 8
        start_byte += received_line_bytes
        start_byte += 4

        # Trailing bytes = frame end(8) - RAW12(4). RAW12 comes from the offset added to the start_byte
        trailing_bytes = 8 - 4

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
            CAM_I2C_ADDRESS, write_bytes[: serializer.length()], read_byte_count
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
            CAM_I2C_ADDRESS,
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
