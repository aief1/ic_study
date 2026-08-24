// testbench：通过 mode1 modport 使用 arc 接口
module test(arc.mode1 u_arc);

  // 1) 复位：rst_n 在 modport 里是 output，由 TB 驱动
  initial begin
    u_arc.rst_n = 0;
    repeat (3) @(u_arc.cb);       // 3 个时钟有效沿
    u_arc.rst_n = 1;
  end

  // 2) 激励：通过 clocking 块驱动 data_out（cb 中为 output，只能驱动不能读）
  initial begin
    wait (u_arc.rst_n === 1'b1);  // 等复位释放
    @(u_arc.cb);
    u_arc.cb.data_out <= 32'hA5A5_5A5A;
    @(u_arc.cb);
    u_arc.cb.data_out <= 32'h1234_5678;
    @(u_arc.cb);
    u_arc.cb.data_out <= 32'hDEAD_BEEF;
  end

  // 3) 采样：cb 中 input 的信号可以读（#1step 采样值）
  always @(u_arc.cb) begin
    $display("[%0t] TB sampled data_in = %h", $time, u_arc.cb.data_in);
  end

  // 4) 结束
  initial begin
    repeat (20) @(u_arc.cb);
    $finish;
  end

endmodule
