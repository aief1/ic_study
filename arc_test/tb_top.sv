// 顶层：产生时钟，例化接口，用 "假DUT" 驱动 data_in，再例化 test
module tb_top;
  logic clk;

  arc u_arc(.clk(clk));              // 例化接口（clk 是接口端口）

  // 假 DUT：每个时钟沿驱动 data_in（模拟 DUT 输出）
  initial u_arc.data_in = 32'h0;
  always @(posedge clk) begin
    u_arc.data_in <= u_arc.data_in + 32'h1;
  end

  // 时钟：10ns 周期
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // 例化测试模块（把接口实例连到 mode1 modport 端口）
  test u_test(.u_arc(u_arc));

  // 顶层可访问接口全部原始信号，做全局观测
  initial $monitor("[%0t] rst_n=%b data_in=%h data_out=%h",
                   $time, u_arc.rst_n, u_arc.data_in, u_arc.data_out);

  // 出波形：只有 +define+DUMP_FSDB 时才 dump（普通 sim 不受影响）
`ifdef DUMP_FSDB
  initial begin
    $fsdbDumpfile("wave.fsdb");
    $fsdbDumpvars(0, tb_top);
  end
`endif

  initial #220 $finish;
endmodule
