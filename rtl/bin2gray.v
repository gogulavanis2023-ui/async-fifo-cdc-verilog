/*module b2g_converter #(parameter WIDTH=6) (input [WIDTH-1:0] binary, output [WIDTH-1:0] gray);
  assign gray = binary ^ (binary >> 1);
endmodule*/

module bin2gray
        (input [5:0] bin, //binary input
         output [5:0] G //gray code output
        );

//xor gates.
assign G[5] = bin[5];
assign G[4] = bin[5] ^ bin[4];
assign G[3] = bin[4] ^ bin[3];
assign G[2] = bin[3] ^ bin[2];
assign G[1] = bin[2] ^ bin[1];
assign G[0] = bin[1] ^ bin[0];

endmodule

