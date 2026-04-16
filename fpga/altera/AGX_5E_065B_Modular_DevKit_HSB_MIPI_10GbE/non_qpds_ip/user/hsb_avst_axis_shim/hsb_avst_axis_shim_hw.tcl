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

package require -exact qsys 18.0

set_module_property NAME                         hsb_avst_axis_shim
set_module_property VERSION                      1.0
set_module_property GROUP                        "Generic Shims"
set_module_property EDITABLE                     false
set_module_property AUTHOR                       "Altera"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property INTERNAL                     false

# Include Packaging Helpers
source ../common_tcl/common_package.tcl

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH my_generate ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL hsb_avst_axis_shim

proc my_generate { entity } {
}

# Adding Core hsb_avst_axis_shim
add_fileset_file hsb_avst_axis_shim.sv SYSTEM_VERILOG PATH systemverilog/hsb_avst_axis_shim.sv

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL hsb_avst_axis_shim

# Adding Core hsb_avst_axis_shim
add_fileset_file hsb_avst_axis_shim.sv SYSTEM_VERILOG PATH systemverilog/hsb_avst_axis_shim.sv

add_fileset SIM_VHDL SIM_VHDL "" ""
set_fileset_property SIM_VHDL TOP_LEVEL hsb_avst_axis_shim

# Adding Core hsb_avst_axis_shim
add_fileset_file hsb_avst_axis_shim.sv SYSTEM_VERILOG PATH systemverilog/hsb_avst_axis_shim.sv
set_module_property NAME hsb_avst_axis_shim
set_module_property DESCRIPTION "This IP provides AVST (non video) to AXIS conversions"
set_module_property DISPLAY_NAME "AVST to AXIS Shim"

# --------------------------------------------------------------------------------------------------
# --                                                                                              --
# -- Callbacks                                                                                    --
# --                                                                                              --
# --------------------------------------------------------------------------------------------------
# Declare Standard Interfaces
common_add_clk  clk

common_add_rstn resetn  clk

add_display_item  "" "Streaming Parameters"  GROUP

add_parameter           C_AV_EMPTY_WIDTH            Integer               3
set_parameter_property  C_AV_EMPTY_WIDTH            DISPLAY_NAME          "Empty Width"
set_parameter_property  C_AV_EMPTY_WIDTH            HDL_PARAMETER         true
set_parameter_property  C_AV_EMPTY_WIDTH            AFFECTS_ELABORATION   true
set_parameter_property  C_AV_EMPTY_WIDTH            DESCRIPTION           "Empty width"
set_parameter_property  C_AV_EMPTY_WIDTH            VISIBLE               false
set_parameter_property  C_AV_EMPTY_WIDTH            DERIVED               true


add_parameter           C_M_AXIS_TDATA_WIDTH        INTEGER               64
set_parameter_property  C_M_AXIS_TDATA_WIDTH        DISPLAY_NAME          "Bus Data Width"
set_parameter_property  C_M_AXIS_TDATA_WIDTH        VISIBLE               true
set_parameter_property  C_M_AXIS_TDATA_WIDTH        ALLOWED_RANGES        32:96
set_parameter_property  C_M_AXIS_TDATA_WIDTH        HDL_PARAMETER         true
set_parameter_property  C_M_AXIS_TDATA_WIDTH        AFFECTS_ELABORATION   true
set_parameter_property  C_M_AXIS_TDATA_WIDTH        DESCRIPTION           "Bus Data width"

add_parameter           C_AXIS_TUSER_WIDTH          INTEGER               1
set_parameter_property  C_AXIS_TUSER_WIDTH          DISPLAY_NAME          "AXIS Tuser Width"
set_parameter_property  C_AXIS_TUSER_WIDTH          VISIBLE               true
set_parameter_property  C_AXIS_TUSER_WIDTH          HDL_PARAMETER         true
set_parameter_property  C_AXIS_TUSER_WIDTH          AFFECTS_ELABORATION   true
set_parameter_property  C_AXIS_TUSER_WIDTH          DESCRIPTION           "AXIS Tuser width"

add_parameter           C_BYTE_SWAP                 INTEGER               1
set_parameter_property  C_BYTE_SWAP                 ALLOWED_RANGES        0:1
set_parameter_property  C_BYTE_SWAP                 DISPLAY_HINT          boolean
set_parameter_property  C_BYTE_SWAP                 HDL_PARAMETER         true
set_parameter_property  C_BYTE_SWAP                 DISPLAY_NAME          "Byte Swap"
set_parameter_property  C_BYTE_SWAP                 DESCRIPTION           "Swaps Byte order of entire bus."
set_parameter_property  C_BYTE_SWAP                 AFFECTS_ELABORATION   false


add_display_item  ""  "Streaming Parameters"  GROUP
add_display_item "Streaming Parameters" C_M_AXIS_TDATA_WIDTH parameter
add_display_item "Streaming Parameters" C_AXIS_TUSER_WIDTH parameter
add_display_item "Streaming Parameters" C_BYTE_SWAP parameter

# Callback for the composition of this component
set_module_property ELABORATION_CALLBACK elaboration_cb

proc elaboration_cb {} {

  set bytes [expr [ get_parameter_value   C_M_AXIS_TDATA_WIDTH ]/8]

  add_av_st_input_port   clk  av_sink  8 1 2 0 0 1 "" ${bytes}

  set_parameter_value     C_AV_EMPTY_WIDTH   [clogb2_pure ${bytes}]

  common_add_axi4s_interface_tkeep  m_axis clk resetn master

}
