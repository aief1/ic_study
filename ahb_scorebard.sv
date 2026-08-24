class ahb_scoreboard;
 mailbox #(ahb_transaction) act_mbx;
 mailbox #(ahb_transaction) exp_mbx;

 int pass_cnt;
 int fail_cnt;

 function new(
        mailbox #(ahb_transaction) act_mbx,
        mailbox #(ahb_transaction) exp_mbx
 );
 this.act_mbx = act_mbx;
 this.exp_mbx = exp_mbx;
 pass_cnt = 0;
 fail_cnt = 0;
 endfunction

 task run();
 forever begin
    ahb_transaction act, exp;
    act_mbx.get(act);
    exp_mbx.get(exp);

    compare(act, exp);

 end
 endtask
 function void compare(ahb_transaction act, ahb_transaction exp);
 bit match = 1;
 if (act.hresp !== exp.hresp)begin
    match = 0;
    $error("[SCB] HRESP MISMATCH: act=%b exp=%b", act.hresp, exp.hresp);
 end
 if(!exp.hwrite && act.hrdata !== exp.hrdata) begin
    match = 0;
             $error("[SCB] HRDATA MISMATCH @0x%08h: act=0x%08h exp=0x%08h",
                   act.haddr, act.hrdata, exp.hrdata);
        end

        // 3. 比较 SRAM 写数据（写操作）
        if (exp.hwrite && act.sram_wdata !== exp.sram_wdata) begin
            match = 0;
            $error("[SCB] SRAM_WDATA MISMATCH @0x%08h: act=0x%08h exp=0x%08h",
                   act.haddr, act.sram_wdata, exp.sram_wdata);
        end

        // 4. 比较 SRAM 地址和字节选通
        if (act.sram_addr !== exp.sram_addr) begin
            match = 0;
            $error("[SCB] SRAM_ADDR MISMATCH: act=0x%0h exp=0x%0h", act.sram_addr, exp.sram_addr);
        end
        if (act.sel !== exp.sel) begin
            match = 0;
            $error("[SCB] SEL MISMATCH: act=%b exp=%b", act.sel, exp.sel);
        end
        if (match) pass_cnt++;
        else fail_cnt++;
 endfunction
 endclass