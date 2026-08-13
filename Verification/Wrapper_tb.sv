`timescale 1ns / 1ps

module Wrapper_tb;

    // Parameters
    parameter integer WIDTH = 16;
    // 100 seeds * 16 cycles per block
    parameter integer NUM_TESTS = 1632; 

    // Signals
    logic               clk;
    logic               BS;
    logic [2*WIDTH-1:0] in_sample;
    logic [2*WIDTH-1:0] out_sample;

    // Testbench Memory Arrays
    logic [2*WIDTH-1:0] mem_in  [0:NUM_TESTS-1];
    logic [2*WIDTH-1:0] mem_out [0:NUM_TESTS-1];

    int errors;


    Wrapper #(
        .WIDTH(WIDTH)
    ) DUT (
    .clk(clk),   // Clock
    .BS(BS),   // Block Select
    .din(in_sample),   // 32-bit data input
    .dout(out_sample)   // 32-bit data output
    );


    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Main Test Sequence
    initial begin

        // Variables for floating-point conversion and formatting
        real exp_r, exp_i, abs_exp_i;
        real got_r, got_i, abs_got_i;
        string exp_sign, got_sign;
        real err_r, err_i;
        automatic real max_err_r = 0.0;
        automatic real max_err_i = 0.0;

        integer fd_rtl;
        // 1. Load the binary text files into the memory arrays
        $readmemb("golden_fft_inputs.txt", mem_in);
        $readmemb("golden_fft_outputs.txt", mem_out);

        fd_rtl = $fopen("rtl_outputs.txt", "w");
        if (fd_rtl == 0) begin
            $display("Error: Could not open rtl_outputs.txt for writing!");
            $stop;
        end

        // 2. Initialize signals
        @(negedge clk);

        BS = 0;
        in_sample = '0;
        errors = 0;

        // 3. Hold Reset (BS=0) for a few cycles
        #25; 
        
        // Align to the falling edge to release reset cleanly
        @(negedge clk);
        BS = 1; 

        $display("--- Starting FFT 16-pt Top-Level Verification ---");

        // 4. Cycle-by-Cycle Verification Loop
for (int i = 0; i < NUM_TESTS; i++) begin
    in_sample = mem_in[i];
    @(negedge clk);
    #3;
    $fwrite(fd_rtl, "%032b\n", out_sample);

    // Compute display values every cycle, unconditionally
    exp_r = $itor($signed(mem_out[i][31:16])) / 2048.0;
    exp_i = $itor($signed(mem_out[i][15:0]))  / 2048.0;
    got_r = $itor($signed(out_sample[31:16])) / 2048.0;
    got_i = $itor($signed(out_sample[15:0]))  / 2048.0;
    exp_sign  = (exp_i < 0) ? "-" : "+";
    abs_exp_i = (exp_i < 0) ? -exp_i : exp_i;
    got_sign  = (got_i < 0) ? "-" : "+";
    abs_got_i = (got_i < 0) ? -got_i : got_i;

    if (out_sample !== mem_out[i]) begin
        err_r = (got_r > exp_r) ? (got_r - exp_r) : (exp_r - got_r);
        err_i = (got_i > exp_i) ? (got_i - exp_i) : (exp_i - got_i);
        if (err_r > max_err_r) max_err_r = err_r;
        if (err_i > max_err_i) max_err_i = err_i;

        $display("Cycle %4d RAM cnt %0d [FAIL] | Expected: %0.4f %s i %0.4f | Got: %0.4f %s i %0.4f",
                 i, 5'(unsigned'(DUT.RAM_block.cnt - 1)), exp_r, exp_sign, abs_exp_i, got_r, got_sign, abs_got_i);
        errors++;
        if (max_err_r > 0.01 || max_err_i > 0.01) begin
            $display("ERROR: Maximum error exceeded threshold! Halting simulation.");
            $stop;
        end
    end else begin
        $display("Cycle %4d RAM cnt %0d [PASS] | Expected: %0.4f %s i %0.4f | Got: %0.4f %s i %0.4f",
                 i, 5'(unsigned'(DUT.RAM_block.cnt - 1)), exp_r, exp_sign, abs_exp_i, got_r, got_sign, abs_got_i);
    end
end

        // 5. Final Report
        $display("=================================================");
        if (errors == 0) begin
            $display("--- VERIFICATION PASSED! 0 Errors in %0d cycles.", NUM_TESTS);
        end else begin
            $display("--- VERIFICATION FAILED! %0d Errors found.", errors);
            $display("--- MAX REAL ERROR : %0.4f", max_err_r);
            $display("--- MAX IMAG ERROR : %0.4f", max_err_i);
        end
        $display("=================================================");
        $fclose(fd_rtl);
        $stop;
    end

endmodule