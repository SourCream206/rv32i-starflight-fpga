module game_video (
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       active_video,
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
                tunnel_ring = (tunnel_radius[4:0] <= 2) && (tunnel_radius > 10'd20);
                tunnel_spoke = ((pixel_x >= (10'd320 - (pixel_y >> 3))) &&
                                                (pixel_x < (10'd323 - (pixel_y >> 3)))) ||
                                             ((pixel_x >= (10'd317 + (pixel_y >> 3))) &&
                                                (pixel_x < (10'd320 + (pixel_y >> 3))));

                ship_pixel = ((pixel_y >= 10'd438) && (pixel_y < 10'd442) &&
                                            (pixel_x >= player_x - 10'd28) &&
                                            (pixel_x < player_x + 10'd29)) ||
                                         ((pixel_x >= player_x - 10'd3) &&
                                            (pixel_x < player_x + 10'd3) &&
                                            (pixel_y >= 10'd420) && (pixel_y < 10'd455));

                asteroid_pixel = ((((pixel_x >= asteroid_left) &&
                                                        (pixel_x < asteroid_left + 10'd3)) ||
                                                     ((pixel_x >= asteroid_right - 10'd3) &&
                                                        (pixel_x < asteroid_right))) &&
                                                    (pixel_y >= asteroid_top) &&
                                                    (pixel_y < asteroid_bottom)) ||
                                                 ((((pixel_y >= asteroid_top) &&
                                                        (pixel_y < asteroid_top + 10'd3)) ||
                                                     ((pixel_y >= asteroid_bottom - 10'd3) &&
                                                        (pixel_y < asteroid_bottom))) &&
                                                    (pixel_x >= asteroid_left) &&
                                                    (pixel_x < asteroid_right));

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
