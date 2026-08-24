class ahb_ref_model;
    // 内部 SRAM 镜像 — 跟 DUT 里的 SRAM 行为一致
    bit [31:0] mem [0:1023];       // 1024 字 × 32-bit

    // 地址译码参数 — 跟 DUT 例化参数一致
    bit [31:0] base_addr;
    bit [31:0] addr_mask;
    int        sram_addr_width;

    function new(bit [31:0] base = 32'h0000_0000,
                 bit [31:0] mask = 32'hFFFF_FC00,
                 int        aw   = 10);
        base_addr       = base;
        addr_mask       = mask;
        sram_addr_width = aw;
        foreach (mem[i]) mem[i] = 32'h0;
    endfunction

    // 处理一笔传输，返回预测结果
    function void predict(
        input  ahb_transaction txn_in,      // Monitor 抓到的请求
        output ahb_transaction txn_out      // 预测 DUT 应该输出什么
    );
        bit        addr_match;
        bit [31:0] word_addr;

        // 1. 地址译码 — 跟 RTL 的 addr_match 逻辑一致
        addr_match = ((txn_in.haddr & ~addr_mask) == (base_addr & ~addr_mask));

        // 2. 计算 SRAM 字地址
        word_addr = txn_in.haddr >> 2;       // 字节地址 → 字地址

        // 3. 拷贝请求信息
        txn_out = txn_in;

        // 4. 地址越界 → ERROR
        if (!addr_match) begin
            txn_out.hresp = 2'b01;           // ERROR
            txn_out.sram_wen = 1'b0;
            return;
        end

        // 5. 地址有效 → OKAY
        txn_out.hresp = 2'b00;               // OKAY

        // 6. 写操作
        if (txn_in.hwrite) begin
            txn_out.sram_wen  = 1'b1;
            txn_out.sram_addr = word_addr[sram_addr_width-1:0];
            txn_out.sram_wdata = txn_in.hwdata;
            txn_out.sel       = gen_sel(txn_in.hsize, txn_in.haddr[1:0]);
            // 更新内部镜像
            mem_write(word_addr, txn_in.hwdata, txn_out.sel);
        end
        // 7. 读操作
        else begin
            txn_out.sram_wen  = 1'b0;
            txn_out.sram_addr = word_addr[sram_addr_width-1:0];
            txn_out.sel       = 4'b0000;
            txn_out.hrdata    = mem[word_addr];  // 从内部镜像读出
        end
    endfunction

    // ---- 字节选通生成 — 跟 RTL 的 SEL_GEN_PROC 一致 ----
    function bit [3:0] gen_sel(bit [2:0] hsize, bit [1:0] addr_low);
        case ({hsize[1:0], addr_low})
            {2'b00, 2'b00}: gen_sel = 4'b0001;
            {2'b00, 2'b01}: gen_sel = 4'b0010;
            {2'b00, 2'b10}: gen_sel = 4'b0100;
            {2'b00, 2'b11}: gen_sel = 4'b1000;
            {2'b01, 2'b00}: gen_sel = 4'b0011;
            {2'b01, 2'b10}: gen_sel = 4'b1100;
            {2'b10, 2'b00}: gen_sel = 4'b1111;
            default:        gen_sel = 4'b0000;
        endcase
    endfunction

    // ---- 按字节选通写入内部 SRAM 镜像 ----
    function void mem_write(bit [31:0] addr, bit [31:0] data, bit [3:0] sel);
        if (sel[0]) mem[addr][7:0]   = data[7:0];
        if (sel[1]) mem[addr][15:8]  = data[15:8];
        if (sel[2]) mem[addr][23:16] = data[23:16];
        if (sel[3]) mem[addr][31:24] = data[31:24];
    endfunction

endclass