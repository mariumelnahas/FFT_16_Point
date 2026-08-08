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