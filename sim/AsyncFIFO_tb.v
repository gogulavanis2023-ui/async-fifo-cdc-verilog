`timescale 1 ps / 1 ps

module AsyncFIFO_tb;

    parameter DEPTH      = 32;
    parameter DATA_WIDTH = 8;
    parameter PTR_WIDTH  = 6;      // log2(DEPTH)+1 : extra MSB for full/empty

    // -----------------------------------------
    // Write domain
    // -----------------------------------------
    reg wr_clk;
    reg wr_en;
    reg [DATA_WIDTH-1:0] data_in;

    // -----------------------------------------
    // Read domain
    // -----------------------------------------
    reg rd_clk;
    reg rd_en;

    // -----------------------------------------
    // Reset
    // -----------------------------------------
    reg rst_n;

    // -----------------------------------------
    // FIFO outputs
    // -----------------------------------------
    wire [DATA_WIDTH-1:0] data_out;
    wire full;
    wire empty;

    integer i, j;                  // separate loop variables for each process

    // -----------------------------------------
    // Scoreboard (expected data model)
    // -----------------------------------------
    reg [DATA_WIDTH-1:0] exp_q [0:255];
    integer wr_count = 0, rd_count = 0, errors = 0;
    reg     rd_valid;

    // -----------------------------------------
    // DUT
    // -----------------------------------------
    asynchronous_fifo #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH),
        .PTR_WIDTH(PTR_WIDTH)
    ) DUT (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    // -----------------------------------------
    // Write clock : 10 ps period
    // -----------------------------------------
    always #5 wr_clk = ~wr_clk;

    // -----------------------------------------
    // Read clock : 14 ps period (asynchronous to write clock)
    // -----------------------------------------
    always #7 rd_clk = ~rd_clk;

    // -----------------------------------------
    // Reset
    // -----------------------------------------
    initial begin

        wr_clk  = 1'b0;
        rd_clk  = 1'b0;

        wr_en   = 1'b0;
        rd_en   = 1'b0;

        data_in = 8'h00;

        rst_n   = 1'b0;

        #50;

        rst_n = 1'b1;

        $display("----------------------------------------");
        $display("RESET RELEASED");
        $display("----------------------------------------");

    end

    // -----------------------------------------
    // WRITE PROCESS
    // 40 write attempts into a 32-deep FIFO -> last 8 must be blocked by FULL
    // -----------------------------------------
    initial begin

        wait(rst_n == 1'b1);

        #10;

        $display("----------------------------------------");
        $display("WRITE OPERATION STARTED");
        $display("----------------------------------------");

        for(i = 0; i < 40; i = i + 1) begin

            @(posedge wr_clk);

            wr_en   <= 1'b1;               // non-blocking: no race with DUT
            data_in <= i + 8'hA0;          // A0, A1, A2 ...

        end

        @(posedge wr_clk);

        wr_en <= 1'b0;

        $display("----------------------------------------");
        $display("WRITE OPERATION COMPLETED");
        $display("----------------------------------------");

    end

    // -----------------------------------------
    // READ PROCESS
    // Starts after the FIFO is full; 45 read attempts -> last ones blocked by EMPTY
    // -----------------------------------------
    initial begin

        #600;

        $display("----------------------------------------");
        $display("READ OPERATION STARTED");
        $display("----------------------------------------");

        for(j = 0; j < 45; j = j + 1) begin

            @(posedge rd_clk);

            rd_en <= 1'b1;

        end

        @(posedge rd_clk);

        rd_en <= 1'b0;

        #100;

        $display("----------------------------------------");
        $display("READ OPERATION COMPLETED");
        $display("----------------------------------------");
        $display("Words written : %0d  (expected %0d)", wr_count, DEPTH);
        $display("Words read    : %0d  (expected %0d)", rd_count, DEPTH);
        if (errors == 0 && wr_count == DEPTH && rd_count == DEPTH)
            $display("*** TEST PASSED ***");
        else
            $display("*** TEST FAILED : %0d data errors ***", errors);
        $display("----------------------------------------");

        $finish;

    end

    // -----------------------------------------
    // WRITE MONITOR : log every write and push expected data
    // -----------------------------------------
    always @(posedge wr_clk) begin
        if (wr_en) begin
            if (!full) begin
                exp_q[wr_count] = data_in;
                $display("[%0t] WRITE : data_in = %h | full = %b", $time, data_in, full);
                wr_count = wr_count + 1;
            end
            else
                $display("[%0t] WRITE BLOCKED : FIFO FULL", $time);
        end
    end

    // -----------------------------------------
    // READ MONITOR : read accepted at posedge, data_out valid after it
    // (RAM address is registered on rd_clk), so check on the next negedge
    // -----------------------------------------
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n)
            rd_valid <= 1'b0;
        else begin
            rd_valid <= rd_en & !empty;
            if (rd_en & empty)
                $display("[%0t] READ BLOCKED : FIFO EMPTY", $time);
        end
    end

    always @(negedge rd_clk) begin
        if (rd_valid) begin
            if (data_out === exp_q[rd_count])
                $display("[%0t] READ  : data_out = %h | empty = %b", $time, data_out, empty);
            else begin
                $display("[%0t] READ  : data_out = %h  ** MISMATCH, expected %h **",
                         $time, data_out, exp_q[rd_count]);
                errors = errors + 1;
            end
            rd_count = rd_count + 1;
        end
    end

endmodule
