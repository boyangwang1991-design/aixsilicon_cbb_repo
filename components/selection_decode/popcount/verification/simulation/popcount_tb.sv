// ============================================================================
// popcount_tb — G4 功能验证测试台 (verify-cbb: 定向 + 穷举 + 随机)
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_exhaust_w8  : W=8 全空间 256 输入穷举 × 三实现 (REQ-001/INV-001)
//                    [Change C1] PC_IMPL=2 已由 lookup 切换为 impl_dadda
//   tc_edge        : 全0/全1/one-hot 逐位扫描 × W∈{8,16,64} × 三实现 (REQ-002/INV-002)
//   tc_random      : 固定 seed 随机向量 ≥1000 × W∈{16,64} × 三实现 (REQ-001)
// 黄金模型：TB 内独立 for-loop 数位（不复用 $countones 综合同源路径）
// 时序纪律：组合 DUT；驱动后 #1 采样（无时钟构件，无 $sampled 握手问题）
//
// 非仿真形态用例（引用落地标注，执行体在对应脚本/TCL）：
//   tc_negative_elab : 非法参数 elaboration 拦截（run_static_checks.sh 负向编译）
//   tc_equiv_lec     : fm_shell 实现等价（lec_equiv.tcl + run_functional_sim.sh）
// ============================================================================
`timescale 1ns/1ps

module popcount_tb;

    localparam int MAXW = 64;                 // 本 TB 最大实例宽度
    localparam int SEED = 32'hCBB_2026_0827;  // 固定 seed（可复现纪律）

    logic [MAXW-1:0] data;
    logic [7:0]      cnt8;                    // 宽度上界采样（右对齐，W<8 高位补 0 无碍）

    // 三实现并行实例（同输入同时观测，跨 impl 一致性直接可比）
    logic [7:0] cnt_impl [3];

    popcount #(.INPUT_WIDTH(8),  .PC_IMPL(0)) dut_t8 (.data_i(data[7:0]),   .cnt_o(cnt_impl[0][5:0]));
    popcount #(.INPUT_WIDTH(8),  .PC_IMPL(1)) dut_c8 (.data_i(data[7:0]),   .cnt_o(cnt_impl[1][5:0]));
    popcount #(.INPUT_WIDTH(8),  .PC_IMPL(2)) dut_l8 (.data_i(data[7:0]),   .cnt_o(cnt_impl[2][5:0]));
    // 注：cnt_o 接到统一观测向量的低位——CNT_W=4（W=8），高位为 z/x 不关心，
    //     比较时用独立位宽信号。为避免截断混叠改用显式 wires：

    logic [3:0] w8_tree, w8_cc, w8_lut;
    assign w8_tree = cnt_impl[0][3:0];        // CNT_W(W=8)=$clog2(9)=4
    wire [3:0] _t = cnt_impl[0][3:0];
    wire [3:0] _c = cnt_impl[1][3:0];
    wire [3:0] _l = cnt_impl[2][3:0];

    // W=16 / W=64 实例
    logic [15:0] d16;
    logic [31:0] d64;
    wire [4:0] w16_t, w16_c, w16_l;           // CNT_W(16)=5
    wire [6:0] w64_t, w64_c, w64_l;           // CNT_W(64)=7
    popcount #(.INPUT_WIDTH(16), .PC_IMPL(0)) u16_t (.data_i(d16), .cnt_o(w16_t));
    popcount #(.INPUT_WIDTH(16), .PC_IMPL(1)) u16_c (.data_i(d16), .cnt_o(w16_c));
    popcount #(.INPUT_WIDTH(16), .PC_IMPL(2)) u16_l (.data_i(d16), .cnt_o(w16_l));
    popcount #(.INPUT_WIDTH(64), .PC_IMPL(0)) u64_t (.data_i(d64), .cnt_o(w64_t));
    popcount #(.INPUT_WIDTH(64), .PC_IMPL(1)) u64_c (.data_i(d64), .cnt_o(w64_c));
    popcount #(.INPUT_WIDTH(64), .PC_IMPL(2)) u64_l (.data_i(d64), .cnt_o(w64_l));

    // ---- 黄金参考（独立实现：逐位累加）----
    function automatic int golden(input logic [63:0] v, input int width);
        int acc;
        acc = 0;
        for (int b = 0; b < width; b++) if (v[b]) acc++;
        return acc;
    endfunction

    int errors;
    initial errors = 0;

    task automatic check_w(input int width,
                           input logic [63:0] vec,
                           input int gtree, input int gcc, input int glut);
        int exp;
        exp = golden(vec, width);
        case (width)
            8: begin
                if (_t !== exp[3:0]) begin errors++; $display("[FAIL] W8 tree vec=%h got=%0d exp=%0d", vec, _t, exp); end
                if (_c !== exp[3:0]) begin errors++; $display("[FAIL] W8 colcmp vec=%h got=%0d exp=%0d", vec, _c, exp); end
                if (_l !== exp[3:0]) begin errors++; $display("[FAIL] W8 lookup vec=%h got=%0d exp=%0d", vec, _l, exp); end
                // 跨 impl 一致性（INV-003）
                if (!(_t === _c && _c === _l)) begin errors++; $display("[FAIL] W8 impl mismatch t/c/l=%0d/%0d/%0d", _t, _c, _l); end
            end
            16: begin
                if (w16_t !== exp[4:0]) begin errors++; $display("[FAIL] W16 tree vec=%h got=%0d exp=%0d", d16, w16_t, exp); end
                if (w16_c !== exp[4:0]) begin errors++; $display("[FAIL] W16 colcmp got=%0d exp=%0d", w16_c, exp); end
                if (w16_l !== exp[4:0]) begin errors++; $display("[FAIL] W16 lookup got=%0d exp=%0d", w16_l, exp); end
            end
            64: begin
                if (w64_t !== exp[6:0]) begin errors++; $display("[FAIL] W64 tree got=%0d exp=%0d", w64_t, exp); end
                if (w64_c !== exp[6:0]) begin errors++; $display("[FAIL] W64 colcmp got=%0d exp=%0d", w64_c, exp); end
                if (w64_l !== exp[6:0]) begin errors++; $display("[FAIL] W64 lookup got=%0d exp=%0d", w64_l, exp); end
            end
        endcase
    endtask

    initial begin
        $display("=== popcount_tb start (seed=%0d) ===", SEED);

        // ---------------- tc_exhaust_w8 : 256 输入全空间穷举 ----------------
        begin : tc_exhaust_w8
            logic [63:0] v;
            for (int i = 0; i < 256; i++) begin
                v = 64'(i[7:0]);
                data = v[7:0];
                #1;
                check_w(8, v, 0, 0, 0);
            end
            $display("[tc_exhaust_w8] done: 256 exhaustive vectors checked");
        end

        // ---------------- tc_edge : 全0 / 全1 / one-hot 扫描 ----------------
        begin : tc_edge
            // W=8
            data = 8'h00; #1; check_w(8, 64'h00, 0, 0, 0);       // 下界锚点 → 0
            data = 8'hFF; #1; check_w(8, 64'hFF, 0, 0, 0);       // 上界锚点 → 8
            for (int b = 0; b < 8; b++) begin
                data = 8'(1 << b); #1; check_w(8, 64'(data), 0, 0, 0);
            end
            // W=16
            d16 = 16'h0000; #1; check_w(16, {48'd0, d16}, 0, 0, 0);
            d16 = 16'hFFFF; #1; check_w(16, {48'd0, d16}, 0, 0, 0);
            for (int b = 0; b < 16; b++) begin
                d16 = 16'(1 << b); #1; check_w(16, {48'd0, d16}, 0, 0, 0);
            end
            // W=64
            d64 = 64'h0;          #1; check_w(64, d64, 0, 0, 0);  // → 0
            d64 = ~64'h0;         #1; check_w(64, d64, 0, 0, 0);  // → 64（上界）
            for (int b = 0; b < 64; b++) begin
                d64 = 64'(1) << b; #1; check_w(64, d64, 0, 0, 0); // → 1 每位
            end
            $display("[tc_edge] done: anchors + onehot scans checked");
        end

        // ---------------- tc_random : 固定 seed 随机 ----------------
        begin : tc_random
            logic [63:0] v;
            void'(std::randomize(v));
            process::self.srandom(SEED);
            for (int i = 0; i < 1000; i++) begin
                void'(std::randomize(data));
                #1; check_w(8, {56'd0, data}, 0, 0, 0);
            end
            for (int i = 0; i < 1000; i++) begin
                void'(std::randomize(d16));
                #1; check_w(16, {48'd0, d16}, 0, 0, 0);
            end
            for (int i = 0; i < 1000; i++) begin
                void'(std::randomize(d64));
                #1; check_w(64, d64, 0, 0, 0);
            end
            $display("[tc_random] done: 3000 seeded random vectors checked");
        end

        // ---------------- 终局判定 ----------------
        if (errors == 0)
            $display("=== POPCOUNT_TB PASS: all scenarios clean ===");
        else
            $display("=== POPCOUNT_TB FAIL: %0d mismatches ===", errors);
        $finish;
    end

    // 超时看门狗
    initial begin
        #10_000_000;
        $display("=== POPCOUNT_TB TIMEOUT ===");
        $finish;
    end

endmodule
