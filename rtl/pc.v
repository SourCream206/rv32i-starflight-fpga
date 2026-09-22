module pc (
    input  wire        clk,
    input  wire        rst,
    input  wire        pc_write,
    input  wire        branch_taken,
    input  wire [31:0] branch_target,
    output reg  [31:0] pc_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 32'h00000000;
        end else if (pc_write) begin
            if (branch_taken)
                pc_out <= branch_target;
            else
                pc_out <= pc_out + 32'd4;
        end
    end

endmodule