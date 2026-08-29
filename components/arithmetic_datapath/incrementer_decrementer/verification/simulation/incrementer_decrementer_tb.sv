// ============================================================================
// incrementer_decrementer_tb — G4 功能验证测试台
//   (verify-cbb: 穷举 + 随机 + 边界 + 等价 + 变异)
// ----------------------------------------------------------------------------
// 场景（REQ→tc 映射见 trace/rtm.yaml）：
//   tc_exhaust_w8 : W=8 全空间 256 向量 × 两实现 × {inc,dec,hold} (REQ-001)
//   tc_edge       : 全0 / 全1 / 单bit / carry_out 边界 (REQ-002/003)
//   tc_random     : 随机向量 × {W=8,16,32} × 两实现（黄金 + 等价） (REQ-001/004)
//   tc_equiv      : 两实现跨实现一致 (REQ-004)
//   tc_mutation   : 变异——破坏 carry 传播条件，断言应能检测 (REQ-001)
//   tc_negative_elab : 非法参数 elaboration $error 拦截，TB 在 verification/formal/
//                      negative_elab_tb.sv（本表为场景索引汇总） (REQ-005)
// 黄金模型：独立算术（dout=din±1 模 2^W；carry 独立计算），与实现无共享结构。
// ============================================================================
`timescale 1ns/1ps

module incrementer_decrementer_tb;
    localparam int SEED = 32'h5000_2026;   // 里程碑 seed（2026-08-29）

    // ---- 驱动信号（须先于 DUT 实例声明，避免隐式 net 冲突）----
    logic inc_en, dec_en;

    // ---- W=8 穷举：两实现（ripple / segmented SEG=4）----
    logic [63:0] din8;
    wire [7:0]  r8, s8;
    wire        cr8, cs8;
    incrementer_decrementer #(.DATA_W(8),  .ID_IMPL(0), .CG_EN(1))          dut_r8  (.din(din8[7:0]),  .inc_en(inc_en), .dec_en(dec_en), .dout(r8),  .carry_out(cr8));
    incrementer_decrementer #(.DATA_W(8),  .ID_IMPL(1), .SEG_W(4), .CG_EN(1)) dut_s8 (.din(din8[7:0]),  .inc_en(inc_en), .dec_en(dec_en), .dout(s8),  .carry_out(cs8));

    // ---- CG 等价：CG_EN=0（原始） vs CG_EN=1（自动门控）输出必须一致（ASM-005）----
    wire [7:0]  r8_cg0, s8_cg0;
    wire        cr8_cg0, cs8_cg0;
    incrementer_decrementer #(.DATA_W(8),  .ID_IMPL(0), .CG_EN(0))          dut_r8_cg0  (.din(din8[7:0]),  .inc_en(inc_en), .dec_en(dec_en), .dout(r8_cg0),  .carry_out(cr8_cg0));
    incrementer_decrementer #(.DATA_W(8),  .ID_IMPL(1), .SEG_W(4), .CG_EN(0)) dut_s8_cg0 (.din(din8[7:0]),  .inc_en(inc_en), .dec_en(dec_en), .dout(s8_cg0),  .carry_out(cs8_cg0));

    // ---- W=16 / 32 随机 + 等价 ----
    logic [63:0] din16, din32;
    wire [15:0] r16, s16;
    wire [31:0] r32, s32;
    wire        cr16, cs16, cr32, cs32;
    incrementer_decrementer #(.DATA_W(16), .ID_IMPL(0), .CG_EN(1))          dut_r16 (.din(din16[15:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(r16), .carry_out(cr16));
    incrementer_decrementer #(.DATA_W(16), .ID_IMPL(1), .SEG_W(4), .CG_EN(1)) dut_s16 (.din(din16[15:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(s16), .carry_out(cs16));
    incrementer_decrementer #(.DATA_W(32), .ID_IMPL(0), .CG_EN(1))          dut_r32 (.din(din32[31:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(r32), .carry_out(cr32));
    incrementer_decrementer #(.DATA_W(32), .ID_IMPL(1), .SEG_W(8), .CG_EN(1)) dut_s32 (.din(din32[31:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(s32), .carry_out(cs32));

    // ---- 黄金参考：独立算术 ----
    function automatic logic [63:0] golden_dout(input logic [63:0] din, input int n,
                                                input logic ie, input logic de);
        logic [63:0] v; v = din;
        if (ie && !de) v = din + 1;
        else if (de && !ie) v = din - 1;
        return v & ((64'b1 << n) - 1);       // 模 2^n
    endfunction
    function automatic logic golden_carry(input logic [63:0] din, input int n,
                                          input logic ie, input logic de);
        return (ie && (din & ((64'b1 << n) - 1)) == ((64'b1 << n) - 1))
            || (de && (din & ((64'b1 << n) - 1)) == 0);
    endfunction

    // ---- 检查（黄金） ----
    integer errors;
    initial errors = 0;
    task automatic chk(input logic [63:0] din, input int n,
                       input logic ie, input logic de,
                       input logic [63:0] got, input logic gcarry,
                       input string tag);
        logic [63:0] exp; logic ec;
        exp = golden_dout(din, n, ie, de);
        ec  = golden_carry(din, n, ie, de);
        if (got !== exp) begin
            errors++;
            $display("[FAIL] %s din=%0h ie=%0b de=%0b got=%0h exp=%0h", tag, din, ie, de, got, exp);
        end
        if (gcarry !== ec) begin
            errors++;
            $display("[FAIL] %s carry din=%0h ie=%0b de=%0b got=%0b exp=%0b", tag, din, ie, de, gcarry, ec);
        end
    endtask

    // ---- 检查（多实现等价） ----
    task automatic chk_eq(input logic [63:0] din, input int n,
                          input logic ie, input logic de,
                          input logic [63:0] a, input logic [63:0] b,
                          input logic ca, input logic cb, input string tag);
        if (a !== b) begin
            errors++;
            $display("[FAIL] %s eq din=%0h ie=%0b de=%0b a=%0h b=%0h", tag, din, ie, de, a, b);
        end
        if (ca !== cb) begin
            errors++;
            $display("[FAIL] %s carry_eq din=%0h ie=%0b de=%0b ca=%0b cb=%0b", tag, din, ie, de, ca, cb);
        end
    endtask

    // ---- 变异注入：对 carry 传播条件取反（覆盖 ripple 内部 c[i+1]）----
    // 通过 macro 开关在编译期启用变异版 DUT（tc_mutation）：
    //   正常：c[i+1]=inc_en ? (din[i]&c[i]) : (~din[i]&c[i])
    //   变异：c[i+1]=inc_en ? (din[i]&c[i]) : ( din[i]&c[i])  ← 借位条件写反
    `ifdef MUTATION
    wire [7:0] m8;
    wire cm8;
    incrementer_decrementer_impl_ripple_mut #(.DATA_W(8)) dut_m8 (
        .din(din8[7:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(m8), .carry_out(cm8));
    `endif

    initial begin
        $display("=== incrementer_decrementer_tb start (seed=%0d) ===", SEED);
        din8 = '0; din16 = '0; din32 = '0; inc_en = 0; dec_en = 0;
        #1;

        // ---------------- tc_exhaust_w8（两实现 × 三使能模式）----------------
        for (int m = 0; m < 3; m++) begin
            inc_en = (m == 0); dec_en = (m == 1);
            for (int v = 0; v < 256; v++) begin
                din8 = 64'(v); #1;
                chk(din8,8,inc_en,dec_en,64'(r8),cr8,"E8R");
                chk(din8,8,inc_en,dec_en,64'(s8),cs8,"E8S");
                chk_eq(din8,8,inc_en,dec_en,64'(r8),64'(s8),cr8,cs8,"E8RS");
                // tc_cg_equiv：CG_EN=0 vs CG_EN=1 输出一致（ASM-005）
                chk_eq(din8,8,inc_en,dec_en,64'(r8),64'(r8_cg0),cr8,cr8_cg0,"CG_R");
                chk_eq(din8,8,inc_en,dec_en,64'(s8),64'(s8_cg0),cs8,cs8_cg0,"CG_S");
            end
        end
        $display("[tc_exhaust_w8] 256×3 × 2 impl + CG0/1 eq done");

        // ---------------- tc_edge ----------------
        // 全 0：inc→1, dec→全1+carry, hold→0
        din8 = '0; inc_en=1; dec_en=0; #1;
        chk(din8,8,1,0,64'(r8),cr8,"E0R"); chk(din8,8,1,0,64'(s8),cs8,"E0S");
        inc_en=0; dec_en=1; #1;
        chk(din8,8,0,1,64'(r8),cr8,"E0D_R"); chk(din8,8,0,1,64'(s8),cs8,"E0D_S");
        // 全 1：inc→0+carry, dec→全0, hold→全1
        din8 = 64'hFF; inc_en=1; dec_en=0; #1;
        chk(din8,8,1,0,64'(r8),cr8,"EA_R"); chk(din8,8,1,0,64'(s8),cs8,"EA_S");
        inc_en=0; dec_en=1; #1;
        chk(din8,8,0,1,64'(r8),cr8,"EA_D_R"); chk(din8,8,0,1,64'(s8),cs8,"EA_D_S");
        // 单 bit 逐位：inc/dec/hold
        for (int b = 0; b < 8; b++) begin
            din8 = 64'(1) << b;
            inc_en=1; dec_en=0; #1;
            chk(din8,8,1,0,64'(r8),cr8,"onehotI_R"); chk(din8,8,1,0,64'(s8),cs8,"onehotI_S");
            inc_en=0; dec_en=1; #1;
            chk(din8,8,0,1,64'(r8),cr8,"onehotD_R"); chk(din8,8,0,1,64'(s8),cs8,"onehotD_S");
        end
        // hold：不使能 → dout=din, carry=0
        din8 = 64'hA5; inc_en=0; dec_en=0; #1;
        chk(din8,8,0,0,64'(r8),cr8,"HOLD_R"); chk(din8,8,0,0,64'(s8),cs8,"HOLD_S");
        $display("[tc_edge] done");

        // ---------------- tc_random（黄金 + 等价，两实现 × 多宽度）----------------
        process::self.srandom(SEED);
        for (int i = 0; i < 4000; i++) begin
            void'(std::randomize(din8, din16, din32, inc_en, dec_en));
            // 约束：inc_en 与 dec_en 不同时断言（ASM-002）
            if (inc_en && dec_en) dec_en = 0;
            #1;
            // W=8：黄金 + 等价
            chk(din8,8,inc_en,dec_en,64'(r8),cr8,"R8R");
            chk(din8,8,inc_en,dec_en,64'(s8),cs8,"R8S");
            chk_eq(din8,8,inc_en,dec_en,64'(r8),64'(s8),cr8,cs8,"R8RS");
            // W=16：黄金 + 等价
            chk(din16,16,inc_en,dec_en,64'(r16),cr16,"R16R");
            chk(din16,16,inc_en,dec_en,64'(s16),cs16,"R16S");
            chk_eq(din16,16,inc_en,dec_en,64'(r16),64'(s16),cr16,cs16,"R16RS");
            // W=32：黄金 + 等价
            chk(din32,32,inc_en,dec_en,64'(r32),cr32,"R32R");
            chk(din32,32,inc_en,dec_en,64'(s32),cs32,"R32S");
            chk_eq(din32,32,inc_en,dec_en,64'(r32),64'(s32),cr32,cs32,"R32RS");
        end
        $display("[tc_random] 4000 × {W8,16,32} × 2 impl + eq done");

        // ---------------- tc_mutation（变异，仅 MUTATION 编译）----------------
        // 目的：证明 checker（黄金模型）有效——变异版（借位条件写反）与黄金模型
        // 递减语义必须产生差异；差异数 > 0 即证明 checker 能捕获该变异。
        `ifdef MUTATION
        begin
            integer mut_detected;
            mut_detected = 0;
            inc_en=0; dec_en=1;
            for (int v = 0; v < 256; v++) begin
                din8 = 64'(v); #1;
                if (m8 !== golden_dout(din8,8,0,1)) mut_detected++;
            end
            if (mut_detected == 0) begin
                errors++;
                $display("[FAIL] tc_mutation 变异未被黄金模型检测（checker 失效）");
            end else begin
                $display("[tc_mutation] 变异被检测：%0d/256 向量与黄金模型差异（checker 有效）",
                         mut_detected);
            end
        end
        `else
        $display("[tc_mutation] skipped (未定义 MUTATION；正式回归不启用)");
        `endif

        // ---------------- 汇总 ----------------
        if (errors == 0) begin
            $display("=== PASS: incrementer_decrementer_tb (0 errors) ===");
        end else begin
            $display("=== FAIL: %0d errors ===", errors);
            $fatal(1);
        end
    end
endmodule

// ============================================================================
// 变异版 ripple（tc_mutation）：借位传播条件写反
//   正常：c[i+1] = inc_en ? (din[i]&c[i]) : (~din[i]&c[i])
//   变异：c[i+1] = inc_en ? (din[i]&c[i]) : ( din[i]&c[i])   ← 递减借位条件错误
// ============================================================================
module incrementer_decrementer_impl_ripple_mut #(
    parameter int DATA_W = 32
) (
    input  logic [DATA_W-1:0] din,
    input  logic              inc_en,
    input  logic              dec_en,
    output logic [DATA_W-1:0] dout,
    output logic              carry_out
);
    localparam int W = DATA_W;
    logic [W:0] c;
    assign c[0] = inc_en | dec_en;
    for (genvar i = 0; i < W; i++) begin : g_chain
        assign dout[i] = din[i] ^ c[i];
        assign c[i+1]  = inc_en ? (din[i] & c[i]) : (din[i] & c[i]);  // MUTATION
    end
    assign carry_out = c[W];
endmodule
