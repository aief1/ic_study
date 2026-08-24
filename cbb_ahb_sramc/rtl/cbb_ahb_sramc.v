// =====================================================================================================================
// (c) Copyright 2026 CBB Team. All rights reserved.
// Designer     : Leo
// Project      : CBB
// Create Date  : 2026-08-14
// Description  : CBB_AHB_SRAMC — AHB-Lite to SRAM Controller
//                Bridges AHB-Lite bus protocol to synchronous single-port SRAM.
//                Supports SINGLE, INCR, WRAP4/8/16, INCR4/8/16 burst types.
//                0 wait-state, 1-stage pipeline, byte write enable with SEL.
// =====================================================================================================================

module CBB_AHB_SRAMC
   #(
    parameter                            SRAM_ADDR_WIDTH       = 10,          // SRAM word addr width (depth=2^W)
    parameter         [31:0]             BASE_ADDR             = 32'h0000_0000,// Base address
    parameter         [31:0]             ADDR_MASK             = 32'hFFFF_FC00,// Address mask
    parameter                            BYTE_ENABLE           = 1,           // Byte write enable
    parameter                            PIPELINE_STAGES       = 1            // Pipeline stages (fixed=1)
    )
    (
    // AHB-Lite Slave Interface
    input                                HCLK,                                // AHB clock
    input                                HRESETn,                             // Async reset, active low
    input                                HSEL,                                // Slave select
    input              [31:0]            HADDR,                               // Address (byte addr)
    input                                HWRITE,                              // Write enable
    input              [1:0]             HTRANS,                              // Transfer type
    input              [2:0]             HSIZE,                               // Transfer size
    input              [2:0]             HBURST,                              // Burst type
    input              [3:0]             HPROT,                               // Protection (unused)
    input              [31:0]            HWDATA,                              // Write data
    output reg         [31:0]            HRDATA,                              // Read data
    output                               HREADY_OUT,                          // Slave ready (0 wait states)
    output reg         [1:0]             HRESP,                               // Response: 00=OKAY, 01=ERROR
    // SRAM Interface
    output reg         [SRAM_ADDR_WIDTH-1:0]  SRAM_ADDR,                      // SRAM word address
    output reg         [31:0]            SRAM_WDATA,                          // SRAM write data
    input              [31:0]            SRAM_RDATA,                          // SRAM read data
    output reg                           SRAM_WEN,                            // SRAM write enable (1=write)
    output reg                           SRAM_CEN,                            // SRAM chip enable (0=enabled)
    output reg         [3:0]             SEL                                  // Byte write select
    );

// ---------------------------------------------------------------------------------------------------------------------
// Localparam
// ---------------------------------------------------------------------------------------------------------------------
// AHB transfer type constants
localparam HTRANS_IDLE                   = 2'b00;                             // IDLE transfer type
localparam HTRANS_BUSY                   = 2'b01;                             // BUSY transfer type
localparam HTRANS_NONSEQ                 = 2'b10;                             // NONSEQ transfer type
localparam HTRANS_SEQ                    = 2'b11;                             // SEQ transfer type

// AHB response constants
localparam HRESP_OKAY                    = 2'b00;                             // OKAY response
localparam HRESP_ERROR                   = 2'b01;                             // ERROR response

// FSM state encoding
localparam ST_IDLE                       = 1'b0;                              // Idle state
localparam ST_ACCESS                     = 1'b1;                              // Access state

// ---------------------------------------------------------------------------------------------------------------------
// Internal Signals
// ---------------------------------------------------------------------------------------------------------------------
// Pipeline registers
reg                [SRAM_ADDR_WIDTH+1:0] haddr_d1;                            // HADDR registered (word-aligned bits)
reg                                       hwrite_d1;                           // HWRITE registered
reg                [1:0]                 htrans_d1;                            // HTRANS registered
reg                [2:0]                 hsize_d1;                             // HSIZE registered
reg                [2:0]                 hburst_d1;                            // HBURST registered
reg                [31:0]                hwdata_d1;                            // HWDATA registered
reg                                       valid_d1;                            // Valid transaction registered

// Address decode
wire                                      addr_match;                          // Address within range
wire                                      addr_error;                          // Address out of range
wire                                      xfer_valid;                          // Current transfer is valid

// FSM
reg                                       curr_st;                             // Current state
reg                                       next_st;                             // Next state

// Byte select
reg                [3:0]                 sel_comb;                             // Byte select (combinational)

// ---------------------------------------------------------------------------------------------------------------------
// FSM: Next State (Combinational)
// ---------------------------------------------------------------------------------------------------------------------
always @(*) begin : FSM_NEXT_PROC
    next_st = curr_st;
    case (curr_st)
        ST_IDLE : begin
            if (xfer_valid == 1'b1) begin
                next_st = ST_ACCESS;
            end
        end
        ST_ACCESS : begin
            if (xfer_valid == 1'b1) begin
                next_st = ST_ACCESS;
            end else begin
                next_st = ST_IDLE;
            end
        end
        default : begin
            next_st = ST_IDLE;
        end
    endcase
end

// ---------------------------------------------------------------------------------------------------------------------
// FSM: State Register (Sequential)
// ---------------------------------------------------------------------------------------------------------------------
always @(posedge HCLK or negedge HRESETn) begin : FSM_STATE_PROC
    if (HRESETn == 1'b0) begin
        curr_st <= ST_IDLE;
    end else begin
        curr_st <= next_st;
    end
end

// ---------------------------------------------------------------------------------------------------------------------
// Address Decode (Combinational)
// ---------------------------------------------------------------------------------------------------------------------
assign xfer_valid = (HSEL == 1'b1) && ((HTRANS == HTRANS_NONSEQ) || (HTRANS == HTRANS_SEQ));
assign addr_match = ((HADDR & ~ADDR_MASK) == (BASE_ADDR & ~ADDR_MASK));
assign addr_error = (xfer_valid == 1'b1) && (addr_match == 1'b0);

// ---------------------------------------------------------------------------------------------------------------------
// Pipeline Register (Sequential)
// ---------------------------------------------------------------------------------------------------------------------
always @(posedge HCLK or negedge HRESETn) begin : PIPE_PROC
    if (HRESETn == 1'b0) begin
        haddr_d1  <= {SRAM_ADDR_WIDTH+2{1'b0}};
        hwrite_d1 <= 1'b0;
        htrans_d1 <= HTRANS_IDLE;
        hsize_d1  <= 3'b000;
        hburst_d1 <= 3'b000;
        hwdata_d1 <= {32{1'b0}};
        valid_d1  <= 1'b0;
    end else begin
        haddr_d1  <= HADDR[SRAM_ADDR_WIDTH+1:0];
        hwrite_d1 <= HWRITE;
        htrans_d1 <= HTRANS;
        hsize_d1  <= HSIZE;
        hburst_d1 <= HBURST;
        hwdata_d1 <= HWDATA;
        valid_d1  <= xfer_valid;
    end
end

// ---------------------------------------------------------------------------------------------------------------------
// Byte Select Generation (Combinational)
// ---------------------------------------------------------------------------------------------------------------------
always @(*) begin : SEL_GEN_PROC
    if (BYTE_ENABLE == 1'b0) begin
        sel_comb = 4'b1111;
    end else begin
        case ({hsize_d1[1:0], haddr_d1[1:0]})
            {2'b00, 2'b00} : sel_comb = 4'b0001;                              // BYTE, offset 0
            {2'b00, 2'b01} : sel_comb = 4'b0010;                              // BYTE, offset 1
            {2'b00, 2'b10} : sel_comb = 4'b0100;                              // BYTE, offset 2
            {2'b00, 2'b11} : sel_comb = 4'b1000;                              // BYTE, offset 3
            {2'b01, 2'b00} : sel_comb = 4'b0011;                              // HALFWORD, offset 0
            {2'b01, 2'b10} : sel_comb = 4'b1100;                              // HALFWORD, offset 2
            {2'b10, 2'b00} : sel_comb = 4'b1111;                              // WORD, offset 0
            default        : sel_comb = 4'b0000;
        endcase
    end
end

// ---------------------------------------------------------------------------------------------------------------------
// SRAM Control Outputs (Combinational)
// ---------------------------------------------------------------------------------------------------------------------
always @(*) begin : SRAM_CTRL_PROC
    SRAM_ADDR  = haddr_d1[SRAM_ADDR_WIDTH+1:2];
    SRAM_WDATA = hwdata_d1;
    SRAM_WEN   = (hwrite_d1 == 1'b1) && (valid_d1 == 1'b1) && (addr_error == 1'b0);
    SRAM_CEN   = ~((valid_d1 == 1'b1) && (addr_error == 1'b0));
    SEL        = sel_comb;
end

// ---------------------------------------------------------------------------------------------------------------------
// AHB Response Outputs
// ---------------------------------------------------------------------------------------------------------------------
// HREADY_OUT: always ready (0 wait states)
assign HREADY_OUT = 1'b1;

// HRESP: OKAY or ERROR
always @(*) begin : RESP_PROC
    if (addr_error == 1'b1) begin
        HRESP = HRESP_ERROR;
    end else begin
        HRESP = HRESP_OKAY;
    end
end

// HRDATA: registered from SRAM read data
always @(posedge HCLK or negedge HRESETn) begin : RDATA_PROC
    if (HRESETn == 1'b0) begin
        HRDATA <= {32{1'b0}};
    end else begin
        HRDATA <= SRAM_RDATA;
    end
end

// ---------------------------------------------------------------------------------------------------------------------
// Parameter Validation (Simulation Only)
// ---------------------------------------------------------------------------------------------------------------------
initial begin : PARAM_CHECK_PROC
    if (SRAM_ADDR_WIDTH < 1) begin
        $fatal(1, "[CBB_AHB_SRAMC] SRAM_ADDR_WIDTH must be >= 1 (got %0d)", SRAM_ADDR_WIDTH);
    end
    if (PIPELINE_STAGES != 1) begin
        $fatal(1, "[CBB_AHB_SRAMC] PIPELINE_STAGES must be 1 (got %0d)", PIPELINE_STAGES);
    end
end

endmodule