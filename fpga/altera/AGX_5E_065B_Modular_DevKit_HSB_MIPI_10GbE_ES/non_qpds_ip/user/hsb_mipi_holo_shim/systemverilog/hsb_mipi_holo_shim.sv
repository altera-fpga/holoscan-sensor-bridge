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

module hsb_mipi_holo_shim #(
    parameter int C_AXIS_TUSER_WIDTH   = 1,
    parameter int C_M_AXIS_TDATA_WIDTH = 64,
    parameter int C_S_AXIS_TDATA_WIDTH = 64
)(
    input  logic                                 axis_aclk,
    input  logic                                 axis_aresetn,

    input  logic [C_AXIS_TUSER_WIDTH-1:0]        s_axis_tuser,
    input  logic                                 s_axis_tlast,
    output logic                                 s_axis_tready,
    input  logic                                 s_axis_tvalid,
    input  logic [C_S_AXIS_TDATA_WIDTH-1:0]      s_axis_tdata,
    input  logic [(C_S_AXIS_TDATA_WIDTH/8)-1:0]  s_axis_tkeep,

    output logic [C_AXIS_TUSER_WIDTH-1:0]        m_axis_tuser,
    output logic                                 m_axis_tlast,
    input  logic                                 m_axis_tready,
    output logic                                 m_axis_tvalid,
    output logic [C_M_AXIS_TDATA_WIDTH-1:0]      m_axis_tdata,
    output logic [(C_M_AXIS_TDATA_WIDTH/8)-1:0]  m_axis_tkeep
);

    // Local parameters for packet types
    localparam logic [5:0] PT_SOF = 6'b000000;
    localparam logic [5:0] PT_EOF = 6'b000001;
    localparam logic [5:0] PT_SOL = 6'b000010;
    localparam logic [5:0] PT_EOL = 6'b000011;
    localparam logic [5:0] PT_EOT = 6'b000100;
    localparam logic [5:0] PT_EMB = 6'b010010;
    localparam logic [5:0] PT_R10 = 6'b101011;
    localparam logic [5:0] PT_R12 = 6'b101100;

    localparam int EXP_EMB_SIZE = 5768;
    localparam int EXP_R10_SIZE = 4808;
    localparam int EXP_R12_SIZE = 5768;
    localparam int BYTES_PER_TICK = 8;

    // Internal signals
    logic axis_areset;

    logic [C_AXIS_TUSER_WIDTH-1:0] axis_tuser_int;
    logic [C_M_AXIS_TDATA_WIDTH-1:0] axis_tdata_int;
    logic axis_tvalid_int;
    logic axis_tready_int;
    logic axis_tready_int_d1;
    logic axis_tlast_int;
    logic axis_tlast_out;
    logic [(C_S_AXIS_TDATA_WIDTH/8)-1:0] axis_tkeep_int;

    logic tlast_mask, tlast_mask_d1, tlast_fast_mask;

    logic [5:0] packet_type, packet_type_reg;
    logic [15:0] packet_hdr_size;

    int sof_count, eof_count, sol_count, eol_count, eot_count, emb_count, r10_count, r12_count;
    int sof_size_good, eof_size_good, sol_size_good, eol_size_good, eot_size_good, emb_size_good, r10_size_good, r12_size_good;
    int sof_size_bad, eof_size_bad, sol_size_bad, eol_size_bad, eot_size_bad, emb_size_bad, r10_size_bad, r12_size_bad;
    int unknown_count, unknown_short, unknown_long;
    int packet_size, frame_lines, line_count;
    int unexpected_tuser;
    int ready_low_count, ready_low_latched, ready_low_max;

    // Active high reset
    assign axis_areset = ~axis_aresetn;

    // Input shim instantiation
    common_axis_shim #(
        .C_AXIS_TDATA_WIDTH(C_S_AXIS_TDATA_WIDTH),
        .C_AXIS_TUSER_WIDTH(C_AXIS_TUSER_WIDTH)
    ) u_input_shim (
        .clk            (axis_aclk),
        .rst            (axis_areset),
        .s_axis_tuser   (s_axis_tuser),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tkeep   (s_axis_tkeep),
        .s_axis_tstrb   ('0), // unused
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .m_axis_tuser   (axis_tuser_int),
        .m_axis_tdata   (axis_tdata_int),
        .m_axis_tkeep   (axis_tkeep_int),
        .m_axis_tstrb   (),   // open
        .m_axis_tvalid  (axis_tvalid_int),
        .m_axis_tready  (axis_tready_int),
        .m_axis_tlast   (axis_tlast_int)
    );

    // Output shim instantiation
    common_axis_shim #(
        .C_AXIS_TDATA_WIDTH(C_M_AXIS_TDATA_WIDTH),
        .C_AXIS_TUSER_WIDTH(C_AXIS_TUSER_WIDTH)
    ) u_output_shim (
        .clk            (axis_aclk),
        .rst            (axis_areset),
        .s_axis_tuser   (axis_tuser_int),
        .s_axis_tdata   (axis_tdata_int),
        .s_axis_tkeep   (axis_tkeep_int),
        .s_axis_tstrb   ('0),
        .s_axis_tvalid  (axis_tvalid_int),
        .s_axis_tready  (axis_tready_int),
        .s_axis_tlast   (axis_tlast_out),
        .m_axis_tuser   (m_axis_tuser),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tstrb   (), // open
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast)
    );

    // Packet type extraction
    always_comb begin
        packet_type = axis_tdata_int[5:0];
    end

    // Fast Mask
    always_comb begin
        tlast_fast_mask = 1'b1;
        if (axis_tuser_int[0] == 1'b1 && (packet_type == PT_EOF || packet_type == PT_EOT))
            tlast_fast_mask = 1'b0;
    end

    // Registered mask
    always_ff @(posedge axis_aclk) begin
        if (axis_areset) begin
            tlast_mask <= 1'b1;
        end else if (axis_tready_int && axis_tvalid_int && axis_tuser_int[0]) begin
            tlast_mask <= tlast_fast_mask;
        end
    end

    // Use fast mask value if same cycle as tuser otherwise use registered mask
    always_comb begin
        if ((axis_tuser_int[0] && tlast_fast_mask == 1'b0) || (!axis_tuser_int[0] && tlast_mask == 1'b0))
            axis_tlast_out = axis_tlast_int;
        else
            axis_tlast_out = 1'b0;
    end

    // Debug counts and statistics
    always_ff @(posedge axis_aclk) begin
        if (axis_areset) begin
            packet_type_reg <= 6'b111111;
            sof_count <= 0; eof_count <= 0; sol_count <= 0; eol_count <= 0; eot_count <= 0;
            emb_count <= 0; r10_count <= 0; r12_count <= 0;
            sof_size_good <= 0; eof_size_good <= 0; sol_size_good <= 0; eol_size_good <= 0; eot_size_good <= 0;
            emb_size_good <= 0; r10_size_good <= 0; r12_size_good <= 0;
            sof_size_bad <= 0; eof_size_bad <= 0; sol_size_bad <= 0; eol_size_bad <= 0; eot_size_bad <= 0;
            emb_size_bad <= 0; r10_size_bad <= 0; r12_size_bad <= 0;
            unknown_count <= 0; unknown_short <= 0; unknown_long <= 0;
            packet_size <= BYTES_PER_TICK;
            frame_lines <= 0; line_count <= 0;
            unexpected_tuser <= 0;
        end else if (axis_tready_int && axis_tvalid_int) begin
            packet_size <= packet_size + BYTES_PER_TICK;
            if (axis_tuser_int[0]) begin
                packet_type_reg <= packet_type;
                packet_hdr_size <= BYTES_PER_TICK;
                case (packet_type)
                    PT_SOF:  sof_count  <= sof_count + 1;
                    PT_EOF:  eof_count  <= eof_count + 1;
                    PT_SOL:  sol_count  <= sol_count + 1;
                    PT_EOL:  eol_count  <= eol_count + 1;
                    PT_EOT:  eot_count  <= eot_count + 1;
                    PT_EMB:  begin
                        emb_count <= emb_count + 1;
                        packet_hdr_size <= axis_tdata_int[23:8];
                    end
                    PT_R10:  begin
                        r10_count <= r10_count + 1;
                        packet_hdr_size <= axis_tdata_int[23:8];
                    end
                    PT_R12:  begin
                        r12_count <= r12_count + 1;
                        packet_hdr_size <= axis_tdata_int[23:8];
                    end
                    default: unknown_count <= unknown_count + 1;
                endcase
                if (packet_size != BYTES_PER_TICK)
                    unexpected_tuser <= unexpected_tuser + 1;
            end
            if (axis_tlast_int) begin
                packet_size <= BYTES_PER_TICK;
                if (axis_tuser_int[0]) begin
                    case (packet_type)
                        PT_SOF:  sof_size_good <= sof_size_good + 1;
                        PT_EOF:  begin
                            eof_size_good <= eof_size_good + 1;
                            frame_lines   <= line_count;
                            line_count    <= 0;
                        end
                        PT_SOL:  sol_size_good <= sol_size_good + 1;
                        PT_EOL:  eol_size_good <= eol_size_good + 1;
                        PT_EOT:  eot_size_good <= eot_size_good + 1;
                        PT_EMB:  emb_size_bad  <= emb_size_bad + 1;
                        PT_R10:  begin
                            r10_size_bad <= r10_size_bad + 1;
                            line_count   <= line_count + 1;
                        end
                        PT_R12:  begin
                            r12_size_bad <= r12_size_bad + 1;
                            line_count   <= line_count + 1;
                        end
                        default: unknown_short <= unknown_short + 1;
                    endcase
                end else begin
                    case (packet_type_reg)
                        PT_SOF:  sof_size_bad  <= sof_size_bad + 1;
                        PT_EOF:  begin
                            eof_size_bad <= eof_size_bad + 1;
                            frame_lines  <= line_count;
                            line_count   <= 0;
                        end
                        PT_SOL:  sol_size_bad  <= sol_size_bad + 1;
                        PT_EOL:  eol_size_bad  <= eol_size_bad + 1;
                        PT_EOT:  eot_size_bad  <= eot_size_bad + 1;
                        PT_EMB:  if ((packet_size == EXP_R10_SIZE) || (packet_size == EXP_R12_SIZE))
                                    emb_size_good <= emb_size_good + 1;
                                 else
                                    emb_size_bad  <= emb_size_bad + 1;
                        PT_R10:  begin
                            if (packet_size == EXP_R10_SIZE)
                                r10_size_good <= r10_size_good + 1;
                            else
                                r10_size_bad  <= r10_size_bad + 1;
                            line_count     <= line_count + 1;
                        end
                        PT_R12: begin
                            if (packet_size == EXP_R12_SIZE)
                                r12_size_good <= r12_size_good + 1;
                            else
                                r12_size_bad  <= r12_size_bad + 1;
                            line_count     <= line_count + 1;
                        end
                        default: unknown_long  <= unknown_long + 1;
                    endcase
                end
            end
        end
    end

    // tready monitoring for debug purpose
    always_ff @(posedge axis_aclk) begin
        if (axis_areset) begin
            ready_low_count      <= 0;
            ready_low_latched    <= 0;
            ready_low_max        <= 0;
            axis_tready_int_d1   <= 1'b0;
        end else begin
            axis_tready_int_d1 <= axis_tready_int;
            if (axis_tready_int && !axis_tready_int_d1) begin
                ready_low_latched <= ready_low_count;
                if (ready_low_count > ready_low_max)
                    ready_low_max <= ready_low_count;
                ready_low_count <= 0;
            end else if (!axis_tready_int) begin
                ready_low_count <= ready_low_count + 1;
            end
        end
    end

endmodule