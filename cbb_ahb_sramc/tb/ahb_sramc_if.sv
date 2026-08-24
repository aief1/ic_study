// ====================================================================================================================
// (c) Copyright 2026 CBB Team. All rights reserved.
// Designer     : Leo
// Project      : CBB
// Create Date  : 2026-08-14
// Description  : ahb_sramc_if — AHB-Lite + SRAM 接口封装
//                提供 driver/monitor 用的 modport 和时钟块
// ====================================================================================================================

interface ahb_sramc_if #(
    parameter int SRAM_ADDR_WIDTH = 10,
    parameter int DATA_WIDTH      = 32,
    parameter int ADDR_WIDTH      = 32
) (
    input logic HCLK,
    input logic HRESETn
);

    // ---- AHB-Lite 从设备信号 ----
    logic                        HSEL;
    logic [ADDR_WIDTH-1:0]       HADDR;
    logic                        HWRITE;
    logic [1:0]                  HTRANS;
    logic [2:0]                  HSIZE;
    logic [2:0]                  HBURST;
    logic [3:0]                  HPROT;
    logic [DATA_WIDTH-1:0]       HWDATA;
    logic [DATA_WIDTH-1:0]       HRDATA;
    logic                        HREADY_OUT;
    logic [1:0]                  HRESP;

    // ---- SRAM 信号 ----
    logic [SRAM_ADDR_WIDTH-1:0]  SRAM_ADDR;
    logic [DATA_WIDTH-1:0]       SRAM_WDATA;
    logic [DATA_WIDTH-1:0]       SRAM_RDATA;
    logic                        SRAM_WEN;
    logic                        SRAM_CEN;
    logic [3:0]                  SEL;

    // ---- 时钟块：driver 用（同步驱动）----
    clocking drv_cb @(posedge HCLK);
        default input #1 output #1;
        output HSEL, HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT, HWDATA;
        input  HRDATA, HREADY_OUT, HRESP;
    endclocking

    // ---- 时钟块：monitor 用（同步采样）----
    clocking mon_cb @(posedge HCLK);
        default input #1;
        input HSEL, HADDR, HWRITE, HTRANS, HSIZE, HBURST, HWDATA;
        input HRDATA, HREADY_OUT, HRESP;
        input SRAM_ADDR, SRAM_WDATA, SRAM_WEN, SRAM_CEN, SEL;
    endclocking

    // ---- modport：driver 视角 ----
    modport driver(
        clocking drv_cb,
        input HCLK, HRESETn
    );

    // ---- modport：monitor 视角 ----
    modport monitor(
        clocking mon_cb,
        input HCLK, HRESETn
    );

    // ---- modport：DUT 连线用（无时钟块）----
    modport dut(
        input  HCLK, HRESETn,
        input  HSEL, HADDR, HWRITE, HTRANS, HSIZE, HBURST, HPROT, HWDATA,
        output HRDATA, HREADY_OUT, HRESP,
        output SRAM_ADDR, SRAM_WDATA, SRAM_WEN, SRAM_CEN, SEL,
        input  SRAM_RDATA
    );

    // ---- modport：SRAM 模型连线用 ----
    modport sram(
        input  SRAM_ADDR, SRAM_WDATA, SRAM_WEN, SRAM_CEN, SEL,
        output SRAM_RDATA
    );

    // ---- 断言：检查 HRESP 编码合法 ----
    property resp_legal;
        @(posedge HCLK) disable iff (!HRESETn)
        (HRESP inside {2'b00, 2'b01});
    endproperty
    A_RESP_LEGAL: assert property (resp_legal)
        else $error("[AHB_SRAMC_IF] HRESP illegal value: %b", HRESP);

endinterface