// - async active-low reset (rst_n)
// - sync load from ui_in when LOAD=1
// - count enable CNT_EN
// - tri-state bus on uio_* via OE
// Control pins on uio_in:
//   uio_in[0] = LOAD
//   uio_in[1] = CNT_EN
//   uio_in[2] = OE

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,   // load data
    output wire [7:0] uo_out,  // counter value (only when ena=1)
    input  wire [7:0] uio_in,  // control pins (LOAD,CNT_EN,OE)
    output wire [7:0] uio_out, // tri-state data bus
    output wire [7:0] uio_oe,  // tri-state enables
    input  wire       ena,     // fabric enable
    input  wire       clk,     // clock
    input  wire       rst_n    // async active-low reset
);

    // controls
    wire load   = uio_in[0];
    wire cnt_en = uio_in[1];
    wire oe     = uio_in[2];

    // counter
    reg [7:0] cnt;

    // Asynchronous reset, synchronous load/count gated by ena
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 8'h00;
        end else if (ena) begin
            if (load)      cnt <= ui_in;
            else if (cnt_en) cnt <= cnt + 8'h01;
            // else hold
        end
        // if ena==0: hold
    end

    // Outputs: gate by ena; tri-state enables by (ena & oe)
    assign uo_out = ena ? cnt : 8'h00;
    assign uio_out = ena ? cnt : 8'h00;
    assign uio_oe  = (ena && oe) ? 8'hFF : 8'h00;

endmodule

`default_nettype wire
