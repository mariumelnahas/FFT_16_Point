`timescale 1ns / 1ps

module shift_register #(
    parameter STAGE = 1
)(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] d,
    output wire [31:0] q
);
    localparam DEPTH = (STAGE == 1) ? 8 : (STAGE == 2) ? 4 : (STAGE == 3) ? 2 : 1;

    reg [31:0] sr [0:DEPTH-1] = '{default: 32'd0};
    integer i;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < DEPTH; i = i + 1) begin
                sr[i] <= 32'd0;
            end
        end else begin
            sr[0] <= d;
            for (i = 1; i < DEPTH; i = i + 1) begin
                sr[i] <= sr[i-1];
            end
        end
    end

    assign q = sr[DEPTH-1];

endmodule