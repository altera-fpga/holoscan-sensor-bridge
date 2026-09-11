// ##################################################################################
// Copyright (C) Altera Corporation
//
// This software and the related documents are Altera copyrighted materials, and
// your use of them is governed by the express license under which they were
// provided to you ("License"). Unless the License provides otherwise, you may
// not use, modify, copy, publish, distribute, disclose or transmit this software
// or the related documents without Altera's prior written permission.
//
// This software and the related documents are provided as is, with no express
// or implied warranties, other than those that are expressly stated in the License.
// ##################################################################################


module AGX_FM87_Devkit_HSB_NVQLINK_100GbE
   (

      clk_100_mhz,
      rst_pb_n,

      user_pb_n,

      fpga_sgpio_clk,
      fpga_sgpio_sync,
      fpga_sgpi,
      fpga_sgpo,


      // Code auto-generated from script: ftile_eth_subsystem
      serial_i_rx_serial,
      serial_i_rx_serial_n,
      refclk_eth_fgt,
      serial_o_tx_serial,
      serial_o_tx_serial_n,
      qsfp_lowpwr,
      qsfp_rstn
   );

  input clk_100_mhz;
  input rst_pb_n;

  input   [1:0] user_pb_n;

  input   fpga_sgpio_clk;
  input   fpga_sgpio_sync;
  input   fpga_sgpi;
  output  fpga_sgpo;

   // Code auto-generated from script: ftile_eth_subsystem
   input  wire  [3:0]  serial_i_rx_serial;
   input  wire  [3:0]  serial_i_rx_serial_n;
   input  wire    refclk_eth_fgt;
   output  wire  [3:0]  serial_o_tx_serial;
   output  wire  [3:0]  serial_o_tx_serial_n;
   output  wire    qsfp_lowpwr;
   output  wire    qsfp_rstn;

  // sgpio i/o synchronized to fpga clock domain
  wire       fpga_sgpio_rst;
  wire [7:0] fpga_sgpio_user_dip_sw_n;
  wire [7:0] fpga_sgpio_user_led_g;

  // sgpio i/o synchronized to user clock domain
  wire user_sgpio_clk;
  wire user_sgpio_rst;
  wire [7:0] user_dip_sw_n;
  wire [7:0] user_led_g;

   // Code auto-generated from script: ftile_eth_subsystem
   wire    o_rst_ack_n;
   wire    o_tx_rst_ack_n;
   wire    o_rx_rst_ack_n;
   wire    o_tx_lanes_stable;
   wire    o_rx_pcs_ready;
   wire    rx_is_lockedtodata;
   wire    o_tx_pll_locked;
   wire    eth_pll_lock;
   wire  [7:0]  o_rx_pfc;
   wire    o_rx_pause;

   // Code auto-generated from script: ftile_eth_subsystem
   assign qsfp_lowpwr = "1'b0";
   assign qsfp_rstn = "1'b1";

  // sync user reset to sgpio fpga clock domain
  altera_reset_controller #(
    .NUM_RESET_INPUTS           (1),
    .RESET_REQ_WAIT_TIME        (1),
    .MIN_RST_ASSERTION_TIME     (3),
    .RESET_REQ_EARLY_DSRT_TIME  (1)
  ) fpga_sgpio_rst_inst (
    .reset_in0  (user_sgpio_rst   ),
    .clk        (fpga_sgpio_clk   ),
    .reset_out  (fpga_sgpio_rst   )
  );

  sgpio_slave fpga_sgpio_inst (    
    .i_rstn     (~fpga_sgpio_rst          ),
    .i_clk      (fpga_sgpio_clk           ),
    .i_sync     (fpga_sgpio_sync          ),
    .i_mosi     (fpga_sgpi                ),
    .o_miso     (fpga_sgpo                ),
    .o_user_sw  (fpga_sgpio_user_dip_sw_n ),
    .i_user_led (fpga_sgpio_user_led_g    )
  );

  // sync user_led to fpga clock domain
  altera_std_synchronizer_bundle #(
    .width    (8),
    .depth    (3)
  ) user_led_sync_inst (
    .clk      (fpga_sgpio_clk         ), 
    .reset_n  (~fpga_sgpio_rst        ),
    .din      (user_led_g             ),
    .dout     (fpga_sgpio_user_led_g  )
  );

  // sync user_dip_sw to user clock domain
  altera_std_synchronizer_bundle #(
    .width    (8),
    .depth    (3)
  ) user_dip_sw_sync_inst (
    .clk      (user_sgpio_clk           ), 
    .reset_n  (~user_sgpio_rst          ),
    .din      (fpga_sgpio_user_dip_sw_n ),
    .dout     (user_dip_sw_n            )
  );


  AGX_FM87_Devkit_HSB_NVQLINK_100GbE_qsys u0 (
    .board_subsystem_i_clk_clk            (clk_100_mhz),
    .board_subsystem_ia_reset_pb_n_reset  (rst_pb_n),

      // Code auto-generated from script: ftile_eth_subsystem
       .ftile_eth_subsystem_c_refclk_fgt_in_refclk_fgt_0  (refclk_eth_fgt),
       .ftile_eth_subsystem_c_sys_pll_locked_o_sys_pll_locked  (eth_pll_lock),
       .ftile_eth_subsystem_c_serial_o_tx_serial  (serial_o_tx_serial),
       .ftile_eth_subsystem_c_serial_i_rx_serial  (serial_i_rx_serial),
       .ftile_eth_subsystem_c_serial_o_tx_serial_n  (serial_o_tx_serial_n),
       .ftile_eth_subsystem_c_serial_i_rx_serial_n  (serial_i_rx_serial_n),
       .ftile_eth_subsystem_c_rst_status_o_rst_ack_n  (o_rst_ack_n),
       .ftile_eth_subsystem_c_rst_status_o_tx_rst_ack_n  (o_tx_rst_ack_n),
       .ftile_eth_subsystem_c_rst_status_o_rx_rst_ack_n  (o_rx_rst_ack_n),
       .ftile_eth_subsystem_c_clk_status_o_cdr_lock  (rx_is_lockedtodata),
       .ftile_eth_subsystem_c_clk_status_o_tx_pll_locked  (o_tx_pll_locked),
       .ftile_eth_subsystem_c_clk_status_o_tx_lanes_stable  (o_tx_lanes_stable),
       .ftile_eth_subsystem_c_clk_status_o_rx_pcs_ready  (o_rx_pcs_ready),
       .ftile_eth_subsystem_i_eth_intf_rst_reset  (~eth_pll_lock),
       .ftile_eth_subsystem_c_tx_ports_i_tx_skip_crc  (1'b0),
       .ftile_eth_subsystem_c_pfc_ports_i_tx_pfc  (8'h00),
       .ftile_eth_subsystem_c_pfc_ports_o_rx_pfc  (o_rx_pfc),
       .ftile_eth_subsystem_c_sfc_ports_i_tx_pause  (1'b0),
       .ftile_eth_subsystem_c_sfc_ports_o_rx_pause  (o_rx_pause)
  );

endmodule








