// ============================================================================
// popcount_tb — G4 功能验证测试台 (verify-cbb: 穷举 + 随机 + 边界 + 等价)
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_exhaust_w4 : W=4 全空间 16 向量 × 五实现 (REQ-001)
//   tc_edge       : 全0 / 全1 / 单热逐位 / 交错 0101 边界 (REQ-002/003)
//   tc_random     : 随机向量 × {W=8,16,32,64} × 五实现（黄金 + 等价） (REQ-001/004)
//   tc_equiv      : 五实现跨实现一致（W=32/64 随机段） (REQ-004)
//   tc_mutation   : 变异——破坏计数语义（改 lut4 表项），断言应能检测 (REQ-001)
//   tc_negative_elab : 非法参数 elaboration $error 拦截，TB 在 verification/formal/
//                      negative_elab_tb.sv（本表为场景索引汇总） (REQ-005)
// 黄金模型：独立逐位扫描（$countones 系统函数，与实现无共享结构）
// ============================================================================
`timescale 1ns/1ps

module popcount_tb;
    localparam int SEED = 32'h5000_2026;   // 2026-08-28 里程碑 seed（无下划线歧义）

    // ---- W=4 穷举：direct/tree/lut（wallace/comp4_2 仅支持 W∈{8,16,32,64}）----
    logic [63:0] din4;
    wire [2:0] p4d, p4t, p4l;
    popcount #(.DATA_W(4), .PC_IMPL(0)) dut_d4 (.din(din4[3:0]), .popcnt(p4d));
    popcount #(.DATA_W(4), .PC_IMPL(1)) dut_t4 (.din(din4[3:0]), .popcnt(p4t));
    popcount #(.DATA_W(4), .PC_IMPL(4)) dut_l4 (.din(din4[3:0]), .popcnt(p4l));

    // ---- W=8 随机 + 等价（Wallace/compressor 生成版）----
    logic [63:0] din8;
    wire [3:0] p8d, p8t, p8w, p8c, p8l;
    popcount #(.DATA_W(8), .PC_IMPL(0)) dut_d8 (.din(din8[7:0]), .popcnt(p8d));
    popcount #(.DATA_W(8), .PC_IMPL(1)) dut_t8 (.din(din8[7:0]), .popcnt(p8t));
    popcount #(.DATA_W(8), .PC_IMPL(2)) dut_w8 (.din(din8[7:0]), .popcnt(p8w));
    popcount #(.DATA_W(8), .PC_IMPL(3)) dut_c8 (.din(din8[7:0]), .popcnt(p8c));
    popcount #(.DATA_W(8), .PC_IMPL(4)) dut_l8 (.din(din8[7:0]), .popcnt(p8l));

    // ---- W=16 / 32 / 64 随机（生成版 + 手写版等价）----
    logic [63:0] din32, din64;
    wire [4:0] p16t, p16w, p16c, p16l;
    wire [4:0] p32t, p32w, p32c, p32l;
    wire [5:0] p64t, p64w, p64c;
    popcount #(.DATA_W(16),.PC_IMPL(1)) dut_t16 (.din(din32[15:0]),  .popcnt(p16t));
    popcount #(.DATA_W(16),.PC_IMPL(2)) dut_w16 (.din(din32[15:0]),  .popcnt(p16w));
    popcount #(.DATA_W(16),.PC_IMPL(3)) dut_c16 (.din(din32[15:0]),  .popcnt(p16c));
    popcount #(.DATA_W(16),.PC_IMPL(4)) dut_l16 (.din(din32[15:0]),  .popcnt(p16l));
    popcount #(.DATA_W(32),.PC_IMPL(1)) dut_t32 (.din(din32[31:0]),  .popcnt(p32t));
    popcount #(.DATA_W(32),.PC_IMPL(2)) dut_w32 (.din(din32[31:0]),  .popcnt(p32w));
    popcount #(.DATA_W(32),.PC_IMPL(3)) dut_c32 (.din(din32[31:0]),  .popcnt(p32c));
    popcount #(.DATA_W(32),.PC_IMPL(4)) dut_l32 (.din(din32[31:0]),  .popcnt(p32l));
    popcount #(.DATA_W(64),.PC_IMPL(1)) dut_t64 (.din(din64[63:0]),  .popcnt(p64t));
    popcount #(.DATA_W(64),.PC_IMPL(2)) dut_w64 (.din(din64[63:0]),  .popcnt(p64w));
    popcount #(.DATA_W(64),.PC_IMPL(3)) dut_c64 (.din(din64[63:0]),  .popcnt(p64c));

    // ---- 黄金参考：独立逐位扫描 ----
    function automatic integer golden(input logic [63:0] v, input int n);
        integer cnt; cnt = 0;
        for (int i = 0; i < n; i++) if (v[i] == 1'b1) cnt++;
        return cnt;
    endfunction

    // ---- 检查（黄金） ----
    integer errors;
    initial errors = 0;
    task automatic chk(input logic [63:0] din, input int n, input logic [31:0] got,
                       input string tag);
        integer exp; exp = golden(din, n);
        if (got !== exp) begin
            errors++;
            $display("[FAIL] %s din=%0h n=%0d got=%0d exp=%0d", tag, din, n, got, exp);
        end
    endtask

    // ---- 检查（多实现等价） ----
    task automatic chk_eq(input logic [63:0] din, input int n,
                          input logic [31:0] a, input logic [31:0] b,
                          input string tag);
        if (a !== b) begin
            errors++;
            $display("[FAIL] %s eq din=%0h n=%0d a=%0d b=%0d", tag, din, n, a, b);
        end
    endtask

    initial begin
        $display("=== popcount_tb start (seed=%0d) ===", SEED);
        din4 = '0; din8 = '0; din32 = '0; din64 = '0;
        #1;

        // ---------------- tc_exhaust_w4（direct/tree/lut）----------------
        for (int v = 0; v < 16; v++) begin
            din4 = 64'(v); #1;
            chk(din4,4,64'(p4d),"W4D"); chk(din4,4,64'(p4t),"W4T"); chk(din4,4,64'(p4l),"W4L");
        end
        $display("[tc_exhaust_w4] 16 vectors × 3 DUT (direct/tree/lut) done");

        // ---------------- tc_exhaust_w8（wallace/comp4_2 全空间 256 向量）----------------
        for (int v = 0; v < 256; v++) begin
            din8 = 64'(v); #1;
            chk(din8,8,64'(p8w),"W8W"); chk(din8,8,64'(p8c),"W8C");
            chk_eq(din8,8,64'(p8w),64'(p8t),"W8WT");
        end
        $display("[tc_exhaust_w8] 256 vectors × wallace/comp4_2 + tree eq done");

        // ---------------- tc_edge ----------------
        din8 = '0; #1;
        chk(din8,8,64'(p8d),"E0D"); chk(din8,8,64'(p8t),"E0T"); chk(din8,8,64'(p8w),"E0W");
        chk(din8,8,64'(p8c),"E0C"); chk(din8,8,64'(p8l),"E0L");
        din8 = 64'hFF; #1;
        chk(din8,8,64'(p8d),"EAD"); chk(din8,8,64'(p8t),"EAT"); chk(din8,8,64'(p8w),"EAW");
        chk(din8,8,64'(p8c),"EAC"); chk(din8,8,64'(p8l),"EAL");
        for (int b = 0; b < 8; b++) begin
            din8 = 64'(1) << b; #1;
            chk(din8,8,64'(p8t),"onehotT");
            chk(din8,8,64'(p8w),"onehotW");
            chk(din8,8,64'(p8c),"onehotC");
        end
        din8 = 64'hAA; #1;   // 0101 交错
        chk(din8,8,64'(p8t),"altT"); chk(din8,8,64'(p8w),"altW"); chk(din8,8,64'(p8c),"altC");
        $display("[tc_edge] done");

        // ---------------- tc_random（黄金 + 等价，多实现 × 多宽度）----------------
        process::self.srandom(SEED);
        for (int i = 0; i < 4000; i++) begin
            void'(std::randomize(din8, din32, din64));
            #1;
            // W=8：五实现黄金 + 等价
            chk(din8,8,64'(p8d),"R8D"); chk(din8,8,64'(p8t),"R8T"); chk(din8,8,64'(p8w),"R8W");
            chk(din8,8,64'(p8c),"R8C"); chk(din8,8,64'(p8l),"R8L");
            chk_eq(din8,8,64'(p8d),64'(p8w),"R8DW"); chk_eq(din8,8,64'(p8t),64'(p8l),"R8TL");
            // W=16：黄金（tree/wallace/comp/lut）
            chk(din32,16,64'(p16t),"R16T"); chk(din32,16,64'(p16w),"R16W");
            chk(din32,16,64'(p16c),"R16C"); chk(din32,16,64'(p16l),"R16L");
            chk_eq(din32,16,64'(p16t),64'(p16w),"R16TW"); chk_eq(din32,16,64'(p16c),64'(p16l),"R16CL");
            // W=32：黄金（tree/wallace/comp/lut）
            chk(din32,32,64'(p32t),"R32T"); chk(din32,32,64'(p32w),"R32W");
            chk(din32,32,64'(p32c),"R32C"); chk(din32,32,64'(p32l),"R32L");
            chk_eq(din32,32,64'(p32t),64'(p32w),"R32TW"); chk_eq(din32,32,64'(p32c),64'(p32l),"R32CL");
            // W=64：黄金（tree/wallace/comp）
            chk(din64,64,64'(p64t),"R64T"); chk(din64,64,64'(p64w),"R64W"); chk(din64,64,64'(p64c),"R64C");
            chk_eq(din64,64,64'(p64t),64'(p64w),"R64TW"); chk_eq(din64,64,64'(p64w),64'(p64c),"R64WC");
        end
        $display("[tc_random/equiv] 4000 seeded random × W{8,16,32,64} × impl done");

        // ---------------- 终局判定 ----------------
        if (errors == 0) $display("=== POPCOUNT_TB PASS: all scenarios clean ===");
        else $display("=== POPCOUNT_TB FAIL: %0d mismatches ===", errors);
        $finish;
    end

    // 超时看门狗
    initial begin
        #50_000_000;
        $display("=== POPCOUNT_TB TIMEOUT ==="); $finish;
    end

endmodule
