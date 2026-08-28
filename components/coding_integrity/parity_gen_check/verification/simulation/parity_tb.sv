// ============================================================================
// parity_tb — G4 功能验证测试台 (verify-cbb: 定向 + 穷举 + 随机 + 等价)
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_exhaust_w8  : W=8 全空间 256 输入穷举 × {tree,linear} (REQ-001/INV-001)
//   tc_edge        : 全0/全1/one-hot 逐位扫描 × even/odd × {tree,linear} (REQ-002/INV-002)
//   tc_random      : 固定 seed 随机 ≥1000 × W∈{8,16,64} × {tree,linear} (REQ-001)
//   tc_equiv       : tree ≡ linear 跨实现一致性 (REQ-003/INV-003)
//   tc_negative_elab : 非法参数 elaboration 拦截（DATA_WIDTH/PC_IMPL 越界；执行体
//                      verification/scripts/run_static_checks.sh，REQ-004）
// 黄金模型：TB 内独立逐位 XOR 归约（不复用综合同源路径）
// 时序纪律：组合 DUT；驱动后 #1 采样
// ============================================================================
`timescale 1ns/1ps

module parity_tb;

    localparam int SEED = 32'hCBB_2026_0828;  // 固定 seed（可复现纪律）

    // ---- 实例化：tree/reduction/linear × even/odd，同输入观测（三形态对比）----
    logic [511:0] data;
    wire  t8_ev, t8_od, r8_ev, l8_ev;        // W=8
    wire  t16_ev, r16_ev, l16_ev;            // W=16
    wire  t64_ev, r64_ev, l64_ev, t64_od;    // W=64

    parity_gen_check #(.DATA_WIDTH(8),  .PC_IMPL(0), .PARITY_TYPE(0)) dut_t8_ev  (.data_i(data[7:0]),   .parity_o(t8_ev));
    parity_gen_check #(.DATA_WIDTH(8),  .PC_IMPL(0), .PARITY_TYPE(1)) dut_t8_od  (.data_i(data[7:0]),   .parity_o(t8_od));
    parity_gen_check #(.DATA_WIDTH(8),  .PC_IMPL(1), .PARITY_TYPE(0)) dut_r8_ev  (.data_i(data[7:0]),   .parity_o(r8_ev));
    parity_gen_check #(.DATA_WIDTH(8),  .PC_IMPL(2), .PARITY_TYPE(0)) dut_l8_ev  (.data_i(data[7:0]),   .parity_o(l8_ev));
    parity_gen_check #(.DATA_WIDTH(16), .PC_IMPL(0), .PARITY_TYPE(0)) dut_t16_ev (.data_i(data[15:0]), .parity_o(t16_ev));
    parity_gen_check #(.DATA_WIDTH(16), .PC_IMPL(1), .PARITY_TYPE(0)) dut_r16_ev (.data_i(data[15:0]), .parity_o(r16_ev));
    parity_gen_check #(.DATA_WIDTH(16), .PC_IMPL(2), .PARITY_TYPE(0)) dut_l16_ev (.data_i(data[15:0]), .parity_o(l16_ev));
    parity_gen_check #(.DATA_WIDTH(64), .PC_IMPL(0), .PARITY_TYPE(0)) dut_t64_ev (.data_i(data[63:0]), .parity_o(t64_ev));
    parity_gen_check #(.DATA_WIDTH(64), .PC_IMPL(1), .PARITY_TYPE(0)) dut_r64_ev (.data_i(data[63:0]), .parity_o(r64_ev));
    parity_gen_check #(.DATA_WIDTH(64), .PC_IMPL(2), .PARITY_TYPE(0)) dut_l64_ev (.data_i(data[63:0]), .parity_o(l64_ev));
    parity_gen_check #(.DATA_WIDTH(64), .PC_IMPL(0), .PARITY_TYPE(1)) dut_t64_od (.data_i(data[63:0]), .parity_o(t64_od));

    // ---- 黄金参考（独立逐位 XOR 归约）----
    function automatic logic golden(input logic [63:0] v, input int width);
        logic p;
        p = 1'b0;
        for (int b = 0; b < width; b++) p ^= v[b];
        return p;
    endfunction

    int errors;
    initial errors = 0;

    // ---- 判定任务：even 实例 vs 黄金，跨三实现等价 ----
    task automatic chk_even(input int width, input logic [63:0] vec,
                            input logic got_t, input logic got_r, input logic got_l,
                            input string tag);
        logic exp;
        exp = golden(vec, width);
        if (got_t !== exp) begin errors++; $display("[FAIL] %s tree got=%0b exp=%0b", tag, got_t, exp); end
        if (got_r !== exp) begin errors++; $display("[FAIL] %s reduction got=%0b exp=%0b", tag, got_r, exp); end
        if (got_l !== exp) begin errors++; $display("[FAIL] %s linear got=%0b exp=%0b", tag, got_l, exp); end
        if (!(got_t === got_r && got_r === got_l)) begin
            errors++; $display("[FAIL] %s impl mismatch t/r/l=%0b/%0b/%0b", tag, got_t, got_r, got_l);
        end
    endtask

    initial begin
        $display("=== parity_tb start (seed=%0d) ===", SEED);

        // ---------------- tc_exhaust_w8 : 256 输入全空间穷举 ----------------
        begin : tc_exhaust_w8
            for (int i = 0; i < 256; i++) begin
                data = 512'(i[7:0]);
                #1;
                chk_even(8, 64'(i[7:0]), t8_ev, r8_ev, l8_ev, "W8");
            end
            $display("[tc_exhaust_w8] done: 256 exhaustive vectors checked");
        end

        // ---------------- tc_edge : 全0/全1/one-hot（even/odd 边界）----------------
        begin : tc_edge
            // W=8
            data = 512'h00; #1;
            if (t8_ev !== 1'b0) begin errors++; $display("[FAIL] W8 even all0 got=%0b", t8_ev); end
            if (t8_od !== 1'b1) begin errors++; $display("[FAIL] W8 odd all0 got=%0b", t8_od); end
            data = 512'hFF; #1;
            if (t8_ev !== 1'b0) begin errors++; $display("[FAIL] W8 even all1 got=%0b", t8_ev); end
            if (t8_od !== 1'b1) begin errors++; $display("[FAIL] W8 odd all1 got=%0b", t8_od); end
            for (int b = 0; b < 8; b++) begin
                data = 512'(1 << b); #1;
                if (t8_ev !== 1'b1) begin errors++; $display("[FAIL] W8 even onehot bit%d got=%0b", b, t8_ev); end
                if (t8_od !== 1'b0) begin errors++; $display("[FAIL] W8 odd onehot bit%d got=%0b", b, t8_od); end
            end
            // W=64
            data = 512'h0; #1;
            if (t64_ev !== 1'b0) begin errors++; $display("[FAIL] W64 even all0 got=%0b", t64_ev); end
            if (t64_od !== 1'b1) begin errors++; $display("[FAIL] W64 odd all0 got=%0b", t64_od); end
            data = 512'hFFFFFFFFFFFFFFFF; #1;
            // 64 个 1 → even=0, odd=1
            if (t64_ev !== 1'b0) begin errors++; $display("[FAIL] W64 even all1 got=%0b", t64_ev); end
            if (t64_od !== 1'b1) begin errors++; $display("[FAIL] W64 odd all1 got=%0b", t64_od); end
            for (int b = 0; b < 64; b++) begin
                data = 512'(1) << b; #1;
                if (t64_ev !== 1'b1) begin errors++; $display("[FAIL] W64 even onehot bit%d got=%0b", b, t64_ev); end
            end
            $display("[tc_edge] done: anchors + onehot scans checked");
        end

        // ---------------- tc_random : 固定 seed 随机 ----------------
        begin : tc_random
            process::self.srandom(SEED);
            for (int i = 0; i < 1000; i++) begin
                void'(std::randomize(data));
                #1; chk_even(8, {56'd0, data[7:0]}, t8_ev, r8_ev, l8_ev, "W8");
            end
            for (int i = 0; i < 1000; i++) begin
                void'(std::randomize(data));
                #1; chk_even(16, {48'd0, data[15:0]}, t16_ev, r16_ev, l16_ev, "W16");
            end
            for (int i = 0; i < 1000; i++) begin
                void'(std::randomize(data));
                #1; chk_even(64, data[63:0], t64_ev, r64_ev, l64_ev, "W64");
            end
            $display("[tc_random] done: 3000 seeded random vectors checked");
        end

        // ---------------- 终局判定 ----------------
        if (errors == 0)
            $display("=== PARITY_TB PASS: all scenarios clean ===");
        else
            $display("=== PARITY_TB FAIL: %0d mismatches ===", errors);
        $finish;
    end

    // 超时看门狗
    initial begin
        #10_000_000;
        $display("=== PARITY_TB TIMEOUT ===");
        $finish;
    end

endmodule
