module double_sync(clk, rst_n, in, out);
  input clk, rst_n;
  input [5:0] in;
  output [5:0] out;

  reg [5:0] in_d, out;

  always @(posedge clk or negedge rst_n)
    if(!rst_n)
      begin
        in_d <= 5'b0;
        out <= 5'b0;
      end     
    else
      begin
        in_d <= in;
        out <= in_d;
      end

endmodule
