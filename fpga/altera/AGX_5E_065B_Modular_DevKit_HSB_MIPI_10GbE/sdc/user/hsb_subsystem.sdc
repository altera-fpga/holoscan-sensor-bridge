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

proc apply_cdc {v_from_list v_to_list {v_is_bus 0} {v_comb 0}} {
    if {[get_collection_size ${v_from_list}] > 0 && [get_collection_size ${v_to_list}] > 0} {
        if {[get_collection_size ${v_from_list}] > 1 || [get_collection_size ${v_to_list}] > 1} {
             set v_is_bus 1
        }
        if {${v_is_bus}} {
            set_max_skew  -from ${v_from_list} -to ${v_to_list} -get_skew_value_from_clock_period \
            min_clock_period -skew_value_multiplier 0.8
        }
        set_max_delay -from ${v_from_list} -to ${v_to_list} 100
        set_min_delay -from ${v_from_list} -to ${v_to_list} -100

        #avoid set_net_delay being executed during synthesis
        if { ![string equal "quartus_syn" $::TimeQuestInfo(nameofexecutable)] } {
            if {${v_comb}} {
                set_data_delay -from ${v_from_list} -to ${v_to_list} -get_value_from_clock_period \
                dst_clock_period -value_multiplier 0.8
            } else {
                set_net_delay -from ${v_from_list}  -to ${v_to_list} -max -get_value_from_clock_period \
                dst_clock_period -value_multiplier 0.8
            }
        }
    }
}

# I2C
foreach v_i2c_name {i2c_0 i2c_1} {
    foreach v_i2c_role {scl sda} {
         set_output_delay -clock [get_clocks clk_100_mhz] -max 100 [get_ports ${v_i2c_name}_${v_i2c_role}]
         set_output_delay -clock [get_clocks clk_100_mhz] -min -100 [get_ports ${v_i2c_name}_${v_i2c_role}]
         set_false_path -to [get_ports ${v_i2c_name}_${v_i2c_role}]
         set_false_path -from [get_ports ${v_i2c_name}_${v_i2c_role}]
    }
}

# HOLOLINK IP
set v_hololink_ip [get_entity_instances HOLOLINK_top]

# dcfifo
# Embedded sdc needs to be disabled, DRC violations remain because the embedded
# set_false_paths override set_max/min_delay

set v_l_dcfifo [get_entity_instances dcfifo]

foreach i [lsearch -all ${v_l_dcfifo} ${v_hololink_ip}|*] {

    set v_dcfifo [lindex ${v_l_dcfifo} $i]

    apply_cdc [get_keepers -nowarn -no_duplicates ${v_dcfifo}|auto_generated|delayed_wrptr_g*] \
    [get_keepers -nowarn ${v_dcfifo}|auto_generated|rs_dgwp|dffpipe*]
    apply_cdc [get_keepers -nowarn -no_duplicates ${v_dcfifo}|auto_generated|rdptr_g*] \
    [get_keepers -nowarn ${v_dcfifo}|auto_generated|ws_dgrp|dffpipe*]

    set_false_path -to [get_keepers -nowarn -no_duplicates ${v_dcfifo}|auto_generated|rdaclr|dffe*[0]]
    set_false_path -to [get_keepers -nowarn -no_duplicates ${v_dcfifo}|auto_generated|wraclr|dffe*[0]]

}

# Check if synchronization logic is needed

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|u_bootp|ptp*]
set_false_path -to   [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|u_bootp|ptp*]
set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_ptp_top|u_ptp_egress|ptp_port[0]]
set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_ptp_top|first_sync_rx_dpll_en]

set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|*|a2b_reg_sync*]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|*|a2b_val_sync[0]]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|*|b2a_ack_sync[0]]

# reset_sync

# Async Resets to HSB IP clock domains
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|u_rst_gen|u_apb_rst|aasr_rst*]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|u_rst_gen|u_hif_rst|aasr_rst*]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|u_rst_gen|u_ptp_rst|aasr_rst*]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|u_rst_gen|gen_sif_rx_rst[*].u_sif_rx_rst|aasr_rst*]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|u_rst_gen|gen_sif_tx_rst[*].u_sif_tx_rst|aasr_rst*]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|u_rst_gen|gen_sif_tx_rst[*].u_sif_tx_rst|aasr_rst*]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|gen_stx_buf[*].u_tx_stream_buffer|u_axis_tx_buffer|axis_buffer_cdc|u_reset_sync_rd|arst]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|gen_stx_buf[*].u_tx_stream_buffer|u_axis_tx_buffer|axis_buffer_cdc|u_reset_sync_rd|aasr_rst*]

# Async Resets from HSB IP clock domains to Eth clock domain
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|gen_pack_inst[*].packetizer_top_inst|gen_bypass_vp.[*].bypass_vp|axis_buffer|axis_buffer_cdc|u_reset_sync_rd|arst]
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|gen_pack_inst[*].packetizer_top_inst|gen_bypass_vp.[*].bypass_vp|axis_buffer|axis_buffer_cdc|u_reset_sync_rd|aasr_rst*]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|gen_pack_inst[*].packetizer_top_inst|ptp_fifo|u_reset_sync_rd|arst]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|gen_pack_inst[*].packetizer_top_inst|ptp_fifo|u_reset_sync_rd|aasr_rst*]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|u_axis_buffer|axis_buffer_cdc|u_reset_sync_rd|arst]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|u_axis_buffer|axis_buffer_cdc|u_reset_sync_rd|aasr_rst*]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_rx_ls_parser|u_evt_int|ptp_fifo|u_reset_sync_rd|arst]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_rx_ls_parser|u_evt_int|ptp_fifo|u_reset_sync_rd|aasr_rst*]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_rx_ls_parser|u_evt_int|ptp_pulse_sync|u_reset_sync_rd|arst]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_rx_ls_parser|u_evt_int|ptp_pulse_sync|u_reset_sync_rd|aasr_rst*]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_ptp_top|u_ptp_ingress|u_axis_buffer|axis_buffer_cdc|u_reset_sync_rd|arst]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_ptp_top|u_ptp_ingress|u_axis_buffer|axis_buffer_cdc|u_reset_sync_rd|aasr_rst*]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_ptp_top|u_ptp_egress|u_axis_buffer|axis_buffer_cdc|u_reset_sync_rd|arst]

set_false_path -to [get_keepers -no_duplicates \
${v_hololink_ip}|u_ptp_top|u_ptp_egress|u_axis_buffer|axis_buffer_cdc|u_reset_sync_rd|aasr_rst*]

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_sys_init|done] -to \
[get_keepers -no_duplicates ${v_hololink_ip}|*]

#ECB RD/WR Controller
# Response data is stable before the ecb_to_axis_rdresp is triggered

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|resp_data*] \
-to [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|ecb_to_axis_rdresp|*]

# Header is sent with valid signal. Valid is synchronized into aclk domain
# so header should be stable when the synchronized valid asserts

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|ecb_cmd*]
set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|ecb_flags*]
set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|ecb_seq*]
set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|cmd_addr*]
set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_rx_ls_parser|ecb_rdwr_ctrl_inst|cmd_dout*]

# data_sync
set_false_path -to [get_keepers -no_duplicates ${v_hololink_ip}|*|filter_pipe[*][0]]

# Read data going back to the apb_clk domain.
# Will be stable prior to the signal indicating the APB command is done.

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_rdata_q*] \
-to [get_keepers -no_duplicates ${v_hololink_ip}|u_apb_intc|u_apb_ff_lvl2|apb_s2m_q.prdata*]

#s_apb_ram
# Write data to RAM is latched in APB clock domain. The RAM wren is synchronized from the APB clock domain
# to the HIF clock domain. So the write data is stable when the wren asserts.

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_wdata*] \
-to [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|blk_mem*]

# Write addr. Same as above.
set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_addr*] \
-to [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|blk_mem*]

# Read data is latched into the hif_clk domain from logic in the APB domain. The data should be stable
# before being consumed on the APB interface using rden that is synchronized from the hif_clk to the apb_clk.

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_addr*] \
-to [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_rdata_q*]

# The read data latched in the hif_clk also has dependency on the reg_address, which has dependency on
# reg_wren and reg_rden. The apb_clk signals should be stable so latching in the hif_clk should be ok.

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_wren] \
 -to [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_rdata_q*]

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_rden] \
 -to [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_rdata_q*]

# Read data going back to the apb_clk domain. Will be stable prior to the signal
# indicating the APB command is done.

set_false_path -from [get_keepers -no_duplicates ${v_hololink_ip}|u_dp_pkt_top|u_config_ram|reg_rdata_q*] \
-to [get_keepers -no_duplicates ${v_hololink_ip}|u_apb_intc|u_apb_ff_lvl2|apb_s2m_q.prdata*]
