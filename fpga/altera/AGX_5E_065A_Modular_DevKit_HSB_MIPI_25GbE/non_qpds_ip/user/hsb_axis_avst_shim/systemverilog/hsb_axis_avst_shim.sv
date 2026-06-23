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

module hsb_axis_avst_shim #(
    parameter int C_BYTE_SWAP          = 1,   // Byte Swap
    parameter int C_AV_EMPTY_WIDTH     = 3,   // bits in the Avalon empty signal
    parameter int C_AXIS_TUSER_WIDTH   = 1,   // bits in s_axis_tuser
    parameter int C_S_AXIS_TDATA_WIDTH = 64   // bits in s_axis_tdata
)(
    input  logic                                   clk,
    input  logic                                   resetn,

    input  logic [C_AXIS_TUSER_WIDTH-1:0]          s_axis_tuser,
    input  logic                                   s_axis_tlast,
    output logic                                   s_axis_tready,
    input  logic                                   s_axis_tvalid,
    input  logic [C_S_AXIS_TDATA_WIDTH-1:0]        s_axis_tdata,
    input  logic [(C_S_AXIS_TDATA_WIDTH/8)-1:0]    s_axis_tkeep,

    output logic                                   av_src_startofpacket,
    output logic                                   av_src_endofpacket,
    output logic [C_S_AXIS_TDATA_WIDTH-1:0]        av_src_data,
    output logic [C_AV_EMPTY_WIDTH-1:0]            av_src_empty,
    output logic                                   av_src_valid,
    input  logic                                   av_src_ready
);

    localparam int C_BYTES = C_S_AXIS_TDATA_WIDTH/8;

    // Internal registers
    logic                       eop_reg;
    logic [C_S_AXIS_TDATA_WIDTH-1:0] data_reg;

    logic [C_S_AXIS_TDATA_WIDTH-1:0] data_out;
    logic                       eop, eop_r, eop_out, eop_sent;
    logic                       av_valid_int, av_valid_out;
    logic                       s_axis_tready_int, s_axis_tready_int_d1, s_axis_tready_out;

    int                         empty_reg, empty, empty_r;

    // Debug signals for Signal Tap
    int ready_low_count, ready_low_latched, ready_low_max;

    // Function to count zeros in a vector
    function automatic int count_zero(input logic [C_BYTES-1:0] v);
        int result = 0;
        for (int i = 0; i < C_BYTES; i++)
            if (v[i] == 1'b0)
                result++;
        return result;
    endfunction

    // Bus format conversion
    assign av_valid_int      = s_axis_tvalid | (av_valid_out & (~s_axis_tready_out | ~av_src_ready));
    assign s_axis_tready_int = av_src_ready | (s_axis_tready_out & (~av_valid_out | ~s_axis_tvalid));

    assign s_axis_tready     = s_axis_tready_out;
    assign av_src_valid      = av_valid_out;
    assign av_src_endofpacket = eop_out;

    // Sequential logic for main pipeline
    always_ff @(posedge clk) begin
        if (!resetn) begin
            s_axis_tready_out  <= 1'b1;
            av_valid_out       <= 1'b0;
        end else begin
            s_axis_tready_out  <= s_axis_tready_int;
            av_valid_out       <= av_valid_int;
        end

        if (s_axis_tready_out) begin
            data_reg  <= s_axis_tdata;
            eop_reg   <= eop;
            empty_reg <= empty;
        end

        if (av_src_ready || !av_valid_out) begin
            if (!s_axis_tready_out) begin
                data_out     <= data_reg;
                eop_out      <= eop_reg;
                av_src_empty <= empty_reg[C_AV_EMPTY_WIDTH-1:0];
            end else begin
                data_out     <= s_axis_tdata;
                eop_out      <= eop;
                av_src_empty <= empty[C_AV_EMPTY_WIDTH-1:0];
            end
        end

        eop_r   <= eop;
        empty_r <= empty;
    end

    // SOP generation
    assign av_src_startofpacket = eop_sent;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            eop_sent <= 1'b1;
        end else if (av_src_ready && av_valid_out) begin
            if (eop_out)
                eop_sent <= 1'b1;
            else
                eop_sent <= 1'b0;
        end
    end

    // Set EOP
    always_comb begin
        eop = eop_r;
        if (s_axis_tvalid && s_axis_tready_out)
            eop = s_axis_tlast;
    end

    // Set empty (count zeros in tkeep)
    always_comb begin
        empty = empty_r;
        if (s_axis_tvalid && s_axis_tready_out)
            empty = count_zero(s_axis_tkeep);
    end

    // Byte swap if needed
    always_comb begin
        if (C_BYTE_SWAP == 1) begin
            for (int i = 0; i < C_BYTES; i++) begin
                av_src_data[i*8 +: 8] = data_out[(C_BYTES-1-i)*8 +: 8];
            end
        end else begin
            av_src_data = data_out;
        end
    end

    // tready monitoring for debug purpose
    always_ff @(posedge clk) begin
        if (!resetn) begin
            ready_low_count      <= 0;
            ready_low_latched    <= 0;
            ready_low_max        <= 0;
            s_axis_tready_int_d1 <= 1'b0;
        end else begin
            s_axis_tready_int_d1 <= s_axis_tready_int;
            if (s_axis_tready_int && !s_axis_tready_int_d1) begin
                ready_low_latched <= ready_low_count;
                if (ready_low_count > ready_low_max)
                    ready_low_max <= ready_low_count;
                ready_low_count <= 0;
            end else if (!s_axis_tready_int) begin
                ready_low_count <= ready_low_count + 1;
            end
        end
    end

endmodule
