module reg_file (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,         // Write Enable
    input  wire [4:0]  rs1_addr,   // Source Register 1 Address
    input  wire [4:0]  rs2_addr,   // Source Register 2 Address
    input  wire [4:0]  rd_addr,    // Destination Register Address
    input  wire [31:0] rd_data,    // Data to write to Destination Register
    output wire [31:0] rs1_data,   // Source Register 1 Data
    output wire [31:0] rs2_data    // Source Register 2 Data
);

    reg [31:0] registers [0:31];
    integer i;

    // Read logic (asynchronous, Register 0 is hardwired to 0)
    assign rs1_data = (rs1_addr == 0) ? 32'b0 : registers[rs1_addr];
    assign rs2_data = (rs2_addr == 0) ? 32'b0 : registers[rs2_addr];

    // Write logic (synchronous)
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else if (we && rd_addr != 0) begin
            registers[rd_addr] <= rd_data;
        end
    end

endmodule