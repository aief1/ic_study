class ahb_driver;
virtual AHB_SRAMC_IF.drv vif;

function new(virtual AHB_SRAMC_IF.drv vif);
    this.vif = vif;
endfunction

task write(input bit [31:0] addr, input bit[31:0]data,
           input bit [2:0] size = 3'b010,
           output bit [1:0] resp);
  @(posedge vif.HCLK);
  vif.drv_cb.HSEL   <= 1'b1;
  vif.drv_cb.HADDR  <= addr;
  vif.drv_cb.HWRITE <= 1'b1;       // 写
  vif.drv_cb.HTRANS <= 2'b10;      // NONSEQ
  vif.drv_cb.HSIZE  <= size;
  vif.drv_cb.HBURST <= 3'b000;     // SINGLE
  vif.drv_cb.HWDATA <= data;

  @(posedge vif.HCLK);

    resp = vif.drv_cb.HRESP;

        // 回到 IDLE
    vif.drv_cb.HSEL   <= 1'b0;
    vif.drv_cb.HTRANS <= 2'b00;

endtask

    task read(input bit [31:0] addr,
              input bit [2:0] size = 3'b010,
              output bit [31:0] data,
              output bit [1:0] resp);
        @(posedge vif.HCLK);
        // 地址相位
        vif.drv_cb.HSEL   <= 1'b1;
        vif.drv_cb.HADDR  <= addr;
        vif.drv_cb.HWRITE <= 1'b0;       // 读
        vif.drv_cb.HTRANS <= 2'b10;      // NONSEQ
        vif.drv_cb.HSIZE  <= size;
        vif.drv_cb.HBURST <= 3'b000;     // SINGLE
        vif.drv_cb.HWDATA <= 32'h0;

        @(posedge vif.HCLK);             // 数据相位：采样数据
        data = vif.drv_cb.HRDATA;
        resp = vif.drv_cb.HRESP;

        // 回到 IDLE
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HTRANS <= 2'b00;
    endtask
endclass