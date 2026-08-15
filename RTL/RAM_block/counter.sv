// =====================================================================
// Counter Module
// =====================================================================
// Description:
//   Generates a programmable-length counter with asynchronous reset
//   and enable control. Provides both multiplexer select signals for
//   FFT pipeline stages and address/RAM selection for output memory.
//   Within the FFT block, functionally equivalent to cascaded clock
//   dividers with outputs tapped after each division stage.
//   The MSB output controls RAM role switching.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================
module counter #(
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
