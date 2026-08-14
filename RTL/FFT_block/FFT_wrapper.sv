// =====================================================================
// FFT Wrapper Module (16-point SDF Architecture)
// =====================================================================
// Description:
//   Top-level wrapper for a 16-point Single Delay Feedback (SDF) FFT 
//   implementation. Integrates four pipelined stages, each containing 
//   a butterfly computation, shift register for data recirculation, and 
//   twiddle factor multiplication. Includes fractional bit-width alignments
//   at stage boundaries to prevent overflow while maintaining MATLAB-
//   matching numerical behavior. The counter generates multiplexer select 
//   signals synchronized across all stages.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================
`timescale 1ns / 1ps

module FFT_wrapper #(
    parameter integer WIDTH = 16
)(
    input  wire                      clk,
    input  wire                      BS,

    input  wire [2*WIDTH-1:0]        in_sample,
    output wire [2*WIDTH-1:0]        out_sample
);

    // System reset (active-high) from inverted bit-stream enable
    wire sys_rst = ~BS;

    // Generate twiddle factor select counter
    // Runs on inverted clock for proper synchronization
    wire [3:0] tw_count;
       counter #(
        .LENGTH(4)
    ) u_tw_counter (
        .clk  (~clk),
        .rst  (sys_rst),
        .en   (1'b1),
        .count(tw_count)
    );

    // Derive stage-specific mux select signals from counter bits
    // Each stage uses different counter bits for timing alignment
    wire sel4 = ~tw_count[0];
    wire sel3 = ~tw_count[1];
    wire sel2 = ~tw_count[2];
    wire sel1 = ~tw_count[3];

    wire [2*WIDTH-1:0] stage_in_1,   stage_in_2,   stage_in_3,   stage_in_4;
    wire [2*WIDTH-1:0] sr_q_1,       sr_q_2,       sr_q_3,       sr_q_4;
    wire [2*WIDTH-1:0] bfly_sum_1,   bfly_sum_2,   bfly_sum_3,   bfly_sum_4;
    wire [2*WIDTH-1:0] bfly_diff_1,  bfly_diff_2,  bfly_diff_3,  bfly_diff_4;
    wire [2*WIDTH-1:0] top_mux_out_1,top_mux_out_2,top_mux_out_3,top_mux_out_4;
    wire [2*WIDTH-1:0] bot_mux_out_1,bot_mux_out_2,bot_mux_out_3,bot_mux_out_4;
    wire [2*WIDTH-1:0] mult_out_1,   mult_out_2,   mult_out_3;

    assign stage_in_1 = in_sample;
    assign stage_in_2 = mult_out_1;
    assign stage_in_3 = mult_out_2;
    assign stage_in_4 = mult_out_3;
  

    // ========================================================================
    // STAGE 1: 8-point SDF (SR Delay = 8)
    // Input FL13 → Align to FL12 for SR and butterfly operations
    // ========================================================================
    // Fractional length adjustment: divide by 2 to convert FL13 → FL12
    wire [2*WIDTH-1:0] stage_in_1_algnd = { 
        (stage_in_1[31:16]), 
        (stage_in_1[15:0])
    };

    butterfly #(.STAGE(1), .WIDTH(WIDTH)) u_bfly_1 (
        .top_in  (sr_q_1),
        .bot_in  (stage_in_1),
        .sum_out (bfly_sum_1),
        .diff_out(bfly_diff_1)
    );

    mux_2_1_32bit u_botmux_1 (.a(bfly_diff_1), .b(stage_in_1_algnd), .sel(sel1),  .y(bot_mux_out_1));
    mux_2_1_32bit u_topmux_1 (.a(sr_q_1), .b(bfly_sum_1), .sel(~sel1), .y(top_mux_out_1));

    shift_register #(.STAGE(1)) u_sr_1 (.clk(clk), .reset(sys_rst), .d(bot_mux_out_1), .q(sr_q_1));
    complex_multiplier #(.STAGE(1)) u_mult_1 (.idx(tw_count), .data_in(top_mux_out_1), .data_out(mult_out_1));

    // ========================================================================
    // STAGE 2: 4-point SDF (SR Delay = 4)
    // Butterfly output FL11 → Align to FL12 for SR (left-shift 1)
    // SR output FL12 → Align to FL11 for multiplier (right-shift 1)
    // ========================================================================
    // Fractional length alignment: butterfly output FL11 → FL12 (left-shift 1)
    wire [2*WIDTH-1:0] bfly_diff_2_algnd = {
        $signed(bfly_diff_2[31:16]) <<< 1,
        $signed(bfly_diff_2[15:0])  <<< 1
    };
    // Fractional length alignment: SR output FL12 → FL11 (right-shift 1)
    wire [2*WIDTH-1:0] sr_q_2_algnd = {
        (sr_q_2[31:16]),
        (sr_q_2[15:0])
    };

    butterfly #(.STAGE(2), .WIDTH(WIDTH)) u_bfly_2 (
        .top_in  (sr_q_2),
        .bot_in  (stage_in_2),
        .sum_out (bfly_sum_2),
        .diff_out(bfly_diff_2)
    );

    mux_2_1_32bit u_botmux_2 (.a(bfly_diff_2_algnd), .b(stage_in_2), .sel(sel2),  .y(bot_mux_out_2));
    mux_2_1_32bit u_topmux_2 (.a(sr_q_2_algnd), .b(bfly_sum_2), .sel(~sel2), .y(top_mux_out_2));

    shift_register #(.STAGE(2)) u_sr_2 (.clk(clk), .reset(sys_rst), .d(bot_mux_out_2), .q(sr_q_2));
    complex_multiplier #(.STAGE(2)) u_mult_2 (.idx(tw_count), .data_in(top_mux_out_2), .data_out(mult_out_2));

    // ========================================================================
    // STAGE 3: 2-point SDF (SR Delay = 2)
    // All signals natively FL11. No fractional length alignment required.
    // ========================================================================
    butterfly #(.STAGE(3), .WIDTH(WIDTH)) u_bfly_3 (
        .top_in  (sr_q_3),
        .bot_in  (stage_in_3),
        .sum_out (bfly_sum_3),
        .diff_out(bfly_diff_3)
    );

    mux_2_1_32bit u_botmux_3 (.a(bfly_diff_3), .b(stage_in_3), .sel(sel3),  .y(bot_mux_out_3));
    mux_2_1_32bit u_topmux_3 (.a(sr_q_3), .b(bfly_sum_3), .sel(~sel3), .y(top_mux_out_3));

    shift_register #(.STAGE(3)) u_sr_3 (.clk(clk), .reset(sys_rst), .d(bot_mux_out_3), .q(sr_q_3));
    complex_multiplier #(.STAGE(3)) u_mult_3 (.idx(tw_count), .data_in(top_mux_out_3), .data_out(mult_out_3));


    // ========================================================================
    // STAGE 4: Final Butterfly (SR Delay = 1)
    // Butterfly real FL10 → Align to FL11 (left-shift 1)
    // Butterfly imag FL11 → No alignment needed
    // ========================================================================
    // Fractional length alignment: real part FL10 → FL11 (left-shift 1)
    // Imaginary part already FL11, no adjustment needed
    wire [2*WIDTH-1:0] bfly_diff_4_algnd = {
        $signed(bfly_diff_4[31:16]) <<< 1,
        bfly_diff_4[15:0] 
    };

    // Fractional length alignment: real part FL10 → FL11 (left-shift 1)
    // Imaginary part already FL11, no adjustment needed
    wire [2*WIDTH-1:0] bfly_sum_4_algnd = {
        $signed(bfly_sum_4[31:16]) <<< 1,
        bfly_sum_4[15:0] 
    };

    butterfly #(.STAGE(4), .WIDTH(WIDTH)) u_bfly_4 (
        .top_in  (sr_q_4),
        .bot_in  (stage_in_4),
        .sum_out (bfly_sum_4),
        .diff_out(bfly_diff_4)
    );

    mux_2_1_32bit u_botmux_4 (.a(bfly_diff_4_algnd), .b(stage_in_4), .sel(sel4),  .y(bot_mux_out_4));
    mux_2_1_32bit u_topmux_4 (.a(sr_q_4), .b(bfly_sum_4_algnd), .sel(~sel4), .y(top_mux_out_4));

    shift_register #(.STAGE(4)) u_sr_4 (.clk(clk), .reset(sys_rst), .d(bot_mux_out_4), .q(sr_q_4));

    // Final output: select upper-path result from Stage 4
    assign out_sample = top_mux_out_4;

endmodule
