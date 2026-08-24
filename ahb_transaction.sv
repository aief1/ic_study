class ahb_transaction;

bit [31:0] addr;
bit        write;
bit [2:0] size;
bit [2:0] burst;
bit [1:0] trans;
bit [31:0] wdata;

    // 数据相位（下一拍）
bit [31:0] rdata;       // 读数据
bit [1:0]  resp;

// SRAM 侧（DUT 对 SRAM 做了什么）
bit [9:0]  sram_addr;   // 用最大位宽 10
bit        sram_wen;
bit [3:0]  sel;
bit [31:0] sram_wdata;
endclass