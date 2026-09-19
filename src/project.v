`default_nettype none

module tt_um_vga_example (
    input  wire [7:0] ui_in,    // Inputs: [2]=Left Arrow, [3]=Right Arrow, [0]=Up Arrow (Reset)
    output wire [7:0] uo_out,   // TinyVGA PMOD output
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,      // 25.175 MHz pixel clock
    input  wire       rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // VGA Sync Signals
    wire hsync, vsync, video_active;
    wire [9:0] pix_x, pix_y;

    hvsync_generator sync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    wire [1:0] R, G, B;
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // -------------------------------------------------------------
    // Controls (Arrow Keys)
    // -------------------------------------------------------------
    wire move_left  = ui_in[2]; // Keyboard Left Arrow
    wire move_right = ui_in[3]; // Keyboard Right Arrow
    wire reset_game = ui_in[0]; // Keyboard Up Arrow

    // -------------------------------------------------------------
    // Game Physics & Movement Registers
    // -------------------------------------------------------------
    reg [9:0] player_x;
    reg signed [11:0] player_y;
    reg signed [7:0]  velocity_y;

    localparam GRAVITY      = 8'sd1;
    localparam JUMP_IMPULSE = -8'sd15;

    wire frame_tick = (pix_x == 10'd639 && pix_y == 10'd479);

    // -------------------------------------------------------------
    // Platform Coordinates & Heights
    // -------------------------------------------------------------
    localparam P1_TOP = 12'd380;
    localparam P2_TOP = 12'd260;
    localparam P3_TOP = 12'd140;

    wire p1_on = (pix_x >= 100 && pix_x <= 220 && pix_y >= P1_TOP && pix_y <= P1_TOP + 10);
    wire p2_on = (pix_x >= 280 && pix_x <= 400 && pix_y >= P2_TOP && pix_y <= P2_TOP + 10);
    wire p3_on = (pix_x >= 460 && pix_x <= 580 && pix_y >= P3_TOP && pix_y <= P3_TOP + 10);

    // Feet Position (Bottom edge of 16px tall character)
    wire [11:0] player_feet = player_y + 12'd16;
    wire is_falling = (velocity_y > 0);

    // Collision Detection (Checks if feet pass through or reach the top edge)
    wire landed_p1 = is_falling && (player_feet >= P1_TOP && player_feet <= P1_TOP + velocity_y + 4) && (player_x + 12 >= 100 && player_x <= 220);
    wire landed_p2 = is_falling && (player_feet >= P2_TOP && player_feet <= P2_TOP + velocity_y + 4) && (player_x + 12 >= 280 && player_x <= 400);
    wire landed_p3 = is_falling && (player_feet >= P3_TOP && player_feet <= P3_TOP + velocity_y + 4) && (player_x + 12 >= 460 && player_x <= 580);

    // -------------------------------------------------------------
    // Physics State Engine with Instant Edge Snapping
    // -------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || reset_game) begin
            player_x   <= 10'd150;
            player_y   <= P1_TOP - 12'd16; // Start right on top of platform 1
            velocity_y <= JUMP_IMPULSE;
        end else if (frame_tick) begin
            // Horizontal Movement
            if (move_left  && !move_right && player_x > 10'd10)  player_x <= player_x - 10'd5;
            if (move_right && !move_left  && player_x < 10'd618) player_x <= player_x + 10'd5;

            // Collision Reaction: Snap Y position to exact top edge of platform, then jump
            if (landed_p1) begin
                player_y   <= P1_TOP - 12'd16; // Prevents penetration/clipping
                velocity_y <= JUMP_IMPULSE;
            end else if (landed_p2) begin
                player_y   <= P2_TOP - 12'd16;
                velocity_y <= JUMP_IMPULSE;
            end else if (landed_p3) begin
                player_y   <= P3_TOP - 12'd16;
                velocity_y <= JUMP_IMPULSE;
            end else if (player_y >= 12'd460) begin
                // Reset on fall off-screen
                player_x   <= 10'd150;
                player_y   <= P1_TOP - 12'd16;
                velocity_y <= JUMP_IMPULSE;
            end else begin
                // Apply Gravity & Update Vertical Position
                velocity_y <= velocity_y + GRAVITY;
                player_y   <= player_y + velocity_y;
            end
        end
    end

    // -------------------------------------------------------------
    // Pixel Drawing
    // -------------------------------------------------------------
    wire is_player = (pix_x >= player_x && pix_x <= player_x + 12) &&
                     (pix_y >= player_y && pix_y <= player_y + 16);

    reg [1:0] r_reg, g_reg, b_reg;

    always @(*) begin
        if (!video_active) begin
            r_reg = 2'b00; g_reg = 2'b00; b_reg = 2'b00;
        end else if (is_player) begin
            r_reg = 2'b11; g_reg = 2'b11; b_reg = 2'b00; // Yellow character
        end else if (p1_on || p2_on || p3_on) begin
            r_reg = 2'b00; g_reg = 2'b11; b_reg = 2'b00; // Green platforms
        end else begin
            r_reg = 2'b00; g_reg = 2'b00; b_reg = 2'b01; // Blue background
        end
    end

    assign R = r_reg;
    assign G = g_reg;
    assign B = b_reg;

endmodule
