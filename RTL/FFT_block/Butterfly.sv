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
   
    // -------------------------------------------------------------------
    // Fraction-length local parameters, per stage, sourced from
    // fft_16pt_types.m ('FxPt' case). Integer length is derived as
    // WIDTH - FRAC (WordLength is fixed at 16 for every signal).
    // -------------------------------------------------------------------
    localparam integer TOP_FRAC     = (STAGE == 1) ? 12 :
                                      (STAGE == 2) ? 12 :
                                      (STAGE == 3) ? 11 : 11;              // srN_r / srN_i

    localparam integer BOT_FRAC     = (STAGE == 1) ? 13 :
                                      (STAGE == 2) ? 12 :
                                      (STAGE == 3) ? 11 : 11;              // in / stageN_mult_add_out

    localparam integer SUM_RE_FRAC  = (STAGE == 1) ? 12 :
                                      (STAGE == 2) ? 11 :
                                      (STAGE == 3) ? 11 : 10;              // stageN_add_out_r
    localparam integer SUM_IM_FRAC  = (STAGE == 1) ? 12 :
                                      (STAGE == 2) ? 11 :
                                      (STAGE == 3) ? 11 : 11;              // stageN_add_out_i

    localparam integer DIFF_RE_FRAC = SUM_RE_FRAC;                          // stageN_sub_out_r (mirrors add_out_r)
    localparam integer DIFF_IM_FRAC = SUM_IM_FRAC;                          // stageN_sub_out_i (mirrors add_out_i)

    localparam integer TOP_INT      = WIDTH - TOP_FRAC;
    localparam integer BOT_INT      = WIDTH - BOT_FRAC;
    localparam integer SUM_RE_INT   = WIDTH - SUM_RE_FRAC;
    localparam integer SUM_IM_INT   = WIDTH - SUM_IM_FRAC;
    localparam integer DIFF_RE_INT  = WIDTH - DIFF_RE_FRAC;
    localparam integer DIFF_IM_INT  = WIDTH - DIFF_IM_FRAC;

    // -------------------------------------------------------------------
    // Unpack top_in / bot_in into real and imaginary halves.
    // Convention (per the port comment): upper WIDTH bits = real,
    // lower WIDTH bits = imag.
    // -------------------------------------------------------------------
    wire signed [WIDTH-1:0] top_r = top_in[2*WIDTH-1:WIDTH];
    wire signed [WIDTH-1:0] top_i = top_in[WIDTH-1:0];
    wire signed [WIDTH-1:0] bot_r = bot_in[2*WIDTH-1:WIDTH];
    wire signed [WIDTH-1:0] bot_i = bot_in[WIDTH-1:0];

    wire signed [WIDTH-1:0] sum_r, sum_i, diff_r, diff_i;

    // -------------------------------------------------------------------
    // Real path
    // -------------------------------------------------------------------
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(SUM_RE_FRAC), .IS_SUB(0))
        u_sum_r  (.a(top_r), .b(bot_r), .out(sum_r));
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(DIFF_RE_FRAC), .IS_SUB(1))
        u_diff_r (.a(top_r), .b(bot_r), .out(diff_r));

    // -------------------------------------------------------------------
    // Imag path
    // -------------------------------------------------------------------
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(SUM_IM_FRAC), .IS_SUB(0))
        u_sum_i  (.a(top_i), .b(bot_i), .out(sum_i));
    fxpt_addsub #(.WIDTH(WIDTH), .A_FRAC(TOP_FRAC), .B_FRAC(BOT_FRAC), .OUT_FRAC(DIFF_IM_FRAC), .IS_SUB(1))
        u_diff_i (.a(top_i), .b(bot_i), .out(diff_i));

    // -------------------------------------------------------------------
    // Repack outputs
    // -------------------------------------------------------------------
    assign sum_out  = {sum_r,  sum_i};
    assign diff_out = {diff_r, diff_i};


endmodule
