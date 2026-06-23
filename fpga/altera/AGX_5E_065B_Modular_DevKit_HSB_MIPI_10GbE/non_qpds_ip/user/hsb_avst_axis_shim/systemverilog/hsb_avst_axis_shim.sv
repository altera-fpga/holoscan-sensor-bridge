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

// Avalon to AXIS shim module in SystemVerilog
module hsb_avst_axis_shim #(
    parameter int C_BYTE_SWAP          = 1,     // Byte Swap enable
    parameter int C_AV_EMPTY_WIDTH     = 3,     // Bits in the Avalon empty signal
    parameter int C_M_AXIS_TDATA_WIDTH = 96,    // Bits per avalon data word
    parameter int C_AXIS_TUSER_WIDTH   = 1      // Bits per av_sink_startofpacket
)(
    input  logic                                 clk,
    input  logic                                 resetn,

    input  logic                                 av_sink_startofpacket,
    input  logic                                 av_sink_endofpacket,
    input  logic [C_M_AXIS_TDATA_WIDTH-1:0]      av_sink_data,
    input  logic [C_AV_EMPTY_WIDTH-1:0]          av_sink_empty,
    input  logic                                 av_sink_valid,
    output logic                                 av_sink_ready,

    output logic [C_AXIS_TUSER_WIDTH-1:0]        m_axis_tuser,
    output logic                                 m_axis_tlast,
    input  logic                                 m_axis_tready,
    output logic                                 m_axis_tvalid,
    output logic [C_M_AXIS_TDATA_WIDTH-1:0]      m_axis_tdata,
    output logic [(C_M_AXIS_TDATA_WIDTH/8)-1:0]  m_axis_tkeep
);

    localparam int C_BYTES = C_M_AXIS_TDATA_WIDTH/8;

    // Internal registers
    logic                         av_ready_in_int, av_ready_in_out;
    logic                         m_axis_tvalid_int, m_axis_tvalid_out;
    logic                         tlast, tlast_r;
    logic [C_M_AXIS_TDATA_WIDTH-1:0] data_reg, m_axis_tdata_out;
    logic                         tlast_reg;
    logic                         tuser_reg;

    int                           valid_bytes_reg, valid_bytes, valid_bytes_r;

    // Function to generate tkeep mask
    function automatic logic [C_BYTES-1:0] gen_tkeep(input int num_valid);
        logic [C_BYTES-1:0] tkeep_mask;
        for (int i = 0; i < C_BYTES; i++)
            tkeep_mask[i] = (i < num_valid) ? 1'b1 : 1'b0;
        return tkeep_mask;
    endfunction

    // Bus format conversion
    assign m_axis_tvalid_int = av_sink_valid | (m_axis_tvalid_out & (~av_ready_in_out | ~m_axis_tready));
    assign av_ready_in_int   = m_axis_tready | (av_ready_in_out & (~m_axis_tvalid_out | ~av_sink_valid));

    assign av_sink_ready     = av_ready_in_out;
    assign m_axis_tvalid     = m_axis_tvalid_out;

    // Sequential logic
    always_ff @(posedge clk) begin
        if (!resetn) begin
            m_axis_tvalid_out <= 1'b0;
            av_ready_in_out   <= 1'b1;
        end else begin
            m_axis_tvalid_out <= m_axis_tvalid_int;
            av_ready_in_out   <= av_ready_in_int;
        end

        if (av_ready_in_out) begin
            data_reg        <= av_sink_data;
            tlast_reg       <= tlast;
            tuser_reg       <= av_sink_startofpacket;
            valid_bytes_reg <= valid_bytes;
        end

        if (m_axis_tready || !m_axis_tvalid_out) begin
            if (!av_ready_in_out) begin
                m_axis_tdata_out <= data_reg;
                m_axis_tuser[0]  <= tuser_reg;
                m_axis_tlast     <= tlast_reg;
                m_axis_tkeep     <= gen_tkeep(valid_bytes_reg);
            end else begin
                m_axis_tdata_out <= av_sink_data;
                m_axis_tuser[0]  <= av_sink_startofpacket;
                m_axis_tlast     <= tlast;
                m_axis_tkeep     <= gen_tkeep(valid_bytes);
            end
        end

        tlast_r       <= tlast;
        valid_bytes_r <= valid_bytes;
    end

    // Map tlast to EOP
    always_comb begin
        tlast = tlast_r;
        if (av_sink_valid && av_ready_in_out)
            tlast = av_sink_endofpacket;
    end

    // Calculate valid_bytes
    always_comb begin
        valid_bytes = valid_bytes_r;
        if (av_sink_valid && av_ready_in_out)
            valid_bytes = C_BYTES - av_sink_empty;
    end

    // Byte swap if needed
    always_comb begin
        if (C_BYTE_SWAP == 1) begin
            for (int i = 0; i < C_BYTES; i++) begin
                m_axis_tdata[i*8 +: 8] = m_axis_tdata_out[(C_BYTES-1-i)*8 +: 8];
            end
        end else begin
            m_axis_tdata = m_axis_tdata_out;
        end
    end

endmodule