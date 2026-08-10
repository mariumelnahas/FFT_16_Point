module clk_div (
    input  wire clk_in,
    input  wire rst,      // async, active-high
    output reg  clk_out
);
 
    always @(posedge clk_in or posedge rst) begin
        if (rst)
            clk_out <= 1'b1;
        else
            clk_out <= ~clk_out;
    end
 
endmodule