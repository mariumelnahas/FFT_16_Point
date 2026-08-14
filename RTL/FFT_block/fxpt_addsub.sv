// =====================================================================
// Fixed-Point Adder/Subtractor Module
// =====================================================================
// Description:
//   Performs fixed-point arithmetic (addition or subtraction) on operands
//   with independent fractional bit-widths. Internally extends operands
//   to 2*WIDTH to align fractional points, computes the result, and rescales
//   to WIDTH with round-to-nearest behavior. Used by the Butterfly module
//   for upper-path additions and lower-path subtractions.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================
module fxpt_addsub #(
    parameter integer WIDTH    = 16,
    parameter integer A_FRAC   = 12,
    parameter integer B_FRAC   = 12,
    parameter integer OUT_FRAC = 12,
    parameter         IS_SUB   = 0     // Operation: 0 = addition (a+b), 1 = subtraction (a-b)
)(
    input  wire signed [WIDTH-1:0] a,
    input  wire signed [WIDTH-1:0] b,
    output wire signed [WIDTH-1:0] out
);

    localparam integer A_INT     = WIDTH - A_FRAC;
    localparam integer B_INT     = WIDTH - B_FRAC;
    localparam integer EXT_WIDTH = 2*WIDTH;

    // Extend operands to 2*WIDTH bits to align fractional points.
    // This allows arithmetic on operands with different fractional lengths.
    // After operation: both integer and fractional parts occupy WIDTH bits.
    wire signed [EXT_WIDTH-1:0] a_ext;
    wire signed [EXT_WIDTH-1:0] b_ext;
    wire signed [EXT_WIDTH-1:0] sum_ext;

    // Sign-extend integer part; zero-pad fractional part
    // a_ext format: [A_FRAC sign-bits | a(WIDTH-1:0) | A_INT zero-bits]
    assign a_ext = {{A_FRAC{a[WIDTH-1]}}, a, {A_INT{1'b0}}};  
    assign b_ext = {{B_FRAC{b[WIDTH-1]}}, b, {B_INT{1'b0}}};

    assign sum_ext = IS_SUB ? (a_ext - b_ext) : (a_ext + b_ext);

    // Round and rescale result from 2*WIDTH to WIDTH with round-to-nearest 
    localparam integer SHIFT = WIDTH - OUT_FRAC;  

    wire signed [EXT_WIDTH-1:0] round_bias = {{(EXT_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT-1);
    wire signed [EXT_WIDTH-1:0] biased      = sum_ext + round_bias;
    wire signed [EXT_WIDTH-1:0] shifted     = biased >>> SHIFT;
    assign out = shifted[WIDTH-1:0];

endmodule
