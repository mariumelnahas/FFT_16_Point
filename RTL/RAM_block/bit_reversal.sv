module bit_reversal (
    input  wire [3:0] in,   // e.g., 4'b1011
    output wire [3:0] out   // e.g., 4'b1101
);

    assign out = {in[0], in[1], in[2], in[3]};

endmodule
