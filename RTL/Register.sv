module register #(
    parameter int WIDTH = 32
) (
    input  logic             clk,    // Clock signal
    input  logic             rst,    // Active-high asynchronous reset
    input  logic             we,     // Write enable
    input  logic [WIDTH-1:0] din,    // Data input
    output logic [WIDTH-1:0] dout    // Data output
);

    // Sequential block with active-low async reset
    always_ff @(posedge clk or negedge rst) begin
        if (rst) begin
            dout <= '0;
        end else if (we) begin
            dout <= din;
        end
    end

endmodule