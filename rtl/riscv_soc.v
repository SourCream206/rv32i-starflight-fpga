module riscv_soc (
    input  wire       clk, 
    input  wire       rst,  
    input  wire       BTN1,
    input  wire [8:1] SW,   
    output wire [9:0] LEDR,
    
    // Updated to all 6 HEX displays (8-bit for decoders)
    output wire [7:0] HEX0,
    output wire [7:0] HEX1,
    output wire [7:0] HEX2,
    output wire [7:0] HEX3,
    output wire [7:0] HEX4,
    output wire [7:0] HEX5,
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B,
    output wire       VGA_HS,
    output wire       VGA_VS,
    output wire       GSENSOR_CS_N,
    output wire       GSENSOR_SCLK,
    inout  wire       GSENSOR_SDI,
    inout  wire       GSENSOR_SDO
);

    wire cpu_rst = ~rst; 
    wire [31:0] imem_addr, imem_rdata;
    wire [31:0] dmem_addr, real_dmem_rdata, dmem_wdata;
    wire        cpu_we;
    wire [3:0]  dmem_byte_en;
    wire [31:0] cpu_rdata; 
    wire [15:0] tilt_x;
    wire illegal_instruction;
    wire [9:0] pixel_x, pixel_y;
    wire [7:0] frame_count;
    wire active_video, frame_tick;
    wire [3:0] video_red, video_green, video_blue;
    reg [9:0] live_player_x;
    reg [9:0] live_asteroid_x;
    reg [9:0] live_asteroid_y;
    reg [7:0] live_asteroid_depth;
    reg [9:0] asteroid_lfsr;
    reg  [9:0]  led_reg;
    reg  [9:0]  player_x_reg;
    reg  [9:0]  asteroid_x_reg;
    reg  [9:0]  asteroid_y_reg;
    reg  [7:0]  asteroid_depth_reg;

    // --------------------------------------------------------
    // ADDRESS DECODER (Routing Logic)
    // --------------------------------------------------------
    // Protect the RAM: Only enable writing if address is 0x0001XXXX
    wire ram_we = cpu_we & (dmem_addr[31:16] == 16'h0001);
    
    // Enable writing to HEX if address is 0x0003XXXX
    wire hex_we = cpu_we & (dmem_addr[31:16] == 16'h0003);
    wire led_we = cpu_we & (dmem_addr[31:16] == 16'h0004);
    wire video_we = cpu_we & (dmem_addr[31:16] == 16'h0005);

    // Read Routing
    assign cpu_rdata = (dmem_addr[31:16] == 16'h0001) ? real_dmem_rdata :          // RAM
                       (dmem_addr[31:16] == 16'h0002) ? {{16{tilt_x[15]}}, tilt_x} : // Signed sensor
                       (dmem_addr == 32'h0000_0004)   ? {23'b0, ~BTN1, SW[8:1]} : 32'd0;  // Switches

    // --------------------------------------------------------
    // HEX Display Register
    // --------------------------------------------------------
    reg [31:0] hex_display_reg;

    always @(posedge clk) begin
        if (cpu_rst) begin
            hex_display_reg <= 32'd0;
            led_reg <= 10'd0;
            player_x_reg <= 10'd320;
            asteroid_x_reg <= 10'd320;
            asteroid_y_reg <= 10'd180;
            asteroid_depth_reg <= 8'd220;
        end else begin
            if (hex_we) hex_display_reg <= dmem_wdata;
            if (led_we) led_reg <= dmem_wdata[9:0];
            if (video_we) begin
                case (dmem_addr[5:2])
                    4'd0: player_x_reg <= dmem_wdata[9:0];
                    4'd1: asteroid_x_reg <= dmem_wdata[9:0];
                    4'd2: asteroid_y_reg <= dmem_wdata[9:0];
                    4'd3: asteroid_depth_reg <= dmem_wdata[7:0];
                    default: ;
                endcase
            end
        end
    end

    assign LEDR = led_reg;

    always @(*) begin
        if ($signed(tilt_x) < -16'sd960)
            live_player_x = 10'd80;
        else if ($signed(tilt_x) > 16'sd960)
            live_player_x = 10'd560;
        else
            live_player_x = 10'd320 + ($signed(tilt_x) >>> 2);
    end

    always @(posedge clk) begin
        if (cpu_rst) begin
            live_asteroid_x <= 10'd320;
            live_asteroid_y <= 10'd220;
            live_asteroid_depth <= 8'd240;
            asteroid_lfsr <= 10'b1011010111;
        end else if (frame_tick) begin
            asteroid_lfsr <= {asteroid_lfsr[8:0],
                              asteroid_lfsr[9] ^ asteroid_lfsr[6]};
            if (live_asteroid_depth > 8'd8)
                live_asteroid_depth <= live_asteroid_depth - 8'd2;
            else begin
                live_asteroid_depth <= 8'd240;
                live_asteroid_x <= 10'd80 + {1'b0, asteroid_lfsr[8:0]};
                live_asteroid_y <= 10'd120 + {2'b0, asteroid_lfsr[7:0]};
            end
        end
    end

    hex_decoder h0 (.in(hex_display_reg[3:0]),   .out(HEX0));
    hex_decoder h1 (.in(hex_display_reg[7:4]),   .out(HEX1));
    hex_decoder h2 (.in(hex_display_reg[11:8]),  .out(HEX2));
    hex_decoder h3 (.in(hex_display_reg[15:12]), .out(HEX3));
    hex_decoder h4 (.in(hex_display_reg[19:16]), .out(HEX4));
    hex_decoder h5 (.in(hex_display_reg[23:20]), .out(HEX5));

    vga_timing video_timing (
        .clk(clk),
        .rst(cpu_rst),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .active_video(active_video),
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .frame_tick(frame_tick),
        .frame_count(frame_count)
    );

    game_video video_renderer (
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .active_video(active_video),
        .frame_count(frame_count),
        .player_x(live_player_x),
        .asteroid_x(live_asteroid_x),
        .asteroid_y(live_asteroid_y),
        .asteroid_depth(live_asteroid_depth),
        .red(video_red),
        .green(video_green),
        .blue(video_blue)
    );

    assign VGA_R = video_red;
    assign VGA_G = video_green;
    assign VGA_B = video_blue;

    // --------------------------------------------------------
    // CORE MODULES
    // --------------------------------------------------------
    riscVCPU cpu (
        .clk(clk),
        .rst(cpu_rst),
        .imem_addr(imem_addr), 
        .imem_rdata(imem_rdata),
        .dmem_addr(dmem_addr), 
        .dmem_rdata(cpu_rdata),
        .dmem_wdata(dmem_wdata), 
        .dmem_we(cpu_we),
        .dmem_byte_en(dmem_byte_en),
        .illegal_instruction(illegal_instruction)
    );

    imem instruction_memory (.addr(imem_addr), .rdata(imem_rdata));
    
    dmem data_memory (
        .clk(clk), 
        .we(ram_we), // Using protected RAM Write Enable!
        .byte_en(dmem_byte_en), 
        .addr(dmem_addr),
        .wdata(dmem_wdata), 
        .rdata(real_dmem_rdata) 
    );

    adxl345_controller gsensor (
        .clk(clk),
        .rst(cpu_rst),
        .GSENSOR_CS_N(GSENSOR_CS_N),
        .GSENSOR_SCLK(GSENSOR_SCLK),
        .GSENSOR_SDI(GSENSOR_SDI),
        .GSENSOR_SDO(GSENSOR_SDO),
        .data_x(tilt_x)
    );
endmodule

module hex_decoder(input [3:0] in, output reg [7:0] out);
    always @(*) begin
        case(in)
            4'h0: out = ~8'h3F; 4'h1: out = ~8'h06; 4'h2: out = ~8'h5B; 4'h3: out = ~8'h4F;
            4'h4: out = ~8'h66; 4'h5: out = ~8'h6D; 4'h6: out = ~8'h7D; 4'h7: out = ~8'h07;
            4'h8: out = ~8'h7F; 4'h9: out = ~8'h67; 4'hA: out = ~8'h77; 4'hB: out = ~8'h7C;
            4'hC: out = ~8'h39; 4'hD: out = ~8'h5E; 4'hE: out = ~8'h79; 4'hF: out = ~8'h71;
            default: out = ~8'h00;
        endcase
    end
endmodule