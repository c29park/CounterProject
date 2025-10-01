`default_nettype none
module tt_um_example (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Controls
    wire load   = uio_in[0];
    wire cnt_en = uio_in[1];
    wire oe     = uio_in[2];

    // Counter register
    reg [7:0] cnt;

    // **Async reset**; sync load/count only when ena==1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 8'h00;
        end else if (ena) begin
            if (load)      cnt <= ui_in;
            else if (cnt_en) cnt <= cnt + 8'h01;
            // else hold
        end
    end

    // Outputs:
    // - Primary outputs forced to 0 when ena==0
    // - Tri-state bus enabled only when (ena && oe). When not enabled, drive 0 and set OE low.
    assign uo_out = ena ? cnt : 8'h00;
    assign uio_out = ena ? cnt : 8'h00;   // <-- DO NOT tie to ui_in
    assign uio_oe  = (ena && oe) ? 8'hFF : 8'h00;
endmodule
`default_nettype wire
