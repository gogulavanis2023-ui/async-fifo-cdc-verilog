// =====================================================================
// DE2-115 top level for asynchronous FIFO (Task 6)
//
//  Write domain : wr_clk = CLOCK_50          (50 MHz)
//  Read  domain : rd_clk = CLOCK2_50 / 4     (12.5 MHz)  -> different clocks
//
//  SW[7:0]  : data to write            (also shown on LEDR[7:0] and HEX5-HEX4)
//  KEY[0]   : press = write one word   (debounced, 1 wr_clk pulse)
//  KEY[1]   : press = read  one word   (debounced, 1 rd_clk pulse)
//  KEY[3]   : reset (active low)
//  HEX1-HEX0: data read from FIFO (data_out)
//  LEDG[0]  : empty      LEDG[1] : full
//
//  Port names match the Terasic DE2-115 pin file, so you can import
//  DE2_115.qsf or run DE2_115_pins.tcl.
// =====================================================================
module AsyncFIFO_top (
    input         CLOCK_50,
    input         CLOCK2_50,
    input  [3:0]  KEY,
    input  [17:0] SW,
    output [17:0] LEDR,
    output [8:0]  LEDG,
    output [6:0]  HEX0, HEX1, HEX2, HEX3, HEX4, HEX5, HEX6, HEX7
);

    wire rst_n  = KEY[3];
    wire wr_clk = CLOCK_50;

    // ---- read clock: CLOCK2_50 / 4 ----
    reg [1:0] div;
    always @(posedge CLOCK2_50 or negedge rst_n)
        if (!rst_n) div <= 2'b00;
        else        div <= div + 1'b1;
    wire rd_clk = div[1];

    // ---- push buttons -> single clean pulse in each domain ----
    wire wr_en, rd_en;
    key_pulse #(.CNT_MAX(20'd1_000_000)) WR_KEY (   // ~20 ms @ 50 MHz
        .clk(wr_clk), .rst_n(rst_n), .key_n(KEY[0]), .pulse(wr_en));
    key_pulse #(.CNT_MAX(20'd250_000))   RD_KEY (   // ~20 ms @ 12.5 MHz
        .clk(rd_clk), .rst_n(rst_n), .key_n(KEY[1]), .pulse(rd_en));

    // ---- the FIFO (your design, unchanged) ----
    wire [7:0] data_out;
    wire full, empty;

    asynchronous_fifo #(.DEPTH(32), .DATA_WIDTH(8), .PTR_WIDTH(6)) FIFO_INST (
        .wr_clk(wr_clk), .rd_clk(rd_clk), .rst_n(rst_n),
        .wr_en(wr_en), .rd_en(rd_en),
        .data_in(SW[7:0]), .data_out(data_out),
        .full(full), .empty(empty));

    // ---- outputs ----
    assign LEDR = {10'b0, SW[7:0]};
    assign LEDG = {7'b0, full, empty};

    seg7 S0 (.hex(data_out[3:0]), .seg(HEX0));
    seg7 S1 (.hex(data_out[7:4]), .seg(HEX1));
    seg7 S4 (.hex(SW[3:0]),       .seg(HEX4));
    seg7 S5 (.hex(SW[7:4]),       .seg(HEX5));
    assign HEX2 = 7'h7F;   // blank (active-low segments)
    assign HEX3 = 7'h7F;
    assign HEX6 = 7'h7F;
    assign HEX7 = 7'h7F;

endmodule


// ---------------------------------------------------------------------
// Debounce an active-low push button and output a 1-clock pulse on press
// ---------------------------------------------------------------------
module key_pulse #(parameter [19:0] CNT_MAX = 20'd1_000_000) (
    input  clk, rst_n, key_n,
    output pulse
);
    reg [1:0]  sync;        // 2-FF synchronizer for the async button
    reg [19:0] cnt;
    reg        stable, stable_d;

    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            sync <= 2'b11; cnt <= 0; stable <= 1'b1; stable_d <= 1'b1;
        end
        else begin
            sync     <= {sync[0], key_n};
            stable_d <= stable;
            if (sync[1] == stable)      cnt <= 0;
            else if (cnt == CNT_MAX) begin
                stable <= sync[1];
                cnt    <= 0;
            end
            else                        cnt <= cnt + 1'b1;
        end

    assign pulse = stable_d & ~stable;   // falling edge = key pressed
endmodule


// ---------------------------------------------------------------------
// Hex to 7-segment, active-low (DE2-115): seg[6:0] = g f e d c b a
// ---------------------------------------------------------------------
module seg7 (input [3:0] hex, output reg [6:0] seg);
    always @(*)
        case (hex)
            4'h0: seg = 7'b1000000;  4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;  4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;  4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;  4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;  4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;  4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;  4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;  4'hF: seg = 7'b0001110;
        endcase
endmodule
