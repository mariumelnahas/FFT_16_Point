// =====================================================================
// RAM Wrapper Module
// =====================================================================
// Description:
//   Ping-pong dual-RAM architecture for buffering and reordering FFT
//   output samples. Implements bit-reversal through address generation
//   during the read phase while write phase uses sequential addressing.
//   The counter MSB selects which RAM operates in write/read mode,
//   enabling continuous pipelined operation.
//
// Authors: Marium Waleed, Yossef Medhat
// =====================================================================

module ram_wrapper (
    input  wire        clk,
    input  wire        rst,   // Active-high asynchronous reset
    input  wire [31:0] din,   // Incoming data stream
    output logic [31:0] dout   // Outgoing bit-reversed data stream
);

    // Internal Wires & Control Signals
    wire [4:0] cnt;
    wire [3:0] seq_addr;
    wire [3:0] rev_addr;
    wire       phase;     // cnt[4]: Controls RAM read/write select

    wire       we0, we1;
    wire [3:0] addr0, addr1;
    wire [31:0] dout0, dout1;


    // Counter: Generates address sequence and RAM phase control
    counter #(
        .LENGTH(5)
    ) u_counter (
        .clk  (~clk),
        .rst  (rst),
        .en   (1'b1),
        .count(cnt)
    );

    assign phase    = cnt[4];    // MSB toggles every 16 cycles for RAM selection
    assign seq_addr = cnt[3:0];  // 4 LSBs provide sequential addressing

    // Convert sequential address to bit-reversed address for output reordering
    bit_reversal u_reverser (
        .in  (seq_addr),
        .out (rev_addr)
    );

    
    // RAM write enable: alternates based on phase
    assign we0   = ~phase;
    assign we1   = phase;

    // Address multiplexing: sequential for write, bit-reversed for read
    assign addr0 = (~phase) ? seq_addr : rev_addr;
    assign addr1 = (phase)  ? seq_addr : rev_addr;


    // Output multiplexing: select RAM based on phase
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            dout <= 32'h0;
        end else begin
            dout <= (phase) ? dout0 : dout1;
        end
    end

    // RAM Instantiations
    RAM u_ram0 (
        .clk (clk),
        .rst (rst),
        .we  (we0),
        .addr(addr0),
        .din (din),
        .dout(dout0)
    );

    RAM u_ram1 (
        .clk (clk),
        .rst (rst),
        .we  (we1),
        .addr(addr1),
        .din (din),
        .dout(dout1)
    );

endmodule
