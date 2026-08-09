`timescale 1ns / 1ps

module complex_multiplier #(
    parameter STAGE = 1
)(
    input  wire [3:0]  idx,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    // INPUT FRACTIONAL LENGTHS
    localparam FL_IN_R = (STAGE == 1) ? 12 : 11;
    localparam FL_IN_I = (STAGE == 1) ? 12 : 11;

    // TWIDDLE FRACTIONAL LENGTHS
    localparam FL_TW_R = (STAGE == 1) ? 14 :
                         (STAGE == 2) ? 14 :
                         (STAGE == 3) ? 0 : 0;
                         
    localparam FL_TW_I = (STAGE == 1) ? 15 :
                         (STAGE == 2) ? 15 :
                         (STAGE == 3) ? 0  : 0;

    // MULTIPLICATION FRACTIONAL LENGTHS
    localparam FL_OUT_RXR = (STAGE == 1) ? 12 : 11;
    localparam FL_OUT_IXI = (STAGE == 1) ? 12 :
                            (STAGE == 2) ? 11 :
                            (STAGE == 3) ? 11 : 0;
                            
    localparam FL_OUT_RXI = (STAGE == 1) ? 12 :
                            (STAGE == 2) ? 11 :
                            (STAGE == 3) ? 11 : 0;
    localparam FL_OUT_IXR = (STAGE == 1) ? 12 : 11;
    
    // OUTPUT FRACTIONAL LENGTHS 
    localparam FL_OUT_ADD_R = (STAGE == 1) ? 12 : 11;
    localparam FL_OUT_ADD_I = (STAGE == 1) ? 12 : 11;

    // SHIFT CALCULATIONS ( Shift = FL_IN + FL_TW - FL_OUTPUT )
    // We align the partial products directly to the final ADD/SUB target FL 
    localparam SHIFT_RXR = (FL_IN_R + FL_TW_R) - FL_OUT_ADD_R;
    localparam SHIFT_II  = (FL_IN_I + FL_TW_I) - FL_OUT_ADD_R;
    
    localparam SHIFT_RI  = (FL_IN_R + FL_TW_I) - FL_OUT_ADD_I;
    localparam SHIFT_IR  = (FL_IN_I + FL_TW_R) - FL_OUT_ADD_I;

    reg signed [15:0] tw_r, tw_i;
    
    // TWIDDLE FACTOR LUT
    always @(*) begin
        case (STAGE)
            1: begin
                case(idx[3:0])
                    4'd0: begin tw_r =  16384; tw_i =      0; end //0
                    4'd1: begin tw_r =  15137; tw_i = -12540; end //1
                    4'd2: begin tw_r =  11585; tw_i = -23170; end //2
                    4'd3: begin tw_r =   6270; tw_i = -30274; end //3
                    4'd4: begin tw_r =      0; tw_i = -32768; end //4
                    4'd5: begin tw_r =  -6270; tw_i = -30274; end //5
                    4'd6: begin tw_r = -11585; tw_i = -23170; end //6
                    4'd7: begin tw_r = -15137; tw_i = -12540; end //7
                    default: begin tw_r = 16384; tw_i = 0; end
                endcase
            end
            2: begin
                case(idx[2:0])
                    3'd0: begin tw_r =  16384; tw_i =      0; end //0
                    3'd1: begin tw_r =  11585; tw_i = -23170; end //1
                    3'd2: begin tw_r =      0; tw_i = -32768; end //2
                    3'd3: begin tw_r = -11585; tw_i = -23170; end //3
                    default: begin tw_r = 16384; tw_i = 0; end
                endcase
            end
            3: begin
                case(idx[1:0])
                    2'd0: begin tw_r =  1; tw_i =  0; end //0
                    2'd1: begin tw_r =  0; tw_i = -1; end //1
                    default: begin tw_r = 1; tw_i = 0; end
                endcase
            end

            default: begin
                tw_r = 1; tw_i = 0; // Last Stage
            end
        endcase
    end

    // COMPLEX MULTIPLIER LOGIC
    wire signed [15:0] d_r = data_in[31:16];
    wire signed [15:0] d_i = data_in[15:0];

    // Multiplication
    wire signed [31:0] rr = d_r * tw_r;
    wire signed [31:0] ii = d_i * tw_i;
    wire signed [31:0] ri = d_r * tw_i;
    wire signed [31:0] ir = d_i * tw_r;

    // Fractional Alignment
    wire signed [15:0] rr_shifted = rr >>> SHIFT_RXR;
    wire signed [15:0] ii_shifted = ii >>> SHIFT_II;
    
    wire signed [15:0] ri_shifted = ri >>> SHIFT_RI;
    wire signed [15:0] ir_shifted = ir >>> SHIFT_IR;

    // Final Addition / Subtraction
    assign data_out[31:16] = rr_shifted - ii_shifted;
    assign data_out[15:0]  = ri_shifted + ir_shifted;

endmodule