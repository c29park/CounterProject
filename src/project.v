`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // unused
  output wire [7:0] uo_out,   // {hsync,B0,G0,R0,vsync,B1,G1,R1}
  input  wire [7:0] uio_in,   // unused
  output wire [7:0] uio_out,  // unused
  output wire [7:0] uio_oe,   // unused
  input  wire       ena,      // unused
  input  wire       clk,      // ~25 MHz pixel clock
  input  wire       rst_n     // active-low reset
);

  // -------------------------------------------------------
  // VGA signals
  // -------------------------------------------------------
  wire hsync;
  wire vsync;
  wire activevideo;
  wire [9:0] x_px;
  wire [9:0] y_px;

  hvsync_generator hvsync_gen(
    .clk        (clk),
    .reset      (~rst_n),
    .hsync      (hsync),
    .vsync      (vsync),
    .display_on (activevideo),
    .hpos       (x_px),
    .vpos       (y_px)
  );

  // TinyVGA PMOD mapping
  reg [1:0] R, G, B;
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;
  wire _unused_ok = &{ena, ui_in, uio_in};

  // -------------------------------------------------------
  // Animation Timer
  // -------------------------------------------------------
  reg [7:0] frame_cnt;
  reg vsync_prev;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        frame_cnt  <= 8'd0;
        vsync_prev <= 1'b0;
    end else begin
        vsync_prev <= vsync;
        if (vsync && !vsync_prev) begin
            frame_cnt <= frame_cnt + 8'd1;
        end
    end
  end

  // -------------------------------------------------------
  // Geometry Engine
  // -------------------------------------------------------
  
  // Center screen (320, 240)
  wire signed [10:0] dx = $signed({1'b0, x_px}) - 11'sd320;
  wire signed [10:0] dy = $signed({1'b0, y_px}) - 11'sd240;

  // 1. Squared Distances
  wire [21:0] dx_sq = dx * dx;
  wire [21:0] dy_sq = dy * dy;

  // 2. Metrics
  // Circular (for Shadow and Halo)
  wire [21:0] r2_circ = dx_sq + dy_sq;
  // Flat Elliptical (for Belt) - y squashed by 4x (shift left 4 = mult 16)
  wire [21:0] r2_flat = dx_sq + (dy_sq << 4);

  // -------------------------------------------------------
  // Constants & Thresholds
  // -------------------------------------------------------
  
  // Shadow Radius
  localparam SHADOW_R2 = 22'd7225; // r=85

  // Belt (Front/Back Disk)
  localparam BELT_IN_R2  = 22'd10000;
  localparam BELT_OUT_R2 = 22'd85000;

  // Halo (Lensed Background)
  localparam HALO_IN_R2  = 22'd5000;
  localparam HALO_OUT_R2 = 22'd22000;

  // -------------------------------------------------------
  // Text Generation ("UW")
  // -------------------------------------------------------
  // Simple hardcoded shapes for 'U' and 'W'
  // Position: Top middle. Let's say y from 20 to 52 (32px high).
  // 'U' width 24, space 8, 'W' width 24. Total width 56.
  // Start X = 320 - (56/2) = 292.

  // Common Y-box for text
  wire in_text_y = (y_px >= 10'd20 && y_px < 10'd52);
  wire [4:0] rel_y = y_px[4:0] - 5'd20; // Relative Y 0-31

  // Letter 'U' Logic (X: 292-315)
  wire in_u_x = (x_px >= 10'd292 && x_px < 10'd316);
  // Fixed lint warning: 292 % 32 = 4, so we use 5'd4 instead of 5'd292
  wire [4:0] u_rel_x = x_px[4:0] - 5'd4; // Relative X 0-23
  // U shape: left bar OR right bar OR bottom bar
  wire draw_u = in_text_y && in_u_x && (
                 (u_rel_x < 5'd4) ||                 // Left bar
                 (u_rel_x >= 5'd20) ||               // Right bar
                 (rel_y >= 5'd28)                    // Bottom bar
                 );

  // Letter 'W' Logic (X: 324-347)
  wire in_w_x = (x_px >= 10'd324 && x_px < 10'd348);
  // Fixed lint warning: 324 % 32 = 4, so we use 5'd4 instead of 5'd324
  wire [4:0] w_rel_x = x_px[4:0] - 5'd4; // Relative X 0-23
  // W shape: left bar OR right bar OR bottom bar OR middle-bottom bar
  wire draw_w = in_text_y && in_w_x && (
                 (w_rel_x < 5'd4) ||                 // Left bar
                 (w_rel_x >= 5'd20) ||               // Right bar
                 (rel_y >= 5'd28) ||                 // Bottom bar
                 ((w_rel_x >= 5'd10 && w_rel_x < 5'd14) && (rel_y >= 5'd16)) // Middle bar (bottom half)
                 );

  wire draw_text = draw_u || draw_w;

  // -------------------------------------------------------
  // Rendering Logic
  // -------------------------------------------------------
  
  // Textures (Ring patterns)
  wire [7:0] belt_tex_val = (r2_flat[15:8]) - frame_cnt;
  wire belt_gap = belt_tex_val[4];
  wire belt_yellow = belt_tex_val[2]; 
  
  wire [7:0] halo_tex_val = (r2_circ[13:6]) - frame_cnt;
  wire halo_gap = halo_tex_val[4];
  wire halo_yellow = halo_tex_val[2];

  // Region Flags
  wire in_shadow = (r2_circ < SHADOW_R2);
  wire in_belt   = (r2_flat >= BELT_IN_R2 && r2_flat <= BELT_OUT_R2);
  wire in_halo   = (r2_circ >= HALO_IN_R2 && r2_circ <= HALO_OUT_R2);

  // "3D" Depth Logic
  wire belt_is_in_front = (dy > 4); 

  always @* begin
    // Background: Deep Space Black
    R = 2'b00; G = 2'b00; B = 2'b00;

    if (activevideo) begin

        // PRIORITY 0: Text Overlay ("UW")
        // Draws on top of everything else.
        if (draw_text) begin
            R = 2'b11; G = 2'b11; B = 2'b11; // White Text
        end

        // PRIORITY 1: The Front Belt (Bottom Half)
        else if (in_belt && belt_is_in_front) begin
            if (belt_gap) begin
                R = 2'b01; G = 2'b00; B = 2'b00; // Very Dim Red Gap
            end else if (belt_yellow) begin
                R = 2'b11; G = 2'b10; B = 2'b00; // Yellow/Orange Ring
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00; // Bright Blood Red
            end

        // PRIORITY 2: The Shadow (Event Horizon)
        end else if (in_shadow) begin
            R = 2'b00; G = 2'b00; B = 2'b00; // Pure Black

        // PRIORITY 3: The Back Belt (Top Half)
        end else if (in_belt) begin
            if (belt_gap) begin
                R = 2'b01; G = 2'b00; B = 2'b00; // Very Dim Red Gap
            end else if (belt_yellow) begin
                R = 2'b11; G = 2'b10; B = 2'b00; // Yellow/Orange Ring
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00; // Bright Blood Red
            end

        // PRIORITY 4: The Halo (Lensed Disk)
        end else if (in_halo) begin
            if (halo_gap) begin
                R = 2'b01; G = 2'b00; B = 2'b00; // Very Dim Red Gap
            end else if (halo_yellow) begin
                R = 2'b11; G = 2'b10; B = 2'b00; // Yellow/Orange Ring
            end else begin
                R = 2'b11; G = 2'b00; B = 2'b00; // Bright Blood Red
            end
        end
    end
  end

endmodule

// ===========================================================
// Simple 640x480@60 Hz VGA sync generator (pixel clock ~25 MHz)
// ===========================================================
module hvsync_generator (
    input  wire       clk,
    input  wire       reset,       // active-high
    output reg        hsync,
    output reg        vsync,
    output wire       display_on,
    output wire [9:0] hpos,
    output wire [9:0] vpos
);

  // Horizontal timings (in pixels)
  localparam H_VISIBLE     = 640;
  localparam H_FRONT_PORCH = 16;
  localparam H_SYNC_PULSE  = 96;
  localparam H_BACK_PORCH  = 48;
  localparam H_MAX =
    H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH - 1; // 799

  // Vertical timings (in lines)
  localparam V_VISIBLE     = 480;
  localparam V_FRONT_PORCH = 10;
  localparam V_SYNC_PULSE  = 2;
  localparam V_BACK_PORCH  = 33;
  localparam V_MAX =
    V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH - 1; // 524

  reg [9:0] h_count;
  reg [9:0] v_count;

  assign hpos       = h_count;
  assign vpos       = v_count;
  assign display_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

  // Horizontal / vertical counters
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      h_count <= 10'd0;
      v_count <= 10'd0;
    end else begin
      if (h_count == H_MAX) begin
        h_count <= 10'd0;
        if (v_count == V_MAX)
          v_count <= 10'd0;
        else
          v_count <= v_count + 10'd1;
      end else begin
        h_count <= h_count + 10'd1;
      end
    end
  end

  // Generate sync pulses (active low)
  always @* begin
    hsync = ~((h_count >= H_VISIBLE + H_FRONT_PORCH) &&
              (h_count <  H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE));

    vsync = ~((v_count >= V_VISIBLE + V_FRONT_PORCH) &&
              (v_count <  V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE));
  end

endmodule
