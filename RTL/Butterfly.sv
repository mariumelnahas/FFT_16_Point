// =============================================================================
// Module      : butterfly
// Description : Radix-2 FFT "butterfly" add/sub stage (fully combinational).
//               Two complex inputs (top, bot) and two complex outputs
//               (SUM = top+bot, DIFF = top-bot), each packed as
//                 [MSBs] = signed real part
//                 [LSBs] = signed imaginary part
//
//               Only ONE parameter is exposed: STAGE (1, 2, 3, or 4), which
//               selects which butterfly stage of the 16-point SDF pipeline
//               this instance implements. All port bit widths and Q-format
//               (integer/fractional split) local parameters are derived
//               from STAGE, using the exact fixed-point formats defined in
//               fft_16pt_types.m (the 'FxPt' case):
//
//                 Stage | top (sr_N)   | bot (input)          | sum/diff out
//                 ------+--------------+----------------------+---------------
//                   1   | sr1: (16,12) | in:  (16,13)         | (16,12) re/im
//                   2   | sr2: (16,12) | s1_mult_add: (16,12) | (16,11) re/im
//                   3   | sr3: (16,11) | s2_mult_add: (16,11) | (16,11) re/im
//                   4   | sr4: (16,11) | s3_mult_add: (16,11) | re:(16,10)
//                       |              |                      | im:(16,11)
//
//               (WordLength, WL) is 16 bits for every signal in the design,
//               so component/port widths never change -- only the fraction-
//               length (and therefore the implied integer-length) changes
//               per stage. Stage 4 is the only stage where the real and
//               imaginary fraction lengths of the outputs differ.
//
//               The add/sub arithmetic itself is Q-format agnostic (plain
//               two's-complement add/sub); the derived INT/FRAC localparams
//               below exist purely to document/verify the fixed-point
//               interpretation of each port for this stage, matching the
//               types table.
//
//               Outputs:
//                 sum_out  = top + bot   (top path in the diagram, "+" adder)
//                 diff_out = top - bot   (bottom path in the diagram, "-" adder)
// =============================================================================

module butterfly #(
    parameter integer STAGE = 1   // FFT stage: 1, 2, 3, or 4
)(
    // Packed complex inputs: {real[WIDTH-1:0], imag[WIDTH-1:0]}
    input  wire signed [2*WIDTH-1:0] top_in,
    input  wire signed [2*WIDTH-1:0] bot_in,

    // Packed complex outputs
    output wire signed [2*WIDTH-1:0] sum_out,    // top + bot
    output wire signed [2*WIDTH-1:0] diff_out,   // top - bot

);

    localparam integer WIDTH = 16;  // Word length of every signal in the design (fixed at 16)
    
    // -------------------------------------------------------------------
    // Fraction-length local parameters, per stage, sourced from
    // fft_16pt_types.m ('FxPt' case). Integer length is derived as
    // WIDTH - FRAC (WordLength is fixed at 16 for every signal).
    // -------------------------------------------------------------------
    localparam integer TOP_FRAC     = (STAGE == 1) ? 12 :
                                       (STAGE == 2) ? 12 :
                                       (STAGE == 3) ? 11 : 11;             

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

    // Guard bit for overflow detection during add/sub (word length is the
    // same, WIDTH, for top and bot in every stage, per the table above).
    localparam integer EXT_W = WIDTH + 1;

    // -------------------------------------------------------------------
    // Unpack inputs into signed real/imag components
    // -------------------------------------------------------------------
    wire signed [WIDTH-1:0] top_re = top_in[2*WIDTH-1:WIDTH];
    wire signed [WIDTH-1:0] top_im = top_in[WIDTH-1:0];
    wire signed [WIDTH-1:0] bot_re = bot_in[2*WIDTH-1:WIDTH];
    wire signed [WIDTH-1:0] bot_im = bot_in[WIDTH-1:0];

    // -------------------------------------------------------------------
    // Guard-bit-wide sums/differences, computed before saturating down to
    // the output width.
    // -------------------------------------------------------------------
    wire signed [EXT_W-1:0] sum_re_ext  = {top_re[WIDTH-1], top_re} + {bot_re[WIDTH-1], bot_re};
    wire signed [EXT_W-1:0] sum_im_ext  = {top_im[WIDTH-1], top_im} + {bot_im[WIDTH-1], bot_im};
    wire signed [EXT_W-1:0] diff_re_ext = {top_re[WIDTH-1], top_re} - {bot_re[WIDTH-1], bot_re};
    wire signed [EXT_W-1:0] diff_im_ext = {top_im[WIDTH-1], top_im} - {bot_im[WIDTH-1], bot_im};

    // -------------------------------------------------------------------
    // Saturate the (WIDTH+1)-bit result back into WIDTH bits, flagging
    // overflow.
    // -------------------------------------------------------------------
    function automatic [WIDTH:0] saturate;
        input signed [EXT_W-1:0] val_ext;
        reg signed [WIDTH-1:0]   max_val;
        reg signed [WIDTH-1:0]   min_val;
        begin
            max_val = {1'b0, {(WIDTH-1){1'b1}}};   // 0111...1
            min_val = {1'b1, {(WIDTH-1){1'b0}}};   // 1000...0
            if (val_ext > $signed({1'b0, max_val}))
                saturate = {1'b1, max_val};        // {ovf_flag, sat_value}
            else if (val_ext < $signed({1'b1, min_val}))
                saturate = {1'b1, min_val};
            else
                saturate = {1'b0, val_ext[WIDTH-1:0]};
        end
    endfunction

    wire [WIDTH:0] sum_re_sat  = saturate(sum_re_ext);
    wire [WIDTH:0] sum_im_sat  = saturate(sum_im_ext);
    wire [WIDTH:0] diff_re_sat = saturate(diff_re_ext);
    wire [WIDTH:0] diff_im_sat = saturate(diff_im_ext);

    assign sum_out  = {sum_re_sat[WIDTH-1:0],  sum_im_sat[WIDTH-1:0]};
    assign diff_out = {diff_re_sat[WIDTH-1:0], diff_im_sat[WIDTH-1:0]};
    
endmodule