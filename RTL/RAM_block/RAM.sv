module RAM (
    input  wire        clk,   // Clock
    input  wire        we,    // Write enable (1 = Write, 0 = Read)
    input wire        rst,   // Active-high asynchronous reset
    input  wire [3:0]  addr,  // 4-bit address line (2^4 = 16 locations)
    input  wire [31:0] din,   // 32-bit data input
    output wire  [31:0] dout   // 32-bit data output
);

    // Memory array: 16 memory slots, each 32 bits wide
    reg [31:0] mem [0:15];

    assign dout = (rst) ? 32'h0 : (~we) ? mem[addr] : 32'bz; // Tri-state output for read operation

    // Asynchronous Active-High Reset Logic
    always @(posedge clk) begin
            if (we) mem[addr] <= din;   // Synchronous write operation

    end

endmodule
