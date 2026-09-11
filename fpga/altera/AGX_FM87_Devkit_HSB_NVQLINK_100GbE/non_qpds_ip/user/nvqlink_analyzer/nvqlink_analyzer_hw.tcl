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

# +-----------------------------------
# | 
# +-----------------------------------
package require -exact qsys 24.3.1

# +-----------------------------------
# | module nvqlink_analyzer
# | 
set_module_property DESCRIPTION "NVQLink instrumentation analyzer: PTP/SIF ILA capture and RAM player self-test datapath for the HSB sensor loop"
set_module_property NAME nvqlink_analyzer
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property OPAQUE_ADDRESS_MAP true
set_module_property AUTHOR "Intel Corporation"
set_module_property DISPLAY_NAME nvqlink_analyzer
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE false
set_module_property REPORT_TO_TALKBACK false
set_module_property ALLOW_GREYBOX_GENERATION false
set_module_property REPORT_HIERARCHY false
set_module_property ELABORATION_CALLBACK nvqlink_analyzer_elaboration_cb
# | 
# +-----------------------------------

# +-----------------------------------
# | file sets
# | 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL nvqlink_analyzer
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file nvqlink_analyzer.sv SYSTEM_VERILOG PATH systemverilog/nvqlink_analyzer.sv TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL nvqlink_analyzer
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file nvqlink_analyzer.sv SYSTEM_VERILOG PATH systemverilog/nvqlink_analyzer.sv
# | 
# +-----------------------------------

# +-----------------------------------
# | parameters
# | 
add_parameter DATAPATH_WIDTH INTEGER 512
set_parameter_property DATAPATH_WIDTH DEFAULT_VALUE 512
set_parameter_property DATAPATH_WIDTH DISPLAY_NAME DATAPATH_WIDTH
set_parameter_property DATAPATH_WIDTH UNITS None
set_parameter_property DATAPATH_WIDTH HDL_PARAMETER true
set_parameter_property DATAPATH_WIDTH AFFECTS_ELABORATION true

add_parameter DATAKEEP_WIDTH INTEGER 64
set_parameter_property DATAKEEP_WIDTH DEFAULT_VALUE 64
set_parameter_property DATAKEEP_WIDTH DISPLAY_NAME DATAKEEP_WIDTH
set_parameter_property DATAKEEP_WIDTH UNITS None
set_parameter_property DATAKEEP_WIDTH HDL_PARAMETER true
set_parameter_property DATAKEEP_WIDTH AFFECTS_ELABORATION true

add_parameter DATAUSER_WIDTH INTEGER 2
set_parameter_property DATAUSER_WIDTH DEFAULT_VALUE 2
set_parameter_property DATAUSER_WIDTH DISPLAY_NAME DATAUSER_WIDTH
set_parameter_property DATAUSER_WIDTH UNITS None
set_parameter_property DATAUSER_WIDTH HDL_PARAMETER true
set_parameter_property DATAUSER_WIDTH AFFECTS_ELABORATION true

add_parameter PTP_CLK_FREQ INTEGER 100000000
set_parameter_property PTP_CLK_FREQ DEFAULT_VALUE 100000000
set_parameter_property PTP_CLK_FREQ DISPLAY_NAME PTP_CLK_FREQ
set_parameter_property PTP_CLK_FREQ UNITS Hertz
set_parameter_property PTP_CLK_FREQ HDL_PARAMETER true

add_parameter SIF_CLK_FREQ INTEGER 400000000
set_parameter_property SIF_CLK_FREQ DEFAULT_VALUE 400000000
set_parameter_property SIF_CLK_FREQ DISPLAY_NAME SIF_CLK_FREQ
set_parameter_property SIF_CLK_FREQ UNITS Hertz
set_parameter_property SIF_CLK_FREQ HDL_PARAMETER true
# | 
# +-----------------------------------

# --------------------------------------------------------------------------------------------------
# --                                                                                              --
# -- Callbacks                                                                                    --
# --                                                                                              --
# --------------------------------------------------------------------------------------------------
proc nvqlink_analyzer_elaboration_cb {} {

    set v_datapath_width [get_parameter_value DATAPATH_WIDTH]
    set v_datakeep_width [get_parameter_value DATAKEEP_WIDTH]
    set v_datauser_width [get_parameter_value DATAUSER_WIDTH]

    # +-----------------------------------
    # | connection point apb_clk
    # | 
    add_interface apb_clk clock end
    set_interface_property apb_clk clockRate 0
    set_interface_property apb_clk ENABLED true
    add_interface_port apb_clk apb_clk clk Input 1
    # +-----------------------------------

    # +-----------------------------------
    # | connection point apb_rst
    # | 
    add_interface apb_rst reset end
    set_interface_property apb_rst associatedClock apb_clk
    set_interface_property apb_rst synchronousEdges DEASSERT
    set_interface_property apb_rst ENABLED true
    add_interface_port apb_rst apb_rst reset Input 1
    # +-----------------------------------

    # +-----------------------------------
    # | connection point sif_clk
    # | 
    add_interface sif_clk clock end
    set_interface_property sif_clk clockRate 0
    set_interface_property sif_clk ENABLED true
    add_interface_port sif_clk sif_clk clk Input 1
    # +-----------------------------------

    # +-----------------------------------
    # | connection point sif_rst
    # | 
    add_interface sif_rst reset end
    set_interface_property sif_rst associatedClock sif_clk
    set_interface_property sif_rst synchronousEdges DEASSERT
    set_interface_property sif_rst ENABLED true
    add_interface_port sif_rst sif_rst reset Input 1
    # +-----------------------------------

    # +-----------------------------------
    # | connection point ptp_clk
    # | 
    add_interface ptp_clk clock end
    set_interface_property ptp_clk clockRate 0
    set_interface_property ptp_clk ENABLED true
    add_interface_port ptp_clk ptp_clk clk Input 1
    # +-----------------------------------

    # +-----------------------------------
    # | connection point ptp_rst
    # | 
    add_interface ptp_rst reset end
    set_interface_property ptp_rst associatedClock ptp_clk
    set_interface_property ptp_rst synchronousEdges NONE
    set_interface_property ptp_rst ENABLED true
    add_interface_port ptp_rst ptp_rst reset Input 1
    # +-----------------------------------

    # +-----------------------------------
    # | connection point i_ptp (PTP timestamp value, consumer side)
    # | 
    add_interface i_ptp conduit end
    add_interface_port i_ptp ptp_sec  ptp_sec     Input 48
    add_interface_port i_ptp ptp_nsec ptp_nanosec Input 32
    add_interface_port i_ptp ptp_pps  pps         Input 1
    # +-----------------------------------

    # +-----------------------------------
    # | connection points apb_0 .. apb_4 (APB slave register windows)
    # | 
    for {set nv_apb_idx 0} {${nv_apb_idx} < 5} {incr nv_apb_idx} {

        add_interface apb_${nv_apb_idx} apb end
        set_interface_property apb_${nv_apb_idx} associatedClock apb_clk
        set_interface_property apb_${nv_apb_idx} associatedReset apb_rst
        set_interface_property apb_${nv_apb_idx} ENABLED true

        add_interface_port apb_${nv_apb_idx} apb_psel_${nv_apb_idx}    psel     Input  1
        add_interface_port apb_${nv_apb_idx} apb_penable_${nv_apb_idx} penable  Input  1
        add_interface_port apb_${nv_apb_idx} apb_paddr_${nv_apb_idx}   paddr    Input  32
        add_interface_port apb_${nv_apb_idx} apb_pwdata_${nv_apb_idx}  pwdata   Input  32
        add_interface_port apb_${nv_apb_idx} apb_pwrite_${nv_apb_idx}  pwrite   Input  1
        add_interface_port apb_${nv_apb_idx} apb_pready_${nv_apb_idx}  pready   Output 1
        add_interface_port apb_${nv_apb_idx} apb_prdata_${nv_apb_idx}  prdata   Output 32
        add_interface_port apb_${nv_apb_idx} apb_pserr_${nv_apb_idx}   pslverr  Output 1
    }
    # +-----------------------------------

    # +-----------------------------------
    # | connection point sif_rx_axis (RAM player output -> HSB sensor RX)
    # | 
    add_interface sif_rx_axis axi4stream start
    set_interface_property sif_rx_axis associatedClock sif_clk
    set_interface_property sif_rx_axis associatedReset sif_rst
    set_interface_property sif_rx_axis ENABLED true

    add_interface_port sif_rx_axis sif_rx_axis_tvalid tvalid Output 1
    add_interface_port sif_rx_axis sif_rx_axis_tlast  tlast  Output 1
    add_interface_port sif_rx_axis sif_rx_axis_tdata  tdata  Output ${v_datapath_width}
    add_interface_port sif_rx_axis sif_rx_axis_tkeep  tkeep  Output ${v_datakeep_width}
    add_interface_port sif_rx_axis sif_rx_axis_tuser  tuser  Output ${v_datauser_width}
    add_interface_port sif_rx_axis sif_rx_axis_tready tready Input  1
    # +-----------------------------------

    # +-----------------------------------
    # | connection point sif_tx_axis (HSB sensor TX -> analyzer input)
    # | 
    add_interface sif_tx_axis axi4stream end
    set_interface_property sif_tx_axis associatedClock sif_clk
    set_interface_property sif_tx_axis associatedReset sif_rst
    set_interface_property sif_tx_axis ENABLED true

    add_interface_port sif_tx_axis sif_tx_axis_tvalid tvalid Input 1
    add_interface_port sif_tx_axis sif_tx_axis_tlast  tlast  Input 1
    add_interface_port sif_tx_axis sif_tx_axis_tdata  tdata  Input ${v_datapath_width}
    add_interface_port sif_tx_axis sif_tx_axis_tkeep  tkeep  Input ${v_datakeep_width}
    add_interface_port sif_tx_axis sif_tx_axis_tuser  tuser  Input ${v_datauser_width}
    add_interface_port sif_tx_axis sif_tx_axis_tready tready Output 1
    # +-----------------------------------
}
