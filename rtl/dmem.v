module dmem (
    input  wire        clk,
    input  wire        we,
    input  wire [3:0]  byte_en,    // NEW PORT
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata
);

	reg [31:0] ram [0:255];

	assign rdata = ram[addr[9:2]];

	 always @(posedge clk) begin
			   if (we) begin
						 if (byte_en[0]) ram[addr[9:2]][7:0]   <= wdata[7:0];
						 if (byte_en[1]) ram[addr[9:2]][15:8]  <= wdata[15:8];
						 if (byte_en[2]) ram[addr[9:2]][23:16] <= wdata[23:16];
						 if (byte_en[3]) ram[addr[9:2]][31:24] <= wdata[31:24];
			   end
		  end
endmodule