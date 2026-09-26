module game_video (
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       active_video,
    input  wire [7:0] frame_count,
    input  wire [9:0] player_x,
    input  wire [9:0] asteroid_x,
    input  wire [9:0] asteroid_y,
    input  wire [7:0] asteroid_depth,
    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue
);
    reg [9:0] asteroid_size;
    reg [9:0] asteroid_left;
    reg [9:0] asteroid_right;
    reg [9:0] asteroid_top;
    reg [9:0] asteroid_bottom;
    reg [9:0] dx;
    reg [9:0] dy;
    reg [9:0] tunnel_radius;
    reg [9:0] animated_radius;
    reg [9:0] ship_center;
    reg [9:0] ship_width;
    reg [9:0] ship_height;
    reg [9:0] asteroid_center_x;
    reg [9:0] asteroid_center_y;
    reg [9:0] asteroid_distance;
    reg tunnel_ring;
    reg tunnel_spoke;
    reg ship_pixel;
    reg asteroid_pixel;

    always @(*) begin
        asteroid_size = 10'd8 + ((8'd255 - asteroid_depth) >> 2);
        asteroid_left = (asteroid_x > asteroid_size) ? asteroid_x - asteroid_size : 10'd0;
        asteroid_right = asteroid_x + asteroid_size;
        asteroid_top = (asteroid_y > asteroid_size) ? asteroid_y - asteroid_size : 10'd0;
        asteroid_bottom = asteroid_y + asteroid_size;

                dx = (pixel_x >= 10'd320) ? pixel_x - 10'd320 : 10'd320 - pixel_x;
                dy = (pixel_y >= 10'd240) ? pixel_y - 10'd240 : 10'd240 - pixel_y;
                tunnel_radius = (dx > dy) ? dx : dy;
                animated_radius = 10'd24 + {2'b0, frame_count};
                tunnel_ring = (tunnel_radius >= animated_radius) &&
                                            (tunnel_radius < animated_radius + 10'd3) &&
                                            (animated_radius < 10'd300);
                tunnel_spoke = ((pixel_x >= (10'd320 - (pixel_y >> 2))) &&
                                                (pixel_x < (10'd323 - (pixel_y >> 2)))) ||
                                             ((pixel_x >= (10'd317 + (pixel_y >> 2))) &&
                                                (pixel_x < (10'd320 + (pixel_y >> 2)))) ||
                                             ((pixel_y >= (10'd240 - (pixel_x >> 3))) &&
                                                (pixel_y < (10'd243 - (pixel_x >> 3)))) ||
                                             ((pixel_y >= (10'd237 + (pixel_x >> 3))) &&
                                                (pixel_y < (10'd240 + (pixel_x >> 3))));

                ship_center = player_x;
                ship_width = 10'd34;
                ship_height = 10'd42;
                ship_pixel = ((pixel_y >= 10'd430) && (pixel_y < 10'd434) &&
                                            (pixel_x >= ship_center - ship_width) &&
                                            (pixel_x < ship_center + ship_width)) ||
                                         ((pixel_y >= 10'd434) && (pixel_y < 10'd455) &&
                                            (pixel_x >= ship_center - ((pixel_y - 10'd430) << 1)) &&
                                            (pixel_x < ship_center + ((pixel_y - 10'd430) << 1))) ||
                                         ((pixel_x >= ship_center - 10'd4) &&
                                            (pixel_x < ship_center + 10'd4) &&
                                            (pixel_y >= 10'd410) && (pixel_y < 10'd430));

                asteroid_center_x = asteroid_x;
                asteroid_center_y = asteroid_y;
                asteroid_distance = ((pixel_x >= asteroid_center_x) ?
                                                         pixel_x - asteroid_center_x : asteroid_center_x - pixel_x) +
                                                        ((pixel_y >= asteroid_center_y) ?
                                                         pixel_y - asteroid_center_y : asteroid_center_y - pixel_y);
                asteroid_pixel = (asteroid_distance >= asteroid_size - 10'd3) &&
                                                 (asteroid_distance <= asteroid_size) &&
                                                 (pixel_x >= asteroid_left) && (pixel_x < asteroid_right) &&
                                                 (pixel_y >= asteroid_top) && (pixel_y < asteroid_bottom);

        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;

        if (active_video) begin
            if (tunnel_ring || tunnel_spoke || ship_pixel || asteroid_pixel) begin
                red = 4'h8;
                green = 4'h8;
                blue = 4'h8;
            end
        end
    end
endmodule
