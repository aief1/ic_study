interface AHB_SRAMC_IF #(
    localparam                            SRAM_ADDR_WIDTH       = 10
    )
    (
    input logic                                HCLK,                              // AHB clock
    input logic                                HRESETn
    );
    // AHB-Lite Slave Interface
    logic                                HSEL;                                // Slave select
    logic              [31:0]            HADDR;                               // Address (byte addr)
    logic                                HWRITE;                              // Write enable
    logic              [1:0]             HTRANS;                             // Transfer type
    logic              [2:0]             HSIZE;                               // Transfer size
    logic              [2:0]             HBURST;                              // Burst type
    logic              [3:0]             HPROT;                            // Protection (unused)
    logic              [31:0]            HWDATA;                              // Write data
    logic             [31:0]            HRDATA;                              // Read data
    logic                               HREADY_OUT;                          // Slave ready (0 wait states)
    logic             [1:0]             HRESP;                               // Response: 00=OKAY, 01=ERROR
    // SRAM Interface
    logic             [SRAM_ADDR_WIDTH-1:0]  SRAM_ADDR;                     // SRAM word address
    logic             [31:0]            SRAM_WDATA;                          // SRAM write data
    logic              [31:0]           SRAM_RDATA;                          // SRAM read data
    logic                               SRAM_WEN;                            // SRAM write enable (1=write)
    logic                               SRAM_CEN;                            // SRAM chip enable (0=enabled)
    logic             [3:0]             SEL;
    //driver的clocking
    clocking drv_cb @(posedge HCLK);
    default input #1 output #1;
    input   HRDATA, HREADY_OUT, HRESP;
    output  HSEL,HADDR,HWRITE,HTRANS,HSIZE,HBURST,HPROT,HWDATA;
    endclocking
    //moniter的clocking
    clocking mon_cb @(posedge HCLK);
    default input #1;
    input HSEL,HADDR,HWRITE,HTRANS,HSIZE,HBURST,HPROT,HWDATA,HRDATA,HREADY_OUT,HRESP;
    input SRAM_ADDR,SRAM_WDATA,SRAM_WEN,SRAM_CEN,SEL;
    endclocking

    modport drv (clocking drv_cb, input HCLK,HRESETn);
    modport mon (clocking mon_cb, input HCLK, HRESETn);
    //dut的信号
    modport dut (input HSEL,HADDR,HWRITE,HTRANS,HSIZE,HBURST,HPROT,HWDATA,
    input HCLK, HRESETn,
    input SRAM_RDATA,
    output SRAM_ADDR,SRAM_WDATA,SRAM_WEN,SRAM_CEN,SEL,
    output HRDATA, HREADY_OUT, HRESP);
    //sram的信号
    modport sram (input SRAM_ADDR,SRAM_WDATA,SRAM_WEN,SRAM_CEN,SEL,
    output SRAM_RDATA);


endinterface