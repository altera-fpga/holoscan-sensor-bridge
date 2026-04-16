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
set_fileset_property QUARTUS_SYNTH TOP_LEVEL hsb_mipi_holo_shim
add_fileset_file      common_axis_shim.sv          SYSTEM_VERILOG                    PATH \
  "systemverilog/common_axis_shim.sv"
add_fileset_file hsb_mipi_holo_shim/systemverilog/hsb_mipi_holo_shim.sv SYSTEM_VERILOG PATH  \
  "../hsb_mipi_holo_shim/systemverilog/hsb_mipi_holo_shim.sv"
add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL hsb_mipi_holo_shim

# Adding Core hsb_mipi_holo_shim
add_fileset_file hsb_mipi_holo_shim/systemverilog/hsb_mipi_holo_shim.sv SYSTEM_VERILOG PATH \
  "../hsb_mipi_holo_shim/systemverilog/hsb_mipi_holo_shim.sv"

add_fileset SIM_VHDL SIM_VHDL "" ""
set_fileset_property SIM_VHDL TOP_LEVEL hsb_mipi_holo_shim

# Adding Core hsb_mipi_holo_shim
add_fileset_file hsb_mipi_holo_shim/systemverilog/hsb_mipi_holo_shim.sv SYSTEM_VERILOG PATH \
  "../hsb_mipi_holo_shim/systemverilog/hsb_mipi_holo_shim.sv"

set_module_property NAME hsb_mipi_holo_shim
set_module_property DESCRIPTION "This IP adapts MIPI CSI-2 packet output \
to that expected by the Hololink Sensor Interface"
set_module_property DISPLAY_NAME "MIPI CSI-2 to Hololink Shim"

# --------------------------------------------------------------------------------------------------
# --                                                                                              --
# -- Callbacks                                                                                    --
# --                                                                                              --
# --------------------------------------------------------------------------------------------------
# Declare Standard Interfaces
common_add_clk  axis_aclk

common_add_rstn axis_aresetn  axis_aclk

add_display_item  "" "Streaming Parameters"  GROUP

add_parameter           C_AXIS_TDATA_WIDTH        INTEGER                    64
set_parameter_property  C_AXIS_TDATA_WIDTH        DISPLAY_NAME               "Bus Data Width"
set_parameter_property  C_AXIS_TDATA_WIDTH        VISIBLE                    true
set_parameter_property  C_AXIS_TDATA_WIDTH        ALLOWED_RANGES             32:256
set_parameter_property  C_AXIS_TDATA_WIDTH        HDL_PARAMETER              false
set_parameter_property  C_AXIS_TDATA_WIDTH        AFFECTS_ELABORATION        true
set_parameter_property  C_AXIS_TDATA_WIDTH        DESCRIPTION                "Bus Data width"

add_parameter           C_AXIS_TUSER_WIDTH        INTEGER                    1
set_parameter_property  C_AXIS_TUSER_WIDTH        DISPLAY_NAME               "AXIS Tuser Width"
set_parameter_property  C_AXIS_TUSER_WIDTH        VISIBLE                    true
set_parameter_property  C_AXIS_TUSER_WIDTH        HDL_PARAMETER              true
set_parameter_property  C_AXIS_TUSER_WIDTH        AFFECTS_ELABORATION        true
set_parameter_property  C_AXIS_TUSER_WIDTH        DESCRIPTION                "AXIS Tuser width"

add_display_item  ""  "Streaming Parameters"      GROUP

add_display_item      "Streaming Parameters"      C_AXIS_TDATA_WIDTH parameter
add_display_item      "Streaming Parameters"      C_AXIS_TUSER_WIDTH parameter

# AXIS width Generics
add_parameter           C_S_AXIS_TDATA_WIDTH      INTEGER             64
set_parameter_property  C_S_AXIS_TDATA_WIDTH      VISIBLE             false
set_parameter_property  C_S_AXIS_TDATA_WIDTH      DERIVED             true
set_parameter_property  C_S_AXIS_TDATA_WIDTH      HDL_PARAMETER       true

add_parameter           C_M_AXIS_TDATA_WIDTH      INTEGER             64
set_parameter_property  C_M_AXIS_TDATA_WIDTH      VISIBLE             false
set_parameter_property  C_M_AXIS_TDATA_WIDTH      DERIVED             true
set_parameter_property  C_M_AXIS_TDATA_WIDTH      HDL_PARAMETER       true

# Callback for the composition of this component
set_module_property ELABORATION_CALLBACK elaboration_cb

proc elaboration_cb {} {

  # set Master and Slave AXIS width from common width parameter
  set axis_tdata_width   [ get_parameter_value   C_AXIS_TDATA_WIDTH ]

  set_parameter_value     C_S_AXIS_TDATA_WIDTH    ${axis_tdata_width}
  set_parameter_value     C_M_AXIS_TDATA_WIDTH    ${axis_tdata_width}

  common_add_axi4s_interface_tkeep s_axis axis_aclk axis_aresetn slave
  common_add_axi4s_interface_tkeep m_axis axis_aclk axis_aresetn master

}
