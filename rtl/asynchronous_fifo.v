`timescale 1 ps / 1 ps
module asynchronous_fifo #(parameter DEPTH=32, DATA_WIDTH=8, PTR_WIDTH = 6) (
  input wr_clk, rd_clk, rst_n,
  input wr_en, rd_en,
  input [DATA_WIDTH-1:0] data_in,
  output [DATA_WIDTH-1:0] data_out,
  output full, empty
);
  
  reg [PTR_WIDTH -1:0] w_ptr, r_ptr; //$clog2 will return the log base 2 of the argument 
  
 wire [5:0] wptr_G, wptr_G_sync, wptr_bin_sync;
 wire [5:0] rptr_G, rptr_G_sync, rptr_bin_sync;
  
  // Write pointer to FIFO
  always@(posedge wr_clk or negedge rst_n)
    if(!rst_n) 
      w_ptr <= 0;
    else if(wr_en & !full)
      w_ptr <= w_ptr + 1;
    
 bin2gray B2G_WRPTR_INST(.bin(w_ptr),.G(wptr_G)); 
 double_sync SYNC_WRPTR(.clk(rd_clk), .rst_n(rst_n), .in(wptr_G), .out(wptr_G_sync));
 gray2bin G2B_WRPTR_INST(.G(wptr_G_sync), .bin(wptr_bin_sync));
 
 
  // Read pointer to FIFO
  always@(posedge rd_clk or negedge rst_n) 
    if(!rst_n) 
      r_ptr <= 0;
    else if(rd_en & !empty) 
      r_ptr <= r_ptr + 1;
      
 bin2gray B2G_RDPTR_INST(.bin(r_ptr),.G(rptr_G)); 
 double_sync SYNC_RDPTR(.clk(wr_clk), .rst_n(rst_n), .in(rptr_G), .out(rptr_G_sync));
 gray2bin G2B_RDPTR_INST(.G(rptr_G_sync), .bin(rptr_bin_sync));
    
  dpram RAM_INST(
    .data(data_in),
    .rd_aclr(!rst_n),
    .rdaddress(r_ptr[4:0]),
    .rdclock(rd_clk),
    .rden(rd_en & !empty),   // read only when not empty
    .wraddress(w_ptr[4:0]),
    .wrclock(wr_clk),
    .wren(wr_en & !full),    // write only when not full (prevents overwrite)
    .q(data_out));
  
  assign full = (w_ptr[5] != rptr_bin_sync[5]) && (w_ptr[4:0] == rptr_bin_sync[4:0]);
  
  assign empty = (wptr_bin_sync == r_ptr);
  
    
endmodule
