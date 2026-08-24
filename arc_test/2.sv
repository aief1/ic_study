module top(arc);
.arc arc_if(clk);
initial begin
	clk = 1'b0;
	foever #5 clk=~clk;
       end
test test_if(arc);
aarr aarr_if(.data_in (arc_if.data_in)
             .clk (arc_if.clk);
endmodule
