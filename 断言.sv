task write_reg(input int a, input int b);
 assert (a inside {[0:255]} else $error("本地：%0h",a));
 
endtask

property ok;
@(posedge clk) req |-> gnt;

endproperty
assert property (ok);