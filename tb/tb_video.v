`timescale 1ns/1ps

module tb_video;
    reg clk;
    reg rst;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire active_video;
    wire hsync;
    wire vsync;
    wire frame_tick;
    reg [3:0] red;
    reg [3:0] green;
    reg [3:0] blue;
    wire [3:0] rendered_red;
    wire [3:0] rendered_green;
    wire [3:0] rendered_blue;

    vga_timing timing (
        .clk(clk),
        .rst(rst),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .active_video(active_video),
        .hsync(hsync),
        .vsync(vsync),
        .frame_tick(frame_tick)
    );

    game_video renderer (
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .active_video(active_video),
        .player_x(10'd320),
        .asteroid_x(10'd320),
        .asteroid_y(10'd180),
        .asteroid_depth(8'd220),
        .red(rendered_red),
        .green(rendered_green),
        .blue(rendered_blue)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        #20;
        rst = 1'b0;

        repeat (1601) @(posedge clk);
        if (pixel_x !== 10'd0 || pixel_y !== 10'd1)
            $fatal(1, "Horizontal timing failed: x=%d y=%d", pixel_x, pixel_y);

        @(posedge frame_tick);

        force timing.pixel_x = 10'd320;
        force timing.pixel_y = 10'd440;
        #1;
        if (rendered_green == 4'd0)
            $fatal(1, "Player was not rendered");

        force timing.pixel_x = 10'd304;
        force timing.pixel_y = 10'd180;
        #1;
        if (rendered_red == 4'd0)
            $fatal(1, "Asteroid was not rendered");

        release timing.pixel_x;
        release timing.pixel_y;
        $display("PASS: VGA timing and procedural renderer tests");
        $finish;
    end
endmodule
