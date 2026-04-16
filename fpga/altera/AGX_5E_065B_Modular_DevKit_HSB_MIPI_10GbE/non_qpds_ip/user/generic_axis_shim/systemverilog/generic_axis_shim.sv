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

module generic_axis_shim #(
    parameter int C_AXIS_TDATA_WIDTH    = 64,
    parameter int C_S_AXIS_TUSER_WIDTH  = 1,
    parameter int C_S_AXIS_USE_TSTRB    = 0,
    parameter int C_S_AXIS_USE_TKEEP    = 0,
    parameter int C_M_AXIS_TUSER_WIDTH  = 1,
    parameter int C_M_AXIS_USE_TSTRB    = 0,
    parameter int C_M_AXIS_USE_TKEEP    = 0
)(
    input  logic                                axis_aclk,
    input  logic                                axis_aresetn,

    input  logic [C_S_AXIS_TUSER_WIDTH-1:0]     s_axis_tuser,
    input  logic                                s_axis_tlast,
    output logic                                s_axis_tready,
    input  logic                                s_axis_tvalid,
    input  logic [C_AXIS_TDATA_WIDTH-1:0]       s_axis_tdata,
    input  logic [(C_AXIS_TDATA_WIDTH/8)-1:0]   s_axis_tkeep,
    input  logic [(C_AXIS_TDATA_WIDTH/8)-1:0]   s_axis_tstrb,

    output logic [C_M_AXIS_TUSER_WIDTH-1:0]     m_axis_tuser,
    output logic                                m_axis_tlast,
    input  logic                                m_axis_tready,
    output logic                                m_axis_tvalid,
    output logic [C_AXIS_TDATA_WIDTH-1:0]       m_axis_tdata,
    output logic [(C_AXIS_TDATA_WIDTH/8)-1:0]   m_axis_tkeep,
    output logic [(C_AXIS_TDATA_WIDTH/8)-1:0]   m_axis_tstrb
);


    // Internal signals
    logic axis_areset;

    logic [C_M_AXIS_TUSER_WIDTH-1:0]    axis_tuser_int;
    logic [(C_AXIS_TDATA_WIDTH/8)-1:0]  axis_tkeep_int;
    logic [(C_AXIS_TDATA_WIDTH/8)-1:0]  axis_tstrb_int;


    // Active high reset
    assign axis_areset = ~axis_aresetn;

    // tuser mapping
    generate
      if (C_M_AXIS_TUSER_WIDTH > C_S_AXIS_TUSER_WIDTH) begin : g_tuser_out_gt_tuser_in
        // Tuser Out width greater than Tuser In width (Output padded with zeros)
        assign axis_tuser_int = {{(C_M_AXIS_TUSER_WIDTH-C_S_AXIS_TUSER_WIDTH){1'b0}}, s_axis_tuser};
      end else begin : g_tuser_out_lte_tuser_in
        // Tuser Out width less than or equal to Tuser In width (Input truncated)
        assign axis_tuser_int = s_axis_tuser[C_M_AXIS_TUSER_WIDTH-1:0];
      end
    endgenerate

    // tkeep mapping
    generate
      if (C_M_AXIS_USE_TKEEP == 1 && C_S_AXIS_USE_TKEEP == 1) begin : g_use_tkeep_in_and_out
        // TKEEP used on both input and output, map input to output
        assign axis_tkeep_int = s_axis_tkeep;
      end else if (C_M_AXIS_USE_TKEEP == 1 && C_S_AXIS_USE_TKEEP == 0) begin : g_use_tkeep_out_not_in
        // TKEEP used on output but not input, must set to all 1's to keep data at sink
        assign axis_tkeep_int = {(C_AXIS_TDATA_WIDTH/8){1'b1}};
      end else begin : g_use_tkeep_ignored
        // Any case with TKEEP not used on output, set to all 0's since it will be ignored
        assign axis_tkeep_int = {(C_AXIS_TDATA_WIDTH/8){1'b0}}; 
      end
    endgenerate

    // tstrb mapping
    generate
      if (C_M_AXIS_USE_TSTRB == 1 && C_S_AXIS_USE_TSTRB == 1) begin : g_use_tstrb_in_and_out
        // TSTRB used on both input and output, map input to output
        assign axis_tstrb_int = s_axis_tstrb;
      end else if (C_M_AXIS_USE_TSTRB == 1 && C_S_AXIS_USE_TSTRB == 0) begin : g_use_tstrb_out_not_in
        // TSTRB used on output but not input, must set to all 1's to keep data at sink
        assign axis_tstrb_int = {(C_AXIS_TDATA_WIDTH/8){1'b1}};
      end else begin : g_use_tstrb_ignored
        // Any case with TSTRB not used on output, set to all 0's since it will be ignored
        assign axis_tstrb_int = {(C_AXIS_TDATA_WIDTH/8){1'b0}}; 
      end
    endgenerate

    // Output shim instantiation
    common_axis_shim #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH),
        .C_AXIS_TUSER_WIDTH(C_M_AXIS_TUSER_WIDTH)
    ) u_output_shim (
        .clk            (axis_aclk),
        .rst            (axis_areset),
        .s_axis_tuser   (axis_tuser_int),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tkeep   (axis_tkeep_int),
        .s_axis_tstrb   (axis_tstrb_int),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .m_axis_tuser   (m_axis_tuser),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tstrb   (m_axis_tstrb),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast)
    );



endmodule