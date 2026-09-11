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

###################################################################################
# nvqlink_subsystem.sdc
#
# CDC exceptions for nvqlink_subsystem's instances of the shared s_apb_ram /
# s_apb_ram_dyn dual-clock APB RAM primitive -- the same module used by
# hsb_subsystem's u_config_ram (see hsb_subsystem.sdc, #s_apb_ram section).
#
# These constraints are migrated from sdc/user/hsb_subsystem.sdc (the
# #s_apb_ram / u_config_ram section), retargeted from ${v_hololink_ip} to
# nvqlink_subsystem's own instances of the same s_apb_ram primitive.
###################################################################################

set v_nvqlink_ip [get_entity_instances nvqlink_analyzer]

foreach v_inst {u_apb_ila|u_apb_ram_inst u_apb_sif_ila|u_apb_ram_inst u_ram_player|u_s_apb_ram_dyn} {

    # Write data to RAM is latched in the apb_clk domain. The RAM wren is
    # synchronized from apb_clk to sif_clk, so write data is stable when wren asserts.
    set_false_path -from [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_wdata*] \
                   -to   [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|blk_mem*]

    # Write addr. Same as above.
    set_false_path -from [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_addr*] \
                   -to   [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|blk_mem*]

    # Read data is latched into the sif_clk domain from logic in the apb_clk domain.
    # It should be stable before being consumed via rden synchronized sif_clk->apb_clk.
    set_false_path -from [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_addr*] \
                   -to   [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_rdata_q*]

    set_false_path -from [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_wren] \
                   -to   [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_rdata_q*]

    set_false_path -from [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_rden] \
                   -to   [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_rdata_q*]

    # Read data going back to the apb_clk domain. Unlike u_config_ram (which feeds a
    # single named u_apb_ff_lvl2 register), reg_rdata_q here fans out combinationally
    # through the APB read-data mux to many different downstream consumers, so the
    # exception is applied from reg_rdata_q with no -to restriction. Same rationale
    # as hsb_subsystem.sdc: this data will be stable prior to the signal indicating the
    # APB command is done.
    set_false_path -from [get_keepers -no_duplicates ${v_nvqlink_ip}|${v_inst}|*|reg_rdata_q*]
}

###################################################################################
# Generic reg_cdc / data_sync (glitch_filter) synchronizer exceptions.
#
# s_apb_ila, s_apb_ram, s_apb_ram_dyn, ram_player, and streaming_cdc (all
# instantiated by nvqlink_analyzer) are the same nvidia_hsb_263 (HOLOLINK IP)
# modules used throughout hsb_subsystem, and internally rely on the same
# reg_cdc.sv (a2b_reg_sync / a2b_val_sync / b2a_ack_sync) and data_sync.sv /
# glitch_filter.sv (filter_pipe) synchronizer primitives -- including the
# Gray-code pointer sync inside streaming_cdc's dc_fifo_generic instance.
#
# These are the exact exceptions hsb_subsystem.sdc applies to ${v_hololink_ip}
# (see hsb_subsystem.sdc, "Check if synchronization logic is needed" and
# "data_sync" sections). nvqlink_subsystem's copies of these primitives live
# outside the HOLOLINK_top hierarchy, so they need this same treatment applied
# to ${v_nvqlink_ip}.
###################################################################################

set_false_path -to [get_keepers -no_duplicates ${v_nvqlink_ip}|*|a2b_reg_sync*]
set_false_path -to [get_keepers -no_duplicates ${v_nvqlink_ip}|*|a2b_val_sync[0]]
set_false_path -to [get_keepers -no_duplicates ${v_nvqlink_ip}|*|b2a_ack_sync[0]]

set_false_path -to [get_keepers -no_duplicates ${v_nvqlink_ip}|*|filter_pipe[*][0]]
