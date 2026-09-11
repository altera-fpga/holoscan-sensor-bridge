//##################################################################################
// Copyright (C) 2025 Altera Corporation
//
// This software and the related documents are Altera copyrighted materials, and
// your use of them is governed by the express license under which they were
// provided to you ("License"). Unless the License provides otherwise, you may
// not use, modify, copy, publish, distribute, disclose or transmit this software
// or the related documents without Altera's prior written permission.
//
// This software and the related documents are provided as is, with no express
// or implied warranties, other than those that are expressly stated in the License.
//##################################################################################
//
module nvqlink_analyzer
#(
  parameter DATAPATH_WIDTH = 512,
  parameter DATAKEEP_WIDTH = 64,
  parameter DATAUSER_WIDTH = 2,
  
  parameter PTP_CLK_FREQ = 100000000, // 100 MHz
  parameter SIF_CLK_FREQ = 400000000  // 400 MHz -- HSB datapath domain (clock_subsystem.o_gen_clk_0_clk)

)(
  input         apb_clk,
  input         apb_rst,

  input         sif_clk,
  input         sif_rst,

  input         ptp_clk,
  input         ptp_rst,

  input         apb_psel_0,
  input         apb_penable_0,
  input [31:0]  apb_paddr_0,
  input [31:0]  apb_pwdata_0,
  input         apb_pwrite_0,
  output        apb_pready_0,
  output [31:0] apb_prdata_0, 
  output        apb_pserr_0,

  input         apb_psel_1,
  input         apb_penable_1,
  input [31:0]  apb_paddr_1,
  input [31:0]  apb_pwdata_1,
  input         apb_pwrite_1,
  output        apb_pready_1,
  output [31:0] apb_prdata_1, 
  output        apb_pserr_1,

  input         apb_psel_2,
  input         apb_penable_2,
  input [31:0]  apb_paddr_2,
  input [31:0]  apb_pwdata_2,
  input         apb_pwrite_2,
  output        apb_pready_2,
  output [31:0] apb_prdata_2, 
  output        apb_pserr_2,

  input         apb_psel_3,
  input         apb_penable_3,
  input [31:0]  apb_paddr_3,
  input [31:0]  apb_pwdata_3,
  input         apb_pwrite_3,
  output        apb_pready_3,
  output [31:0] apb_prdata_3, 
  output        apb_pserr_3,

  input         apb_psel_4,
  input         apb_penable_4,
  input [31:0]  apb_paddr_4,
  input [31:0]  apb_pwdata_4,
  input         apb_pwrite_4,
  output        apb_pready_4,
  output [31:0] apb_prdata_4, 
  output        apb_pserr_4,

  input [31:0]                ptp_nsec,
  input [47:0]                ptp_sec,
  input                       ptp_pps, // unused

  // RAM player interface
  output                      sif_rx_axis_tvalid,
  output                      sif_rx_axis_tlast,
  output [DATAPATH_WIDTH-1:0] sif_rx_axis_tdata,
  output [DATAKEEP_WIDTH-1:0] sif_rx_axis_tkeep,
  output [DATAUSER_WIDTH-1:0] sif_rx_axis_tuser,
  input                       sif_rx_axis_tready,

  // Sensor TX interface
  input                      sif_tx_axis_tvalid,
  input                      sif_tx_axis_tlast,
  input [DATAPATH_WIDTH-1:0] sif_tx_axis_tdata,
  input [DATAKEEP_WIDTH-1:0] sif_tx_axis_tkeep,
  input [DATAUSER_WIDTH-1:0] sif_tx_axis_tuser,
  output                     sif_tx_axis_tready

);
  localparam REG_INST = 5;
  localparam HOST_IF_INST = 1;
  localparam SENSOR_RX_IF_INST = 1;
  localparam SENSOR_TX_IF_INST = 1;

  localparam W_DATA = 32; // data bus width
  localparam W_ADDR = 32; // address bus width

  //------------------------------------------------------------------------------
  // APB Bus (moved apb_pkg to here so that this module is self-contained)
  //------------------------------------------------------------------------------
  
  typedef struct packed {
    logic              psel;
    logic              penable;
    logic [W_ADDR-1:0] paddr;
    logic [W_DATA-1:0] pwdata;
    logic              pwrite;
  } apb_m2s;
  
  typedef struct packed {
    logic              pready;
    logic [W_DATA-1:0] prdata;
    logic              pserr;
  } apb_s2m;


//------------------------------------------------------------------------------
// Clock and Reset
//------------------------------------------------------------------------------

  logic [HOST_IF_INST-1:0] usr_clk_rdy; // pcs user clock out ready
  logic                     usr_clk_locked;
  /* synthesis syn_keep=1 nomerge=""*/
  // logic                     apb_clk;     // ctrl plane clock
  /* synthesis syn_keep=1 nomerge=""*/
  // logic                     sif_clk;     // data plane clock
  /* synthesis syn_keep=1 nomerge=""*/
  // logic                     ptp_clk;     // ptp clock
  /* synthesis syn_keep=1 nomerge=""*/
  logic                     sys_rst;     // system active high reset
  logic [SENSOR_RX_IF_INST-1:0] sif_rx_rst;     // sensor Rx interface active high reset
  logic [SENSOR_TX_IF_INST-1:0] sif_tx_rst;     // sensor Tx interface active high reset
  logic                     cmac_sys_rst;   // ethernet cmac system active high
  /* synthesis syn_keep=1 nomerge=""*/
  // logic [31:0]              ptp_nsec;
  // logic [47:0]              ptp_sec;
  logic [HOST_IF_INST-1:0] aligned;
  logic [HOST_IF_INST-1  :0] pll_locked;

  logic        init_done;

//------------------------------------------------------------------------------
// APB Interface
//------------------------------------------------------------------------------

  // User Drops
  logic [REG_INST-1:0]       apb_psel;
  logic                      apb_penable;
  logic [31:0]               apb_paddr;
  logic [31:0]               apb_pwdata;
  logic [REG_INST-1:0]       apb_pready;
  logic                      apb_pwrite;
  logic [REG_INST-1:0][31:0] apb_prdata;
  logic [REG_INST-1:0]       apb_pserr;

  assign apb_psel = {apb_psel_4, apb_psel_3, apb_psel_2, apb_psel_1, apb_psel_0};

  always_comb begin
    apb_penable = apb_penable_0;
    apb_paddr   = apb_paddr_0;
    apb_pwdata  = apb_pwdata_0;
    apb_pwrite  = apb_pwrite_0;
    if (apb_psel_1) begin
      apb_penable = apb_penable_1;
      apb_paddr   = apb_paddr_1;
      apb_pwdata  = apb_pwdata_1;
      apb_pwrite  = apb_pwrite_1;
    end else if (apb_psel_2) begin
      apb_penable = apb_penable_2;
      apb_paddr   = apb_paddr_2;
      apb_pwdata  = apb_pwdata_2;
      apb_pwrite  = apb_pwrite_2;
    end else if (apb_psel_3) begin
      apb_penable = apb_penable_3;
      apb_paddr   = apb_paddr_3;
      apb_pwdata  = apb_pwdata_3;
      apb_pwrite  = apb_pwrite_3;
    end else if (apb_psel_4) begin
      apb_penable = apb_penable_4;
      apb_paddr   = apb_paddr_4;
      apb_pwdata  = apb_pwdata_4;
      apb_pwrite  = apb_pwrite_4;
    end
  end

  assign apb_pready_0 = apb_pready[0];
  assign apb_prdata_0 = apb_prdata[0];
  assign apb_pserr_0  = apb_pserr[0];
  assign apb_pready_1 = apb_pready[1];
  assign apb_prdata_1 = apb_prdata[1];
  assign apb_pserr_1  = apb_pserr[1];
  assign apb_pready_2 = apb_pready[2];
  assign apb_prdata_2 = apb_prdata[2];
  assign apb_pserr_2  = apb_pserr[2];
  assign apb_pready_3 = apb_pready[3];
  assign apb_prdata_3 = apb_prdata[3];
  assign apb_pserr_3  = apb_pserr[3];
  assign apb_pready_4 = apb_pready[4];
  assign apb_prdata_4 = apb_prdata[4];
  assign apb_pserr_4  = apb_pserr[4];

  genvar i;

//------------------------------------------------------------------------------
// APB
//------------------------------------------------------------------------------

//Tie off unused APB bus signals. 
assign apb_pserr[1:0]         = '0;
assign apb_pready[1:0]        = '0;
assign apb_prdata[1]          = 'h011;
assign apb_prdata[0]          = 'h010;


//------------------------------------------------------------------------------
// Sensor IF
//------------------------------------------------------------------------------

logic                sof;
logic                eof;
logic [79:0]         ptp_ts;
logic                ptp_ts_en ;
logic [11:0]         frame_cnt;

always_ff @ (posedge sif_clk) begin
  if (sif_rst) begin
    ptp_ts <= '0;
    ptp_ts_en <= '0;
    frame_cnt <= '0;
  end
  else begin
    ptp_ts <= (sof) ? sif_tx_axis_tdata[79:0] : ptp_ts;
    frame_cnt <= (sof) ? sif_tx_axis_tdata[91:80] : frame_cnt;
    ptp_ts_en <= sof;
  end
end 
assign sof = sif_tx_axis_tvalid;
assign eof = sif_tx_axis_tlast;

// This block is a passive tap/monitor of the SIF Tx stream (PTP timestamp
// extraction + ILA capture below); it never needs to backpressure the
// sensor source, so it is always ready to accept data.
assign sif_tx_axis_tready = 1'b1;

logic [47:0] ptp_sec_sync_usr;
logic [31:0] ptp_nsec_sync_usr;
logic        ptp_sync_usr_valid;

streaming_cdc #(
  .DATA_WIDTH ( 80                                        ),
  .SRC_FREQ   ( PTP_CLK_FREQ                             ),
  .DST_FREQ   ( SIF_CLK_FREQ                             )
) u_ptp_sif_cdc (
  .i_src_clk  ( ptp_clk                                 ),
  .i_dst_clk  ( sif_clk                                 ),
  .i_src_rst  ( ptp_rst                                 ),
  .i_dst_rst  ( sif_rst                                 ),
  .i_src_data ( {ptp_sec, ptp_nsec}                   ),
  .o_dst_data ( {ptp_sec_sync_usr, ptp_nsec_sync_usr} ),
  .o_dst_valid ( ptp_sync_usr_valid                       )
);

logic [31:0] cnt;

always_ff @ (posedge sif_clk) begin
  if (sif_rst) begin
    cnt <= '0;
  end
  else begin
    cnt <= cnt + 1'b1;
  end
end


localparam ILA_DATA_WIDTH = 256;
logic [ILA_DATA_WIDTH-1:0] ila_wr_data;
assign ila_wr_data[63:0] = ptp_ts[63:0];
assign ila_wr_data[127:64] = {ptp_sec_sync_usr[31:0], ptp_nsec_sync_usr[31:0]};
assign ila_wr_data[139:128] = frame_cnt;
assign ila_wr_data[140] = sof;
assign ila_wr_data[141] = eof;
assign ila_wr_data[223:142] = 'h123456789ABCDEF;
assign ila_wr_data[255:224] = cnt;

apb_m2s ila_apb_m2s;
apb_s2m ila_apb_s2m;

s_apb_ila #(
  .DEPTH            ( 16384                          ),
  .W_DATA           ( ILA_DATA_WIDTH                 )
) u_apb_ila (
  .i_aclk           ( apb_clk                        ),
  .i_arst           ( apb_rst                        ),
  .i_apb_m2s        ( ila_apb_m2s                    ),
  .o_apb_s2m        ( ila_apb_s2m                    ),
  .i_pclk           ( sif_clk                        ),
  .i_prst           ( sif_rst                        ),
  .i_trigger        ( '1                             ),
  .i_enable         ( '1                             ),
  .i_wr_data        ( ila_wr_data                    ),
  .i_wr_en          ( ptp_ts_en                      ),
  .o_ctrl_reg       (                                )
);



assign ila_apb_m2s.psel   = apb_psel     [2];
assign ila_apb_m2s.penable= apb_penable     ;
assign ila_apb_m2s.paddr  = apb_paddr       ;
assign ila_apb_m2s.pwdata = apb_pwdata      ;
assign ila_apb_m2s.pwrite = apb_pwrite      ;
assign apb_pready [2]        = ila_apb_s2m.pready; 
assign apb_prdata [2]        = ila_apb_s2m.prdata; 
assign apb_pserr  [2]        = ila_apb_s2m.pserr;



//------------------------------------------------------------------------------
// SIF Latch
//------------------------------------------------------------------------------

// Field offsets are computed from DATAPATH_WIDTH (instead of hardcoded to
// the 512-bit default) so the SIF ILA capture buffer stays consistent if
// this component is ever elaborated with a different DATAPATH_WIDTH.
localparam SIF_ILA_WSTRB       = $clog2(DATAPATH_WIDTH/8);
localparam SIF_ILA_TVALID_BIT  = DATAPATH_WIDTH;
localparam SIF_ILA_TLAST_BIT   = DATAPATH_WIDTH + 1;
localparam SIF_ILA_TCNT_LSB    = DATAPATH_WIDTH + 2;
localparam SIF_ILA_TCNT_MSB    = SIF_ILA_TCNT_LSB + SIF_ILA_WSTRB - 1;
localparam SIF_ILA_PTP_LSB     = SIF_ILA_TCNT_MSB + 1;
localparam SIF_ILA_PTP_MSB     = SIF_ILA_PTP_LSB + 63; // {ptp_sec_sync_usr, ptp_nsec_sync_usr} = 32+32 bits
localparam SIF_ILA_DATA_WIDTH  = SIF_ILA_PTP_MSB + 1;

logic [SIF_ILA_DATA_WIDTH-1:0] sif_ila_wr_data;
logic [SIF_ILA_WSTRB-1:0] sif_ila_wr_tcnt;

assign sif_ila_wr_data[DATAPATH_WIDTH-1:0]           = sif_tx_axis_tdata;
assign sif_ila_wr_data[SIF_ILA_TVALID_BIT]           = sif_tx_axis_tvalid;
assign sif_ila_wr_data[SIF_ILA_TLAST_BIT]            = sif_tx_axis_tlast;
assign sif_ila_wr_data[SIF_ILA_TCNT_MSB:SIF_ILA_TCNT_LSB] = sif_ila_wr_tcnt;
assign sif_ila_wr_data[SIF_ILA_PTP_MSB:SIF_ILA_PTP_LSB]   = {ptp_sec_sync_usr[31:0], ptp_nsec_sync_usr[31:0]};

integer j;
always_comb begin
  sif_ila_wr_tcnt = '0;
  for (j=0;j<(DATAPATH_WIDTH/8);j=j+1) begin
    if (sif_tx_axis_tkeep[j]) begin
      sif_ila_wr_tcnt = SIF_ILA_WSTRB'(j);
    end
  end
end

apb_m2s sif_ila_apb_m2s;
apb_s2m sif_ila_apb_s2m;

s_apb_ila #(
  .DEPTH            ( 8192                           ),
  .W_DATA           ( SIF_ILA_DATA_WIDTH             )
) u_apb_sif_ila (
  .i_aclk           ( apb_clk                        ),
  .i_arst           ( apb_rst                        ),
  .i_apb_m2s        ( sif_ila_apb_m2s                ),
  .o_apb_s2m        ( sif_ila_apb_s2m                ),
  .i_pclk           ( sif_clk                        ),
  .i_prst           ( sif_rst                        ),
  .i_trigger        ( '1                             ),
  .i_enable         ( '1                             ),
  .i_wr_data        ( sif_ila_wr_data                ),
  .i_wr_en          ( sif_tx_axis_tvalid              ),
  .o_ctrl_reg       (                                )
);


assign sif_ila_apb_m2s.psel   = apb_psel     [3];
assign sif_ila_apb_m2s.penable= apb_penable     ;
assign sif_ila_apb_m2s.paddr  = apb_paddr       ;
assign sif_ila_apb_m2s.pwdata = apb_pwdata      ;
assign sif_ila_apb_m2s.pwrite = apb_pwrite      ;
assign apb_pready [3]        = sif_ila_apb_s2m.pready; 
assign apb_prdata [3]        = sif_ila_apb_s2m.prdata; 
assign apb_pserr  [3]        = sif_ila_apb_s2m.pserr;


//------------------------------------------------------------------------------
// RAM Player
//------------------------------------------------------------------------------

apb_m2s ram_apb_m2s;
apb_s2m ram_apb_s2m;

ram_player #(
  .W_DATA           ( DATAPATH_WIDTH                        )
) u_ram_player (
  .i_apb_clk        ( apb_clk                               ),
  .i_apb_rst        ( apb_rst                               ),
  .i_sif_clk        ( sif_clk                               ),
  .i_sif_rst        ( sif_rst                               ),
  .i_apb_m2s        ( ram_apb_m2s                           ),
  .o_apb_s2m        ( ram_apb_s2m                           ),
  .o_ram_axis_mux   (                                       ),
  .i_ptp            ( {ptp_sec_sync_usr, ptp_nsec_sync_usr} ),
  .o_axis_tvalid    ( sif_rx_axis_tvalid                    ),
  .o_axis_tdata     ( sif_rx_axis_tdata                     ),
  .o_axis_tkeep     ( sif_rx_axis_tkeep                     ),
  .o_axis_tuser     ( sif_rx_axis_tuser  [0]                ),
  .o_axis_tlast     ( sif_rx_axis_tlast                     ),
  .i_axis_tready    ( sif_rx_axis_tready                    )
);
// ram_player only produces a single tuser bit; tie off the rest of the
// DATAUSER_WIDTH-wide bus so it isn't left floating.
generate
  if (DATAUSER_WIDTH > 1) begin : g_sif_rx_tuser_tieoff
    assign sif_rx_axis_tuser[DATAUSER_WIDTH-1:1] = '0;
  end
endgenerate

assign ram_apb_m2s.psel    = apb_psel     [4];
assign ram_apb_m2s.penable = apb_penable;
assign ram_apb_m2s.paddr   = apb_paddr;
assign ram_apb_m2s.pwdata  = apb_pwdata;
assign ram_apb_m2s.pwrite  = apb_pwrite;
assign apb_pready [4]      = ram_apb_s2m.pready; 
assign apb_prdata [4]      = ram_apb_s2m.prdata; 
assign apb_pserr  [4]      = ram_apb_s2m.pserr;

endmodule
