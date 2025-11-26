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

  // ============================================================
  // USER TUNABLES (same as your original)
  // ============================================================

  // Geometry scale:
  //   S0     = half-size in x/y/z
  //   WBOOST = half-size in w (distance between inner/outer cubes)
  localparam signed [8:0] S0     = 9'sd145;   // try 48..200
  localparam signed [8:0] WBOOST = 9'sd145;   // start same as S0

  // Screen placement:
  localparam signed [10:0] CENTER_X = 11'd320;
  localparam signed [10:0] CENTER_Y = 11'd240;

  // Global scale factor after projection:
  // Bigger GLOBAL_GAIN = larger on screen
  localparam signed [7:0] GLOBAL_GAIN = 8'sd130;

  // "Camera distance" knobs for perspective:
  // DEPTH_K_W: farther -> less crazy 4D foreshortening
  // DEPTH_K_Z: farther -> less 3D bulge
  localparam signed [7:0] DEPTH_K_W = 8'sd128;
  localparam signed [7:0] DEPTH_K_Z = 8'sd110;

  // Plane enable flags (1 = include that rotation plane in the pipeline)
  // Planes correspond to: zw, yw, yz, xw, xz, xy
  localparam ENABLE_ZW = 1'b1;
  localparam ENABLE_YW = 1'b1;
  localparam ENABLE_YZ = 1'b1;
  localparam ENABLE_XW = 1'b1;
  localparam ENABLE_XZ = 1'b1;
  localparam ENABLE_XY = 1'b1;

  // Spin control:
  // Each plane gets: which frame_ctr bits feed its angle (speed),
  // plus an optional PHASE offset into the LUT.
  localparam integer ROT_SPEED_SEL_ZW = 0;
  localparam integer ROT_SPEED_SEL_YW = 0;
  localparam integer ROT_SPEED_SEL_YZ = 0;
  localparam integer ROT_SPEED_SEL_XW = 0;
  localparam integer ROT_SPEED_SEL_XZ = 0;
  localparam integer ROT_SPEED_SEL_XY = 0;

  localparam [5:0] PHASE_ZW = 6'd0;
  localparam [5:0] PHASE_YW = 6'd8;
  localparam [5:0] PHASE_YZ = 6'd16;
  localparam [5:0] PHASE_XW = 6'd0;
  localparam [5:0] PHASE_XZ = 6'd12;
  localparam [5:0] PHASE_XY = 6'd20;

  // ============================================================
  // VGA TIMING
  // ============================================================
  wire hsync, vsync, video_active;
  wire [9:0] pix_x, pix_y;

  hvsync_generator hvsync_gen (
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // VGA PMOD packing (2:2:2 RGB split across the byte)
  reg [1:0] R, G, B;
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // unused IO
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  // ============================================================
  // FRAME COUNTER FOR ANIMATION
  // ============================================================
  reg vsync_d;
  reg [15:0] frame_ctr;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vsync_d   <= 1'b0;
      frame_ctr <= 16'd0;
    end else begin
      vsync_d <= vsync;
      if (vsync && !vsync_d)
        frame_ctr <= frame_ctr + 16'd1;
    end
  end

  // vsync rising edge (start of frame)
  wire vsync_rise = vsync && !vsync_d;

  // Angles for all six planes.
  wire [5:0] ang_zw = frame_ctr[ROT_SPEED_SEL_ZW +: 6] + PHASE_ZW;
  wire [5:0] ang_yw = frame_ctr[ROT_SPEED_SEL_YW +: 6] + PHASE_YW;
  wire [5:0] ang_yz = frame_ctr[ROT_SPEED_SEL_YZ +: 6] + PHASE_YZ;
  wire [5:0] ang_xw = frame_ctr[ROT_SPEED_SEL_XW +: 6] + PHASE_XW;
  wire [5:0] ang_xz = frame_ctr[ROT_SPEED_SEL_XZ +: 6] + PHASE_XZ;
  wire [5:0] ang_xy = frame_ctr[ROT_SPEED_SEL_XY +: 6] + PHASE_XY;

  // LUT sin/cos for each plane (Q1.7 signed) – same as original
  wire signed [7:0] cos_zw_q7, sin_zw_q7;
  wire signed [7:0] cos_yw_q7, sin_yw_q7;
  wire signed [7:0] cos_yz_q7, sin_yz_q7;
  wire signed [7:0] cos_xw_q7, sin_xw_q7;
  wire signed [7:0] cos_xz_q7, sin_xz_q7;
  wire signed [7:0] cos_xy_q7, sin_xy_q7;

  sincos64 lut_zw(.idx(ang_zw), .cos_q(cos_zw_q7), .sin_q(sin_zw_q7));
  sincos64 lut_yw(.idx(ang_yw), .cos_q(cos_yw_q7), .sin_q(sin_yw_q7));
  sincos64 lut_yz(.idx(ang_yz), .cos_q(cos_yz_q7), .sin_q(sin_yz_q7));
  sincos64 lut_xw(.idx(ang_xw), .cos_q(cos_xw_q7), .sin_q(sin_xw_q7));
  sincos64 lut_xz(.idx(ang_xz), .cos_q(cos_xz_q7), .sin_q(sin_xz_q7));
  sincos64 lut_xy(.idx(ang_xy), .cos_q(cos_xy_q7), .sin_q(sin_xy_q7));

  // ============================================================
  // HELPER FUNCTIONS
  // ============================================================

  // abs for ~11-bit signed
  function [10:0] abs11;
    input signed [10:0] v;
    begin
      abs11 = v[10] ? (~v + 1'b1) : v;
    end
  endfunction

  // clamp X to visible 0..639
  function [9:0] clamp_x;
    input signed [10:0] v;
    begin
      if (v < 0)             clamp_x = 10'd0;
      else if (v > 11'sd639) clamp_x = 10'd639;
      else                   clamp_x = v[9:0];
    end
  endfunction

  // clamp Y to visible 0..479
  function [9:0] clamp_y;
    input signed [10:0] v;
    begin
      if (v < 0)             clamp_y = 10'd0;
      else if (v > 11'sd479) clamp_y = 10'd479;
      else                   clamp_y = v[9:0];
    end
  endfunction

  // tiny diamond point (~3px manhattan radius)
  function dot2;
    input [9:0] px, py;
    input [9:0] cx, cy;
    reg signed [10:0] dx, dy;
    reg [10:0] adx, ady;
    reg [10:0] man;
    begin
      dx  = $signed({1'b0,px}) - $signed({1'b0,cx});
      dy  = $signed({1'b0,py}) - $signed({1'b0,cy});
      adx = abs11(dx);
      ady = abs11(dy);
      man = adx + ady;
      dot2 = (man <= 11'd3);
    end
  endfunction

  // 16-entry reciprocal LUT in Q0.8
  // we use this for rough 1/(K - depth)
  function [7:0] inv16_q0p8;
    input [3:0] idx;
    begin
      case (idx)
        4'h0: inv16_q0p8=8'd255; 4'h1: inv16_q0p8=8'd224;
        4'h2: inv16_q0p8=8'd192; 4'h3: inv16_q0p8=8'd171;
        4'h4: inv16_q0p8=8'd153; 4'h5: inv16_q0p8=8'd137;
        4'h6: inv16_q0p8=8'd123; 4'h7: inv16_q0p8=8'd111;
        4'h8: inv16_q0p8=8'd101; 4'h9: inv16_q0p8=8'd92;
        4'hA: inv16_q0p8=8'd85;  4'hB: inv16_q0p8=8'd78;
        4'hC: inv16_q0p8=8'd73;  4'hD: inv16_q0p8=8'd68;
        4'hE: inv16_q0p8=8'd64;  4'hF: inv16_q0p8=8'd60;
      endcase
    end
  endfunction

  // ============================================================
  // project_vertex: **exact same math as your original**
  // ============================================================
  function [19:0] project_vertex;
    input [3:0] vidx;

    // base Q1.7 coords
    reg signed [15:0] x_q, y_q, z_q, w_q;

    // temp mults
    reg signed [23:0] mulA, mulB;

    // perspective bits
    reg signed [15:0] w_clip_q;
    reg signed [8:0]  w_clip_lite;
    reg signed [8:0]  denom_w;
    reg [3:0]         recip_idx_w;
    reg [7:0]         recip_w_q;
    reg signed [23:0] s_w_mul;
    reg signed [15:0] s_w_q;

    reg signed [15:0] z_clip_q;
    reg signed [8:0]  z_clip_lite;
    reg signed [8:0]  denom_z;
    reg [3:0]         recip_idx_z;
    reg [7:0]         recip_z_q;
    reg signed [23:0] s_z_mul;
    reg signed [15:0] s_z_q;

    reg signed [31:0] s_total_mul;
    reg signed [15:0] s_total_q;

    reg signed [31:0] Xmul, Ymul;
    reg signed [10:0] sx, sy;
    reg [9:0] sx_clamped, sy_clamped;

    begin
      // ---- 1. base corner in Q1.7 ----
      x_q = vidx[0] ?  (S0     <<< 7) : -(S0     <<< 7);
      y_q = vidx[1] ?  (S0     <<< 7) : -(S0     <<< 7);
      z_q = vidx[2] ?  (S0     <<< 7) : -(S0     <<< 7);
      w_q = vidx[3] ?  (WBOOST <<< 7) : -(WBOOST <<< 7);

      // ---- 2. chained 4D rotations ----
      // zw plane (z <-> w)
      if (ENABLE_ZW) begin
        mulA = z_q * cos_zw_q7 - w_q * sin_zw_q7;
        mulB = z_q * sin_zw_q7 + w_q * cos_zw_q7;
        z_q  = mulA >>> 7;
        w_q  = mulB >>> 7;
      end

      // yw plane (y <-> w)
      if (ENABLE_YW) begin
        mulA = y_q * cos_yw_q7 - w_q * sin_yw_q7;
        mulB = y_q * sin_yw_q7 + w_q * cos_yw_q7;
        y_q  = mulA >>> 7;
        w_q  = mulB >>> 7;
      end

      // yz plane (y <-> z)
      if (ENABLE_YZ) begin
        mulA = y_q * cos_yz_q7 - z_q * sin_yz_q7;
        mulB = y_q * sin_yz_q7 + z_q * cos_yz_q7;
        y_q  = mulA >>> 7;
        z_q  = mulB >>> 7;
      end

      // xw plane (x <-> w)
      if (ENABLE_XW) begin
        mulA = x_q * cos_xw_q7 - w_q * sin_xw_q7;
        mulB = x_q * sin_xw_q7 + w_q * cos_xw_q7;
        x_q  = mulA >>> 7;
        w_q  = mulB >>> 7;
      end

      // xz plane (x <-> z)
      if (ENABLE_XZ) begin
        mulA = x_q * cos_xz_q7 - z_q * sin_xz_q7;
        mulB = x_q * sin_xz_q7 + z_q * cos_xz_q7;
        x_q  = mulA >>> 7;
        z_q  = mulB >>> 7;
      end

      // xy plane (x <-> y)
      if (ENABLE_XY) begin
        mulA = x_q * cos_xy_q7 - y_q * sin_xy_q7;
        mulB = x_q * sin_xy_q7 + y_q * cos_xy_q7;
        x_q  = mulA >>> 7;
        y_q  = mulB >>> 7;
      end

      // ---- 3. perspective from W (DEPTH_K_W) ----
      w_clip_q = w_q;
      if (w_clip_q[15]) begin
        w_clip_lite = -9'sd100;
      end else if (w_clip_q[15:7] > 8'sd100) begin
        w_clip_lite = 9'sd100;
      end else begin
        w_clip_lite = {1'b0, w_clip_q[14:7]};
      end

      denom_w = {{1{DEPTH_K_W[7]}}, DEPTH_K_W} - w_clip_lite[7:0];
      if (denom_w[8])
        recip_idx_w = 4'hF;
      else
        recip_idx_w = denom_w[7:4];
      recip_w_q = inv16_q0p8(recip_idx_w); // Q0.8 approx 1/(DEPTH_K_W-w)

      // s_w_q ~ recip_w_q * GLOBAL_GAIN
      s_w_mul = $signed({1'b0,recip_w_q}) * $signed(GLOBAL_GAIN);
      s_w_q   = s_w_mul[22:7]; // ~Q1.7

      // ---- 4. perspective from Z (DEPTH_K_Z) ----
      z_clip_q = z_q;
      if (z_clip_q[15]) begin
        z_clip_lite = -9'sd100;
      end else if (z_clip_q[15:7] > 8'sd100) begin
        z_clip_lite = 9'sd100;
      end else begin
        z_clip_lite = {1'b0, z_clip_q[14:7]};
      end

      denom_z = {{1{DEPTH_K_Z[7]}}, DEPTH_K_Z} - z_clip_lite[7:0];
      if (denom_z[8])
        recip_idx_z = 4'hF;
      else
        recip_idx_z = denom_z[7:4];
      recip_z_q = inv16_q0p8(recip_idx_z); // Q0.8 approx 1/(DEPTH_K_Z-z)

      // s_z_q ~ recip_z_q * 128 (128 ≈ 1.0 in Q1.7)
      s_z_mul = $signed({1'b0,recip_z_q}) * $signed(8'sd128);
      s_z_q   = s_z_mul[22:7]; // ~Q1.7

      // combine
      s_total_mul = $signed(s_w_q) * $signed(s_z_q); // Q1.7*Q1.7 => Q2.14-ish
      s_total_q   = s_total_mul[22:7];               // back to ~Q1.7

      // ---- 5. final screen projection for x,y ----
      Xmul = $signed(x_q) * $signed(s_total_q);
      Ymul = $signed(y_q) * $signed(s_total_q);

      // shift down ~15 to turn Q-ish product into pixels
      sx = $signed(CENTER_X) + (Xmul >>> 15);
      sy = $signed(CENTER_Y) + (Ymul >>> 15);

      // clamp to visible range
      sx_clamped = clamp_x(sx);
      sy_clamped = clamp_y(sy);

      project_vertex = {sx_clamped, sy_clamped};
    end
  endfunction

  // ============================================================
  // GENERATE ALL 16 PROJECTED VERTICES (precompute per frame)
  // ============================================================

  // Storage for 16 vertices: {x[19:10], y[9:0]}
  reg [19:0] v_reg [0:15];
  reg [3:0]  v_idx;
  reg        v_compute;

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v_idx     <= 4'd0;
      v_compute <= 1'b0;
      for (i = 0; i < 16; i = i + 1)
        v_reg[i] <= 20'd0;
    end else begin
      // Start a new vertex computation pass at beginning of frame
      if (vsync_rise) begin
        v_idx     <= 4'd0;
        v_compute <= 1'b1;
      end else if (v_compute) begin
        // Compute one vertex per clock using shared project_vertex logic
        v_reg[v_idx] <= project_vertex(v_idx);

        if (v_idx == 4'd15) begin
          v_compute <= 1'b0;      // done this frame
        end else begin
          v_idx <= v_idx + 4'd1;  // next vertex
        end
      end
    end
  end

  // Wires for convenience
  wire [19:0] v0  = v_reg[0];
  wire [19:0] v1  = v_reg[1];
  wire [19:0] v2  = v_reg[2];
  wire [19:0] v3  = v_reg[3];
  wire [19:0] v4  = v_reg[4];
  wire [19:0] v5  = v_reg[5];
  wire [19:0] v6  = v_reg[6];
  wire [19:0] v7  = v_reg[7];
  wire [19:0] v8  = v_reg[8];
  wire [19:0] v9  = v_reg[9];
  wire [19:0] v10 = v_reg[10];
  wire [19:0] v11 = v_reg[11];
  wire [19:0] v12 = v_reg[12];
  wire [19:0] v13 = v_reg[13];
  wire [19:0] v14 = v_reg[14];
  wire [19:0] v15 = v_reg[15];

  `define VX(v) v[19:10]
  `define VY(v) v[9:0]

  // ============================================================
  // VERTEX DOTS ONLY (no edges)
  // ============================================================
  wire dot_pix =
    dot2(pix_x,pix_y, `VX(v0 ),`VY(v0 )) |
    dot2(pix_x,pix_y, `VX(v1 ),`VY(v1 )) |
    dot2(pix_x,pix_y, `VX(v2 ),`VY(v2 )) |
    dot2(pix_x,pix_y, `VX(v3 ),`VY(v3 )) |
    dot2(pix_x,pix_y, `VX(v4 ),`VY(v4 )) |
    dot2(pix_x,pix_y, `VX(v5 ),`VY(v5 )) |
    dot2(pix_x,pix_y, `VX(v6 ),`VY(v6 )) |
    dot2(pix_x,pix_y, `VX(v7 ),`VY(v7 )) |
    dot2(pix_x,pix_y, `VX(v8 ),`VY(v8 )) |
    dot2(pix_x,pix_y, `VX(v9 ),`VY(v9 )) |
    dot2(pix_x,pix_y, `VX(v10),`VY(v10)) |
    dot2(pix_x,pix_y, `VX(v11),`VY(v11)) |
    dot2(pix_x,pix_y, `VX(v12),`VY(v12)) |
    dot2(pix_x,pix_y, `VX(v13),`VY(v13)) |
    dot2(pix_x,pix_y, `VX(v14),`VY(v14)) |
    dot2(pix_x,pix_y, `VX(v15),`VY(v15));

  // Color rules:
  //   dots        -> white
  //   background  -> black
  wire [1:0] R_pix = dot_pix ? 2'b11 : 2'b00;
  wire [1:0] G_pix = dot_pix ? 2'b11 : 2'b00;
  wire [1:0] B_pix = dot_pix ? 2'b11 : 2'b00;

  // drive pixel RGB during active video
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      R <= 2'b00; G <= 2'b00; B <= 2'b00;
    end else if (video_active) begin
      R <= R_pix;
      G <= G_pix;
      B <= B_pix;
    end else begin
      R <= 2'b00; G <= 2'b00; B <= 2'b00;
    end
  end

endmodule


// ============================================================
// sin/cos lookup table (64 steps), signed Q1.7
// cos(angle) = sin(angle+16)
// ============================================================
module sincos64(
  input  wire [5:0] idx,
  output reg  signed [7:0] cos_q,
  output reg  signed [7:0] sin_q
);
  reg signed [7:0] s[0:63];
  initial begin
    s[ 0]=   0; s[ 1]=  13; s[ 2]=  25; s[ 3]=  38;
    s[ 4]=  49; s[ 5]=  60; s[ 6]=  70; s[ 7]=  79;
    s[ 8]=  87; s[ 9]=  94; s[10]= 100; s[11]= 105;
    s[12]= 109; s[13]= 112; s[14]= 114; s[15]= 115;
    s[16]= 116; s[17]= 115; s[18]= 114; s[19]= 112;
    s[20]= 109; s[21]= 105; s[22]= 100; s[23]=  94;
    s[24]=  87; s[25]=  79; s[26]=  70; s[27]=  60;
    s[28]=  49; s[29]=  38; s[30]=  25; s[31]=  13;
    s[32]=   0; s[33]= -13; s[34]= -25; s[35]= -38;
    s[36]= -49; s[37]= -60; s[38]= -70; s[39]= -79;
    s[40]= -87; s[41]= -94; s[42]= -100; s[43]= -105;
    s[44]= -109; s[45]= -112; s[46]= -114; s[47]= -115;
    s[48]= -116; s[49]= -115; s[50]= -114; s[51]= -112;
    s[52]= -109; s[53]= -105; s[54]= -100; s[55]=  -94;
    s[56]=  -87; s[57]=  -79; s[58]=  -70; s[59]=  -60;
    s[60]=  -49; s[61]=  -38; s[62]=  -25; s[63]=  -13;
  end

  wire [5:0] ic = idx + 6'd16;
  always @* begin
    sin_q = s[idx];
    cos_q = s[ic];
  end
endmodule


// ============================================================
// 640x480@60Hz style timing generator
// ============================================================
module hvsync_generator(
  input  wire       clk,
  input  wire       reset,
  output reg        hsync,
  output reg        vsync,
  output wire       display_on,
  output wire [9:0] hpos,
  output wire [9:0] vpos
);
  localparam integer H_ACTIVE = 640;
  localparam integer H_FRONT  = 16;
  localparam integer H_SYNC   = 96;
  localparam integer H_BACK   = 48;
  localparam integer H_TOTAL  = H_ACTIVE + H_FRONT + H_SYNC + H_BACK; // 800

  localparam integer V_ACTIVE = 480;
  localparam integer V_FRONT  = 10;
  localparam integer V_SYNC   = 2;
  localparam integer V_BACK   = 33;
  localparam integer V_TOTAL  = V_ACTIVE + V_FRONT + V_SYNC + V_BACK; // 525

  reg [9:0] h_ctr;
  reg [9:0] v_ctr;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      h_ctr <= 10'd0;
      v_ctr <= 10'd0;
      hsync <= 1'b1;
      vsync <= 1'b1;
    end else begin
      if (h_ctr == H_TOTAL-1) begin
        h_ctr <= 10'd0;
        if (v_ctr == V_TOTAL-1)
          v_ctr <= 10'd0;
        else
          v_ctr <= v_ctr + 10'd1;
      end else begin
        h_ctr <= h_ctr + 10'd1;
      end

      hsync <= ~((h_ctr >= H_ACTIVE + H_FRONT) &&
                 (h_ctr <  H_ACTIVE + H_FRONT + H_SYNC));
      vsync <= ~((v_ctr >= V_ACTIVE + V_FRONT) &&
                 (v_ctr <  V_ACTIVE + V_FRONT + V_SYNC));
    end
  end

  assign display_on = (h_ctr < H_ACTIVE) && (v_ctr < V_ACTIVE);
  assign hpos       = (h_ctr < H_ACTIVE) ? h_ctr : 10'd0;
  assign vpos       = (v_ctr < V_ACTIVE) ? v_ctr : 10'd0;
endmodule

`default_nettype wire
