`timescale 1ns/1ps
module tb_top;
localparam int SRAM_ADDR_WIDTH = 10;
logic HCLK, HRESETn;
initial begin
    HCLK = 1'b0;
    forever #5 HCLK = ~HCLK;
end

AHB_SRAMC_IF vif(
    .HCLK (HCLK),
    .HRESETn (HRESETn)
)

// output declaration of module CBB_AHB_SRAMC
reg [31:0] HRDATA;
wire HREADY_OUT;
reg [1:0] HRESP;
reg [SRAM_ADDR_WIDTH-1:0] SRAM_ADDR;
reg [31:0] SRAM_WDATA;
reg SRAM_WEN;
reg SRAM_CEN;
reg [3:0] SEL;

    CBB_AHB_SRAMC #(
        .BASE_ADDR       (32'h0000_0000),
        .ADDR_MASK       (32'hFFFF_FC00),
        .BYTE_ENABLE     (1),
        .PIPELINE_STAGES (1)
    ) U_DUT (
        .HCLK         (vif.HCLK),
        .HRESETn      (vif.HRESETn),
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
