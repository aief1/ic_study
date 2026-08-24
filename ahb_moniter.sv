class ahb_monitor;
    virtual AHB_SRAMC_IF.mon vif;
    mailbox #(ahb_transaction) mbx;

    function new(virtual AHB_SRAMC_IF.mon vif,mailbox #(ahb_transaction) mbx);
    this.vif = vif;
    this.mbx = mbx;
    endfunction

    task run();
    forever begin
        @(posedge vif.HCLK);
        if(vif.mon_cb.HSEL && (vif.mon_cb.HTRANS inside {2'b10, 2'b11}))begin
            ahb_transction txn = new();
                // ---- 地址相位 ----
                txn.addr   = vif.mon_cb.HADDR;
                txn.write  = vif.mon_cb.HWRITE;
                txn.size   = vif.mon_cb.HSIZE;
                txn.burst  = vif.mon_cb.HBURST;
                txn.trans  = vif.mon_cb.HTRANS;
                if (txn.write)
                    txn.wdata = vif.mon_cb.HWDATA;

                // ---- 等一拍到数据相位 ----
                @(posedge vif.HCLK);
                if (!txn.write)
                    txn.rdata = vif.mon_cb.HRDATA;
                txn.resp = vif.mon_cb.HRESP;

                // ---- SRAM 侧 ----
                txn.sram_addr  = vif.mon_cb.SRAM_ADDR;
                txn.sram_wen   = vif.mon_cb.SRAM_WEN;
                txn.sel        = vif.mon_cb.SEL;
                txn.sram_wdata = vif.mon_cb.SRAM_WDATA;

                // 发给 Scoreboard
                mbx.put(txn);
        end
    end
    endtask

endclass
