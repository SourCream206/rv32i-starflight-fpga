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
    reg [9:0] player_left;
    reg [9:0] player_right;
    reg [9:0] player_top;
    reg [9:0] player_bottom;
    reg road_left;
    reg road_right;
    reg lane_marker;

    always @(*) begin
        asteroid_size = 10'd8 + ((8'd255 - asteroid_depth) >> 2);
        asteroid_left = (asteroid_x > asteroid_size) ? asteroid_x - asteroid_size : 10'd0;
        asteroid_right = asteroid_x + asteroid_size;
        asteroid_top = (asteroid_y > asteroid_size) ? asteroid_y - asteroid_size : 10'd0;
        asteroid_bottom = asteroid_y + asteroid_size;

        player_left = (player_x > 10'd24) ? player_x - 10'd24 : 10'd0;
        player_right = player_x + 10'd24;
        player_top = 10'd420;
        player_bottom = 10'd460;

        road_left = (pixel_x >= (10'd140 + (pixel_y >> 2))) &&
                    (pixel_x < (10'd145 + (pixel_y >> 2)));
        road_right = (pixel_x >= (10'd495 - (pixel_y >> 2))) &&
                     (pixel_x < (10'd500 - (pixel_y >> 2)));
        lane_marker = (pixel_y[5:4] == 2'b01) &&
                      (pixel_x >= 10'd317) && (pixel_x < 10'd323);

        red = 4'h0;
        green = 4'h0;
        blue = 4'h0;

        if (active_video) begin
            red = 4'h1;
            green = 4'h2;
            blue = 4'h7;

            if (pixel_y >= 10'd300) begin
                red = 4'h0;
                green = 4'h1;
                blue = 4'h1;
            end

            if (road_left || road_right || lane_marker) begin
                red = 4'h8;
                green = 4'h8;
                blue = 4'h8;
            end

            if ((pixel_x >= player_left) && (pixel_x < player_right) &&
                (pixel_y >= player_top) && (pixel_y < player_bottom)) begin
                red = 4'h0;
                green = 4'hF;
                blue = 4'h4;
            end

            if ((pixel_x >= asteroid_left) && (pixel_x < asteroid_right) &&
                (pixel_y >= asteroid_top) && (pixel_y < asteroid_bottom)) begin
                red = 4'hF;
                green = 4'h3;
                blue = 4'h0;
            end
        end
    end
endmodule
