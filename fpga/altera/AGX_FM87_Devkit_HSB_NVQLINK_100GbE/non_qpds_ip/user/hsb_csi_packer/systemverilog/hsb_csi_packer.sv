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

module hsb_csi_packer #(
  parameter int C_M_AXIS_TUSER_WIDTH  = 1,
  parameter int C_M_AXIS_USE_TKEEP    = 0
)(
  input   logic         axis_aclk,
  input   logic         axis_aresetn,

  input   logic [7:0]   s_axis_tuser,
  input   logic         s_axis_tlast,
  output  logic         s_axis_tready,
  input   logic         s_axis_tvalid,
  input   logic [63:0]  s_axis_tdata,

  output  logic [C_M_AXIS_TUSER_WIDTH-1:0]    m_axis_tuser,
  output  logic         m_axis_tlast,
  input   logic         m_axis_tready,
  output  logic         m_axis_tvalid,
  output  logic [63:0]  m_axis_tdata,
  output  logic [7:0]   m_axis_tkeep
);

// This module takes in Bayer RAW (8b,10b,12b) pixel data from an Altera Streaming Video Protocol source and converts it to the CSI-2 format
// This is more efficient packing for data transfer and is compatible with HSB COE - see "Camera Streaming" section of HSB documentation
// All short packets and headers/footers are to be dropped which means this is suited to ASVP rather than MIPI passthrough

// Due to 8 Byte boundary alignment, this module only supports 64b input and output
// Expects up to RAW12 which requires 16bpp so only 4 PIP supported
// Use external VVP IP upstream if necessary to manipulate data width

// Output sideband
// tuser/tkeep use configurable to allow for downstream vvp fifo or direct connection to HSB IP
// tuser[0] - set to denote embedded data (unused as embedded data is being stripped out) so will always be 0 in this shim
// tuser[1] - set to denote end of MIPI long packet which is a line (EOL) for HSB COE, packets "can" be aligned to 8 Byte boundary with zero padding
// tlast    - set to denote end of frame

// The input supports ASVP-full in order to seamlessly determine bit depth and frame size however output is compatible with HSB (2 bit tuser, no control packets)


// Local parameters for decoding control packets
// Control packet BPS = BPS-1
localparam logic [5:0] BPS_8  = 5'b00111;
localparam logic [5:0] BPS_10 = 5'b01001;
localparam logic [5:0] BPS_12 = 5'b01011;

// constant for pixels in parallel on AXIS
localparam int C_AXIS_PIP = 4;

logic axis_areset;

// input only AXIS
logic         axis_tready_in;
logic         axis_tvalid_in;
logic [7:0]   axis_tuser_in;
logic [63:0]  axis_tdata_in;
logic [63:0]  axis_tdata_in_d1;
logic         axis_tlast_in;

// output only AXIS
logic         axis_tready_out;
logic         axis_tvalid_out;
logic [C_M_AXIS_TUSER_WIDTH-1:0]  axis_tuser_out;
logic [63:0]  axis_tdata_out;
logic         axis_tlast_out;
logic [7:0]   axis_tkeep_out;


// Shim control logic
logic       vid_ctrln;      // flag to indicate if expecting video or control packet
logic [1:0] ctrl_pkt_beat;
logic [2:0] vid_pkt_beat;
logic       vid_mid_frame;  // set after vid tuser to denote we're mid frame
logic       packet_flush;   // set when unexpected packet comes in so that errors aren't reported constantly
logic [2:0] alignment_cycles;

// Extracted video information
int ctrl_pkt_bps;
int ctrl_pkt_width;
int ctrl_pkt_height;

// Video measurements
int line_count;         /* synthesis keep */
int pixel_count;        /* synthesis keep */
int valid_out_count;    /* synthesis keep */
int latched_lines;     /* synthesis keep */
int latched_pixels;    /* synthesis keep */
int latched_valid_out; /* synthesis keep */

// Error counters
int width_errors;       /* synthesis keep */  // incremented when input tlast does not come at expected pixel count
int height_errors;      /* synthesis keep */  // incremented when any tuser asserted but last measured frame height does not match captured control packet value
int unexpected_vid;     /* synthesis keep */  // incremented if video packets received when not expected
int unexpected_ctrl;    /* synthesis keep */  // incremented if control packets received when not expected
int unexpected_ctrl_id; /* synthesis keep */  // incremented if control packet id is not image properties
int ctrl_sync_error;    /* synthesis keep */  // incremented if tuser for control not on first beat
int vid_sync_error;     /* synthesis keep */  // incremented if tuser for video not on first beat
int missing_bps_error;  /* synthesis keep */  // incremented if SOF seen but without video frame info

logic [7:0] raw8 [3:0];

logic [7:0] raw10_u [3:0];
logic [1:0] raw10_l [3:0];
logic [7:0] raw10_u_d1 [3:0];
logic [1:0] raw10_l_d1 [3:0];

logic [7:0] raw12_u [3:0];
logic [3:0] raw12_l [3:0];
logic [7:0] raw12_u_d1 [3:0];
logic [3:0] raw12_l_d1 [3:0];

// Active high reset
assign axis_areset = ~axis_aresetn;

    // Input shim instantiation
common_axis_shim #(
  .C_AXIS_TDATA_WIDTH(64),
  .C_AXIS_TUSER_WIDTH(8)
) u_input_shim (
  .clk            (axis_aclk),
  .rst            (axis_areset),
  .s_axis_tuser   (s_axis_tuser),
  .s_axis_tdata   (s_axis_tdata),
  .s_axis_tkeep   (8'hFF),  // tied off
  .s_axis_tstrb   ('0),     // unused
  .s_axis_tvalid  (s_axis_tvalid),
  .s_axis_tready  (s_axis_tready),
  .s_axis_tlast   (s_axis_tlast),
  .m_axis_tuser   (axis_tuser_in),
  .m_axis_tdata   (axis_tdata_in),
  .m_axis_tkeep   (),   // open
  .m_axis_tstrb   (),   // open
  .m_axis_tvalid  (axis_tvalid_in),
  .m_axis_tready  (axis_tready_in),
  .m_axis_tlast   (axis_tlast_in)
);

// Output shim instantiation
common_axis_shim #(
  .C_AXIS_TDATA_WIDTH(64),
  .C_AXIS_TUSER_WIDTH(C_M_AXIS_TUSER_WIDTH)
) u_output_shim (
  .clk            (axis_aclk),
  .rst            (axis_areset),
  .s_axis_tuser   (axis_tuser_out),
  .s_axis_tdata   (axis_tdata_out),
  .s_axis_tkeep   (axis_tkeep_out),
  .s_axis_tstrb   ('0),
  .s_axis_tvalid  (axis_tvalid_out),
  .s_axis_tready  (axis_tready_out),
  .s_axis_tlast   (axis_tlast_out),
  .m_axis_tuser   (m_axis_tuser),
  .m_axis_tdata   (m_axis_tdata),
  .m_axis_tkeep   (m_axis_tkeep),
  .m_axis_tstrb   (), // open
  .m_axis_tvalid  (m_axis_tvalid),
  .m_axis_tready  (m_axis_tready),
  .m_axis_tlast   (m_axis_tlast)
);


// tready in is held high until control packet consumed
// once control packet processed tready/tvalid passed through
assign axis_tready_in   = (vid_ctrln) ? axis_tready_out : 1'b1;

// extract pixel data
always_comb begin
  for (int i = 0; i < 4; i++) begin
      raw8[i]       = axis_tdata_in[(i*16)        +: 8];

      raw10_u[i]    = axis_tdata_in[(i*16)+9      -: 8];
      raw10_l[i]    = axis_tdata_in[(i*16)        +: 2];
      raw10_u_d1[i] = axis_tdata_in_d1[(i*16)+9   -: 8];
      raw10_l_d1[i] = axis_tdata_in_d1[(i*16)     +: 2];

      raw12_u[i]    = axis_tdata_in[(i*16)+11     -: 8];
      raw12_l[i]    = axis_tdata_in[(i*16)        +: 4];
      raw12_u_d1[i] = axis_tdata_in_d1[(i*16)+11  -: 8];
      raw12_l_d1[i] = axis_tdata_in_d1[(i*16)     +: 4];
  end
end
// bit depth extracted from control packet and used to dictate how many cycles are needed for alignment
always_comb begin
    if (ctrl_pkt_bps == BPS_8)
        alignment_cycles = 3'h1;
    else if (ctrl_pkt_bps == BPS_10)
        alignment_cycles = 3'h7;
    else if (ctrl_pkt_bps == BPS_12)
        alignment_cycles = 3'h3;
    else
      alignment_cycles = 3'h0;
end

always_ff @(posedge axis_aclk) begin
  if (axis_areset) begin
    vid_ctrln           <= 1'b0;
    ctrl_pkt_beat       <= 2'h0;
    vid_pkt_beat        <= 3'b000;

    ctrl_pkt_bps        <= 0;
    ctrl_pkt_width      <= 0;
    ctrl_pkt_height     <= 0;

    line_count          <= 1;
    pixel_count         <= 4;
    latched_lines       <= 0;
    latched_pixels      <= 0;

    width_errors        <= 0;
    height_errors       <= 0;
    unexpected_vid      <= 0;
    unexpected_ctrl     <= 0;
    unexpected_ctrl_id  <= 0;
    ctrl_sync_error     <= 0;
    vid_sync_error      <= 0;
    missing_bps_error   <= 0;

    axis_tvalid_out <= 1'b0;
    axis_tuser_out      <= {C_M_AXIS_TUSER_WIDTH{1'b0}};
    axis_tlast_out  <= 1'b0;
    axis_tkeep_out  <= 8'hFF;

  end else begin

    // default output states, irrespective of packet types
    axis_tvalid_out <= 1'b0;
    axis_tuser_out  <= {C_M_AXIS_TUSER_WIDTH{1'b0}};
    axis_tlast_out  <= 1'b0;
    axis_tkeep_out  <= 8'hFF;
    axis_tdata_in_d1 <= axis_tdata_in;

    if (axis_tready_in && axis_tvalid_in) begin

      if (vid_ctrln) begin
        vid_pkt_beat  <= vid_pkt_beat + 1;
        pixel_count   <= pixel_count + 4;

        // Currently expecting video packet so watch for control packet
        if (axis_tuser_in[1] == 1'b1) begin
          unexpected_ctrl  <= unexpected_ctrl + 1;
          packet_flush    <= 1'b1;
          ctrl_pkt_beat   <= 2'b00;
        end

        // check that SOF is when expected (no protection, just flagging error)
        if (axis_tuser_in[0] == 1'b1) begin
          if (vid_mid_frame == 1'b0 && vid_pkt_beat == 3'b000) begin
            vid_mid_frame <= 1'b1;
            // alignment_cycles is set otherwise we've not captured BPS correctly
            if (alignment_cycles == 0) begin
              missing_bps_error <= missing_bps_error + 1;
            end
          end else begin
            vid_sync_error <= vid_sync_error + 1;
            vid_pkt_beat   <= 3'b001;
          end
        end

        if (axis_tlast_in == 1'b1) begin
          // set tuser(1) as end of long packet
          axis_tuser_out[1] <= 1'b1;
          line_count        <= line_count + 1;
          latched_pixels    <= pixel_count;
          pixel_count       <= 4;
          if (pixel_count != ctrl_pkt_width) begin
            width_errors <= width_errors + 1;
          end
          //check if last line of frame, if so assert tlast 
          if (line_count == ctrl_pkt_height) begin
            axis_tlast_out  <= 1'b1;
            latched_lines   <= line_count;
            line_count      <= 1;
            vid_mid_frame   <= 1'b0;
            vid_ctrln       <= 1'b0;
            ctrl_pkt_beat   <= 2'b00;
          end
        end

        if (vid_pkt_beat >= alignment_cycles) begin
          vid_pkt_beat <= 3'b000;
        end

        // Pixel packing
        case (vid_pkt_beat)
          3'b000: begin
            case (ctrl_pkt_bps)
              BPS_8:  axis_tdata_out <= {32'h0, raw8[3], raw8[2], raw8[1], raw8[0]};
              BPS_10: axis_tdata_out <= {24'h0, raw10_l[3], raw10_l[2], raw10_l[1], raw10_l[0], raw10_u[3], raw10_u[2], raw10_u[1], raw10_u[0]};
              BPS_12: axis_tdata_out <= {16'h0, raw12_l[3], raw12_l[2], raw12_u[3], raw12_u[2], raw12_l[1], raw12_l[0], raw12_u[1], raw12_u[0]};
              default: axis_tdata_out <= ctrl_pkt_bps;
            endcase
          end
          3'b001: begin
            axis_tvalid_out <= 1'b1;
            case (ctrl_pkt_bps)
              BPS_8:  axis_tdata_out  <= {raw8[3], raw8[2], raw8[1], raw8[0], axis_tdata_out[31:0]};
              BPS_10: axis_tdata_out  <= {raw10_u[2], raw10_u[1], raw10_u[0], axis_tdata_out[39:0]};
              BPS_12: axis_tdata_out  <= {raw12_u[1], raw12_u[0], axis_tdata_out[47:0]};
              default: axis_tdata_out <= ctrl_pkt_bps;
            endcase
          end
          3'b010: begin
            // only 10b and 12 gearboxing for cycles > 1
            case (ctrl_pkt_bps)
              BPS_10: axis_tdata_out  <= {8'h0, raw10_l[3], raw10_l[2], raw10_l[1], raw10_l[0], raw10_u[3], raw10_u[2], raw10_u[1], raw10_u[0], raw10_l_d1[3], raw10_l_d1[2], raw10_l_d1[1], raw10_l_d1[0], raw10_u_d1[3]};
              BPS_12: begin
                axis_tvalid_out <= 1'b1;
                axis_tdata_out  <= {raw12_u[2], raw12_l[1], raw12_l[0], raw12_u[1], raw12_u[0], raw12_l_d1[3], raw12_l_d1[2], raw12_u_d1[3], raw12_u_d1[2], raw12_l_d1[1], raw12_l_d1[0]};
              end
              default: axis_tdata_out <= ctrl_pkt_bps;
            endcase
          end
          3'b011: begin
            // only 10b and 12 gearboxing for cycles > 1
            axis_tvalid_out <= 1'b1;
            case (ctrl_pkt_bps)
              BPS_10: axis_tdata_out  <= {raw10_u[0], axis_tdata_out[55:0]};
              BPS_12: axis_tdata_out  <= {raw12_l[3], raw12_l[2], raw12_u[3], raw12_u[2], raw12_l[1], raw12_l[0], raw12_u[1], raw12_u[0], raw12_l_d1[3], raw12_l_d1[2], raw12_u_d1[3]};
              default: axis_tdata_out <= ctrl_pkt_bps;
            endcase
          end
          3'b100: begin
            axis_tvalid_out <= 1'b1;
            // only 10b gearboxing for cycles > 3
            axis_tdata_out  <= {raw10_u[3], raw10_u[2], raw10_u[1], raw10_u[0], raw10_l_d1[3], raw10_l_d1[2], raw10_l_d1[1], raw10_l_d1[0], raw10_u_d1[3], raw10_u_d1[2], raw10_u_d1[1]};
          end
          3'b101: begin
            // only 10b gearboxing for cycles > 3
            axis_tdata_out  <= {16'h0, raw10_l[3], raw10_l[2], raw10_l[1], raw10_l[0], raw10_u[3], raw10_u[2], raw10_u[1], raw10_u[0], raw10_l_d1[3], raw10_l_d1[2], raw10_l_d1[1], raw10_l_d1[0]};
          end
          3'b110: begin
            axis_tvalid_out <= 1'b1;
            // only 10b gearboxing for cycles > 3
            axis_tdata_out  <= {raw10_u[1], raw10_u[0], axis_tdata_out[47:0]};
          end
          3'b111: begin
            axis_tvalid_out <= 1'b1;
            // only 10b gearboxing for cycles > 3
            axis_tdata_out  <= {raw10_l[3], raw10_l[2], raw10_l[1], raw10_l[0], raw10_u[3], raw10_u[2], raw10_u[1], raw10_u[0], raw10_l_d1[3], raw10_l_d1[2], raw10_l_d1[1], raw10_l_d1[0], raw10_u_d1[3], raw10_u_d1[2]};
          end
          default: axis_tdata_out <= vid_pkt_beat;
        endcase

      end else begin
        // Currently expecting control packet so watch for video packet
        if (axis_tuser_in[0] == 1'b1) begin
          unexpected_vid  <= unexpected_vid + 1;
          packet_flush    <= 1'b1;
          ctrl_pkt_beat   <= 2'b00;
        end
        // unless start of control packet should not see tuser[1]
        if (axis_tuser_in[1] == 1'b1 && ctrl_pkt_beat != 2'b00) begin
          ctrl_sync_error <= ctrl_sync_error + 1;
          packet_flush    <= 1'b1;
          ctrl_pkt_beat   <= 2'b00;
        end
        // if tlast can clear the flush
        if (axis_tlast_in == 1'b1) begin
          packet_flush    <= 1'b0;
          ctrl_pkt_beat   <= 2'b00;
        end

        // unless flushing the packet, inc the beat and decode contents of control packet 
        if (!packet_flush) begin
          ctrl_pkt_beat <= ctrl_pkt_beat + 1;
          case (ctrl_pkt_beat)
            2'h0: begin
              // first beat of control packet, check tuser(1) is set and check it's a image info packet
              if (axis_tuser_in[1] != 1'b1) begin
                ctrl_sync_error <= ctrl_sync_error + 1;
                packet_flush    <= 1'b1;
                ctrl_pkt_beat   <= 2'b00;
              end else if (axis_tdata_in[4:0] != 0) begin
                unexpected_ctrl_id  <= unexpected_ctrl_id + 1;
                packet_flush        <= 1'b1;
                ctrl_pkt_beat       <= 2'b00;
              end else begin
                // tuser present and image information packet type, crack on with decode
                packet_flush  <= 1'b0; 
                ctrl_pkt_beat <= 2'b01;
              end
            end
            2'h1: begin
              // second beat - width
              ctrl_pkt_width <= axis_tdata_in[15:0] + 1;
            end
            2'h2: begin
              // third beat - height
              ctrl_pkt_height <= axis_tdata_in[15:0] + 1;
            end
            2'h3: begin
              // fourth beat - BPS
              ctrl_pkt_bps  <= axis_tdata_in[4:0];
              vid_ctrln     <= 1'b1; // next expect video packet
              vid_pkt_beat  <= 3'b000;
              // check for tlast
              if (axis_tlast_in != 1'b1) begin
                ctrl_sync_error <= ctrl_sync_error + 1;
                // control packet error so likely best to stay looking for control packets
                vid_ctrln       <= 1'b0;
              end
            end
          endcase
        end
      end
    end
  end
end

// count the number of valid output beats
always_ff @(posedge axis_aclk) begin
  if (axis_areset) begin
    valid_out_count <= 1;
    latched_valid_out <= 1;
  end else begin
    if (axis_tvalid_out && axis_tready_out) begin
      valid_out_count <= valid_out_count + 1;
      if (axis_tlast_out == 1'b1) begin
        latched_valid_out <= valid_out_count;
        valid_out_count <= 1;
      end
    end
  end
end

endmodule