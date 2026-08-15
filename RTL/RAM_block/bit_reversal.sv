// =====================================================================
// Bit Reversal Module
// =====================================================================
// Description:
//   Takes a 4-bit address and performs bit reversal by rearranging
//   the bit order to output the address with reversed bits.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================

module bit_reversal (
    input  wire [3:0] in,   
    output wire [3:0] out   
);

    assign out = {in[0], in[1], in[2], in[3]};

endmodule
