/*
module fxpt_addsub #(
    parameter integer WIDTH    = 16,
    parameter integer A_FRAC   = 12,
    parameter integer B_FRAC   = 12,
    parameter integer OUT_FRAC = 12,
    parameter         IS_SUB   = 0     // 0: result = a+b, 1: result = a-b
)(
    input  wire signed [WIDTH-1:0] a,
    input  wire signed [WIDTH-1:0] b,
    output wire signed [WIDTH-1:0] out
);


    localparam integer A_INT   = WIDTH - A_FRAC;
    localparam integer B_INT   = WIDTH - B_FRAC;
    localparam integer OUT_INT = WIDTH - OUT_FRAC;

    localparam integer EXT_WIDTH = 2*WIDTH;

    wire signed [EXT_WIDTH-1:0] a_ext;
    wire signed [EXT_WIDTH-1:0] b_ext;
    wire signed [EXT_WIDTH-1:0] out_ext;

    assign a_ext = {{(WIDTH - A_INT){a[WIDTH-1]}}, a, {(WIDTH - A_FRAC){1'b0}}};  // extend to EXT_WIDTH, shift left by A_FRAC
    assign b_ext = {{(WIDTH - B_INT){b[WIDTH-1]}}, b, {(WIDTH - B_FRAC){1'b0}}};  // extend to EXT_WIDTH, shift left by B_FRAC

    assign out_ext = IS_SUB ? (a_ext - b_ext) : (a_ext + b_ext);
    assign out     = out_ext[EXT_WIDTH-OUT_FRAC-1 : WIDTH-OUT_FRAC]; 

endmodule
*/

module fxpt_addsub #(
    parameter integer WIDTH    = 16,
    parameter integer A_FRAC   = 12,
    parameter integer B_FRAC   = 12,
    parameter integer OUT_FRAC = 12,
    parameter         IS_SUB   = 0     // 0: result = a+b, 1: result = a-b
)(
    input  wire signed [WIDTH-1:0] a,
    input  wire signed [WIDTH-1:0] b,
    output wire signed [WIDTH-1:0] out
);

    localparam integer A_INT     = WIDTH - A_FRAC;
    localparam integer B_INT     = WIDTH - B_FRAC;
    localparam integer EXT_WIDTH = 2*WIDTH;

    // Both operands are widened into a common EXT_WIDTH-bit field with
    // exactly WIDTH fractional bits (A_INT+A_FRAC = WIDTH always, same
    // for B), so a plain add/sub in this domain is already correctly
    // aligned -- no separate "shift to max(A_FRAC,B_FRAC)" step needed.
    wire signed [EXT_WIDTH-1:0] a_ext;
    wire signed [EXT_WIDTH-1:0] b_ext;
    wire signed [EXT_WIDTH-1:0] sum_ext;

    assign a_ext = {{A_FRAC{a[WIDTH-1]}}, a, {A_INT{1'b0}}};  // sign-extend, shift left by A_INT
    assign b_ext = {{B_FRAC{b[WIDTH-1]}}, b, {B_INT{1'b0}}};  // sign-extend, shift left by B_INT

    assign sum_ext = IS_SUB ? (a_ext - b_ext) : (a_ext + b_ext);

    // -------------------------------------------------------------------
    // Rescale from WIDTH fractional bits down to OUT_FRAC fractional
    // bits with round-to-nearest, matching MATLAB fi's default cast()
    // behavior instead of a bare truncating bit-slice.
    //
    // Round-half-up: bias by half an output ULP before the arithmetic
    // shift-out. This matches MATLAB's round-to-nearest everywhere
    // except ties (exact .5) on a negative operand, where MATLAB's
    // "round half away from zero" rounds one step further from zero
    // than round-half-up does. That tie case is rare enough in this
    // datapath not to warrant the extra sign-dependent logic; flag if
    // bit-exact tie behavior ever matters.
    // -------------------------------------------------------------------
    localparam integer SHIFT = WIDTH - OUT_FRAC;   // frac bits to drop; >=0 for every stage config in this design

    generate
        if (SHIFT > 0) begin : g_round
            wire signed [EXT_WIDTH-1:0] round_bias = {{(EXT_WIDTH-1){1'b0}}, 1'b1} <<< (SHIFT-1);
            wire signed [EXT_WIDTH-1:0] biased      = sum_ext + round_bias;
            wire signed [EXT_WIDTH-1:0] shifted     = biased >>> SHIFT;
            assign out = shifted[WIDTH-1:0];
        end else begin : g_noshift
            // OUT_FRAC >= WIDTH: nothing to drop, just left-shift (exact, no rounding needed).
            wire signed [EXT_WIDTH-1:0] shifted = sum_ext <<< (-SHIFT);
            assign out = shifted[WIDTH-1:0];
        end
    endgenerate

endmodule