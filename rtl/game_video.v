module game_video (
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       active_video,
    input  wire [7:0] frame_count,
    input  wire [9:0] player_x,
    input  wire [9:0] player_y,
    input  wire [9:0] asteroid_x,
    input  wire [9:0] asteroid_y,
    input  wire [7:0] asteroid_depth,
    input  wire [9:0] game_score,
    input  wire       game_started,
    input  wire       game_over,
    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue
);
    // ------------------------------------------------------------------
    // Perspective tunnel & starfield (background)
    // ------------------------------------------------------------------
    reg [9:0] dx, dy;
    reg [9:0] r_oct;
    reg [9:0] ring_phase;
    reg       tunnel_ring;
    reg       spoke_diag;
    reg       star_pixel;
    reg [9:0] lane_dx;
    reg       lane_line;
    reg       score_bar;
    reg       start_panel;
    reg       start_blink;
    reg       score_pixel;
    reg       death_panel;
    reg       start_text_pixel;
    reg       death_text_pixel;
    reg [3:0] score_hundreds, score_tens, score_ones;
    reg [6:0] score_seg_hundreds, score_seg_tens, score_seg_ones;

    function seven_segment_pixel;
        input [9:0] local_x;
        input [9:0] local_y;
        input [6:0] segments;
        begin
            seven_segment_pixel =
                ((segments[6] && local_y < 10'd8 && local_x >= 10'd8 && local_x < 10'd52) ||
                 (segments[5] && local_x < 10'd8 && local_y >= 10'd8 && local_y < 10'd58) ||
                 (segments[4] && local_x >= 10'd52 && local_y >= 10'd8 && local_y < 10'd58) ||
                 (segments[3] && local_y >= 10'd58 && local_y < 10'd66 && local_x >= 10'd8 && local_x < 10'd52) ||
                 (segments[2] && local_x < 10'd8 && local_y >= 10'd66 && local_y < 10'd116) ||
                 (segments[1] && local_x >= 10'd52 && local_y >= 10'd66 && local_y < 10'd116) ||
                 (segments[0] && local_y >= 10'd116 && local_y < 10'd124 && local_x >= 10'd8 && local_x < 10'd52));
        end
    endfunction

    function [6:0] digit_segments;
        input [3:0] digit;
        begin
            case (digit)
                4'd0: digit_segments = 7'b1111110;
                4'd1: digit_segments = 7'b0110000;
                4'd2: digit_segments = 7'b1101101;
                4'd3: digit_segments = 7'b1111001;
                4'd4: digit_segments = 7'b0110011;
                4'd5: digit_segments = 7'b1011011;
                4'd6: digit_segments = 7'b1011111;
                4'd7: digit_segments = 7'b1110000;
                4'd8: digit_segments = 7'b1111111;
                4'd9: digit_segments = 7'b1111011;
                default: digit_segments = 7'b0000001;
            endcase
        end
    endfunction

    function [4:0] glyph_row;
        input [7:0] character;
        input [2:0] row;
        begin
            case (character)
                8'h41: case (row) 3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001; 3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b11111; 3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001; default: glyph_row=5'b10001; endcase
                8'h45: case (row) 3'd0: glyph_row=5'b11111; 3'd1: glyph_row=5'b10000; 3'd2: glyph_row=5'b10000; 3'd3: glyph_row=5'b11110; 3'd4: glyph_row=5'b10000; 3'd5: glyph_row=5'b10000; default: glyph_row=5'b11111; endcase
                8'h47: case (row) 3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001; 3'd2: glyph_row=5'b10000; 3'd3: glyph_row=5'b10111; 3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001; default: glyph_row=5'b01110; endcase
                8'h4D: case (row) 3'd0: glyph_row=5'b10001; 3'd1: glyph_row=5'b11011; 3'd2: glyph_row=5'b10101; 3'd3: glyph_row=5'b10001; 3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001; default: glyph_row=5'b10001; endcase
                8'h4F: case (row) 3'd0: glyph_row=5'b01110; 3'd1: glyph_row=5'b10001; 3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b10001; 3'd4: glyph_row=5'b10001; 3'd5: glyph_row=5'b10001; default: glyph_row=5'b01110; endcase
                8'h52: case (row) 3'd0: glyph_row=5'b11110; 3'd1: glyph_row=5'b10001; 3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b11110; 3'd4: glyph_row=5'b10100; 3'd5: glyph_row=5'b10010; default: glyph_row=5'b10001; endcase
                8'h53: case (row) 3'd0: glyph_row=5'b01111; 3'd1: glyph_row=5'b10000; 3'd2: glyph_row=5'b10000; 3'd3: glyph_row=5'b01110; 3'd4: glyph_row=5'b00001; 3'd5: glyph_row=5'b00001; default: glyph_row=5'b11110; endcase
                8'h54: case (row) 3'd0: glyph_row=5'b11111; 3'd1: glyph_row=5'b00100; 3'd2: glyph_row=5'b00100; 3'd3: glyph_row=5'b00100; 3'd4: glyph_row=5'b00100; 3'd5: glyph_row=5'b00100; default: glyph_row=5'b00100; endcase
                8'h56: case (row) 3'd0: glyph_row=5'b10001; 3'd1: glyph_row=5'b10001; 3'd2: glyph_row=5'b10001; 3'd3: glyph_row=5'b10001; 3'd4: glyph_row=5'b01010; 3'd5: glyph_row=5'b01010; default: glyph_row=5'b00100; endcase
                default: glyph_row=5'b00000;
            endcase
        end
    endfunction

    function glyph_pixel;
        input [9:0] local_x;
        input [9:0] local_y;
        input [7:0] character;
        reg [4:0] row_bits;
        begin
            if ((local_x < 10'd20) && (local_y < 10'd28)) begin
                row_bits = glyph_row(character, local_y[4:2]);
                glyph_pixel = row_bits[4 - local_x[4:2]];
            end else begin
                glyph_pixel = 1'b0;
            end
        end
    endfunction

    // ------------------------------------------------------------------
    // Player ("Arwing") geometry - sized up slightly ("zoom in") vs before
    // ------------------------------------------------------------------
    reg [9:0] ship_dx;
    reg [9:0] wing_width;
    reg       ship_nose;
    reg       ship_body;
    reg       ship_wings;
    reg       ship_thruster;
    reg       ship_pixel;

    // ------------------------------------------------------------------
    // Asteroid geometry - properly widened perspective math (see notes
    // below) so the asteroid actually travels from the vanishing point
    // out to its real random screen position, instead of sitting near
    // dead-center for its whole approach.
    // ------------------------------------------------------------------
    reg [7:0]  ast_size_scale;   // 0..247, grows the WHOLE approach (controls size)
    reg [8:0]  ast_lat_raw;
    reg [7:0]  ast_lat_scale;    // saturates early (controls how far off-center it is)
    reg        ast_neg_x, ast_neg_y;
    reg [9:0]  ast_off_x, ast_off_y;
    reg [19:0] ast_prod_x, ast_prod_y;  // WIDE intermediates: a multiply that
                                        // feeds a shift is only sized by its
                                        // own operands in Verilog, not by
                                        // where the result is used, so this
                                        // product must be computed into a
                                        // wide register BEFORE shifting or
                                        // it silently truncates.
    reg [9:0]  ast_screen_x, ast_screen_y;
    reg [9:0]  ast_dx, ast_dy;
    reg [9:0]  ast_size;
    reg [9:0]  ast_dist;
    reg        asteroid_pixel;

    always @(*) begin
        // -------------------------------------------------------------
        // 1. Perspective tunnel & starfield
        // -------------------------------------------------------------
        dx = (pixel_x >= 10'd320) ? (pixel_x - 10'd320) : (10'd320 - pixel_x);
        dy = (pixel_y >= 10'd240) ? (pixel_y - 10'd240) : (10'd240 - pixel_y);

        r_oct = (dx > dy) ? (dx + (dy >> 1)) : (dy + (dx >> 1));

        ring_phase = 10'd0;
        tunnel_ring = 1'b0;
        spoke_diag = 1'b0;

        lane_dx = (pixel_y > 10'd240) ? (((pixel_y - 10'd240) * 10'd3) >> 2) : 10'd0;
        lane_line = (pixel_y > 10'd242) &&
                (((pixel_x >= 10'd320 - lane_dx) && (pixel_x < 10'd322 - lane_dx)) ||
                 ((pixel_x >= 10'd320 + lane_dx) && (pixel_x < 10'd322 + lane_dx)));
        score_bar = (pixel_y >= 10'd18) && (pixel_y < 10'd22) &&
                (pixel_x >= 10'd40) && (pixel_x < 10'd40 + {4'd0, game_score[5:0]});

        star_pixel = ((pixel_x[5:0] == 6'b101010) &&
                  (pixel_y[4:0] == 5'b10101) && (r_oct > 10'd110));

        start_panel = (((pixel_x >= 10'd120) && (pixel_x < 10'd520) &&
                         (pixel_y >= 10'd105) && (pixel_y < 10'd375)) &&
                        ((pixel_x < 10'd126) || (pixel_x >= 10'd514) ||
                         (pixel_y < 10'd111) || (pixel_y >= 10'd369))) ||
                       (((pixel_y >= 10'd230) && (pixel_y < 10'd250)) &&
                        (pixel_x >= 10'd205) && (pixel_x < 10'd435));

        start_blink = frame_count[4];
        start_text_pixel = glyph_pixel(pixel_x - 10'd195, pixel_y - 10'd180, 8'h53) ||
                   glyph_pixel(pixel_x - 10'd223, pixel_y - 10'd180, 8'h54) ||
                   glyph_pixel(pixel_x - 10'd251, pixel_y - 10'd180, 8'h41) ||
                   glyph_pixel(pixel_x - 10'd279, pixel_y - 10'd180, 8'h52) ||
                   glyph_pixel(pixel_x - 10'd307, pixel_y - 10'd180, 8'h54);
        death_text_pixel = glyph_pixel(pixel_x - 10'd215, pixel_y - 10'd150, 8'h47) ||
                   glyph_pixel(pixel_x - 10'd243, pixel_y - 10'd150, 8'h41) ||
                   glyph_pixel(pixel_x - 10'd271, pixel_y - 10'd150, 8'h4D) ||
                   glyph_pixel(pixel_x - 10'd299, pixel_y - 10'd150, 8'h45) ||
                   glyph_pixel(pixel_x - 10'd215, pixel_y - 10'd190, 8'h4F) ||
                   glyph_pixel(pixel_x - 10'd243, pixel_y - 10'd190, 8'h56) ||
                   glyph_pixel(pixel_x - 10'd271, pixel_y - 10'd190, 8'h45) ||
                   glyph_pixel(pixel_x - 10'd299, pixel_y - 10'd190, 8'h52);

        score_hundreds = game_score / 10'd100;
        score_tens = (game_score / 10'd10) % 10'd10;
        score_ones = game_score % 10'd10;
        score_seg_hundreds = digit_segments(score_hundreds);
        score_seg_tens = digit_segments(score_tens);
        score_seg_ones = digit_segments(score_ones);
        score_pixel = seven_segment_pixel(pixel_x - 10'd190, pixel_y - 10'd235, score_seg_hundreds) ||
              seven_segment_pixel(pixel_x - 10'd270, pixel_y - 10'd235, score_seg_tens) ||
              seven_segment_pixel(pixel_x - 10'd350, pixel_y - 10'd235, score_seg_ones);
        death_panel = ((pixel_x >= 10'd160) && (pixel_x < 10'd480) &&
               (pixel_y >= 10'd125) && (pixel_y < 10'd375)) &&
                  ((pixel_x < 10'd166) || (pixel_x >= 10'd474) ||
                   (pixel_y < 10'd141) || (pixel_y >= 10'd319));

        // -------------------------------------------------------------
        // 2. Player ship (Arwing), driven by player_x/player_y directly
        // -------------------------------------------------------------
        ship_dx = (pixel_x >= player_x) ? (pixel_x - player_x) : (player_x - pixel_x);

        ship_nose = (pixel_y >= player_y - 10'd34) && (pixel_y < player_y - 10'd11) &&
                (ship_dx <= (((pixel_y - (player_y - 10'd34)) >> 1) + 10'd1));

        ship_body = (pixel_y >= player_y - 10'd11) && (pixel_y < player_y + 10'd13) &&
                (ship_dx <= 10'd9);

        wing_width = ((pixel_y - (player_y - 10'd9)) * 10'd4) >> 1;
        ship_wings = (pixel_y >= player_y - 10'd9) && (pixel_y < player_y + 10'd17) &&
                 (ship_dx <= wing_width);

        ship_thruster = (pixel_y >= player_y + 10'd13) && (pixel_y < player_y + 10'd27) &&
                (ship_dx <= 10'd6);

        ship_pixel = ship_nose || ship_body || ship_wings || ship_thruster;

        // -------------------------------------------------------------
        // 3. Asteroid perspective projection (bug fixed) + shading
        // -------------------------------------------------------------
        ast_size_scale = 8'd255 - asteroid_depth;              // 0..247 over full approach

        // Lateral spread reaches its max about half-way through the
        // approach (saturating "<<1"), so the asteroid visibly slides
        // out toward its real position early enough to dodge, rather
        // than only jumping out right before it hits you.
        ast_lat_raw   = ({1'b0, ast_size_scale} << 1);
        ast_lat_scale = (ast_lat_raw > 9'd255) ? 8'd255 : ast_lat_raw[7:0];

        ast_neg_x = (asteroid_x < 10'd320);
        ast_off_x = ast_neg_x ? (10'd320 - asteroid_x) : (asteroid_x - 10'd320);
        ast_neg_y = (asteroid_y < 10'd240);
        ast_off_y = ast_neg_y ? (10'd240 - asteroid_y) : (asteroid_y - 10'd240);

        // Compute the products on their own (into wide regs) BEFORE any
        // shifting - this is the actual fix for the truncation bug.
        ast_prod_x = ast_off_x * ast_lat_scale;
        ast_prod_y = ast_off_y * ast_lat_scale;

        ast_screen_x = ast_neg_x ? (10'd320 - ast_prod_x[19:8]) : (10'd320 + ast_prod_x[19:8]);
        ast_screen_y = ast_neg_y ? (10'd240 - ast_prod_y[19:8]) : (10'd240 + ast_prod_y[19:8]);

        ast_dx = (pixel_x >= ast_screen_x) ? (pixel_x - ast_screen_x) : (ast_screen_x - pixel_x);
        ast_dy = (pixel_y >= ast_screen_y) ? (pixel_y - ast_screen_y) : (ast_screen_y - pixel_y);

        // Smaller overall (was 6 + scale>>2, maxing near 67px radius;
        // now 4 + scale>>3, maxing near 34px radius) so there's real
        // room to dodge.
        ast_size = 10'd4 + ({2'b0, ast_size_scale} >> 3);

        ast_dist = (ast_dx > ast_dy) ? (ast_dx + (ast_dy >> 1)) : (ast_dy + (ast_dx >> 1));
        asteroid_pixel = (ast_dist <= ast_size);

        // -------------------------------------------------------------
        // 4. Color compositing
        // -------------------------------------------------------------
        if (!active_video) begin
            red   = 4'h0;
            green = 4'h0;
            blue  = 4'h0;
        end else if (!game_started) begin
            red   = 4'h0;
            green = start_text_pixel ? 4'hF : (start_panel ? (start_blink ? 4'hD : 4'h6) : 4'h0);
            blue  = start_text_pixel ? 4'hF : (start_panel ? 4'hF : (pixel_y[5] ? 4'h2 : 4'h1));
        end else if (game_over) begin
            red   = 4'h0;
            green = (death_panel || death_text_pixel || score_pixel) ? 4'hC : 4'h0;
            blue  = (death_panel || death_text_pixel || score_pixel) ? 4'h8 : 4'h1;
        end else if (ship_pixel) begin
            if ((pixel_y >= player_y - 10'd13) && (pixel_y < player_y - 10'd2) && (ship_dx <= 10'd3)) begin
                red = 4'h0; green = 4'hE; blue = 4'hF;               // cyan cockpit glass
            end else if ((pixel_y >= player_y - 10'd2) && (ship_dx >= wing_width - 10'd3)) begin
                red = 4'hF; green = 4'h1; blue = 4'h2;               // red laser cannons
            end else if (ship_wings && (ship_dx > 10'd9)) begin
                red = 4'h1; green = 4'h5; blue = 4'hE;               // metallic blue wings
            end else if (ship_thruster) begin
                red = 4'h0; green = 4'hC; blue = 4'hF;                 // steady plasma
            end else begin
                red = 4'hE; green = 4'hE; blue = 4'hF;               // white hull
            end
        end else if (asteroid_pixel) begin
            if (ast_dist >= ast_size - 10'd2) begin
                red = 4'hF; green = 4'h6; blue = 4'h0;               // molten outer rim
            end else if ((pixel_x < ast_screen_x) && (pixel_y < ast_screen_y)) begin
                red = 4'hF; green = 4'hB; blue = 4'h4;               // amber highlight
            end else if (pixel_x > ast_screen_x + (ast_size >> 2)) begin
                red = 4'h7; green = 4'h1; blue = 4'h0;               // rust shadow
            end else begin
                red = 4'hD; green = 4'h4; blue = 4'h1;               // fiery body
            end
        end else if (tunnel_ring) begin
            red = 4'h0; green = 4'hC; blue = 4'hF;                   // neon cyan rings
        end else if (spoke_diag) begin
            red = 4'h9; green = 4'h2; blue = 4'hD;                   // magenta corridor rails
        end else if (score_bar) begin
            red = 4'h0; green = 4'h8; blue = 4'hA;
        end else if (lane_line) begin
            red = 4'h0; green = 4'h3; blue = 4'h6;
        end else if (star_pixel) begin
            red = 4'hF; green = 4'hF; blue = 4'hD;                   // stars
        end else begin
            red   = {2'b0, pixel_y[9:8]};
            green = 4'h0;
            blue  = 4'h2 + {2'b0, pixel_y[8:7]};
        end
    end
endmodule