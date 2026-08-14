module ram_wrapper (
    input  wire        clk,
    input  wire        rst,   // Active-high asynchronous reset
    input  wire [31:0] din,   // Incoming data stream
    output logic [31:0] dout   // Outgoing bit-reversed data stream
);

    // -----------------------------------------------------------------
    // Internal Wires & Control Signals
    // -----------------------------------------------------------------
    wire [4:0] cnt;
    wire [3:0] seq_addr;
    wire [3:0] rev_addr;
    wire       phase;     // cnt[4]: Controls Ping-Pong roles

    wire       we0, we1;
    wire [3:0] addr0, addr1;
    wire [31:0] dout0, dout1;

    // -----------------------------------------------------------------
    // 1. 5-Bit Counter Submodule
    // -----------------------------------------------------------------
    counter #(
        .LENGTH(5)
    ) u_counter (
        .clk  (~clk),
        .rst  (rst),
        .en   (1'b1),
        .count(cnt)
    );


    assign phase    = cnt[4];    // MSB toggles every 16 cycles
    assign seq_addr = cnt[3:0];  // 4 LSBs drive normal 0 -> 15 sequence

    // -----------------------------------------------------------------
    // 2. Bit Reversal Submodule
    // -----------------------------------------------------------------
    bit_reversal u_reverser (
        .in  (seq_addr),
        .out (rev_addr)
    );

    // -----------------------------------------------------------------
    // 3. Control & Muxing Logic
    // -----------------------------------------------------------------
    // Phase 0 (cnt[4] = 0): WRITE RAM0 (Sequential), READ RAM1 (Bit-Reversed)
    // Phase 1 (cnt[4] = 1): WRITE RAM1 (Sequential), READ RAM0 (Bit-Reversed)

    
    assign we0   = ~phase;
    assign we1   = phase;

    assign addr0 = (~phase) ? seq_addr : rev_addr;
    assign addr1 = (phase)  ? seq_addr : rev_addr;

    //assign dout  = (clk)? ((phase)  ? dout0    : dout1) : dout;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            dout <= 32'h0;
        end else begin
            dout <= (phase) ? dout0 : dout1;
        end
    end

    
    // -----------------------------------------------------------------
    // 4. RAM Instantiations
    // -----------------------------------------------------------------
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
