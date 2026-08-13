// =====================================================================
// 2-to-1 Multiplexer (32-bit)
// =====================================================================
// Description:
//   A simple 2-to-1 multiplexer for 32-bit wide data paths. Routes one 
//   of two inputs to the output based on a single-bit select signal. 
//   Used by the FFT module to control dataflow between the computation 
//   path and the shift register feedback path.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================
module mux_2_1_32bit (
    input  wire [31:0] a,      // input 0
    input  wire [31:0] b,      // input 1
    input  wire        sel,    // select line
    output wire [31:0] y       // output
);

    assign y = sel ? b : a;

endmodule