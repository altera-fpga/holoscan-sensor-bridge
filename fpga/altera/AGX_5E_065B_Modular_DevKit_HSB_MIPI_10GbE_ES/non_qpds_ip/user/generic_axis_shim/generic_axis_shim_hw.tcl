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

package require -exact qsys 24.3.1

set_module_property VERSION                      1.0
set_module_property GROUP                        "Generic Shims"
set_module_property EDITABLE                     false
set_module_property AUTHOR                       "Altera"
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property INTERNAL                     false

# Include Packaging Helpers
source ../common_tcl/common_package.tcl

proc my_generate { entity } {
}

add_fileset QUARTUS_SYNTH QUARTUS_SYNTH my_generate ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL generic_axis_shim
add_fileset_file      common_axis_shim.sv          SYSTEM_VERILOG                    PATH \
  "systemverilog/common_axis_shim.sv"
add_fileset_file generic_axis_shim/systemverilog/generic_axis_shim.sv SYSTEM_VERILOG PATH  \
  "../generic_axis_shim/systemverilog/generic_axis_shim.sv"
add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL generic_axis_shim

# Adding Core generic_axis_shim
add_fileset_file generic_axis_shim/systemverilog/generic_axis_shim.sv SYSTEM_VERILOG PATH \
  "../generic_axis_shim/systemverilog/generic_axis_shim.sv"

add_fileset SIM_VHDL SIM_VHDL "" ""
set_fileset_property SIM_VHDL TOP_LEVEL generic_axis_shim

# Adding Core generic_axis_shim
add_fileset_file generic_axis_shim/systemverilog/generic_axis_shim.sv SYSTEM_VERILOG PATH \
  "../generic_axis_shim/systemverilog/generic_axis_shim.sv"

set_module_property NAME generic_axis_shim
set_module_property DESCRIPTION "This IP can be used to adapt AXIS interfaces with different sideband signals"
set_module_property DISPLAY_NAME "Generic AXIS Shim"

# --------------------------------------------------------------------------------------------------
# --                                                                                              --
# -- Callbacks                                                                                    --
# --                                                                                              --
# --------------------------------------------------------------------------------------------------
# Declare Standard Interfaces
common_add_clk  axis_aclk

common_add_rstn axis_aresetn  axis_aclk

add_display_item  "" "Streaming Parameters"  GROUP

# Common AXIS width parameter
add_parameter           C_AXIS_TDATA_WIDTH        INTEGER                   64
set_parameter_property  C_AXIS_TDATA_WIDTH        DISPLAY_NAME              "Bus Data Width"
set_parameter_property  C_AXIS_TDATA_WIDTH        VISIBLE                   true
set_parameter_property  C_AXIS_TDATA_WIDTH        ALLOWED_RANGES            32:256
set_parameter_property  C_AXIS_TDATA_WIDTH        HDL_PARAMETER             true
set_parameter_property  C_AXIS_TDATA_WIDTH        AFFECTS_ELABORATION       true
set_parameter_property  C_AXIS_TDATA_WIDTH        DESCRIPTION               "Bus Data width"

# Slave AXIS parameters
add_parameter           C_S_AXIS_TUSER_WIDTH      INTEGER                   1
set_parameter_property  C_S_AXIS_TUSER_WIDTH      DISPLAY_NAME              "AXIS slave Tuser Width"
set_parameter_property  C_S_AXIS_TUSER_WIDTH      VISIBLE                   true
set_parameter_property  C_S_AXIS_TUSER_WIDTH      HDL_PARAMETER             true
set_parameter_property  C_S_AXIS_TUSER_WIDTH      AFFECTS_ELABORATION       true
set_parameter_property  C_S_AXIS_TUSER_WIDTH      DESCRIPTION               "AXIS slave Tuser width"

add_parameter           C_S_AXIS_USE_TSTRB        INTEGER                   0
set_parameter_property  C_S_AXIS_USE_TSTRB        DISPLAY_NAME              "Use TSTRB on AXIS slave"
set_parameter_property  C_S_AXIS_USE_TSTRB        VISIBLE                   true
set_parameter_property  C_S_AXIS_USE_TSTRB        HDL_PARAMETER             true
set_parameter_property  C_S_AXIS_USE_TSTRB        DISPLAY_HINT              boolean
set_parameter_property  C_S_AXIS_USE_TSTRB        AFFECTS_ELABORATION       true

add_parameter           C_S_AXIS_USE_TKEEP        INTEGER                   0
set_parameter_property  C_S_AXIS_USE_TKEEP        DISPLAY_NAME              "Use TKEEP on AXIS slave"
set_parameter_property  C_S_AXIS_USE_TKEEP        VISIBLE                   true
set_parameter_property  C_S_AXIS_USE_TKEEP        HDL_PARAMETER             true
set_parameter_property  C_S_AXIS_USE_TKEEP        DISPLAY_HINT              boolean
set_parameter_property  C_S_AXIS_USE_TKEEP        AFFECTS_ELABORATION       true

# Master AXIS parameters
add_parameter           C_M_AXIS_TUSER_WIDTH      INTEGER                   1
set_parameter_property  C_M_AXIS_TUSER_WIDTH      DISPLAY_NAME              "AXIS master Tuser Width"
set_parameter_property  C_M_AXIS_TUSER_WIDTH      VISIBLE                   true
set_parameter_property  C_M_AXIS_TUSER_WIDTH      HDL_PARAMETER             true
set_parameter_property  C_M_AXIS_TUSER_WIDTH      AFFECTS_ELABORATION       true
set_parameter_property  C_M_AXIS_TUSER_WIDTH      DESCRIPTION               "AXIS master Tuser width"

add_parameter           C_M_AXIS_USE_TSTRB        INTEGER                   0
set_parameter_property  C_M_AXIS_USE_TSTRB        DISPLAY_NAME              "Use TSTRB on AXIS master"
set_parameter_property  C_M_AXIS_USE_TSTRB        VISIBLE                   true
set_parameter_property  C_M_AXIS_USE_TSTRB        HDL_PARAMETER             true
set_parameter_property  C_M_AXIS_USE_TSTRB        DISPLAY_HINT              boolean
set_parameter_property  C_M_AXIS_USE_TSTRB        AFFECTS_ELABORATION       true

add_parameter           C_M_AXIS_USE_TKEEP        INTEGER                   0
set_parameter_property  C_M_AXIS_USE_TKEEP        DISPLAY_NAME              "Use TKEEP on AXIS master"
set_parameter_property  C_M_AXIS_USE_TKEEP        VISIBLE                   true
set_parameter_property  C_M_AXIS_USE_TKEEP        HDL_PARAMETER             true
set_parameter_property  C_M_AXIS_USE_TKEEP        DISPLAY_HINT              boolean
set_parameter_property  C_M_AXIS_USE_TKEEP        AFFECTS_ELABORATION       true


add_display_item  ""  "Streaming Parameters"      GROUP

add_display_item      "Streaming Parameters"      C_AXIS_TDATA_WIDTH    parameter
add_display_item      "Streaming Parameters"      C_S_AXIS_TUSER_WIDTH  parameter
add_display_item      "Streaming Parameters"      C_S_AXIS_USE_TSTRB    parameter
add_display_item      "Streaming Parameters"      C_S_AXIS_USE_TKEEP    parameter
add_display_item      "Streaming Parameters"      C_M_AXIS_TUSER_WIDTH  parameter
add_display_item      "Streaming Parameters"      C_M_AXIS_USE_TSTRB    parameter
add_display_item      "Streaming Parameters"      C_M_AXIS_USE_TKEEP    parameter

# Callback for the composition of this component
set_module_property ELABORATION_CALLBACK elaboration_cb

proc elaboration_cb {} {

  # set Master and Slave AXIS width from common width parameter
  set axis_tdata_width   [ get_parameter_value   C_AXIS_TDATA_WIDTH ]
  
  set axis_s_tuser_width [ get_parameter_value   C_S_AXIS_TUSER_WIDTH ]
  set axis_s_use_tstrb   [ get_parameter_value   C_S_AXIS_USE_TSTRB ]
  set axis_s_use_tkeep   [ get_parameter_value   C_S_AXIS_USE_TKEEP ]
  
  set axis_m_tuser_width [ get_parameter_value   C_M_AXIS_TUSER_WIDTH ]
  set axis_m_use_tstrb   [ get_parameter_value   C_M_AXIS_USE_TSTRB ]
  set axis_m_use_tkeep   [ get_parameter_value   C_M_AXIS_USE_TKEEP ]

  # proc common_add_axi4s_interface_flexible {prefix, clk, rst, dir, use_tkeep, use_tstrb, tuser_width, tdata_width}
  common_add_axi4s_interface_flexible s_axis axis_aclk axis_aresetn slave ${axis_s_use_tkeep} ${axis_s_use_tstrb} ${axis_s_tuser_width} ${axis_tdata_width}
  common_add_axi4s_interface_flexible m_axis axis_aclk axis_aresetn master ${axis_m_use_tkeep} ${axis_m_use_tstrb} ${axis_m_tuser_width} ${axis_tdata_width}

}
