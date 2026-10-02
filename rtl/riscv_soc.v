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
    wire [31:0] dmem_addr, real_dmem_rdata, dmem_wdata, npu_rdata;
    wire        cpu_we;
    wire [3:0]  dmem_byte_en;
    wire [31:0] cpu_rdata; 
    wire [15:0] tilt_x;
    wire [15:0] tilt_y;
    wire illegal_instruction;
    wire [9:0] pixel_x, pixel_y;
    wire [7:0] frame_count;
    wire active_video, frame_tick;
    wire [3:0] video_red, video_green, video_blue;
    wire [15:0] sensor_magnitude = tilt_x[15] ? ((~tilt_x) + 16'd1) : tilt_x;
    reg [9:0] live_player_x;
    reg [9:0] player_target_x;
    reg [9:0] player_target_y;
    reg [9:0] live_player_y;
    reg [9:0] live_asteroid_x;
    reg [9:0] live_asteroid_y;
    reg [7:0] live_asteroid_depth;
    reg [9:0] asteroid_lfsr;
    reg [9:0] game_score;
    reg game_started;
    reg game_over;
    reg button_prev;
    reg  [9:0]  led_reg;
    reg  [9:0]  player_x_reg;
    reg  [9:0]  asteroid_x_reg;
    reg  [9:0]  asteroid_y_reg;
    reg  [7:0]  asteroid_depth_reg;

    wire [7:0] asteroid_step = 8'd2 + {6'd0, game_score[5:4]};

    wire [9:0] next_asteroid_x = 10'd235 + {2'b0, asteroid_lfsr[6:0]};
    wire [9:0] next_asteroid_y = asteroid_lfsr[8]
        ? 10'd205 + {2'b0, asteroid_lfsr[5:0]}
        : 10'd165 + {2'b0, asteroid_lfsr[5:0]};
    // --------------------------------------------------------
    // ADDRESS DECODER (Routing Logic)
    // --------------------------------------------------------
    // Protect the RAM: Only enable writing if address is 0x0001XXXX
    wire ram_we = cpu_we & (dmem_addr[31:16] == 16'h0001);
    // Enable writing to HEX if address is 0x0003XXXX
    wire hex_we = cpu_we & (dmem_addr[31:16] == 16'h0003);
    wire led_we = cpu_we & (dmem_addr[31:16] == 16'h0004);
    wire video_we = cpu_we & (dmem_addr[31:16] == 16'h0005);

    npu_peripheral npu (
        .clk(clk),
        .rst(cpu_rst),
        .bus_we(cpu_we),
        .bus_byte_enable(dmem_byte_en),
        .bus_addr(dmem_addr),
        .bus_wdata(dmem_wdata),
        .bus_rdata(npu_rdata)
    );

    // Read Routing
    assign cpu_rdata = (dmem_addr[31:16] == 16'h0001) ? real_dmem_rdata :
                       (dmem_addr[31:16] == 16'h0002) ? {{16{tilt_x[15]}}, tilt_x} :
                       (dmem_addr[31:16] == 16'h0006) ? npu_rdata :
                       (dmem_addr == 32'h0000_0004)   ? {23'b0, ~BTN1, SW[8:1]} : 32'd0;

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

    assign LEDR = game_score;

    always @(*) begin
        if ($signed(tilt_x) < -16'sd125)
            player_target_x = 10'd70;
        else if ($signed(tilt_x) > 16'sd125)
            player_target_x = 10'd570;
        else
            player_target_x = 10'd320 + ($signed(tilt_x) <<< 1);
        if ($signed(tilt_y) < -16'sd35)
            player_target_y = 10'd285;
        else if ($signed(tilt_y) > 16'sd35)
            player_target_y = 10'd145;
        else
            player_target_y = 10'd215 - ($signed(tilt_y) <<< 1);
    end

    always @(posedge clk) begin
        if (cpu_rst) begin
            live_player_x <= 10'd320;
        end else if (frame_tick) begin
            if (player_target_x > live_player_x + 10'd6)
                live_player_x <= live_player_x + 10'd6;
            else if (player_target_x + 10'd6 < live_player_x)
                live_player_x <= live_player_x - 10'd6;
            else
                live_player_x <= player_target_x;
        end
    end

    // Vertical movement: SW8/SW7 act as hold-to-move up/down (like a
    // d-pad), not an absolute position readout. This starts centered on
    // reset and only moves while a switch is actively held, so the ship
    // no longer defaults to the top of the screen and can be steered in
    // real time together with the tilt-based X movement.
    localparam [9:0] PLAYER_Y_MIN  = 10'd145;
    localparam [9:0] PLAYER_Y_MAX  = 10'd285;
    localparam [9:0] PLAYER_Y_STEP = 10'd3;

    always @(posedge clk) begin
        if (cpu_rst) begin
            live_player_y <= 10'd240;
        end else if (frame_tick) begin
            if (SW[8] && !SW[7]) begin
                if (live_player_y > PLAYER_Y_MIN + PLAYER_Y_STEP)
                    live_player_y <= live_player_y - PLAYER_Y_STEP;
                else
                    live_player_y <= PLAYER_Y_MIN;
            end else if (SW[7] && !SW[8]) begin
                if (live_player_y < PLAYER_Y_MAX - PLAYER_Y_STEP)
                    live_player_y <= live_player_y + PLAYER_Y_STEP;
                else
                    live_player_y <= PLAYER_Y_MAX;
            end else if (player_target_y > live_player_y + 10'd3)
                live_player_y <= live_player_y + 10'd3;
            else if (player_target_y + 10'd3 < live_player_y)
                live_player_y <= live_player_y - 10'd3;
            else
                live_player_y <= player_target_y;
        end
    end

    always @(posedge clk) begin
        if (cpu_rst) begin
            live_asteroid_x <= 10'd320;
            live_asteroid_y <= 10'd220;
            live_asteroid_depth <= 8'd240;
            asteroid_lfsr <= 10'b1011010111;
            game_score <= 10'd0;
            game_started <= 1'b0;
            game_over <= 1'b0;
            button_prev <= 1'b0;
        end else if (frame_tick) begin
            asteroid_lfsr <= {asteroid_lfsr[8:0],
                              asteroid_lfsr[9] ^ asteroid_lfsr[6]};
            button_prev <= ~BTN1;
            if (!game_started) begin
                if ((~BTN1) && !button_prev) begin
                    game_started <= 1'b1;
                    live_asteroid_depth <= 8'd240;
                    live_asteroid_x <= next_asteroid_x;
                    live_asteroid_y <= next_asteroid_y;
                end
            end else if (game_over) begin
                if ((~BTN1) && !button_prev) begin
                    game_over <= 1'b0;
                    game_score <= 10'd0;
                    live_asteroid_depth <= 8'd240;
                    live_asteroid_x <= next_asteroid_x;
                    live_asteroid_y <= next_asteroid_y;
                end
            end else if (live_asteroid_depth > 8'd8) begin
                live_asteroid_depth <= live_asteroid_depth - asteroid_step;
                if ((live_asteroid_depth <= 8'd24) &&
                    (live_asteroid_x > live_player_x - 10'd44) &&
                    (live_asteroid_x < live_player_x + 10'd44) &&
                    (live_asteroid_y > live_player_y - 10'd44) &&
                    (live_asteroid_y < live_player_y + 10'd44)) begin
                    game_over <= 1'b1;
                end
            end else if ((live_asteroid_x > live_player_x - 10'd44) &&
                         (live_asteroid_x < live_player_x + 10'd44) &&
                         (live_asteroid_y > live_player_y - 10'd44) &&
                         (live_asteroid_y < live_player_y + 10'd44)) begin
                game_over <= 1'b1;
            end else begin
                game_score <= game_score + 10'd1;
                live_asteroid_depth <= 8'd240;
                live_asteroid_x <= next_asteroid_x;
                live_asteroid_y <= next_asteroid_y;
            end
        end
    end

    hex_decoder h0 (.in(game_score[3:0]), .out(HEX0));
    hex_decoder h1 (.in(game_score[7:4]), .out(HEX1));
    hex_decoder h2 (.in({2'b0, game_score[9:8]}), .out(HEX2));
    hex_decoder h3 (.in(4'h0), .out(HEX3));
    hex_decoder h4 (.in(4'h0), .out(HEX4));
    hex_decoder h5 (.in(4'h0), .out(HEX5));

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
        .player_y(live_player_y),
        .asteroid_x(live_asteroid_x),
        .asteroid_y(live_asteroid_y),
        .asteroid_depth(live_asteroid_depth),
        .game_score(game_score),
        .game_started(game_started),
        .game_over(game_over),
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
        .data_x(tilt_x),
        .data_y(tilt_y)
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