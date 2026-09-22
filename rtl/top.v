module top (
    input  wire       MAX10_CLK1_50, // 50 MHz clock
    input  wire [1:0] KEY,           // Push buttons (KEY[0] is reset)
    
    // 7-Segment Displays
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire [7:0] HEX3,
    output wire [7:0] HEX4,
    output wire [7:0] HEX5,
    
    // ADXL345 Accelerometer Pins
    output wire       GSENSOR_CS_N,
    output wire       GSENSOR_SCLK,
    inout  wire       GSENSOR_SDI,
    inout  wire       GSENSOR_SDO
);

    // --------------------------------------------------------
    // Clock and Reset
    // --------------------------------------------------------
    wire clk = MAX10_CLK1_50;
    wire rst = ~KEY[0]; // DE10-Lite buttons are Active-Low, invert for Active-High reset

    // --------------------------------------------------------
    // Internal Wires
    // --------------------------------------------------------
    wire [31:0] cpu_pc;
    wire [31:0] cpu_inst;
    wire [31:0] cpu_data_addr;
    wire [31:0] cpu_data_out;
    reg  [31:0] cpu_read_data; 
    wire [3:0]  cpu_byte_en;
    wire        cpu_mem_write;
    
    wire [31:0] ram_read_data;
    wire [15:0] sensor_tilt_data;

    // --------------------------------------------------------
    // CPU Instantiation (Change name if yours is different!)
    // --------------------------------------------------------
    riscv_cpu cpu_inst (
        .clk(clk),
        .rst(rst),
        .pc(cpu_pc),
        .instr(cpu_inst),
        .mem_addr(cpu_data_addr),
        .mem_wdata(cpu_data_out),
        .mem_rdata(cpu_read_data),
        .mem_we(cpu_mem_write),
        .mem_byte_en(cpu_byte_en)
    );

    // --------------------------------------------------------
    // Instruction Memory (ROM - Loaded with imem.hex)
    // --------------------------------------------------------
    imem rom_inst (
        .clk(clk),
        .addr(cpu_pc),
        .rdata(cpu_inst)
    );

    // --------------------------------------------------------
    // Data Memory (RAM)
    // --------------------------------------------------------
    dmem ram_inst (
        .clk(clk),
        .we(ram_we), // Using the routed WE signal!
        .byte_en(cpu_byte_en),
        .addr(cpu_data_addr),
        .wdata(cpu_data_out),
        .rdata(ram_read_data)
    );

    // --------------------------------------------------------
    // ADXL345 Sensor Controller
    // --------------------------------------------------------
    adxl345_controller sensor_inst (
        .clk(clk),
        .rst(rst),
        .GSENSOR_CS_N(GSENSOR_CS_N),
        .GSENSOR_SCLK(GSENSOR_SCLK),
        .GSENSOR_SDI(GSENSOR_SDI),
        .GSENSOR_SDO(GSENSOR_SDO),
        .data_x(sensor_tilt_data)
    );

    // --------------------------------------------------------
    // READ ROUTING (Sending data back to the CPU)
    // --------------------------------------------------------
    always @(*) begin
        case (cpu_data_addr[31:16])
            16'h0001: cpu_read_data = ram_read_data;             // 0x00010000 -> RAM
            16'h0002: cpu_read_data = {16'd0, sensor_tilt_data}; // 0x00020000 -> ADXL345
            default:  cpu_read_data = 32'd0;                     // Unknown address
        endcase
    end

    // --------------------------------------------------------
    // WRITE ROUTING (Sending CPU data to hardware)
    // --------------------------------------------------------
    // Only enable Write (WE) for the specific module being addressed
    wire ram_we = cpu_mem_write & (cpu_data_addr[31:16] == 16'h0001);
    wire hex_we = cpu_mem_write & (cpu_data_addr[31:16] == 16'h0003);

    // Register to hold the HEX display value
    reg [31:0] hex_display_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hex_display_reg <= 32'd0;
        end else if (hex_we) begin
            hex_display_reg <= cpu_data_out; // CPU writes to 0x00030000
        end
    end

    // --------------------------------------------------------
    // HEX Display Decoders
    // --------------------------------------------------------
    // Converts the 32-bit register into visual 7-segment output
    hex_decoder h0 (.in(hex_display_reg[3:0]),   .out(HEX0));
    hex_decoder h1 (.in(hex_display_reg[7:4]),   .out(HEX1));
    hex_decoder h2 (.in(hex_display_reg[11:8]),  .out(HEX2));
    hex_decoder h3 (.in(hex_display_reg[15:12]), .out(HEX3));
    hex_decoder h4 (.in(hex_display_reg[19:16]), .out(HEX4));
    hex_decoder h5 (.in(hex_display_reg[23:20]), .out(HEX5));

endmodule


// ========================================================
// Helper Module: 7-Segment Hex Decoder
// ========================================================
module hex_decoder(
    input  [3:0] in,
    output reg [7:0] out // Active Low
);
    always @(*) begin
        case(in)
            4'h0: out = ~8'h3F;
            4'h1: out = ~8'h06;
            4'h2: out = ~8'h5B;
            4'h3: out = ~8'h4F;
            4'h4: out = ~8'h66;
            4'h5: out = ~8'h6D;
            4'h6: out = ~8'h7D;
            4'h7: out = ~8'h07;
            4'h8: out = ~8'h7F;
            4'h9: out = ~8'h67;
            4'hA: out = ~8'h77;
            4'hB: out = ~8'h7C;
            4'hC: out = ~8'h39;
            4'hD: out = ~8'h5E;
            4'hE: out = ~8'h79;
            4'hF: out = ~8'h71;
            default: out = ~8'h00;
        endcase
    end
endmodule