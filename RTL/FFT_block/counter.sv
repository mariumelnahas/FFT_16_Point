// =====================================================================
// Counter Module (4-bit)
// =====================================================================
// Description:
//   A modular counter that generates select signals for multiplexer 
//   inputs at each FFT stage. Functionally equivalent to cascaded 
//   clock dividers with outputs tapped after each division stage.
//   Includes asynchronous reset and count enable control.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================
module counter_4 #(
    parameter LENGTH = 4
)(
    input  wire clk,
    input  wire rst,       // active-high asynchronous reset
    input  wire en,        // count enable
    output reg [LENGTH-1:0] count
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            count <= {LENGTH{1'b0}};
        else if (en)
            count <= count + 1'b1;
    end

endmodule