module vga_timing (
    input  wire       clk,
    input  wire       rst,
    output reg  [9:0] pixel_x,
    output reg  [9:0] pixel_y,
    output wire       active_video,
    output wire       hsync,
    output wire       vsync,
    output wire       frame_tick
);
    localparam H_VISIBLE = 10'd640;
    localparam H_FRONT   = 10'd16;
    localparam H_SYNC    = 10'd96;
    localparam H_BACK    = 10'd48;
    localparam H_TOTAL   = 10'd800;
    localparam V_VISIBLE = 10'd480;
    localparam V_FRONT   = 10'd10;
    localparam V_SYNC    = 10'd2;
    localparam V_BACK    = 10'd33;
    localparam V_TOTAL   = 10'd525;

    reg pixel_phase;

    assign active_video = (pixel_x < H_VISIBLE) && (pixel_y < V_VISIBLE);
    assign hsync = !((pixel_x >= H_VISIBLE + H_FRONT) &&
                     (pixel_x < H_VISIBLE + H_FRONT + H_SYNC));
    assign vsync = !((pixel_y >= V_VISIBLE + V_FRONT) &&
                     (pixel_y < V_VISIBLE + V_FRONT + V_SYNC));
    assign frame_tick = (pixel_x == 10'd0) && (pixel_y == 10'd0) && pixel_phase;

    always @(posedge clk) begin
        if (rst) begin
            pixel_phase <= 1'b0;
            pixel_x <= 10'd0;
            pixel_y <= 10'd0;
        end else begin
            pixel_phase <= ~pixel_phase;
            if (pixel_phase) begin
                if (pixel_x == H_TOTAL - 1'b1) begin
                    pixel_x <= 10'd0;
                    if (pixel_y == V_TOTAL - 1'b1)
                        pixel_y <= 10'd0;
                    else
                        pixel_y <= pixel_y + 1'b1;
                end else begin
                    pixel_x <= pixel_x + 1'b1;
                end
            end
        end
    end
endmodule
