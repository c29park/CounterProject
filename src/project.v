// 8-bit programmable binary counter 
// - Asynchronous active-low reset (rst_n)
// - Synchronous load from ui_in when LOAD=1
// - Count enable (CNT_EN)
// - Tri-state outputs on uio_* controlled by OE
//
// Pin map (TinyTapeout wrapper):
//   ui_in[7:0]   : LOAD DATA (preset value)
//   uio_in[0]    : LOAD  (1 => load ui_in on next rising edge)
//   uio_in[1]    : CNT_EN (1 => increment on rising edge)
//   uio_in[2]    : OE (1 => drive uio_out; 0 => tri-state)
//   others       : don't care
//
// Outputs:
//   uo_out[7:0]  : counter value, driven only when ena=1 (else 0)
//   uio_out[7:0] : counter value (same), gated by OE; tri-stated when OE=0
//   uio_oe[7:0]  : {8{OE}} when ena=1, else 0
//
// Behavior when ena=0:
//   - Counter holds its value (no counting, no loading)
//   - uo_out forced to 0
//   - uio_oe forced to 0 (tri-state), uio_out forced to 0

`default_nettype none

module tt_um_prog_counter (
    input  wire [7:0] ui_in,   // load data
    output wire [7:0] uo_out,  // counter value (driven only when ena=1)
    input  wire [7:0] uio_in,  // control signals
    output wire [7:0] uio_out, // counter value (tri-state via uio_oe)
    output wire [7:0] uio_oe,  // tri-state enables
    input  wire       ena,     // fabric enable from TinyTapeout
    input  wire       clk,     // clock
    input  wire       rst_n    // async active-low reset
);

    // Control signals
    wire load   = uio_in[0];
    wire cnt_en = uio_in[1];
    wire oe     = uio_in[2];

    // 8-bit counter register
    reg [7:0] cnt;

    // Asynchronous reset, synchronous behaviors gated by `ena`
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 8'h00;
        end else if (ena) begin
            if (load) begin
                cnt <= ui_in;
            end else if (cnt_en) begin
                cnt <= cnt + 8'h01;
            end
            // else hold
        end
        // If ena==0: hold value; outputs are separately gated below.
    end

    // Output gating per TinyTapeout convention
    wire [7:0] visible = cnt;

    // Primary outputs: only drive when ena=1
    assign uo_out = ena ? visible : 8'h00;

    // Tri-state bus: drive value on uio_out, but only enabled when (ena && oe)
    assign uio_out = ena ? visible : 8'h00;
    assign uio_oe  = ena ? {8{oe}} : 8'h00;

endmodule

`default_nettype wire
