`timescale 1ns / 1ps

module fft_16pt_top #(
    parameter integer WIDTH = 16
)(
    input  wire                      clk,
    input  wire                      BS,

    input  wire [2*WIDTH-1:0]        in_sample,
    output wire [2*WIDTH-1:0]        out_sample
);

    wire sys_rst = ~BS;
    wire gclk    = clk & BS;

    wire [3:0] tw_count;
    counter u_tw_counter (.clk(gclk), .rst(sys_rst), .en(1'b1), .count(tw_count));

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


    // STAGE 1 (SR Delay = 8)
    // stage_in_1 is FL13. SR1 expects FL12.
    wire [2*WIDTH-1:0] stage_in_1_algnd = { 
        $signed(stage_in_1[31:16]) >>> 1, 
        $signed(stage_in_1[15:0])  >>> 1 
    };

    butterfly #(.STAGE(1), .WIDTH(WIDTH)) u_bfly_1 (
        .top_in  (sr_q_1),
        .bot_in  (stage_in_1),
        .sum_out (bfly_sum_1),
        .diff_out(bfly_diff_1)
    );

    mux_2_1_32bit u_botmux_1 (.a(bfly_diff_1), .b(stage_in_1_algnd), .sel(sel1),  .y(bot_mux_out_1));
    mux_2_1_32bit u_topmux_1 (.a(sr_q_1), .b(bfly_sum_1), .sel(~sel1), .y(top_mux_out_1));

    shift_register #(.STAGE(1)) u_sr_1 (.clk(gclk), .reset(sys_rst), .d(bot_mux_out_1), .q(sr_q_1));
    complex_multiplier #(.STAGE(1)) u_mult_1 (.idx(tw_count), .data_in(top_mux_out_1), .data_out(mult_out_1));

    // STAGE 2 (SR Delay = 4)
    // bfly_diff_2 is FL11. SR2 expects FL12.
    wire [2*WIDTH-1:0] bfly_diff_2_algnd = {
        $signed(bfly_diff_2[31:16]) <<< 1,
        $signed(bfly_diff_2[15:0])  <<< 1
    };
    // sr_q_2 is FL12. comp_mult_2 expects FL11.
    wire [2*WIDTH-1:0] sr_q_2_algnd = {
        $signed(sr_q_2[31:16]) >>> 1,
        $signed(sr_q_2[15:0])  >>> 1
    };

    butterfly #(.STAGE(2), .WIDTH(WIDTH)) u_bfly_2 (
        .top_in  (sr_q_2),
        .bot_in  (stage_in_2),
        .sum_out (bfly_sum_2),
        .diff_out(bfly_diff_2)
    );

    mux_2_1_32bit u_botmux_2 (.a(bfly_diff_2_algnd), .b(stage_in_2), .sel(sel2),  .y(bot_mux_out_2));
    mux_2_1_32bit u_topmux_2 (.a(sr_q_2_algnd), .b(bfly_sum_2), .sel(~sel2), .y(top_mux_out_2));

    shift_register #(.STAGE(2)) u_sr_2 (.clk(gclk), .reset(sys_rst), .d(bot_mux_out_2), .q(sr_q_2));
    complex_multiplier #(.STAGE(2)) u_mult_2 (.idx(tw_count), .data_in(top_mux_out_2), .data_out(mult_out_2));

    // STAGE 3 (SR Delay = 2)
    // All inputs natively FL11. No alignment needed.
    butterfly #(.STAGE(3), .WIDTH(WIDTH)) u_bfly_3 (
        .top_in  (sr_q_3),
        .bot_in  (stage_in_3),
        .sum_out (bfly_sum_3),
        .diff_out(bfly_diff_3)
    );

    mux_2_1_32bit u_botmux_3 (.a(bfly_diff_3), .b(stage_in_3), .sel(sel3),  .y(bot_mux_out_3));
    mux_2_1_32bit u_topmux_3 (.a(sr_q_3), .b(bfly_sum_3), .sel(~sel3), .y(top_mux_out_3));

    shift_register #(.STAGE(3)) u_sr_3 (.clk(gclk), .reset(sys_rst), .d(bot_mux_out_3), .q(sr_q_3));
    complex_multiplier #(.STAGE(3)) u_mult_3 (.idx(tw_count), .data_in(top_mux_out_3), .data_out(mult_out_3));


    // STAGE 4 (SR Delay = 1)
    // bfly_diff_4 has Real FL10, Imag FL11. SR4 expects FL11.
    wire [2*WIDTH-1:0] bfly_diff_4_algnd = {
        $signed(bfly_diff_4[31:16]) <<< 1,
        bfly_diff_4[15:0] 
    };

    // bfly_sum_4 has Real FL10, Imag FL11. Output expects FL11.
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

    shift_register #(.STAGE(4)) u_sr_4 (.clk(gclk), .reset(sys_rst), .d(bot_mux_out_4), .q(sr_q_4));

    assign out_sample = top_mux_out_4;

endmodule

