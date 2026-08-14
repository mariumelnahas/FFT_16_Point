module counter #(
    parameter LENGTH = 4
)(
    input  wire clk,
    input  wire rst,       // active-high asynchronous reset
    input  wire en,        // count enable
    output reg [LENGTH-1:0] count
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            count <= {LENGTH{1'b0}};
        else if (en)
            count <= count + 1'b1;
    end

endmodule
