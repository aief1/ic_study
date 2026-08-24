// ====================================================================================================================
// (c) Copyright 2026 CBB Team. All rights reserved.
// Designer     : Leo
// Project      : CBB
// Create Date  : 2026-08-14
// Description  : tb_cbb_ahb_sramc — AHB-SRAMC SVTB 验证顶层
//                包含 driver task、monitor task、SRAM 模型、参考模型、测试用例
// ====================================================================================================================

`timescale 1ns/1ps

module tb_cbb_ahb_sramc;

    // =================================================================================================================
    // 参数
    // =================================================================================================================
    localparam int SRAM_ADDR_WIDTH = 10;
    localparam int SRAM_DEPTH      = 1 << SRAM_ADDR_WIDTH;  // 1024 words
    localparam int DATA_WIDTH      = 32;
    localparam int ADDR_WIDTH      = 32;

    // =================================================================================================================
    // 信号
    // =================================================================================================================
    logic                              HCLK;
    logic                              HRESETn;

    // =================================================================================================================
    // 时钟生成
    // =================================================================================================================
    initial begin
        HCLK = 0;
        forever #5 HCLK = ~HCLK;  // 100MHz
    end

    // =================================================================================================================
    // 接口例化
    // =================================================================================================================
    ahb_sramc_if #(
        .SRAM_ADDR_WIDTH (SRAM_ADDR_WIDTH),
        .DATA_WIDTH      (DATA_WIDTH),
        .ADDR_WIDTH      (ADDR_WIDTH)
    ) vif (
        .HCLK    (HCLK),
        .HRESETn (HRESETn)
    );

    // =================================================================================================================
    // DUT 例化
    // =================================================================================================================
    CBB_AHB_SRAMC #(
        .SRAM_ADDR_WIDTH (SRAM_ADDR_WIDTH),
        .BASE_ADDR       (32'h0000_0000),
        .ADDR_MASK       (32'hFFFF_FC00),
        .BYTE_ENABLE     (1),
        .PIPELINE_STAGES (1)
    ) U_DUT (
        .HCLK         (HCLK),
        .HRESETn      (HRESETn),
        .HSEL         (vif.HSEL),
        .HADDR        (vif.HADDR),
        .HWRITE       (vif.HWRITE),
        .HTRANS       (vif.HTRANS),
        .HSIZE        (vif.HSIZE),
        .HBURST       (vif.HBURST),
        .HPROT        (vif.HPROT),
        .HWDATA       (vif.HWDATA),
        .HRDATA       (vif.HRDATA),
        .HREADY_OUT   (vif.HREADY_OUT),
        .HRESP        (vif.HRESP),
        .SRAM_ADDR    (vif.SRAM_ADDR),
        .SRAM_WDATA   (vif.SRAM_WDATA),
        .SRAM_RDATA   (vif.SRAM_RDATA),
        .SRAM_WEN     (vif.SRAM_WEN),
        .SRAM_CEN     (vif.SRAM_CEN),
        .SEL          (vif.SEL)
    );

    // =================================================================================================================
    // SRAM 模型（同步单端口，同周期读）
    // =================================================================================================================
    logic [DATA_WIDTH-1:0] sram_mem [0:SRAM_DEPTH-1];

    // SRAM 初始化
    initial begin
        for (int i = 0; i < SRAM_DEPTH; i++) begin
            sram_mem[i] = 32'h0000_0000;
        end
    end

    // SRAM 读写操作
    always @(posedge HCLK) begin : SRAM_MODEL_PROC
        if (vif.SRAM_CEN == 1'b0) begin
            if (vif.SRAM_WEN == 1'b1) begin
                // 写操作：按字节选通写入
                if (vif.SEL[0]) sram_mem[vif.SRAM_ADDR][7:0]   <= vif.SRAM_WDATA[7:0];
                if (vif.SEL[1]) sram_mem[vif.SRAM_ADDR][15:8]  <= vif.SRAM_WDATA[15:8];
                if (vif.SEL[2]) sram_mem[vif.SRAM_ADDR][23:16] <= vif.SRAM_WDATA[23:16];
                if (vif.SEL[3]) sram_mem[vif.SRAM_ADDR][31:24] <= vif.SRAM_WDATA[31:24];
            end
            // 读操作（组合逻辑，同周期输出）
            vif.SRAM_RDATA <= sram_mem[vif.SRAM_ADDR];
        end else begin
            vif.SRAM_RDATA <= {DATA_WIDTH{1'b0}};
        end
    end

    // =================================================================================================================
    // 统计
    // =================================================================================================================
    int pass_cnt = 0;
    int fail_cnt = 0;
    int test_id  = 0;

    // =================================================================================================================
    // AHB Driver Tasks
    // =================================================================================================================

    // ---- 单次读 ----
    task ahb_read(
        input  logic [31:0]  addr,
        input  logic [2:0]   size = 3'b010,   // WORD
        input  logic [2:0]   burst = 3'b000,  // SINGLE
        output logic [31:0]  rdata,
        output logic [1:0]   resp
    );
        @(posedge HCLK);
        // 地址相位
        vif.drv_cb.HSEL   <= 1'b1;
        vif.drv_cb.HADDR  <= addr;
        vif.drv_cb.HWRITE <= 1'b0;
        vif.drv_cb.HTRANS <= 2'b10;  // NONSEQ
        vif.drv_cb.HSIZE  <= size;
        vif.drv_cb.HBURST <= burst;
        vif.drv_cb.HPROT  <= 4'b0011;
        vif.drv_cb.HWDATA <= '0;

        @(posedge HCLK);
        // 数据相位：采样响应
        rdata = vif.drv_cb.HRDATA;
        resp  = vif.drv_cb.HRESP;

        // 回到 IDLE
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HTRANS <= 2'b00;
        vif.drv_cb.HADDR  <= '0;
    endtask

    // ---- 单次写 ----
    task ahb_write(
        input  logic [31:0]  addr,
        input  logic [31:0]  wdata,
        input  logic [2:0]   size = 3'b010,   // WORD
        input  logic [2:0]   burst = 3'b000,  // SINGLE
        output logic [1:0]   resp
    );
        @(posedge HCLK);
        // 地址相位
        vif.drv_cb.HSEL   <= 1'b1;
        vif.drv_cb.HADDR  <= addr;
        vif.drv_cb.HWRITE <= 1'b1;
        vif.drv_cb.HTRANS <= 2'b10;  // NONSEQ
        vif.drv_cb.HSIZE  <= size;
        vif.drv_cb.HBURST <= burst;
        vif.drv_cb.HPROT  <= 4'b0011;
        vif.drv_cb.HWDATA <= wdata;

        @(posedge HCLK);
        // 数据相位：采样响应
        resp = vif.drv_cb.HRESP;

        // 回到 IDLE
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HTRANS <= 2'b00;
        vif.drv_cb.HADDR  <= '0;
        vif.drv_cb.HWDATA <= '0;
    endtask

    // ---- Burst 读 ----
    task ahb_burst_read(
        input  logic [31:0]  start_addr,
        input  logic [2:0]   burst_type,
        input  int           beat_cnt,
        output logic [31:0]  rdata_q[$],
        output logic [1:0]   resp_q[$]
    );
        rdata_q.delete();
        resp_q.delete();

        for (int beat = 0; beat < beat_cnt; beat++) begin
            logic [31:0] beat_addr;
            logic [31:0] beat_rdata;
            logic [1:0]  beat_resp;

            // 计算地址（首拍 NONSEQ，后续 SEQ）
            if (beat == 0) begin
                beat_addr = start_addr;
            end else begin
                // 增量地址（对于 WRAP，地址由主设备驱动，这里简化：递增值 = 4）
                beat_addr = start_addr + (beat * 4);
            end

            @(posedge HCLK);
            vif.drv_cb.HSEL   <= 1'b1;
            vif.drv_cb.HADDR  <= beat_addr;
            vif.drv_cb.HWRITE <= 1'b0;
            vif.drv_cb.HTRANS <= (beat == 0) ? 2'b10 : 2'b11;  // NONSEQ / SEQ
            vif.drv_cb.HSIZE  <= 3'b010;
            vif.drv_cb.HBURST <= burst_type;
            vif.drv_cb.HPROT  <= 4'b0011;
            vif.drv_cb.HWDATA <= '0;

            @(posedge HCLK);
            beat_rdata = vif.drv_cb.HRDATA;
            beat_resp  = vif.drv_cb.HRESP;
            rdata_q.push_back(beat_rdata);
            resp_q.push_back(beat_resp);
        end

        // 回到 IDLE
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HTRANS <= 2'b00;
        vif.drv_cb.HADDR  <= '0;
    endtask

    // =================================================================================================================
    // 检查任务
    // =================================================================================================================
    task check_equal(
        input string  test_name,
        input logic   pass,
        input string  msg
    );
        if (pass) begin
            pass_cnt++;
            $display("[PASS] [%s] %s", test_name, msg);
        end else begin
            fail_cnt++;
            $display("[FAIL] [%s] %s", test_name, msg);
        end
    endtask

    task check_resp(
        input string  test_name,
        input [1:0]   actual,
        input [1:0]   expected,
        input string  msg
    );
        check_equal(test_name, (actual == expected),
            $sformatf("%s — RESP: actual=%b expected=%b", msg, actual, expected));
    endtask

    task check_data(
        input string  test_name,
        input [31:0]  actual,
        input [31:0]  expected,
        input string  msg
    );
        check_equal(test_name, (actual == expected),
            $sformatf("%s — DATA: actual=0x%08h expected=0x%08h", msg, actual, expected));
    endtask

    // =================================================================================================================
    // 复位任务
    // =================================================================================================================
    task reset_dut();
        $display("--- Reset ---");
        vif.drv_cb.HSEL   <= 1'b0;
        vif.drv_cb.HADDR  <= '0;
        vif.drv_cb.HWRITE <= 1'b0;
        vif.drv_cb.HTRANS <= 2'b00;
        vif.drv_cb.HSIZE  <= 3'b000;
        vif.drv_cb.HBURST <= 3'b000;
        vif.drv_cb.HPROT  <= 4'b0000;
        vif.drv_cb.HWDATA <= '0;

        HRESETn <= 1'b0;
        repeat (4) @(posedge HCLK);
        HRESETn <= 1'b1;
        repeat (2) @(posedge HCLK);
        $display("--- Reset done ---");
    endtask

    // =================================================================================================================
    // 测试用例
    // =================================================================================================================

    // ---- TC01: 单次读写 ----
    task tc01_single_rw();
        logic [31:0] rdata;
        logic [1:0]  resp;

        $display("=== TC01: Single Read/Write ===");

        // 写 0xAABBCCDD 到地址 0x0000
        ahb_write(32'h0000_0000, 32'hAABBCCDD, 3'b010, 3'b000, resp);
        check_resp("TC01", resp, 2'b00, "Write to 0x0000");

        // 读回来验证
        ahb_read(32'h0000_0000, 3'b010, 3'b000, rdata, resp);
        check_resp("TC01", resp, 2'b00, "Read from 0x0000");
        check_data("TC01", rdata, 32'hAABBCCDD, "Read data match");

        // 写 0x12345678 到地址 0x03FC（最后）
        ahb_write(32'h0000_03FC, 32'h12345678, 3'b010, 3'b000, resp);
        check_resp("TC01", resp, 2'b00, "Write to 0x03FC");

        // 读回来验证
        ahb_read(32'h0000_03FC, 3'b010, 3'b000, rdata, resp);
        check_resp("TC01", resp, 2'b00, "Read from 0x03FC");
        check_data("TC01", rdata, 32'h12345678, "Read data match");
    endtask

    // ---- TC02: 地址越界错误 ----
    task tc02_addr_error();
        logic [31:0] rdata;
        logic [1:0]  resp;

        $display("=== TC02: Address out-of-range Error ===");

        // 读地址越界
        ahb_read(32'h0000_1000, 3'b010, 3'b000, rdata, resp);
        check_resp("TC02", resp, 2'b01, "Read out-of-range 0x1000");

        // 写地址越界
        ahb_write(32'h0000_2000, 32'hDEAD_BEEF, 3'b010, 3'b000, resp);
        check_resp("TC02", resp, 2'b01, "Write out-of-range 0x2000");
    endtask

    // ---- TC03: 字节写使能 ----
    task tc03_byte_enable();
        logic [31:0] rdata;
        logic [1:0]  resp;

        $display("=== TC03: Byte Write Enable ===");

        // 写 WORD 0x12345678 到 0x0000
        ahb_write(32'h0000_0000, 32'h12345678, 3'b010, 3'b000, resp);
        check_resp("TC03", resp, 2'b00, "Word write");

        // 读验证
        ahb_read(32'h0000_0000, 3'b010, 3'b000, rdata, resp);
        check_data("TC03", rdata, 32'h12345678, "Word read after word write");

        // 写 BYTE 0xAB 到 0x0000（低字节）
        ahb_write(32'h0000_0000, 32'h000000AB, 3'b000, 3'b000, resp);
        check_resp("TC03", resp, 2'b00, "Byte write to offset 0");

        // 读验证：只改了低字节
        ahb_read(32'h0000_0000, 3'b010, 3'b000, rdata, resp);
        check_data("TC03", rdata, 32'h123456AB, "Byte write check [7:0]");

        // 写 BYTE 0xCD 到 0x0001（第二个字节）
        ahb_write(32'h0000_0001, 32'h000000CD, 3'b000, 3'b000, resp);
        check_resp("TC03", resp, 2'b00, "Byte write to offset 1");

        ahb_read(32'h0000_0000, 3'b010, 3'b000, rdata, resp);
        check_data("TC03", rdata, 32'h12CD56AB, "Byte write check [15:8]");

        // 写 HALFWORD 0xFFFF 到 0x0002（高半字）
        ahb_write(32'h0000_0002, 32'h0000FFFF, 3'b001, 3'b000, resp);
        check_resp("TC03", resp, 2'b00, "Halfword write to offset 2");

        ahb_read(32'h0000_0000, 3'b010, 3'b000, rdata, resp);
        check_data("TC03", rdata, 32'h12CDFFFF, "Halfword write check [31:16]");
    endtask

    // ---- TC04: WRAP4 Burst 读 ----
    task tc04_wrap4_burst();
        logic [31:0] rdata_q[$];
        logic [1:0]  resp_q[$];

        $display("=== TC04: WRAP4 Burst Read ===");

        // 先写入 4 个字
        ahb_write(32'h0000_0000, 32'hAAA0_0000, 3'b010, 3'b000, resp_q.pop_back());
        ahb_write(32'h0000_0004, 32'hAAA0_0001, 3'b010, 3'b000, resp_q.pop_back());
        ahb_write(32'h0000_0008, 32'hAAA0_0002, 3'b010, 3'b000, resp_q.pop_back());
        ahb_write(32'h0000_000C, 32'hAAA0_0003, 3'b010, 3'b000, resp_q.pop_back());

        // WRAP4 读（起始地址 0x0008，回绕边界 0x0000~0x000F）
        // 期望：addr=0x8→0xC→0x0→0x4
        ahb_burst_read(32'h0000_0008, 3'b010, 4, rdata_q, resp_q);
        check_data("TC04", rdata_q[0], 32'hAAA0_0002, "WRAP4 beat 0 (addr=0x8)");
        check_data("TC04", rdata_q[1], 32'hAAA0_0003, "WRAP4 beat 1 (addr=0xC)");
        check_data("TC04", rdata_q[2], 32'hAAA0_0000, "WRAP4 beat 2 (addr=0x0, wrap)");
        check_data("TC04", rdata_q[3], 32'hAAA0_0001, "WRAP4 beat 3 (addr=0x4)");
    endtask

    // ---- TC05: INCR4 Burst ----
    task tc05_incr4_burst();
        logic [31:0] rdata_q[$];
        logic [1:0]  resp_q[$];

        $display("=== TC05: INCR4 Burst Read ===");

        // 先写入 4 个字
        ahb_write(32'h0000_0010, 32'hBBB0_0000, 3'b010, 3'b000, resp_q.pop_back());
        ahb_write(32'h0000_0014, 32'hBBB0_0001, 3'b010, 3'b000, resp_q.pop_back());
        ahb_write(32'h0000_0018, 32'hBBB0_0002, 3'b010, 3'b000, resp_q.pop_back());
        ahb_write(32'h0000_001C, 32'hBBB0_0003, 3'b010, 3'b000, resp_q.pop_back());

        // INCR4 读
        ahb_burst_read(32'h0000_0010, 3'b011, 4, rdata_q, resp_q);
        check_data("TC05", rdata_q[0], 32'hBBB0_0000, "INCR4 beat 0");
        check_data("TC05", rdata_q[1], 32'hBBB0_0001, "INCR4 beat 1");
        check_data("TC05", rdata_q[2], 32'hBBB0_0002, "INCR4 beat 2");
        check_data("TC05", rdata_q[3], 32'hBBB0_0003, "INCR4 beat 3");
    endtask

    // ---- TC06: 连续读写（背靠背） ----
    task tc06_back2back();
        logic [31:0] rdata;
        logic [1:0]  resp;

        $display("=== TC06: Back-to-back transfers ===");

        // 连续写 3 个不同地址
        ahb_write(32'h0000_0020, 32'hCCCC_0001, 3'b010, 3'b000, resp);
        ahb_write(32'h0000_0024, 32'hCCCC_0002, 3'b010, 3'b000, resp);
        ahb_write(32'h0000_0028, 32'hCCCC_0003, 3'b010, 3'b000, resp);

        // 连续读验证
        ahb_read(32'h0000_0020, 3'b010, 3'b000, rdata, resp);
        check_data("TC06", rdata, 32'hCCCC_0001, "Back2back read 0x20");
        ahb_read(32'h0000_0024, 3'b010, 3'b000, rdata, resp);
        check_data("TC06", rdata, 32'hCCCC_0002, "Back2back read 0x24");
        ahb_read(32'h0000_0028, 3'b010, 3'b000, rdata, resp);
        check_data("TC06", rdata, 32'hCCCC_0003, "Back2back read 0x28");
    endtask

    // =================================================================================================================
    // 主测试序列
    // =================================================================================================================
    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
        test_id  = 0;

        $display("");
        $display("============================================================");
        $display(" CBB_AHB_SRAMC SVTB Testbench");
        $display("============================================================");
        $display("");

        // 复位
        reset_dut();

        // 运行测试
        tc01_single_rw();
        tc02_addr_error();
        tc03_byte_enable();
        tc04_wrap4_burst();
        tc05_incr4_burst();
        tc06_back2back();

        // 报告
        $display("");
        $display("============================================================");
        $display(" Results: PASS=%0d  FAIL=%0d", pass_cnt, fail_cnt);
        $display("============================================================");
        $display("");

        if (fail_cnt == 0) begin
            $display("[PASS] ALL TEST CASES PASSED");
        end else begin
            $display("[FAIL] %0d TEST CASE(S) FAILED", fail_cnt);
        end

        #100;
        $finish();
    end

endmodule