`timescale 1ns / 1ps

module tb_fft_16pt_top;

    // Parameters
    parameter integer WIDTH = 16;
    // 100 seeds * 16 cycles per block
    parameter integer NUM_TESTS = 1616; 

    // Signals
    logic               clk;
    logic               BS;
    logic [2*WIDTH-1:0] in_sample;
    logic [2*WIDTH-1:0] out_sample;

    // Testbench Memory Arrays
    logic [2*WIDTH-1:0] mem_in  [0:NUM_TESTS-1];
    logic [2*WIDTH-1:0] mem_out [0:NUM_TESTS-1];

    int errors;

    // Instantiate the Unit Under Test (UUT)
    fft_16pt_top #(
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .BS(BS),
        .in_sample(in_sample),
        .out_sample(out_sample)
    );

    // Clock Generation (100 MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // Main Test Sequence
    initial begin
        // 1. Load the binary text files into the memory arrays
        $readmemb("fft_inputs.txt", mem_in);
        $readmemb("fft_outputs.txt", mem_out);

        // 2. Initialize signals
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
            
            // Drive inputs safely on the falling edge
            in_sample = mem_in[i];

            // Wait for the rising edge (UUT evaluates the input)
            @(posedge clk);

            // Wait until right before the NEXT falling edge to sample the output
            // This ensures combinational logic has fully settled
            #4; 

            // Compare UUT output against expected memory
            if (out_sample !== mem_out[i]) begin
                $display("Cycle %4d [FAIL] | Expected: %b | Got: %b", 
                         i, mem_out[i], out_sample);
                errors++;
            end

            // Wait for the falling edge to loop and push the next input
            @(negedge clk);
        end

        // 5. Final Report
        if (errors == 0) begin
            $display("--- VERIFICATION PASSED! 0 Errors in %0d cycles.", NUM_TESTS);
        end else begin
            $display("--- VERIFICATION FAILED! %0d Errors found.", errors);
        end

        $finish;
    end

endmodule