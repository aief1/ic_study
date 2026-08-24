module top;
bit clk;
always #5 clk =~clk;
arc arc_if(clk);

test test_if(arc_if);

ok ok_if(.data_in (arc_if.data_in),
        .data_out (arc_if.data_out),
        .clk (clk));


    
endmodule