`timescale 1ns / 1ps
//=============================================================================
// fft_16pt_top
//
// 16-point Radix-2 Single-path Delay Feedback (R2SDF) pipelined FFT,
// Decimation-In-Frequency, 4 cascaded butterfly stages.
//
// Data convention: there is a single 32-bit input port and a single
// 32-bit output port, each carrying one packed complex sample as
// {real[31:16], imag[15:0]} - the same convention already used
// internally by butterfly / shift_register / complex_multiplier. The
// wrapper never splits real/imag itself; that unpacking happens only
// inside those sub-modules.
//
// Control: there is no separate reset pin. A single control input, BS
// (Block Select), is driven high by the user whenever data is being
// shifted in or read out. While BS is low the whole system is held in
// reset - BS is inverted and fed as the active-high async reset into
// every sequential sub-module (clk_div x4, SR x4, and the twiddle
// counter). When BS returns high, reset releases and everything starts
// counting/shifting from zero again.
//
// Twiddle index: the counter module's 4-bit count output is wired
// directly into every complex_multiplier's idx port (which is 3 bits
// wide, so only the lower 3 bits of count are used - each stage's LUT
// internally masks down further to whatever modulus it needs).
//
// Per-stage datapath (matches the hand-drawn 3-stage diagram, extended
// to 4 stages):
//
//   stage_in ---------------------------> bot_in  \
//                                                   >-- butterfly --> sum_out, diff_out
//              sr_q -------------------> top_in    /
//                ^                                          |            |
//                |                                       (sum)        (diff)
//                |                                          |            |
//                |                            b=sum,a=sr_q  |  b=stage_in,a=diff
//                |                          TOP MUX (sel=~seln)   BOTTOM MUX (sel=seln)
//                |                                  |                    |
//                |                            top_mux_out          bot_mux_out
//                |                                  |                    |
//                |                         complex_multiplier      shift_register (SR)
//                |                                  |                    |
//                +----------------------------------|--------------------+  (sr_q feeds back)
//                                                    v
//                                          stage_in of next stage
//
// Clock dividers: clk feeds the STAGE-4 divider first; each divider's
// output feeds the next (slower) stage's divider, producing select
// signals with periods 2,4,8,16 for stages 4,3,2,1 respectively -
// matching bitget(clk,1..4) in the MATLAB golden model.
//=============================================================================
module fft_16pt_top #(
    parameter integer WIDTH = 16
)(
    input  wire                      clk,
    input  wire                      BS,        // Block Select: high while shifting data in/out

    // Single packed complex sample: {real[31:16], imag[15:0]}
    input  wire [2*WIDTH-1:0]        in_sample,

    output wire [2*WIDTH-1:0]        out_sample
);

    //-------------------------------------------------------------------
    // BS is inverted to form the system reset: while BS=0 every
    // sequential element below is held in async reset; while BS=1,
    // reset is released and the pipeline runs on the raw clk.
    //-------------------------------------------------------------------
    wire sys_rst = ~BS;

    //-------------------------------------------------------------------
    // Twiddle index counter (counter.sv). count[3:0] free-runs while
    // BS=1 and resets to 0 whenever BS=0. Its output feeds every
    // complex_multiplier's idx port directly.
    //-------------------------------------------------------------------
    wire [3:0] tw_count;

    counter u_tw_counter (
        .clk  (clk),
        .rst  (sys_rst),
        .en   (1'b1),
        .count(tw_count)
    );

    //-------------------------------------------------------------------
    // Clock dividers: clk -> div4 -> div3 -> div2 -> div1, all held in
    // reset together with everything else while BS=0.
    //-------------------------------------------------------------------
    wire sel4, sel3, sel2, sel1;

    clk_div u_clkdiv_4 (.clk_in(clk),  .rst(sys_rst), .clk_out(sel4));
    clk_div u_clkdiv_3 (.clk_in(sel4), .rst(sys_rst), .clk_out(sel3));
    clk_div u_clkdiv_2 (.clk_in(sel3), .rst(sys_rst), .clk_out(sel2));
    clk_div u_clkdiv_1 (.clk_in(sel2), .rst(sys_rst), .clk_out(sel1));

    //-------------------------------------------------------------------
    // Per-stage packed 32-bit busses: {real[15:0], imag[15:0]}
    //-------------------------------------------------------------------
    wire [2*WIDTH-1:0] stage_in_1,   stage_in_2,   stage_in_3,   stage_in_4;
    wire [2*WIDTH-1:0] sr_q_1,       sr_q_2,       sr_q_3,       sr_q_4;
    wire [2*WIDTH-1:0] bfly_sum_1,   bfly_sum_2,   bfly_sum_3,   bfly_sum_4;
    wire [2*WIDTH-1:0] bfly_diff_1,  bfly_diff_2,  bfly_diff_3,  bfly_diff_4;
    wire [2*WIDTH-1:0] top_mux_out_1,top_mux_out_2,top_mux_out_3,top_mux_out_4;
    wire [2*WIDTH-1:0] bot_mux_out_1,bot_mux_out_2,bot_mux_out_3,bot_mux_out_4;
    wire [2*WIDTH-1:0] mult_out_1,   mult_out_2,   mult_out_3;

    // Stage-1 input comes straight from the top-level serial input port.
    // The port is already packed {real[31:16], imag[15:0]} - the wrapper
    // never splits it; real/imag unpacking happens inside butterfly /
    // complex_multiplier only.
    assign stage_in_1 = in_sample;
    // Stage n (n>1) input is the previous stage's twiddle-multiplier output
    assign stage_in_2 = mult_out_1;
    assign stage_in_3 = mult_out_2;
    assign stage_in_4 = mult_out_3;
    // Stage 4's output (via its top mux, no multiplier) is the FFT
    // wrapper's output - see out_sample assignment at the bottom.

    //=====================================================================
    // STAGE 1  (SR delay = 8)
    //=====================================================================
    butterfly #(.STAGE(1), .WIDTH(WIDTH)) u_bfly_1 (
        .top_in  (sr_q_1),
        .bot_in  (stage_in_1),
        .sum_out (bfly_sum_1),
        .diff_out(bfly_diff_1)
    );

    // Bottom mux: b(sel=1)=stage input, a(sel=0)=butterfly diff -> feeds SR
    mux_2_1_32bit u_botmux_1 (.a(bfly_diff_1), .b(stage_in_1), .sel(sel1),  .y(bot_mux_out_1));

    // Top mux: b(sel=1)=butterfly sum, a(sel=0)=SR output -> feeds multiplier
    mux_2_1_32bit u_topmux_1 (.a(sr_q_1), .b(bfly_sum_1), .sel(~sel1), .y(top_mux_out_1));

    shift_register #(.STAGE(1)) u_sr_1 (
        .clk(clk), .reset(sys_rst), .d(bot_mux_out_1), .q(sr_q_1)
    );

    complex_multiplier #(.STAGE(1)) u_mult_1 (
        .idx(tw_count[3:0]), .data_in(top_mux_out_1), .data_out(mult_out_1)
    );

    //=====================================================================
    // STAGE 2  (SR delay = 4)
    //=====================================================================
    butterfly #(.STAGE(2), .WIDTH(WIDTH)) u_bfly_2 (
        .top_in  (sr_q_2),
        .bot_in  (stage_in_2),
        .sum_out (bfly_sum_2),
        .diff_out(bfly_diff_2)
    );

    mux_2_1_32bit u_botmux_2 (.a(bfly_diff_2), .b(stage_in_2), .sel(sel2),  .y(bot_mux_out_2));

    mux_2_1_32bit u_topmux_2 (.a(sr_q_2), .b(bfly_sum_2), .sel(~sel2), .y(top_mux_out_2));

    shift_register #(.STAGE(2)) u_sr_2 (
        .clk(clk), .reset(sys_rst), .d(bot_mux_out_2), .q(sr_q_2)
    );

    complex_multiplier #(.STAGE(2)) u_mult_2 (
        .idx(tw_count[3:0]), .data_in(top_mux_out_2), .data_out(mult_out_2)
    );

    //=====================================================================
    // STAGE 3  (SR delay = 2)
    //=====================================================================
    butterfly #(.STAGE(3), .WIDTH(WIDTH)) u_bfly_3 (
        .top_in  (sr_q_3),
        .bot_in  (stage_in_3),
        .sum_out (bfly_sum_3),
        .diff_out(bfly_diff_3)
    );

    mux_2_1_32bit u_botmux_3 (.a(bfly_diff_3), .b(stage_in_3), .sel(sel3),  .y(bot_mux_out_3));

    mux_2_1_32bit u_topmux_3 (.a(sr_q_3), .b(bfly_sum_3), .sel(~sel3), .y(top_mux_out_3));

    shift_register #(.STAGE(3)) u_sr_3 (
        .clk(clk), .reset(sys_rst), .d(bot_mux_out_3), .q(sr_q_3)
    );

    complex_multiplier #(.STAGE(3)) u_mult_3 (
        .idx(tw_count[3:0]), .data_in(top_mux_out_3), .data_out(mult_out_3)
    );

    //=====================================================================
    // STAGE 4  (SR delay = 1)
    //=====================================================================
    butterfly #(.STAGE(4), .WIDTH(WIDTH)) u_bfly_4 (
        .top_in  (sr_q_4),
        .bot_in  (stage_in_4),
        .sum_out (bfly_sum_4),
        .diff_out(bfly_diff_4)
    );

    mux_2_1_32bit u_botmux_4 (.a(bfly_diff_4), .b(stage_in_4), .sel(sel4),  .y(bot_mux_out_4));

    mux_2_1_32bit u_topmux_4 (.a(sr_q_4), .b(bfly_sum_4), .sel(~sel4), .y(top_mux_out_4));

    shift_register #(.STAGE(4)) u_sr_4 (
        .clk(clk), .reset(sys_rst), .d(bot_mux_out_4), .q(sr_q_4)
    );

    // Stage 4's twiddle is always exactly 1+0j (final DIF stage never
    // needs a rotation), so no complex_multiplier is instantiated here -
    // the top mux output feeds the FFT wrapper output directly.
    assign out_sample = top_mux_out_4;

endmodule