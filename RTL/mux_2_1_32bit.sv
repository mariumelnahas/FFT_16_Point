module mux_2_1_32bit (
    input  wire [31:0] a,      // input 0
    input  wire [31:0] b,      // input 1
    input  wire        sel,    // select line
    output wire [31:0] y       // output
);

    assign y = sel ? b : a;

endmodule