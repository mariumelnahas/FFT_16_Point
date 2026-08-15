//This module connects the FFT block to the RAM block with an intermediate register for one clock cycle delay
//The clock of the FFT system is gated with the BS signal so that the system stops when there is samples in or out
module Wrapper #(parameter int WIDTH = 16) (
    input  wire        clk,   // Clock
    input  wire        BS,   // Block Select
    input  wire [31:0] din,   // 32-bit data input
    output wire [31:0] dout   // 32-bit data output
);


wire [2*WIDTH-1:0] FFT_out;
wire [2*WIDTH-1:0] reg_out;

wire gclk = clk & BS;

FFT_wrapper #(
    .WIDTH(WIDTH)
) FFT_block
(
    .clk(gclk),
    .BS(BS),
    .in_sample(din),
    .out_sample(FFT_out)
);

register #(
    .WIDTH(2*WIDTH)
) register_block 
(
    .clk(gclk),
    .rst(~BS),
    .we(1'b1),
    .din(FFT_out),
    .dout(reg_out)
);


ram_wrapper  RAM_block(
    .clk(gclk),
    .rst(~BS),
    .din(reg_out),   // Incoming data stream
    .dout(dout)   // Outgoing bit-reversed data stream
);
endmodule 
