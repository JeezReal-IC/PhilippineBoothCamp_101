`default_nettype none

module tt_um_vga_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Drive unused bidirectional outputs to zero
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Quiet Verilator warnings for unused mandatory pins
    wire _unused = &{ena, uio_in, ui_in[7:4], ui_in[1], 1'b0};

    // VGA timing & positional wires
    wire [9:0] pix_x;
    wire [9:0] pix_y;
    wire video_on;
    wire hsync;
    wire vsync;

    // Instantiate VGA Sync Generator
    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(!rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_on),
        .hpos(pix_x),
        .vpos(pix_y)
    );

    // Explicit 10-bit platform vertical positions
    localparam [9:0] P1_TOP = 10'd320;
    localparam [9:0] P2_TOP = 10'd240;
    localparam [9:0] P3_TOP = 10'd160;

    // Player registers
    reg [9:0] player_x;
    reg [9:0] player_y;
    reg [7:0] velocity_y;
    reg       is_falling;

    // Zero-extend velocity_y to 10 bits for matching arithmetic widths
    wire [9:0] vel_y_10b = {2'b00, velocity_y};
    wire [9:0] player_feet = player_y + 10'd16;

    // Landing detection on platforms
    wire landed_p1 = is_falling && (player_feet >= P1_TOP && player_feet <= P1_TOP + vel_y_10b + 10'd4) && (player_x + 10'd12 >= 10'd100 && player_x <= 10'd220);
    wire landed_p2 = is_falling && (player_feet >= P2_TOP && player_feet <= P2_TOP + vel_y_10b + 10'd4) && (player_x + 10'd12 >= 10'd280 && player_x <= 10'd400);
    wire landed_p3 = is_falling && (player_feet >= P3_TOP && player_feet <= P3_TOP + vel_y_10b + 10'd4) && (player_x + 10'd12 >= 10'd460 && player_x <= 10'd580);

    // Simple game movement & physics logic on vsync frame pulse
    wire frame_tick = (pix_x == 10'd0 && pix_y == 10'd480);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_x   <= 10'd300;
            player_y   <= 10'd100;
            velocity_y <= 8'd2;
            is_falling <= 1'b1;
        end else if (frame_tick) begin
            // Input movement control using ui_in bits
            if (ui_in[0] && player_x > 10'd10)  player_x <= player_x - 10'd2; // Left
            if (ui_in[2] && player_x < 10'd610) player_x <= player_x + 10'd2; // Right

            // Platform collision response
            if (landed_p1) begin
                player_y <= P1_TOP - 10'd16;
                is_falling <= 1'b0;
            end else if (landed_p2) begin
                player_y <= P2_TOP - 10'd16;
                is_falling <= 1 me'b0;
            end else if (landed_p3) begin
                player_y <= P3_TOP - 10'd16;
                is_falling <= 1'b0;
            end else begin
                is_falling <= 1'b1;
                player_y   <= player_y + vel_y_10b;
            end
        end
    end

    // Pixel Drawing Logic (Platform & Player geometry)
    wire p1_on = (pix_x >= 10'd100 && pix_x <= 10'd220 && pix_y >= P1_TOP && pix_y <= P1_TOP + 10'd10);
    wire p2_on = (pix_x >= 10'd280 && pix_x <= 10'd400 && pix_y >= P2_TOP && pix_y <= P2_TOP + 10'd10);
    wire p3_on = (pix_x >= 10'd460 && pix_x <= 10'd580 && pix_y >= P3_TOP && pix_y <= P3_TOP + 10'd10);
    
    wire player_on = (pix_x >= player_x && pix_x <= player_x + 10'd16) &&
                     (pix_y >= player_y && pix_y <= player_y + 10'd16);

    // RGB Color Assignment (2 bits per color channel)
    wire [1:0] R = video_on && (player_on || p1_on) ? 2'b11 : 2'b00;
    wire [1:0] G = video_on && (p1_on || p2_on || p3_on) ? 2'b11 : 2'b00;
    wire [1:0] B = video_on && (player_on || p3_on) ? 2'b11 : 2'b00;

    // Standard Tiny Tapeout VGA PMOD Output Mapping
    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

endmodule
