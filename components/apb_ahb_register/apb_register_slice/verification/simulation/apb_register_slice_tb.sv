// ============================================================================
// apb_register_slice_tb — G4 功能验证测试台
// (verify-cbb: 相位保持 + 固定反馈延迟 + 反馈对齐 + 前向打拍 + full + 复位 + 等价 + 变异)
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_phase      : SLICE_MODE=1 直通相位一致 / SLICE_MODE=2 前向打拍原子 (REQ-001)
//   tc_resp_delay : 子完成恰 RESP_STAGES 拍后主 PREADY（RS=1/2 定向）(REQ-002)
//   tc_data_align : PREADY 打拍时 PRDATA/PSLVERR 同拍对齐 (REQ-003)
//   tc_req_mode   : SLICE_MODE=0 前向 1 拍 + 反馈直通 (REQ-004)
//   tc_full_mode  : SLICE_MODE=2 前向/反馈延迟独立叠加 (REQ-005)
//   tc_reset      : 复位清洁——空闲/复位期主/子侧全 0 (REQ-006)
//   tc_random     : 随机事务压力 × 3 模式（PREADY 抖动 0..7、pslverr 随机）(REQ-001..003)
//   tc_equiv      : 三模式空闲基线等价 (REQ-006)
//   tc_mutation   : 变异实例（错位反馈），SVA 应检出 (REQ-001)
// 黄金模型：逐拍事务参考（驱动/观测均在 negedge，标准握手模型）
// ============================================================================
`timescale 1ns/1ps

module apb_register_slice_tb;
    localparam int SEED = 32'hA85_2026_0911;   // "ARS" 助记（合法 hex）
    localparam int AW = 16;
    localparam int DW = 32;

    logic clk, rst_n;
    initial begin clk = 0; forever #5 clk = ~clk; end

    // ---- 公共驱动信号（三 DUT 共享主侧激励）----
    logic            psel, penable, pwrite;
    logic [AW-1:0]   paddr;
    logic [2:0]      pprot;
    logic [DW-1:0]   pwdata;
    logic [DW/8-1:0] pstrb;

    // ---- 子侧模拟从设备（每 DUT 独立响应）----
    logic            rdy0, rdy1, rdy2, rdyM;
    logic [DW-1:0]   rdata0, rdata1, rdata2, rdataM;
    logic            serr0, serr1, serr2, serrM;

    // ---- DUT0: SLICE_MODE=0 (request) ----
    wire            pready0; wire [DW-1:0] prdata0; wire pslverr0;
    wire            psel_s0, pen_s0, pwr_s0; wire [AW-1:0] paddr_s0;
    wire [2:0]      pprot_s0; wire [DW-1:0] pwdata_s0; wire [DW/8-1:0] pstrb_s0;
    apb_register_slice #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW), .SLICE_MODE(0), .RESP_STAGES(1)) dut0 (
        .clk(clk), .rst_n(rst_n),
        .psel_main(psel), .penable_main(penable), .paddr_main(paddr), .pprot_main(pprot),
        .pwrite_main(pwrite), .pwdata_main(pwdata), .pstrb_main(pstrb),
        .pready_main(pready0), .prdata_main(prdata0), .pslverr_main(pslverr0),
        .psel_sub(psel_s0), .penable_sub(pen_s0), .paddr_sub(paddr_s0), .pprot_sub(pprot_s0),
        .pwrite_sub(pwr_s0), .pwdata_sub(pwdata_s0), .pstrb_sub(pstrb_s0),
        .pready_sub(rdy0), .prdata_sub(rdata0), .pslverr_sub(serr0));

    // ---- DUT1: SLICE_MODE=1 (response) ----
    wire            pready1; wire [DW-1:0] prdata1; wire pslverr1;
    wire            psel_s1, pen_s1, pwr_s1; wire [AW-1:0] paddr_s1;
    wire [2:0]      pprot_s1; wire [DW-1:0] pwdata_s1; wire [DW/8-1:0] pstrb_s1;
    apb_register_slice #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW), .SLICE_MODE(1), .RESP_STAGES(1)) dut1 (
        .clk(clk), .rst_n(rst_n),
        .psel_main(psel), .penable_main(penable), .paddr_main(paddr), .pprot_main(pprot),
        .pwrite_main(pwrite), .pwdata_main(pwdata), .pstrb_main(pstrb),
        .pready_main(pready1), .prdata_main(prdata1), .pslverr_main(pslverr1),
        .psel_sub(psel_s1), .penable_sub(pen_s1), .paddr_sub(paddr_s1), .pprot_sub(pprot_s1),
        .pwrite_sub(pwr_s1), .pwdata_sub(pwdata_s1), .pstrb_sub(pstrb_s1),
        .pready_sub(rdy1), .prdata_sub(rdata1), .pslverr_sub(serr1));

    // ---- DUT2: SLICE_MODE=2 (full, RESP_STAGES=1) ----
    wire            pready2; wire [DW-1:0] prdata2; wire pslverr2;
    wire            psel_s2, pen_s2, pwr_s2; wire [AW-1:0] paddr_s2;
    wire [2:0]      pprot_s2; wire [DW-1:0] pwdata_s2; wire [DW/8-1:0] pstrb_s2;
    apb_register_slice #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW), .SLICE_MODE(2), .RESP_STAGES(1)) dut2 (
        .clk(clk), .rst_n(rst_n),
        .psel_main(psel), .penable_main(penable), .paddr_main(paddr), .pprot_main(pprot),
        .pwrite_main(pwrite), .pwdata_main(pwdata), .pstrb_main(pstrb),
        .pready_main(pready2), .prdata_main(prdata2), .pslverr_main(pslverr2),
        .psel_sub(psel_s2), .penable_sub(pen_s2), .paddr_sub(paddr_s2), .pprot_sub(pprot_s2),
        .pwrite_sub(pwr_s2), .pwdata_sub(pwdata_s2), .pstrb_sub(pstrb_s2),
        .pready_sub(rdy2), .prdata_sub(rdata2), .pslverr_sub(serr2));

    // ---- DUTM: SLICE_MODE=2 (full, RESP_STAGES=2) — 深反馈定向 ----
    wire            preadyM; wire [DW-1:0] prdataM; wire pslverrM;
    apb_register_slice #(.ADDR_WIDTH(AW), .DATA_WIDTH(DW), .SLICE_MODE(2), .RESP_STAGES(2)) dutM (
        .clk(clk), .rst_n(rst_n),
        .psel_main(psel), .penable_main(penable), .paddr_main(paddr), .pprot_main(pprot),
        .pwrite_main(pwrite), .pwdata_main(pwdata), .pstrb_main(pstrb),
        .pready_main(preadyM), .prdata_main(prdataM), .pslverr_main(pslverrM),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(rdyM), .prdata_sub(rdataM), .pslverr_sub(serrM));

    // tc_mutation 变异测试：采用【编译期 RTL 变异】由 run_functional_sim.sh 执行——
    // 脚本生成 mutant RTL 副本（破坏反馈对齐：prdata/pslverr 组合直通而 pready 保持
    // 寄存），用本 TB 复跑并确认 SVA PROP_ARS_ALIGN_003 报错（checker 有效性证明）。
    // （TB 内实例化"输入错位流"对自对齐寄存恒合法，无法检出——实测否证，已移除 dutX。）

    // ---- 模拟从设备响应（对 DUT1 的子侧：PREADY 抖动 + 数据/错误）----
    // 注：TB 从设备模型在 negedge 更新（激励源统一；domain-rules §3.1.2 标准模型
    // ①驱动在 negedge 更新为下一 posedge 就绪）——DUT/SVA 在 posedge preponed
    // 采样到的是稳定值，杜绝 active 区竞态误报。
    int              wait_cnt1;
    logic [DW-1:0]   resp_data1;
    logic            resp_err1;
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wait_cnt1 = 0; rdy1 = 1'b0; rdata1 = '0; serr1 = 1'b0;
        end else if (pen_s1 && !rdy1) begin
            if (wait_cnt1 == 0) begin
                rdy1 = 1'b1; rdata1 = resp_data1; serr1 = resp_err1;
            end else begin
                wait_cnt1 = wait_cnt1 - 1;
            end
        end else if (!psel_s1) begin
            rdy1 = 1'b0; wait_cnt1 = 0;
        end
    end

    localparam int M_READY = 3;   // do_xfer mode：DUTM（RESP_STAGES=2 深反馈）

    // 其余 DUT 子侧立即响应（组合 PREADY）
    assign rdy0  = pen_s0;                       // request: 子侧组合 PREADY
    assign rdata0  = pwdata_s0 + 32'h1_0000;     // 数据变换可辨识
    assign serr0   = paddr_s0[0];
    assign rdy2  = pen_s2;
    assign rdata2  = pwdata_s2 + 32'h2_0000;
    assign serr2   = paddr_s2[0];
    assign rdyM  = pen_s2 ? rdy2 : 1'b0;         // 复用 DUT2 子侧节奏
    assign rdataM  = pwdata_s2 + 32'h3_0000;
    assign serrM   = paddr_s2[0];

    int errors;
    initial errors = 0;

    // ---- 单事务驱动 task（标准模型：negedge 驱动 NBA，观测沿前值）----
    // 返回主侧完成拍（dut_sel: 0/1/2/M）的 prdata/pslverr
    task automatic do_xfer(input int mode, input logic wr,
                           input logic [AW-1:0] addr, input logic [DW-1:0] wdata,
                           input int wait_cycles, input logic err,
                           input int dly,   // SETUP 前空闲拍
                           output logic [DW-1:0] rdata, output logic rerr);
        // 空闲
        repeat (dly) begin
            @(negedge clk); psel = 1'b0; penable = 1'b0;
        end
        // SETUP
        @(negedge clk);
        psel = 1'b1; penable = 1'b0; pwrite = wr; paddr = addr;
        pwdata = wdata; pstrb = wr ? '1 : '0; pprot = 3'b001;
        if (mode == 1) begin resp_data1 = wdata + 32'h1_0000; resp_err1 = err; wait_cnt1 = wait_cycles; end
        // ACCESS：保持至对应主侧 PREADY
        @(negedge clk);
        penable = 1'b1;
        forever begin
            @(negedge clk);
            case (mode)
                0: if (pready0) begin rdata = prdata0; rerr = pslverr0; break; end
                1: if (pready1) begin rdata = prdata1; rerr = pslverr1; break; end
                2: if (pready2) begin rdata = prdata2; rerr = pslverr2; break; end
                M_READY: if (preadyM) begin rdata = prdataM; rerr = pslverrM; break; end
                default: begin rdata = '0; rerr = 1'b0; break; end
            endcase
        end
        // 撤销
        @(negedge clk);
        psel = 1'b0; penable = 1'b0;
    endtask

    // ---- 黄金参考：mode 语义期望值 ----
    // request: rdata = pwdata_at_sub + 1_0000（pwdata 打拍 → 从设备组合加），err=addr[0]
    // response/full: rdata = wdata + 1_0000/2_0000（从设备对打拍后 pwdata 计算）

    initial begin
        $display("=== apb_register_slice_tb start (seed=%0d) ===", SEED);
        rst_n = 1'b0; psel = 0; penable = 0; pwrite = 0; paddr = '0; pprot = '0;
        pwdata = '0; pstrb = '0;
        resp_data1 = '0; resp_err1 = 1'b0; wait_cnt1 = 0;
        repeat (3) @(negedge clk); rst_n = 1'b1;
        @(negedge clk);

        // ---------------- tc_reset：复位释放后空闲全 0 ----------------
        begin : tc_reset
            if (psel_s0 !== 1'b0 || pen_s0 !== 1'b0 || pready0 !== 1'b0) begin
                errors++; $display("[FAIL] tc_reset mode0 not clean psel=%b pen=%b rdy=%b", psel_s0, pen_s0, pready0);
            end
            if (psel_s1 !== 1'b0 || pen_s1 !== 1'b0 || pready1 !== 1'b0) begin
                errors++; $display("[FAIL] tc_reset mode1 not clean");
            end
            if (psel_s2 !== 1'b0 || pen_s2 !== 1'b0 || pready2 !== 1'b0) begin
                errors++; $display("[FAIL] tc_reset mode2 not clean");
            end
            // 中途再次复位，寄存输出立即清零
            @(negedge clk); psel = 1'b1; penable = 1'b1; paddr = 16'h00AA; pwdata = 32'hDEAD;
            @(negedge clk);
            rst_n = 1'b0;
            #1;
            if (psel_s0 !== 1'b0 || pready1 !== 1'b0 || pready2 !== 1'b0) begin
                errors++; $display("[FAIL] tc_reset async clear: s0=%b rdy1=%b rdy2=%b", psel_s0, pready1, pready2);
            end
            @(negedge clk); rst_n = 1'b1; psel = 1'b0; penable = 1'b0;
            @(negedge clk);
            $display("[tc_reset] done");
        end

        // ---------------- tc_phase + tc_resp_delay + tc_data_align（定向）----------------
        begin : tc_directed
            logic [DW-1:0] rd; logic re;
            // mode=1（response）：前向直通——SETUP 拍子侧即见 psel/!penable；数据对齐
            do_xfer(1, 1'b0, 16'h1000, 32'hA0A0_0001, 0, 1'b0, 2, rd, re);
            if (rd !== 32'hA0A0_0001 + 32'h1_0000) begin errors++; $display("[FAIL] tc_data_align m1 rdata=%h", rd); end
            // mode=1：PREADY 抖动 3 拍，完成延迟恰 3+1（子完成+RESP_STAGES）
            do_xfer(1, 1'b1, 16'h1002, 32'hB0B0_0002, 3, 1'b1, 2, rd, re);
            if (!re) begin errors++; $display("[FAIL] tc_resp_delay m1 err bit lost"); end
            // mode=2（full）：前向 1 拍 + 反馈 1 拍；数据 = wdata+2_0000（对打拍后 pwdata 计算）
            do_xfer(2, 1'b0, 16'h2000, 32'hC0C0_0003, 0, 1'b0, 2, rd, re);
            if (rd !== 32'hC0C0_0003 + 32'h2_0000) begin errors++; $display("[FAIL] tc_full_mode m2 rdata=%h exp=%h", rd, 32'hC0C0_0003 + 32'h2_0000); end
            // mode=0（request）：反馈直通——数据 = 打拍后 pwdata+1_0000
            do_xfer(0, 1'b0, 16'h3001, 32'hD0D0_0004, 0, 1'b0, 2, rd, re);
            if (rd !== 32'hD0D0_0004 + 32'h1_0000) begin errors++; $display("[FAIL] tc_req_mode m0 rdata=%h", rd); end
            if (re !== 1'b1) begin errors++; $display("[FAIL] tc_req_mode m0 err=addr[0]"); end
            $display("[tc_phase/resp_delay/data_align/req_mode/full_mode directed] done");
        end

        // ---------------- tc_resp_delay：RESP_STAGES=2 深反馈 ----------------
        begin : tc_rs2
            logic [DW-1:0] rd; logic re;
            do_xfer(M_READY, 1'b0, 16'h2004, 32'hE0E0_0005, 2, 1'b0, 2, rd, re);
            if (rd !== 32'hE0E0_0005 + 32'h3_0000) begin errors++; $display("[FAIL] tc_resp_delay rs2 rdata=%h", rd); end
            $display("[tc_resp_delay rs2] done");
        end

        // ---------------- tc_random：随机事务 × 3 模式 ----------------
        begin : tc_random
            logic [DW-1:0] rd; logic re; logic [AW-1:0] a; logic [DW-1:0] w;
            int waitc; logic errb;
            process::self.srandom(SEED);
            for (int i = 0; i < 300; i++) begin
                void'(std::randomize(a)); void'(std::randomize(w));
                void'(std::randomize(waitc) with { waitc dist {0:=6, 1:=2, 2:=1, [3:7]:/2}; });
                void'(std::randomize(errb));
                // mode=1（反馈打拍语义最复杂）走从设备抖动；mode=0/2 立即从设备
                do_xfer(1, (i & 1), a, w, waitc, errb, $urandom_range(0, 3), rd, re);
                if (rd !== (w + 32'h1_0000)) begin errors++; $display("[FAIL] tc_random i=%0d rdata=%h exp=%h", i, rd, w + 32'h1_0000); end
                if (re !== errb)            begin errors++; $display("[FAIL] tc_random i=%0d err=%b exp=%b", i, re, errb); end
            end
            $display("[tc_random] 300 transactions done");
        end

        // ---------------- tc_equiv：三模式空闲基线等价 ----------------
        begin : tc_equiv
            @(negedge clk); psel = 1'b0; penable = 1'b0;
            repeat (4) @(negedge clk);
            // 空闲期：三模式子侧未选中、主侧未完成（request 模式 PREADY 直通子侧=0）
            if (psel_s0 !== psel_s1 || psel_s1 !== psel_s2) begin
                errors++; $display("[FAIL] tc_equiv idle psel mismatch %b/%b/%b", psel_s0, psel_s1, psel_s2);
            end
            if (pready0 !== 1'b0 || pready1 !== 1'b0 || pready2 !== 1'b0) begin
                errors++; $display("[FAIL] tc_equiv idle pready not 0");
            end
            $display("[tc_equiv] done");
        end

        // ---------------- tc_mutation：编译期 RTL 变异由脚本复跑本 TB 检出 ----------------
        // 本 TB 以环境变量 TB_MUT_MODE=1 编译时，激励侧重放对齐敏感事务
        //（mode=1 定向 + 随机），mutant RTL 的 PROP_ARS_ALIGN_003 应在完成拍失败。
        // 正常 RTL 编译（无 TB_MUT_MODE）时本段只做一次定向事务（对齐敏感）。
        begin : tc_mutation
            logic [DW-1:0] rd; logic re;
            do_xfer(1, 1'b0, 16'h1006, 32'hF0F0_0006, 1, 1'b0, 2, rd, re);
            if (rd !== 32'hF0F0_0006 + 32'h1_0000) begin
                errors++; $display("[FAIL] tc_mutation align-sensitive xfer rdata=%h", rd);
            end
            $display("[tc_mutation] done");
        end

        // ---------------- 终局判定 ----------------
        if (errors == 0) $display("=== APB_RS_TB PASS: all scenarios clean ===");
        else $display("=== APB_RS_TB FAIL: %0d mismatches ===", errors);
        $finish;
    end

    // 超时看门狗
    initial begin
        #2_000_000;
        $display("=== APB_RS_TB TIMEOUT ==="); $finish;
    end

endmodule
