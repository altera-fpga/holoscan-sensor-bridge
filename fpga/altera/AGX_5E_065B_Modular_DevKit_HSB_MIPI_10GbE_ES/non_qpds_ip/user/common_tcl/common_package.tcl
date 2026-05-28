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
######################################################################################################################################################################
# HELPER FUNCTIONS
#
# common_add_elab_callback
# common_add_validation_callback
# common_add_family
# common_add_clk { v_name }
# common_add_rstn { v_name v_clk {v_dir 0} {v_slv 0} }
# common_add_rst { v_name v_clk {v_dir 0} {v_slv 0} }
#
###################################################################################

set_module_property ELABORATION_CALLBACK common_elaboration_callback
set common_elaboration_callback_hooks [list]

set_module_property VALIDATION_CALLBACK common_validation_callback
set common_validation_callback_hooks [list]

add_parameter          device_family STRING
set_parameter_property device_family VISIBLE            false
set_parameter_property device_family SYSTEM_INFO        {DEVICE_FAMILY}
set_parameter_property device_family AFFECTS_GENERATION true

# Master Elaboration Callback Hook.
proc common_elaboration_callback {} {
    upvar common_elaboration_callback_hooks v_hooks

    set v_family [get_parameter_value device_family]
    catch {set_parameter_value C_FAMILY ${v_family}}

    foreach v_hook ${v_hooks} {
        ${v_hook}
    }
}

# Master Validation Callback hook.
proc common_validation_callback {} {
    upvar common_validation_callback_hooks v_hooks

    foreach v_hook ${v_hooks} {
        ${v_hook}
    }
}

# Register core level validate call back
proc common_add_validation_callback { func } {
    upvar common_validation_callback_hooks  v_hooks
    lappend v_hooks ${func}
}

# Register core level elab call back
proc common_add_elab_callback { func } {
    upvar common_elaboration_callback_hooks v_hooks
    lappend v_hooks ${func}
}

# Add Family
proc common_add_family { } {
    add_parameter          C_FAMILY  STRING
    set_parameter_property C_FAMILY  DERIVED       true
    set_parameter_property C_FAMILY  VISIBLE       false
    set_parameter_property C_FAMILY  HDL_PARAMETER true
    set_parameter_property C_FAMILY  ENABLED       true
}

proc common_add_clk { v_name } {
    add_interface          ${v_name} clock         end
    set_interface_property ${v_name} clockRate     0
    set_interface_property ${v_name} ENABLED       true
    add_interface_port     ${v_name} ${v_name}     clk    Input 1
}

proc common_add_rstn { v_name v_clk {v_dir 0} {v_slv 0} } {

    if {${v_dir}} {
        set v_direction "start"
        set v_dir_put   "Output"
    } else {
        set v_direction "end"
        set v_dir_put   "Input"
    }

    add_interface          ${v_name} reset            ${v_direction}
    set_interface_property ${v_name} associatedClock  ${v_clk}
    set_interface_property ${v_name} synchronousEdges DEASSERT
    set_interface_property ${v_name} ENABLED          true
    add_interface_port     ${v_name} ${v_name}        reset_n       ${v_dir_put} 1

    if {${v_slv}} {
        set_port_property ${v_name} VHDL_TYPE STD_LOGIC_VECTOR
    }

}

proc common_add_rst { v_name v_clk {v_dir 0} {v_slv 0} } {

    if {${v_dir}} {
        set v_direction "start"
        set v_dir_put   "Output"
    } else {
        set v_direction "end"
        set v_dir_put   "Input"
    }

    add_interface          ${v_name} reset             ${v_direction}
    set_interface_property ${v_name} associatedClock   ${v_clk}
    set_interface_property ${v_name} synchronousEdges  DEASSERT
    set_interface_property ${v_name} ENABLED           true
    add_interface_port     ${v_name} ${v_name}         reset         ${v_dir_put} 1

    if {${v_slv}} {
        set_port_property ${v_name} VHDL_TYPE STD_LOGIC_VECTOR
    }

}

# clogb2_pure: ceil(log2(x))
# ceil(log2(4)) = 2 wires are required to address a memory of depth 4
proc clogb2_pure {v_max_value} {
    set v_l2 [expr int(ceil(log(${v_max_value})/(log(2))))]
    if { ${v_l2} == 0 } {
      set v_l2 1
    }
    return ${v_l2}
}

# add_av_st_input_port
# Add an Avalon-ST Input port to the component, see specialized functions below for a shortened call
# \param     v_clock,               clock interface associated with the Avalon-ST interface
# \param     v_input_name,          v_name of the Avalon-ST interface (din by default)
# \param     v_bits_per_symbol,     number of bits per symbols
# \param     v_symbols_per_beat,    number of symbols per beat (clock cycle)
# \param     v_packets_transfer,    whether sop and eop signals are used, use v_packets_transfer == 2 to also
#                                   include an empty signal when v_symbols_per_beat > 1
# \param     v_ready_latency,       the ready latency, use -1 to omit the ready signal
# \param     v_channel_width,       the width of the channel signal
# \param     v_use_valid,           use 0 to omit the valid signal

proc add_av_st_input_port { v_clock   v_input_name   v_bits_per_symbol   v_symbols_per_beat   {v_packets_transfer 2}
{v_ready_latency 0}   {v_channel_width 0}   {v_use_valid 1}   {v_error_desc ""} {v_pixels_per_beat 1}} {

    set v_data_width [expr ${v_bits_per_symbol} * ${v_symbols_per_beat} * ${v_pixels_per_beat} ]

    add_interface            ${v_input_name}     avalon_streaming              sink      ${v_clock}

    set_interface_property   ${v_input_name}     dataBitsPerSymbol             ${v_bits_per_symbol}

    set_interface_property   ${v_input_name}     symbolsPerBeat                \
                             [expr ${v_symbols_per_beat} * ${v_pixels_per_beat}]

    set_interface_property   ${v_input_name}     errorDescriptor               ${v_error_desc}

    set_interface_property   ${v_input_name}     firstSymbolInHighOrderBits    true

    add_interface_port       ${v_input_name}     ${v_input_name}_data          data      input    ${v_data_width}

    if { ${v_use_valid} != 0} {
        add_interface_port ${v_input_name} ${v_input_name}_valid valid input 1
    }

    if { ${v_packets_transfer} != 0 } {
        add_interface_port ${v_input_name} ${v_input_name}_startofpacket startofpacket input 1
        add_interface_port ${v_input_name} ${v_input_name}_endofpacket   endofpacket   input 1

        if { (${v_packets_transfer} != 1)  && (${v_pixels_per_beat} > 1) } {
            # Use v_channel_width to detect Av-St-Msg, which requires TWO empty buses :
            if {${v_channel_width} != 0} {

                add_interface_port ${v_input_name} ${v_input_name}_sop_empty empty input \
                                   [clogb2_pure [expr ${v_pixels_per_beat}]]

                add_interface_port ${v_input_name} ${v_input_name}_eop_empty empty input \
                                   [clogb2_pure [expr ${v_pixels_per_beat}]]


            } else {
                # Av-St just requires ONE empty bus, but width must indicate number of empty SYMBOLS :
                add_interface_port ${v_input_name} ${v_input_name}_empty empty input \
                                   [clogb2_pure [expr ${v_symbols_per_beat} * ${v_pixels_per_beat}]]

            }
        }
    }

    if { ${v_ready_latency} != -1 } {
        set_interface_property ${v_input_name} readyLatency            ${v_ready_latency}
        add_interface_port     ${v_input_name} ${v_input_name}_ready   ready              output  1
    }

    if { ${v_channel_width} != 0 } {
        add_interface_port     ${v_input_name} ${v_input_name}_channel channel            input   ${v_channel_width}
    }

    set_interface_property   ${v_input_name}     maxChannel           0

    if { [string compare ${v_error_desc} ""] } {
        set v_error_width [ llength [split ${v_error_desc} ,] ]
        add_interface_port     ${v_input_name} ${v_input_name}_error   error              input   ${v_error_width}
        set_interface_property ${v_input_name} errorDescriptor         ${v_error_desc}
    }
}

# add_av_st_output_port
# Add an Avalon-ST Output port to the component, see specialized functions below for a shortened call
# \param     v_clock,               clock associated with the Avalon-ST interface
# \param     v_output_name,         v_name of the Avalon-ST interface
# \param     v_bits_per_symbol,     number of bits per symbols
# \param     v_symbols_per_beat,    number of symbols per beat (clock cycle)
# \param     v_packets_transfer,    whether sop and eop signals are used, use v_packets_transfer == 2 to
#                                   include the empty signal (if v_symbols_per_beat > 1)
# \param     v_ready_latency,       the ready latency, use -1 to omit the ready signal
# \param     v_channel_width,       the width of the channel signal
# \param     v_use_valid,           use 0 to omit the valid signal
proc add_av_st_output_port { v_clock   v_output_name   v_bits_per_symbol   v_symbols_per_beat   {v_packets_transfer 2}
{v_ready_latency 0}   {v_channel_width 0}   {v_use_valid 1}   {v_error_desc ""}  {v_pixels_per_beat 1}} {

    set v_data_width [expr ${v_bits_per_symbol} * ${v_symbols_per_beat} * ${v_pixels_per_beat} ]

    add_interface            ${v_output_name}    avalon_streaming           source  ${v_clock}

    set_interface_property   ${v_output_name}    dataBitsPerSymbol          ${v_bits_per_symbol}

    set_interface_property   ${v_output_name}    symbolsPerBeat             \
                             [expr ${v_symbols_per_beat} * ${v_pixels_per_beat}]

    set_interface_property   ${v_output_name}    errorDescriptor            ${v_error_desc}

    set_interface_property   ${v_output_name}    firstSymbolInHighOrderBits true

    add_interface_port       ${v_output_name}    ${v_output_name}_data      data    output   ${v_data_width}

    if { ${v_use_valid} != 0} {
        add_interface_port ${v_output_name} ${v_output_name}_valid valid output 1
    }

    if { ${v_packets_transfer} != 0 } {
        add_interface_port ${v_output_name} ${v_output_name}_startofpacket  startofpacket output  1
        add_interface_port ${v_output_name} ${v_output_name}_endofpacket    endofpacket   output  1

        if { (${v_packets_transfer} != 1) && (${v_pixels_per_beat} > 1)} {
            # Use v_channel_width to detect Av-St-Msg, which requires TWO empty buses :
            if {${v_channel_width} != 0} {

                add_interface_port ${v_output_name}  ${v_output_name}_sop_empty empty    output \
                                   [clogb2_pure [expr ${v_pixels_per_beat}]]

                add_interface_port ${v_output_name}  ${v_output_name}_eop_empty empty    output \
                                   [clogb2_pure [expr ${v_pixels_per_beat}]]


            } else {
                # Av-St just requires ONE empty bus, but width must indicate number of empty SYMBOLS :
                add_interface_port ${v_output_name}  ${v_output_name}_empty     empty    output \
                                   [clogb2_pure [expr ${v_symbols_per_beat} * ${v_pixels_per_beat}]]

            }
        }
    }

    if { ${v_ready_latency} != -1 } {
        set_interface_property ${v_output_name} readyLatency ${v_ready_latency}
        add_interface_port ${v_output_name}  ${v_output_name}_ready    ready    input   1
    }

    if { ${v_channel_width} != 0 } {
        add_interface_port ${v_output_name}  ${v_output_name}_channel  channel  output  ${v_channel_width}
    }
    set_interface_property   ${v_output_name}    maxChannel           0

    if { [string compare ${v_error_desc} ""] } {
        set v_error_width [ llength [split ${v_error_desc} ,] ]
        add_interface_port     ${v_output_name}  ${v_output_name}_error    error           output  ${v_error_width}
        set_interface_property ${v_output_name}  errorDescriptor           ${v_error_desc}
    }
}

proc common_add_axi4s_interface_tkeep { v_prefix v_clk v_rst {v_dir slave} {v_data_width ""} }  {

    if {${v_dir} == "master"} {
        set v_master_out "Output"
        set v_master_in  "Input"
        set v_direction  "start"
    } else {
        set v_master_out "Input"
        set v_master_in  "Output"
        set v_direction  "end"
    }

    set v_parameter_prefix "C_[string toupper ${v_prefix}]"
    set v_idwidth 1

    if { ${v_data_width} == "" } {
        set v_data_width  ${v_parameter_prefix}_TDATA_WIDTH
        set v_width_int [ get_parameter_value ${v_data_width} ]
    } else {
        set v_width_int ${v_data_width}
    }


    set v_tkeep_width [expr ${v_width_int} / 8]

    add_interface          ${v_prefix} axi4stream       ${v_direction}
    set_interface_property ${v_prefix} associatedClock  ${v_clk}
    set_interface_property ${v_prefix} associatedReset  ${v_rst}

    add_interface_port     ${v_prefix} ${v_prefix}_tvalid tvalid ${v_master_out} 1
    add_interface_port     ${v_prefix} ${v_prefix}_tready tready ${v_master_in}  1
    add_interface_port     ${v_prefix} ${v_prefix}_tlast  tlast  ${v_master_out} 1
    add_interface_port     ${v_prefix} ${v_prefix}_tuser  tuser  ${v_master_out} 1
    add_interface_port     ${v_prefix} ${v_prefix}_tdata  tdata  ${v_master_out} ${v_data_width}
    add_interface_port     ${v_prefix} ${v_prefix}_tkeep  tkeep  ${v_master_out} ${v_tkeep_width}

    set_port_property      ${v_prefix}_tuser VHDL_TYPE STD_LOGIC_VECTOR

}
proc common_add_axi4s_interface_flexible { v_prefix v_clk v_rst {v_dir slave} {v_tkeep 0} {v_tstrb 0} {v_user_width 1} {v_data_width ""} }  {
    if {${v_dir} == "master"} {
        set v_master_out "Output"
        set v_master_in  "Input"
        set v_direction  "start"
    } else {
        set v_master_out "Input"
        set v_master_in  "Output"
        set v_direction  "end"
    }
    set v_parameter_prefix "C_[string toupper ${v_prefix}]"
    set v_idwidth 1
    if { ${v_data_width} == "" } {
        set v_data_width  ${v_parameter_prefix}_TDATA_WIDTH
        set v_width_int [ get_parameter_value ${v_data_width} ]
    } else {
        set v_width_int ${v_data_width}
    }
    set v_byte_width [expr ${v_width_int} / 8]
    add_interface          ${v_prefix} axi4stream       ${v_direction}
    set_interface_property ${v_prefix} associatedClock  ${v_clk}
    set_interface_property ${v_prefix} associatedReset  ${v_rst}
    add_interface_port     ${v_prefix} ${v_prefix}_tvalid tvalid ${v_master_out} 1
    add_interface_port     ${v_prefix} ${v_prefix}_tready tready ${v_master_in}  1
    add_interface_port     ${v_prefix} ${v_prefix}_tlast  tlast  ${v_master_out} 1
    add_interface_port     ${v_prefix} ${v_prefix}_tuser  tuser  ${v_master_out} ${v_user_width}
    add_interface_port     ${v_prefix} ${v_prefix}_tdata  tdata  ${v_master_out} ${v_data_width}
    if { ${v_tstrb} } {
        add_interface_port     ${v_prefix} ${v_prefix}_tstrb  tstrb  ${v_master_out} ${v_byte_width}
    }
    if { ${v_tkeep} } {
        add_interface_port     ${v_prefix} ${v_prefix}_tkeep  tkeep  ${v_master_out} ${v_byte_width}
    }
    set_port_property      ${v_prefix}_tuser VHDL_TYPE STD_LOGIC_VECTOR
}
