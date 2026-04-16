###################################################################################
# Copyright (C) 2025 Altera Corporation
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

#**************************************************************
# Create input reference Clocks
#**************************************************************

create_clock -period "100 MHz"        -name {clk_100_mhz} [get_ports clk_100_mhz]
create_clock -period "156.250000 MHz" -name {refclk_eth}  [get_ports refclk_eth]

# derive_pll_clocks -create_base_clocks
derive_clock_uncertainty

# Design Rule Check RES-50101 - Intra-Clock False path Reset synchronizer
# Overriding the false path constraint set in the iopll sdc. The input reset is synchronous with the iopll refclk.
set_false_path -no_synchronizer -to [get_keepers {*|clock_subsystem|iopll_0|iopll_0|tennm_ph2_iopll~pll_ctrl_reg}]
