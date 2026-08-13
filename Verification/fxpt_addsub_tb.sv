// =============================================================================
// Testbench      : fxpt_addsub_tb
// DUT            : fxpt_addsub
// Strategy       :
//   - WIDTH is held at 16 (all fi(...) signals in fft_16pt_types.m are
//     16-bit) while A_FRAC / B_FRAC / OUT_FRAC step through the 8 real/
//     imaginary butterfly add/sub configs actually used across the 4
//     stages of the 16-point SDF FFT (fft_16pt_sdf.m / fft_16pt_types.m,
//     case 'FxPt'):
//       Stage1 r/i : sr1_{r,i}  (frac=12) +/- in_{r,i}                 (frac=13) -> out frac=12
//       Stage2 r/i : sr2_{r,i}  (frac=12) +/- stage1_mult_add_out_{r,i} (frac=12) -> out frac=11
//       Stage3 r/i : sr3_{r,i}  (frac=11) +/- stage2_mult_add_out_{r,i} (frac=11) -> out frac=11
//       Stage4 r   : sr4_r      (frac=11) +/- stage3_mult_add_out_r     (frac=11) -> out frac=10
//       Stage4 i   : sr4_i      (frac=11) +/- stage3_mult_add_out_i     (frac=11) -> out frac=11
//     Note stage 4 is asymmetric: the real output drops to frac=10 while
//     the imaginary output stays at frac=11, per the types file -- kept
//     as specified rather than "corrected".
//     Each config is instantiated twice (IS_SUB=0 and IS_SUB=1), since
//     IS_SUB is a compile-time parameter, not a runtime signal.
//   - A golden model reproduces the DUT's exact bit-level algorithm
//     (sign-extend -> shift -> add/sub -> truncating slice) using
//     arithmetic shifts/casts instead of variable-width replication, so
//     it is portable across simulators and matches the DUT bit-for-bit,
//     including its truncation (not rounding) behavior and its wrap
//     behavior on overflow. NOTE: this matches the current DUT's
//     truncating requantization, NOT MATLAB fi's default round+saturate
//     semantics used by cast(a+b,'like',T.x) -- if the DUT is updated to
//     round/saturate, update golden() to match.
//   - Directed vectors hit zero, max/min magnitude, all-ones, and mixed
//     sign cases; randomized vectors add broad coverage per config.
// =============================================================================
`timescale 1ns/1ps

module fxpt_addsub_tb;

  localparam int WIDTH = 16;
  localparam int NUM_CFG = 8;

  // Config table (case-based functions instead of array-literal localparams
  // -- the '{...} unpacked-array-with-initializer form is not supported by
  // all simulators, notably Icarus Verilog). Index 0..7:
  //   0: Stage1 real   1: Stage1 imag
  //   2: Stage2 real   3: Stage2 imag
  //   4: Stage3 real   5: Stage3 imag
  //   6: Stage4 real   7: Stage4 imag
  function automatic int cfg_a_frac(input int idx);
    case (idx)
      0,1: cfg_a_frac = 12;  // Stage1 r/i : sr1_{r,i}
      2,3: cfg_a_frac = 12;  // Stage2 r/i : sr2_{r,i}
      4,5: cfg_a_frac = 11;  // Stage3 r/i : sr3_{r,i}
      6,7: cfg_a_frac = 11;  // Stage4 r/i : sr4_{r,i}
      default: cfg_a_frac = 0;
    endcase
  endfunction

  function automatic int cfg_b_frac(input int idx);
    case (idx)
      0,1: cfg_b_frac = 13;  // Stage1 r/i : in_{r,i}
      2,3: cfg_b_frac = 12;  // Stage2 r/i : stage1_mult_add_out_{r,i}
      4,5: cfg_b_frac = 11;  // Stage3 r/i : stage2_mult_add_out_{r,i}
      6,7: cfg_b_frac = 11;  // Stage4 r/i : stage3_mult_add_out_{r,i}
      default: cfg_b_frac = 0;
    endcase
  endfunction

  function automatic int cfg_out_frac(input int idx);
    case (idx)
      0,1: cfg_out_frac = 12;  // Stage1 r/i
      2,3: cfg_out_frac = 11;  // Stage2 r/i
      4,5: cfg_out_frac = 11;  // Stage3 r/i
      6:   cfg_out_frac = 10;  // Stage4 real  (NOTE: asymmetric vs imag)
      7:   cfg_out_frac = 11;  // Stage4 imag
      default: cfg_out_frac = 0;
    endcase
  endfunction

  function automatic string cfg_label(input int idx);
    case (idx)
      0: cfg_label = "Stage1_real";
      1: cfg_label = "Stage1_imag";
      2: cfg_label = "Stage2_real";
      3: cfg_label = "Stage2_imag";
      4: cfg_label = "Stage3_real";
      5: cfg_label = "Stage3_imag";
      6: cfg_label = "Stage4_real";
      7: cfg_label = "Stage4_imag";
      default: cfg_label = "unknown";
    endcase
  endfunction

  // ---------------------------------------------------------------------
  // DUT instances: 4 configs x {add, sub}
  // ---------------------------------------------------------------------
  logic signed [WIDTH-1:0] a [NUM_CFG];
  logic signed [WIDTH-1:0] b [NUM_CFG];
  wire  signed [WIDTH-1:0] out_add [NUM_CFG];
  wire  signed [WIDTH-1:0] out_sub [NUM_CFG];

  genvar gi;
  generate
    for (gi = 0; gi < NUM_CFG; gi++) begin : g_dut
      fxpt_addsub #(
        .WIDTH    (WIDTH),
        .A_FRAC   (cfg_a_frac(gi)),
        .B_FRAC   (cfg_b_frac(gi)),
        .OUT_FRAC (cfg_out_frac(gi)),
        .IS_SUB   (0)
      ) dut_add (
        .a   (a[gi]),
        .b   (b[gi]),
        .out (out_add[gi])
      );

      fxpt_addsub #(
        .WIDTH    (WIDTH),
        .A_FRAC   (cfg_a_frac(gi)),
        .B_FRAC   (cfg_b_frac(gi)),
        .OUT_FRAC (cfg_out_frac(gi)),
        .IS_SUB   (1)
      ) dut_sub (
        .a   (a[gi]),
        .b   (b[gi]),
        .out (out_sub[gi])
      );
    end
  endgenerate

  // ---------------------------------------------------------------------
  // Golden model - mirrors the DUT's algorithm exactly (truncating, wraps
  // on overflow just like the DUT), implemented with casts/shifts only
  // (no variable-width replication) for portability.
  // ---------------------------------------------------------------------
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

  // ---------------------------------------------------------------------
  // Scoreboard
  // ---------------------------------------------------------------------
  int pass_cnt = 0;
  int fail_cnt = 0;

  task automatic check(
      input string label,
      input string mode,
      input int cfg_idx,
      input logic signed [WIDTH-1:0] a_val,
      input logic signed [WIDTH-1:0] b_val,
      input logic signed [WIDTH-1:0] actual,
      input logic signed [WIDTH-1:0] expected
  );
    if (actual !== expected) begin
      fail_cnt++;
      $display("FAIL [%s cfg%0d(%s) %s] a=%0d(0x%0h) b=%0d(0x%0h) -> got=0x%0h exp=0x%0h",
                label, cfg_idx, cfg_label(cfg_idx), mode, a_val, a_val, b_val, b_val, actual, expected);
    end else begin
      pass_cnt++;
    end
  endtask

  task automatic run_vector(
      input int cfg_idx,
      input logic signed [WIDTH-1:0] a_val,
      input logic signed [WIDTH-1:0] b_val,
      input string label
  );
    logic signed [WIDTH-1:0] exp_add, exp_sub;
    a[cfg_idx] = a_val;
    b[cfg_idx] = b_val;
    #1;
    exp_add = golden(a_val, b_val, cfg_a_frac(cfg_idx), cfg_b_frac(cfg_idx), cfg_out_frac(cfg_idx), 0);
    exp_sub = golden(a_val, b_val, cfg_a_frac(cfg_idx), cfg_b_frac(cfg_idx), cfg_out_frac(cfg_idx), 1);
    check(label, "ADD", cfg_idx, a_val, b_val, out_add[cfg_idx], exp_add);
    check(label, "SUB", cfg_idx, a_val, b_val, out_sub[cfg_idx], exp_sub);
  endtask

  // ---------------------------------------------------------------------
  // Directed vectors (raw bit patterns, reinterpreted per config's format)
  // ---------------------------------------------------------------------
  localparam int NUM_DIRECTED = 8;

  function automatic logic signed [WIDTH-1:0] dv_a(input int idx);
    case (idx)
      0: dv_a = 16'sh0000;
      1: dv_a = 16'sh7FFF;
      2: dv_a = 16'sh8000;
      3: dv_a = 16'sh8000;
      4: dv_a = 16'sh7FFF;
      5: dv_a = 16'sh4000;
      6: dv_a = 16'sh0001;
      7: dv_a = 16'shFFFF;
      default: dv_a = 16'sh0000;
    endcase
  endfunction

  function automatic logic signed [WIDTH-1:0] dv_b(input int idx);
    case (idx)
      0: dv_b = 16'sh0000;
      1: dv_b = 16'sh0001;
      2: dv_b = 16'sh0001;
      3: dv_b = 16'sh8000;
      4: dv_b = 16'sh7FFF;
      5: dv_b = 16'shC000;
      6: dv_b = 16'sh0001;
      7: dv_b = 16'sh0001;
      default: dv_b = 16'sh0000;
    endcase
  endfunction

  initial begin
    for (int c = 0; c < NUM_CFG; c++) begin
      $display("--- Config %0d (%s): A_FRAC=%0d B_FRAC=%0d OUT_FRAC=%0d ---",
                c, cfg_label(c), cfg_a_frac(c), cfg_b_frac(c), cfg_out_frac(c));

      // Directed
      for (int v = 0; v < NUM_DIRECTED; v++)
        run_vector(c, dv_a(v), dv_b(v), "directed");

      // Randomized
      for (int r = 0; r < 100; r++)
        run_vector(c, $urandom(), $urandom(), "random");
    end

    $display("=============================================");
    $display("TOTAL: %0d passed, %0d failed", pass_cnt, fail_cnt);
    $display("=============================================");
    if (fail_cnt == 0) $display("RESULT: ALL TESTS PASSED");
    else                $display("RESULT: FAILURES DETECTED");

    $finish;
  end

endmodule