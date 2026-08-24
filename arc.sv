interface arc(input bit clk);
logic [31:0] data_in ;
logic [31:0] data_out;
logic rst_n;
clocking cb @(posedge clk);
default input #1step output #0;
  input data_in;
  output data_out;
endclocking;
modport mode1(clocking cb, output rst_n
);
endinterface