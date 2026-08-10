module Wrapper #(parameter int WIDTH = 16) (
    input  wire        clk,   // Clock
    input  wire        BS,   // Block Select
    input  wire [31:0] din,   // 32-bit data input
    output wire [31:0] dout   // 32-bit data output
);


wire [2*WIDTH-1:0] FFT_out;
wire [2*WIDTH-1:0] reg_out;

fft_16pt_top #(
    .WIDTH(WIDTH)
) FFT_block
(
    .clk(clk),
    .BS(BS),
    .in_sample(din),
    .out_sample(FFT_out)
);

register #(
    .WIDTH(2*WIDTH)
) register_block 
(
    .clk(clk),
    .rst(~BS),
    .we(1'b1),
    .din(FFT_out),
    .dout(reg_out)
);


ram_wrapper  RAM_block(
    .clk(clk),
    .rst(~BS),
    .din(reg_out),   // Incoming data stream
    .dout(dout)   // Outgoing bit-reversed data stream
);
endmodule 