module RAM (
    input  wire        clk,   // Clock
    input  wire        rst,   // Active-high asynchronous reset
    input  wire        we,    // Write enable (1 = Write, 0 = Read)
    input  wire [3:0]  addr,  // 4-bit address line (2^4 = 16 locations)
    input  wire [31:0] din,   // 32-bit data input
    output reg  [31:0] dout   // 32-bit data output
);

    // Memory array: 16 memory slots, each 32 bits wide
    reg [31:0] mem [0:15];
    
    integer i;

    // Asynchronous Active-High Reset Logic
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Clear output and reset all 16 memory locations
            dout <= 32'b0;
            for (i = 0; i < 16; i = i + 1) begin
                mem[i] <= 32'b0;
            end
        end else begin
            if (we) begin
                mem[addr] <= din;   // Synchronous write operation
            end
            dout <= mem[addr];      // Synchronous read-first operation
        end
    end

endmodule