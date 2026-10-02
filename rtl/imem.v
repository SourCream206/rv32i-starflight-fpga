module imem (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);
    reg [31:0] rom [0:4095];

    initial begin
        $readmemh("software/imem.hex", rom);
    end

    assign rdata = rom[addr[13:2]];
endmodule