// =====================================================================
// Butterfly Module
// =====================================================================
// Description:
//   Implements the core FFT butterfly operation by instantiating two
//   fixed-point adder/subtractor modules for the upper and lower paths.
//   The fractional bit-width is dynamically selected per FFT stage based
//   on MATLAB instrumentation analysis to maintain optimal numerical precision.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================
`timescale 1ns / 1ps

module butterfly #(
    parameter integer STAGE = 1,   // FFT stage: 1, 2, 3, or 4
    parameter integer WIDTH = 16
)(
    // Packed complex inputs: {real[WIDTH-1:0], imag[WIDTH-1:0]}
    input  wire signed [2*WIDTH-1:0] top_in,
    input  wire signed [2*WIDTH-1:0] bot_in,

    // Packed complex outputs
    output wire signed [2*WIDTH-1:0] sum_out,    // top + bot
    output wire signed [2*WIDTH-1:0] diff_out    // top - bot
);
   

    // Dynamically assign fractional bit-widths for inputs and outputs based on FFT stage.
    // These values are derived from MATLAB instrumentation to optimize numerical precision.
    localparam integer TOP_FRAC     = (STAGE == 1) ? 12 :
                                      (STAGE == 2) ? 12 :
                                      (STAGE == 3) ? 11 : 11;              

    localparam integer BOT_FRAC     = (STAGE == 1) ? 13 :
                                      (STAGE == 2) ? 12 :
                                      (STAGE == 3) ? 11 : 11;              

    localparam integer SUM_RE_FRAC  = (STAGE == 1) ? 12 :
                                      (STAGE == 2) ? 11 :
                                      (STAGE == 3) ? 11 : 10;              
    localparam integer SUM_IM_FRAC  = (STAGE == 1) ? 12 :
                                      (STAGE == 2) ? 11 :
                                      (STAGE == 3) ? 11 : 11;              

    localparam integer DIFF_RE_FRAC = SUM_RE_FRAC;                          
    localparam integer DIFF_IM_FRAC = SUM_IM_FRAC;                          

    localparam integer TOP_INT      = WIDTH - TOP_FRAC;
    localparam integer BOT_INT      = WIDTH - BOT_FRAC;
    localparam integer SUM_RE_INT   = WIDTH - SUM_RE_FRAC;
    localparam integer SUM_IM_INT   = WIDTH - SUM_IM_FRAC;
    localparam integer DIFF_RE_INT  = WIDTH - DIFF_RE_FRAC;
    localparam integer DIFF_IM_INT  = WIDTH - DIFF_IM_FRAC;


    // Extract real and imaginary components from packed complex inputs
    wire signed [WIDTH-1:0] top_r = top_in[2*WIDTH-1:WIDTH];
    wire signed [WIDTH-1:0] top_i = top_in[WIDTH-1:0];
    wire signed [WIDTH-1:0] bot_r = bot_in[2*WIDTH-1:WIDTH];
    wire signed [WIDTH-1:0] bot_i = bot_in[WIDTH-1:0];

    wire signed [WIDTH-1:0] sum_r, sum_i, diff_r, diff_i;

    // Real path: Compute sum and difference of real components
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(SUM_RE_FRAC), .IS_SUB(0))
        u_sum_r  (.a(top_r), .b(bot_r), .out(sum_r));
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(DIFF_RE_FRAC), .IS_SUB(1))
        u_diff_r (.a(top_r), .b(bot_r), .out(diff_r));

    // Imaginary path: Compute sum and difference of imaginary components
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(SUM_IM_FRAC), .IS_SUB(0))
        u_sum_i  (.a(top_i), .b(bot_i), .out(sum_i));
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(DIFF_IM_FRAC), .IS_SUB(1))
        u_diff_i (.a(top_i), .b(bot_i), .out(diff_i));


    // Repack real and imaginary components into complex output format
    assign sum_out  = {sum_r,  sum_i};
    assign diff_out = {diff_r, diff_i};


endmodule
