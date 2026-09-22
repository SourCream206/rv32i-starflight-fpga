module imem (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);
    reg [31:0] rom [0:255];

    initial begin
        $readmemh("software/imem.hex", rom);
    end

    assign rdata = rom[addr[9:2]];
endmodule