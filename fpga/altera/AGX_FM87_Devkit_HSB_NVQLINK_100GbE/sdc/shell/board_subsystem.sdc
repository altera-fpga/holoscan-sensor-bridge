###################################################################################
# Copyright (C) Altera Corporation
#
# This software and the related documents are Altera copyrighted materials, and
# your use of them is governed by the express license under which they were
# provided to you ("License"). Unless the License provides otherwise, you may
# not use, modify, copy, publish, distribute, disclose or transmit this software
# or the related documents without Altera's prior written permission.
#
# This software and the related documents are provided as is, with no express
# or implied warranties, other than those that are expressly stated in the License.
###################################################################################

create_clock -name {clk_100} -period 10.000 [get_ports {clk_100_mhz}]
create_clock -name {fpga_sgpio_clk} -period 100.000 -waveform {0 50} {fpga_sgpio_clk}

derive_pll_clocks
derive_clock_uncertainty

# Reset to fpga is asynchronous
set_false_path -from [get_ports {rst_pb_n}]

# Asynchronous. No timing requirement to the push buttons
set_false_path -from {get_ports {user_pb*}}

set_input_delay -add_delay -max -clock_fall -clock [get_clocks {fpga_sgpio_clk}]  6 [get_ports {fpga_sgpi}]
set_input_delay -add_delay -min -clock_fall -clock [get_clocks {fpga_sgpio_clk}]  5 [get_ports {fpga_sgpi}]
set_input_delay -add_delay -max -clock_fall -clock [get_clocks {fpga_sgpio_clk}]  6 [get_ports {fpga_sgpio_sync}]
set_input_delay -add_delay -min -clock_fall -clock [get_clocks {fpga_sgpio_clk}]  5 [get_ports {fpga_sgpio_sync}]

set_output_delay -add_delay -max -clock_fall -clock [get_clocks {fpga_sgpio_clk}]  2   [get_ports {fpga_sgpo}]
set_output_delay -add_delay -min -clock_fall -clock [get_clocks {fpga_sgpio_clk}]  0.7 [get_ports {fpga_sgpo}]

set_clock_groups -asynchronous -group [get_clocks {clk_100}]
set_clock_groups -asynchronous -group [get_clocks {fpga_sgpio_clk}]

