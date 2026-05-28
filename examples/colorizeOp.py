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

######################################################################
# Operator which will apply a colorization effect to the
# input image by modifying the pixel values on the GPU.

import cuda.bindings.driver as cuda
import cupy as cp
import holoscan
import numpy as np
from holoscan.core import Operator

######################################################################
# CUDA kernel: one thread per pixel
cuda_src = r"""
extern "C" __global__
void make_red(unsigned short* __restrict__ in16,
              int width, int height, int in_stride_words,
              unsigned short red, unsigned short green, unsigned short blue, float opacity)
{
    int x = blockDim.x * blockIdx.x + threadIdx.x;
    int y = blockDim.y * blockIdx.y + threadIdx.y;
    if (x >= width || y >= height) return;

    // Compute input/output pointers respecting stride
    unsigned short* in_row = in16 + (y * in_stride_words*3);

    // Set red to max value
    if (red > 0) {
        in_row[x*3] = (unsigned short)(float(in_row[x*3]) * opacity) +  (unsigned short)(float(red) * (1.0f - opacity));
    }
    if (green > 0) {
        in_row[x*3 + 1] = (unsigned short)(float(in_row[x*3 + 1]) * opacity) +  (unsigned short)(float(green) * (1.0f - opacity));
    }
    if (blue > 0) {
        in_row[x*3 + 2] = (unsigned short)(float(in_row[x*3 + 2]) * opacity) +  (unsigned short)(float(blue) * (1.0f - opacity));
    }
}
"""

make_red_kernel = cp.RawKernel(cuda_src, "make_red")


######################################################################
def launch_rgb10_to_rgba8(
    in_dev_u16, width, height, in_stride_words, red, green, blue, opacity
):
    """
    Ignore input for now
    # in_dev_u16: CuPy array on device, dtype=uint16, shape (height, in_stride_words)
    width: number of active pixels per row
    height: number of rows
    in_stride_words: stride in 32-bit words (may be >= width due to padding)

    """
    #    print(f"launch_rgb10_to_rgba8: width={width}, height={height}, in_stride_words={in_stride_words}")

    # Grid/block configuration
    block = (32, 8, 1)
    grid = ((width + block[0] - 1) // block[0], (height + block[1] - 1) // block[1], 1)

    make_red_kernel(
        grid,
        block,
        (
            in_dev_u16,
            np.int32(width),
            np.int32(height),
            np.int32(in_stride_words),
            np.uint16(red),
            np.uint16(green),
            np.uint16(blue),
            np.float32(opacity),
        ),
    )


#######################################################################


class ColorizeOperator(Operator):
    def __init__(
        self,
        *args,
        in_tensor_name="",
        out_tensor_name="",
        red=0,
        green=0,
        blue=0,
        opacity=0.9,
        width=0,
        height=0,
        **kwargs
    ):
        super().__init__(*args, **kwargs)
        self.in_tensor_name = in_tensor_name
        self.out_tensor_name = out_tensor_name
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        if self.opacity < 0.0:
            self.opacity = 0.0
        elif self.opacity > 1.0:
            self.opacity = 1.0
        self.width = width
        self.height = height

    def setup(self, spec):
        spec.input("input")
        spec.output("output")

    def configure(self, width, height):
        self.width = width
        self.height = height

    def compute(self, op_input, op_output, context):
        msg = op_input.receive("input")
        in_dev_u8 = cp.asarray(msg.get(self.in_tensor_name))
        in_dev_u16 = in_dev_u8.view(cp.uint16)

        # For now, ignoring input data and generating dummy output
        height = self.height
        in_stride_words = self.width
        width = self.width

        # Launch kernel
        launch_rgb10_to_rgba8(
            in_dev_u16,
            width,
            height,
            in_stride_words,
            self.red,
            self.green,
            self.blue,
            self.opacity,
        )

        op_output.emit({self.out_tensor_name: holoscan.as_tensor(in_dev_u8)}, "output")
