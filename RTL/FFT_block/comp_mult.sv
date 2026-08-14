// =====================================================================
// Complex Multiplier Module
// =====================================================================
// Description:
//   Multiplies the FFT stage output by the corresponding complex twiddle 
//   factor using a lookup table with precalculated values. The module 
//   computes all four cross-products (rr, ii, ri, ir), combines them to 
//   produce real and imaginary results, and rounds to the nearest integer 
//   matching MATLAB's fixed-point behavior. Fractional bit-widths are 
//   predetermined per stage from MATLAB instrumentation analysis to prevent overflow.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================
`timescale 1ns / 1ps

module complex_multiplier #(
    parameter STAGE = 1
)(
    input  wire [3:0]  idx,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    // Fractional bit-widths for input signals (real and imaginary parts)
    localparam FL_IN_R = (STAGE == 1) ? 12 : 11;
    localparam FL_IN_I = (STAGE == 1) ? 12 : 11;

    // Fractional bit-widths for twiddle factors (real and imaginary parts)
    localparam FL_TW_R = (STAGE == 1) ? 14 :
                         (STAGE == 2) ? 14 :
                         (STAGE == 3) ? 0 : 0;
                         
    localparam FL_TW_I = (STAGE == 1) ? 15 :
                         (STAGE == 2) ? 15 :
                         (STAGE == 3) ? 0  : 0;

    // Fractional bit-widths for intermediate multiplication products
    localparam FL_OUT_RXR = (STAGE == 1) ? 12 : 11;
    localparam FL_OUT_IXI = (STAGE == 1) ? 12 :
                            (STAGE == 2) ? 11 :
                            (STAGE == 3) ? 11 : 0;
                            
    localparam FL_OUT_RXI = (STAGE == 1) ? 12 :
                            (STAGE == 2) ? 11 :
                            (STAGE == 3) ? 11 : 0;
    localparam FL_OUT_IXR = (STAGE == 1) ? 12 : 11;
    
    // Fractional bit-widths for final addition/subtraction results 
    localparam FL_OUT_ADD_R = (STAGE == 1) ? 12 : 11;
    localparam FL_OUT_ADD_I = (STAGE == 1) ? 12 : 11;

    // Calculate binary shifts to align intermediate products to final output precision
    // Shift formula: FL_IN + FL_TW - FL_OUTPUT 
    localparam SHIFT_RXR = (FL_IN_R + FL_TW_R) - FL_OUT_ADD_R;
    localparam SHIFT_II  = (FL_IN_I + FL_TW_I) - FL_OUT_ADD_R;
    
    localparam SHIFT_RI  = (FL_IN_R + FL_TW_I) - FL_OUT_ADD_I;
    localparam SHIFT_IR  = (FL_IN_I + FL_TW_R) - FL_OUT_ADD_I;

    reg signed [15:0] tw_r, tw_i;
    
    // Look-up table containing precomputed twiddle factors for each FFT stage
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

    // Extract real and imaginary components from packed input
    wire signed [15:0] d_r = data_in[31:16];
    wire signed [15:0] d_i = data_in[15:0];

    // Compute all four cross-products: real×real, imag×imag, real×imag, imag×real
    wire signed [31:0] rr = d_r * tw_r;
    wire signed [31:0] ii = d_i * tw_i;
    wire signed [31:0] ri = d_r * tw_i;
    wire signed [31:0] ir = d_i * tw_r;


    // -----------------------------------------------------------------------
    // Purpose:  Performs arithmetic right-shift with round-to-nearest behavior.
    //           Adds half-ULP bias before shifting to match MATLAB's rounding.
    // Inputs:   val   - 32-bit signed value to round and shift
    //           shift - Number of bits to shift right
    // Returns:  16-bit signed result (truncated to fit output width)
    // -----------------------------------------------------------------------
    function automatic signed [15:0] round_shift(input signed [31:0] val, input integer shift);
        reg signed [31:0] biased;
        reg signed [31:0] rounded;
        begin
            
            biased  = val + (32'sd1 <<< (shift - 1));  
            rounded = biased >>> shift;
            round_shift = rounded[15:0];
        end
    endfunction

    // Align products to target fractional precision using round-to-nearest method
    wire signed [15:0] rr_shifted = round_shift(rr, SHIFT_RXR);
    wire signed [15:0] ii_shifted = round_shift(ii, SHIFT_II);
    wire signed [15:0] ri_shifted = round_shift(ri, SHIFT_RI);
    wire signed [15:0] ir_shifted = round_shift(ir, SHIFT_IR);

    // Compute real and imaginary parts: re = (rr - ii), im = (ri + ir)
    // Note: Saturating behavior matches MATLAB fi object at each stage
    wire signed [16:0] sum_re = rr_shifted - ii_shifted;
    wire signed [16:0] sum_im = ri_shifted + ir_shifted;

    assign data_out[31:16] = sum_re;
    assign data_out[15:0]  = sum_im;

endmodule
