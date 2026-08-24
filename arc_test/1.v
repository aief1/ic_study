interface arc(input bit  clk);
  logic [31:0]data_in, data1
  logic data_o,rst_n;
  clocking cb @(posedge clk);
  default input #1step output #0;
  	input data_in;
	output data_o;
  endcloaking;
modport model1(clocking cb, output rst_n);
endinterface;
