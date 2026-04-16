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

module common_axis_shim #(
    parameter int C_AXIS_TDATA_WIDTH = 32,
    parameter int C_AXIS_TUSER_WIDTH = 2,
    parameter int C_USE_RDY_MSK      = 0   // 1 = s_axis_tready uses in_rdy_msk
)(
    input  logic                                 clk,
    input  logic                                 rst,

    input  logic [C_AXIS_TUSER_WIDTH-1:0]        s_axis_tuser,
    input  logic [C_AXIS_TDATA_WIDTH-1:0]        s_axis_tdata,
    input  logic [C_AXIS_TDATA_WIDTH/8-1:0]      s_axis_tkeep,
    input  logic [C_AXIS_TDATA_WIDTH/8-1:0]      s_axis_tstrb,
    input  logic                                 s_axis_tvalid,
    output logic                                 s_axis_tready,
    input  logic                                 s_axis_tlast,

    input  logic                                 in_rdy_msk,

    output logic [C_AXIS_TUSER_WIDTH-1:0]        m_axis_tuser,
    output logic [C_AXIS_TDATA_WIDTH-1:0]        m_axis_tdata,
    output logic [C_AXIS_TDATA_WIDTH/8-1:0]      m_axis_tkeep,
    output logic [C_AXIS_TDATA_WIDTH/8-1:0]      m_axis_tstrb,
    output logic                                 m_axis_tvalid,
    input  logic                                 m_axis_tready,
    output logic                                 m_axis_tlast
);

    // Internal registers
    logic m_axis_tvalid_dup, m_axis_tvalid_out;
    logic s_axis_tready_dup, s_axis_tready_out;
    logic [C_AXIS_TDATA_WIDTH-1:0]     tdata_reg;
    logic [C_AXIS_TDATA_WIDTH/8-1:0]   tkeep_reg, tstrb_reg;
    logic [C_AXIS_TUSER_WIDTH-1:0]     tuser_reg;
    logic                              tlast_reg;
    logic m_axis_tvalid_raw, s_axis_tready_raw;
    logic in_rdy_msk_int;

    // m_axis_tvalid and s_axis_tready raw calculations
    assign m_axis_tvalid_raw = s_axis_tvalid | (m_axis_tvalid_dup & (~s_axis_tready_dup | ~m_axis_tready));
    assign s_axis_tready_raw = m_axis_tready | (s_axis_tready_dup & (~m_axis_tvalid_dup | ~s_axis_tvalid));

    // Ready mask logic
    generate
        if (C_USE_RDY_MSK == 1) begin : g_use_tready_mask
            always_comb in_rdy_msk_int = in_rdy_msk;
        end else begin : g_dont_use_tready_mask
            always_comb in_rdy_msk_int = 1'b1;
        end
    endgenerate

    // Main pipeline
    always_ff @(posedge clk) begin
        if (rst) begin
            s_axis_tready_out  <= 1'b1;
            s_axis_tready_dup  <= 1'b1;
            m_axis_tvalid_out  <= 1'b0;
            m_axis_tvalid_dup  <= 1'b0;
            tdata_reg          <= '0;
            tkeep_reg          <= '0;
            tstrb_reg          <= '0;
            tuser_reg          <= '0;
            tlast_reg          <= 1'b0;
        end else begin
            m_axis_tvalid_out  <= m_axis_tvalid_raw;
            m_axis_tvalid_dup  <= m_axis_tvalid_raw;
            s_axis_tready_out  <= s_axis_tready_raw & in_rdy_msk_int;
            s_axis_tready_dup  <= s_axis_tready_raw;

            // 1 Reg deep FIFO
            if (s_axis_tready_dup) begin
                tdata_reg <= s_axis_tdata;
                tlast_reg <= s_axis_tlast;
                tuser_reg <= s_axis_tuser;
                tkeep_reg <= s_axis_tkeep;
                tstrb_reg <= s_axis_tstrb;
            end

            // Select between FIFO or input data
            if (m_axis_tready || !m_axis_tvalid_dup) begin
                if (!s_axis_tready_dup) begin
                    m_axis_tdata <= tdata_reg;
                    m_axis_tuser <= tuser_reg;
                    m_axis_tkeep <= tkeep_reg;
                    m_axis_tstrb <= tstrb_reg;
                    m_axis_tlast <= tlast_reg;
                end else begin
                    m_axis_tdata <= s_axis_tdata;
                    m_axis_tuser <= s_axis_tuser;
                    m_axis_tlast <= s_axis_tlast;
                    m_axis_tkeep <= s_axis_tkeep;
                    m_axis_tstrb <= s_axis_tstrb;
                end
            end
        end
    end

    // Export outputs
    assign s_axis_tready = s_axis_tready_out;
    assign m_axis_tvalid = m_axis_tvalid_out;

endmodule
