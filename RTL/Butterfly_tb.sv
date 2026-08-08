// =============================================================================
// Testbench : butterfly_tb
// DUT       : butterfly (packed {real,imag} complex I/O), STAGE=1..4
// Strategy  : One DUT instance per stage, a handful of directed vectors per
//             stage, self-checked against a golden model that mirrors
//             fxpt_addsub's align-shift-add-truncate behavior (truncating,
//             wraps on overflow -- matches the current DUT, not MATLAB's
//             round+saturate fi() semantics).
// =============================================================================
`timescale 1ns/1ps

module Butterfly_tb;

  localparam integer WIDTH = 16;

  // -------------------------------------------------------------------
  // Golden model: same align-shift-add-truncate algorithm as fxpt_addsub
  // -------------------------------------------------------------------
  function automatic logic signed [WIDTH-1:0] golden(
      input logic signed [WIDTH-1:0] a_in,
      input logic signed [WIDTH-1:0] b_in,
      input int a_frac, b_frac, out_frac, is_sub
  );
    localparam int EXT = 2*WIDTH;
    logic signed [EXT-1:0] a_ext, b_ext, sum_ext, shifted;
    a_ext = EXT'(a_in) <<< (WIDTH - a_frac);
    b_ext = EXT'(b_in) <<< (WIDTH - b_frac);
    sum_ext = is_sub ? (a_ext - b_ext) : (a_ext + b_ext);
    shifted = sum_ext >>> (WIDTH - out_frac);
    golden  = shifted[WIDTH-1:0];
  endfunction

  // Per-stage fraction lengths (mirrors butterfly.sv's own tables)
  function automatic int top_frac(input int stg);
    case (stg) 1: top_frac=12; 2: top_frac=12; 3: top_frac=11; default: top_frac=11; endcase
  endfunction
  function automatic int bot_frac(input int stg);
    case (stg) 1: bot_frac=13; 2: bot_frac=12; 3: bot_frac=11; default: bot_frac=11; endcase
  endfunction
  function automatic int sum_re_frac(input int stg);
    case (stg) 1: sum_re_frac=12; 2: sum_re_frac=11; 3: sum_re_frac=11; default: sum_re_frac=10; endcase
  endfunction
  function automatic int sum_im_frac(input int stg);
    case (stg) 1: sum_im_frac=12; 2: sum_im_frac=11; 3: sum_im_frac=11; default: sum_im_frac=11; endcase
  endfunction

  // -------------------------------------------------------------------
  // DUTs: one per stage
  // -------------------------------------------------------------------
  logic signed [2*WIDTH-1:0] top_in [1:4];
  logic signed [2*WIDTH-1:0] bot_in [1:4];
  wire  signed [2*WIDTH-1:0] sum_out [1:4];
  wire  signed [2*WIDTH-1:0] diff_out [1:4];

  butterfly #(.STAGE(1), .WIDTH(16)) dut1 (.top_in(top_in[1]), .bot_in(bot_in[1]), .sum_out(sum_out[1]), .diff_out(diff_out[1]));
  butterfly #(.STAGE(2), .WIDTH(16)) dut2 (.top_in(top_in[2]), .bot_in(bot_in[2]), .sum_out(sum_out[2]), .diff_out(diff_out[2]));
  butterfly #(.STAGE(3), .WIDTH(16)) dut3 (.top_in(top_in[3]), .bot_in(bot_in[3]), .sum_out(sum_out[3]), .diff_out(diff_out[3]));
  butterfly #(.STAGE(4), .WIDTH(16)) dut4 (.top_in(top_in[4]), .bot_in(bot_in[4]), .sum_out(sum_out[4]), .diff_out(diff_out[4]));

  // -------------------------------------------------------------------
  // Scoreboard
  // -------------------------------------------------------------------
  int pass_cnt = 0;
  int fail_cnt = 0;

  task automatic check_stage(
      input int stg,
      input logic signed [WIDTH-1:0] top_r, top_i,
      input logic signed [WIDTH-1:0] bot_r, bot_i,
      input string label
  );
    logic signed [WIDTH-1:0] exp_sum_r, exp_sum_i, exp_diff_r, exp_diff_i;
    logic signed [WIDTH-1:0] got_sum_r, got_sum_i, got_diff_r, got_diff_i;

    top_in[stg] = {top_r, top_i};
    bot_in[stg] = {bot_r, bot_i};
    #1;

    exp_sum_r  = golden(top_r, bot_r, top_frac(stg), bot_frac(stg), sum_re_frac(stg), 0);
    exp_sum_i  = golden(top_i, bot_i, top_frac(stg), bot_frac(stg), sum_im_frac(stg), 0);
    exp_diff_r = golden(top_r, bot_r, top_frac(stg), bot_frac(stg), sum_re_frac(stg), 1);
    exp_diff_i = golden(top_i, bot_i, top_frac(stg), bot_frac(stg), sum_im_frac(stg), 1);

    got_sum_r  = sum_out[stg][2*WIDTH-1:WIDTH];
    got_sum_i  = sum_out[stg][WIDTH-1:0];
    got_diff_r = diff_out[stg][2*WIDTH-1:WIDTH];
    got_diff_i = diff_out[stg][WIDTH-1:0];

    if (got_sum_r !== exp_sum_r || got_sum_i !== exp_sum_i) begin
      fail_cnt++;
      $display("FAIL [stage%0d %s SUM ] top=(%0d,%0d) bot=(%0d,%0d) got=(%0d,%0d) exp=(%0d,%0d)",
                stg, label, top_r, top_i, bot_r, bot_i, got_sum_r, got_sum_i, exp_sum_r, exp_sum_i);
    end else pass_cnt++;

    if (got_diff_r !== exp_diff_r || got_diff_i !== exp_diff_i) begin
      fail_cnt++;
      $display("FAIL [stage%0d %s DIFF] top=(%0d,%0d) bot=(%0d,%0d) got=(%0d,%0d) exp=(%0d,%0d)",
                stg, label, top_r, top_i, bot_r, bot_i, got_diff_r, got_diff_i, exp_diff_r, exp_diff_i);
    end else pass_cnt++;
  endtask

  // -------------------------------------------------------------------
  // Directed vectors (shared raw values across all 4 stages)
  // -------------------------------------------------------------------
  initial begin
    for (int stg = 1; stg <= 4; stg++) begin
      $display("--- Stage %0d: TOP_FRAC=%0d BOT_FRAC=%0d SUM_RE_FRAC=%0d SUM_IM_FRAC=%0d ---",
                stg, top_frac(stg), bot_frac(stg), sum_re_frac(stg), sum_im_frac(stg));

      check_stage(stg, 16'sd0,     16'sd0,     16'sd0,     16'sd0,     "zero");
      check_stage(stg, 16'sh7FFF,  16'sh7FFF,  16'sh0001,  16'sh0001,  "max_pos");
      check_stage(stg, 16'sh8000,  16'sh8000,  16'sh0001,  16'sh0001,  "max_neg");
      check_stage(stg, 16'sh7FFF,  16'sh8000,  16'sh7FFF,  16'sh8000,  "both_extreme_overflow");
      check_stage(stg, 16'sd1000,  -16'sd500,  16'sd2000,  16'sd800,   "mixed_sign");
      check_stage(stg, -16'sd4096, 16'sd4096,  16'sd4096,  -16'sd4096, "mixed_sign2");
    end

    $display("=============================================");
    $display("TOTAL: %0d passed, %0d failed", pass_cnt, fail_cnt);
    $display("=============================================");
    if (fail_cnt == 0) $display("RESULT: ALL TESTS PASSED");
    else                $display("RESULT: FAILURES DETECTED");

    $finish;
  end

endmodule