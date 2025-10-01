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
    // Control wires
    wire load   = uio_in[0];
    wire cnt_en = uio_in[1];
    wire oe     = uio_in[2];

    // 8-bit counter
    reg [7:0] cnt;

    // Asynchronous active-low reset; sync load/increment gated by ena
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= 8'h00;
        end else if (ena) begin
            if (load)      cnt <= ui_in;
            else if (cnt_en) cnt <= cnt + 8'h01;
            // else hold previous value
        end
        // if ena==0: hold previous value
    end

    // Primary user outputs: only valid when ena==1, else force 0
    assign uo_out = ena ? cnt : 8'h00;

    // Bidirectional bus: only present the counter when both ena and OE are high.
    // When OE=0 (or ena=0), force uio_out to 0 and deassert all output enables.
    assign uio_out = (ena && oe) ? cnt : 8'h00;
    assign uio_oe  = (ena && oe) ? 8'hFF : 8'h00;

endmodule
`default_nettype wire
