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

    // Perspective tunnel & background signals
    reg [9:0] dx;
    reg [9:0] dy;
    reg [9:0] r_oct;
    reg [9:0] ring_phase;
    reg       tunnel_ring;
    reg       spoke_diag;
    reg       star_pixel;

    // Player (Arwing) geometry signals
    reg [9:0] ship_dx;
    reg [9:0] wing_width;
    reg       ship_nose;
    reg       ship_body;
    reg       ship_wings;
    reg       ship_thruster;
    reg       ship_pixel;

    // Asteroid geometry signals
    reg [9:0] ast_dx;
    reg [9:0] ast_dy;
    reg [9:0] ast_size;
    reg [9:0] ast_dist;
    reg       asteroid_pixel;

    always @(*) begin
        // -------------------------------------------------------------
        // 1. Perspective Tunnel & Starfield
        // -------------------------------------------------------------
        dx = (pixel_x >= 10'd320) ? (pixel_x - 10'd320) : (10'd320 - pixel_x);
        dy = (pixel_y >= 10'd240) ? (pixel_y - 10'd240) : (10'd240 - pixel_y);

        // Octagonal distance approximation for perspective corridor
        r_oct = (dx > dy) ? (dx + (dy >> 1)) : (dy + (dx >> 1));

        // Animated concentric tunnel rings expanding outward
        ring_phase = (r_oct - {2'b0, frame_count[5:0], 2'b0}) & 10'h03F;
        tunnel_ring = (ring_phase < 10'd3) && (r_oct > 10'd20) && (r_oct < 10'd310);

        // 3D diagonal corridor corner rails
        spoke_diag = (((dx > dy) ? (dx - dy) : (dy - dx)) < 10'd2) && (r_oct > 10'd15) && (r_oct < 10'd320);

        // Procedural background stars
        star_pixel = ((pixel_x[2:0] ^ pixel_y[2:0] ^ frame_count[2:0]) == 3'b000) &&
                     (pixel_x[1] ^ pixel_y[3]) && (r_oct > 10'd100);

        // -------------------------------------------------------------
        // 2. Player Ship (Star Fox Arwing) Geometry
        // -------------------------------------------------------------
        ship_dx = (pixel_x >= player_x) ? (pixel_x - player_x) : (player_x - pixel_x);

        // Tapered nose cone
        ship_nose = (pixel_y >= 10'd410) && (pixel_y < 10'd430) &&
                    (ship_dx <= (((pixel_y - 10'd410) >> 1) + 10'd1));

        // Central fuselage
        ship_body = (pixel_y >= 10'd430) && (pixel_y < 10'd452) && (ship_dx <= 10'd8);

        // Swept-back wings
        wing_width = ((pixel_y - 10'd430) * 10'd3) >> 1;
        ship_wings = (pixel_y >= 10'd432) && (pixel_y < 10'd455) && (ship_dx <= wing_width);

        // Animated engine thruster flame
        ship_thruster = (pixel_y >= 10'd452) && (pixel_y < 10'd464) && (ship_dx <= 10'd5);

        ship_pixel = ship_nose || ship_body || ship_wings || ship_thruster;

        // -------------------------------------------------------------
        // 3. 3D Asteroid Geometry
        // -------------------------------------------------------------
        ast_dx = (pixel_x >= asteroid_x) ? (pixel_x - asteroid_x) : (asteroid_x - pixel_x);
        ast_dy = (pixel_y >= asteroid_y) ? (pixel_y - asteroid_y) : (asteroid_y - pixel_y);
        ast_size = 10'd8 + ({2'b0, (8'd255 - asteroid_depth)} >> 1);

        // Faceted octagonal rock shape
        ast_dist = (ast_dx > ast_dy) ? (ast_dx + (ast_dy >> 1)) : (ast_dy + (ast_dx >> 1));
        asteroid_pixel = (ast_dist <= ast_size);

        // -------------------------------------------------------------
        // 4. Color Shading Hierarchy
        // -------------------------------------------------------------
        if (!active_video) begin
            red   = 4'h0;
            green = 4'h0;
            blue  = 4'h0;
        end else if (ship_pixel) begin
            // Player Arwing Shading
            if ((pixel_y >= 10'd420) && (pixel_y < 10'd432) && (ship_dx <= 10'd3)) begin
                // Cyan Glass Cockpit
                red   = 4'h0;
                green = 4'hE;
                blue  = 4'hF;
            end else if ((pixel_y >= 10'd448) && (ship_dx >= wing_width - 10'd3)) begin
                // Red Laser Cannons
                red   = 4'hF;
                green = 4'h1;
                blue  = 4'h2;
            end else if (ship_wings && (ship_dx > 10'd8)) begin
                // Metallic Blue Wings
                red   = 4'h1;
                green = 4'h5;
                blue  = 4'hE;
            end else if (ship_thruster) begin
                // Pulsing Cyan Engine Plasma
                red   = 4'h0;
                green = 4'hC + {2'b0, frame_count[1:0]};
                blue  = 4'hF;
            end else begin
                // White Main Hull
                red   = 4'hE;
                green = 4'hE;
                blue  = 4'hF;
            end
        end else if (asteroid_pixel) begin
            // 3D Asteroid Facet Shading
            if (ast_dist >= ast_size - 10'd2) begin
                // Glowing Molten Outer Rim
                red   = 4'hF;
                green = 4'h6;
                blue  = 4'h0;
            end else if ((pixel_x < asteroid_x) && (pixel_y < asteroid_y)) begin
                // Amber Surface Highlight
                red   = 4'hF;
                green = 4'hB;
                blue  = 4'h4;
            end else if (pixel_x > asteroid_x + (ast_size >> 2)) begin
                // Deep Rust Shadow
                red   = 4'h7;
                green = 4'h1;
                blue  = 4'h0;
            end else begin
                // Fiery Red-Orange Body
                red   = 4'hD;
                green = 4'h4;
                blue  = 4'h1;
            end
        end else if (tunnel_ring) begin
            // Neon Cyan Tunnel Rings
            red   = 4'h0;
            green = 4'hC;
            blue  = 4'hF;
        end else if (spoke_diag) begin
            // Purple/Magenta Perspective Corridor Rails
            red   = 4'h9;
            green = 4'h2;
            blue  = 4'hD;
        end else if (star_pixel) begin
            // Starfield
            red   = 4'hF;
            green = 4'hF;
            blue  = 4'hD;
        end else begin
            // Deep Cosmic Blue Space Background Gradient
            red   = {2'b0, pixel_y[9:8]};
            green = 4'h0;
            blue  = 4'h2 + {2'b0, pixel_y[8:7]};
        end
    end

endmodule