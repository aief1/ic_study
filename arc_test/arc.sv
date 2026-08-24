interface arc(input logic clk);
  logic [31:0] data_in;
  logic [31:0] data_out;
  logic rst_n;

  clocking cb @(posedge clk);
    default input #1step output #0;
    input data_in;      // TB 采样（相对 TB 而言）
    output data_out;    // TB 驱动（相对 TB 而言）
  endclocking

  modport mode1(clocking cb, output rst_n);
endinterface
