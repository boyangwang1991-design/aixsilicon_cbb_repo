// ============================================================================
// incrementer_decrementer — Counter 专用 ±1 运算器（ARI-001, A1/P0）
// VLNV: aixsilicon:cbb:incrementer_decrementer:0.1.0
// ----------------------------------------------------------------------------
// 语义（模 2^DATA_W 回绕）：
//   inc_en=1, dec_en=0 → dout = din + 1
//   inc_en=0, dec_en=1 → dout = din - 1
//   inc_en=0, dec_en=0 → dout = din（保持）
//   inc_en=1, dec_en=1 → 行为未定义（ASM-002，调用方保证互斥）
//   carry_out = (inc_en & &din) | (dec_en & ~|din)   // 溢出 / 借位标志
// 纯组合，X 输入不作承诺（ASM-001）。
//
// ID_IMPL 微架构选择（面积/时序 Pareto 实证对比，见 reports/ppa-report.md）：
//   0 = RIPPLE     半加器进位链（O(W) 深，面积最小，基线）
//   1 = SEGMENTED  分段进位 carry-skip（O(SEG+W/SEG) 深，时序更优）
// SEG_W 为 segmented 段位宽（仅 ID_IMPL=1 生效）。
//
// CG_EN 可选自动 Carry/Data Gating（2026-08-29 PPA 选项）：
//   0 = 关闭（原始结构：进位链仅由 c[0] 起止，XOR 直连）
//   1 = 开启（默认）：以 active=inc_en|dec_en 显式门控——
//       · 进位链强制 0（carry gating：hold 模式零翻转，不依赖 c[0] 传播）；
//       · XOR 输入 c&active=0 → 退化为直通（operand isolation / data gating）。
//   自动 CG 无需外部 en 端口（基于已有 inc_en/dec_en），hold 模式动态功耗显著更低；
//   语义与 CG_EN=0 完全等价（active=0 → dout=din、carry_out=0），契约不变。
//   功耗量化对比见 reports/ppa-report.md §CG（run-20260829-02）。
// ============================================================================

module incrementer_decrementer #(
    parameter int DATA_W = 32,
    parameter int ID_IMPL = 0,           // {0=ripple, 1=segmented}
    parameter int SEG_W  = 4,            // segmented 段位宽（仅 ID_IMPL=1 生效）
    parameter int CG_EN  = 1             // {0=关闭 CG, 1=开启自动 Carry/Data Gating}
) (
    input  logic [DATA_W-1:0] din,
    input  logic              inc_en,
    input  logic              dec_en,
    output logic [DATA_W-1:0] dout,
    output logic              carry_out
);
    localparam int W = DATA_W;

    // ---- 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..005）----
    generate
        if (W < 2 || W > 1024) begin : g_param_w
            $error("incrementer_decrementer PC-001/002 violation: DATA_W=%0d outside [2..1024]", W);
        end
        if (ID_IMPL < 0 || ID_IMPL > 1) begin : g_param_impl
            $error("incrementer_decrementer illegal ID_IMPL=%0d not in {0,1}", ID_IMPL);
        end
        if (SEG_W < 2 || SEG_W > 16) begin : g_param_seg
            $error("incrementer_decrementer PC-004 violation: SEG_W=%0d outside [2..16]", SEG_W);
        end
        if (CG_EN < 0 || CG_EN > 1) begin : g_param_cg
            $error("incrementer_decrementer PC-005 violation: CG_EN=%0d not in {0,1}", CG_EN);
        end
    endgenerate

    // ---- 实现分派（多实现：同契约等价）----
    generate
        if (ID_IMPL == 0) begin : g_ripple
            incrementer_decrementer_impl_ripple #(.DATA_W(W), .CG_EN(CG_EN)) u_impl (
                .din(din), .inc_en(inc_en), .dec_en(dec_en), .dout(dout), .carry_out(carry_out));
        end else begin : g_segmented
            incrementer_decrementer_impl_segmented #(.DATA_W(W), .SEG_W(SEG_W), .CG_EN(CG_EN)) u_impl (
                .din(din), .inc_en(inc_en), .dec_en(dec_en), .dout(dout), .carry_out(carry_out));
        end
    endgenerate

    // ---- 就近 SVA（关键不变量）----
    // 本构件纯组合无时钟；内嵌 always_comb 立即断言会在 t=0 输入未初始化时误报
    // （X 传播），且 $isunknown 防护不可综合（SpyGlass SYNTH_5285）。故 RTL 不内嵌
    // 可综合断言，正确性由验证台黄金模型 + 多实现等价覆盖（verification/simulation/
    // incrementer_decrementer_tb.sv：tc_exhaust_w8、tc_edge、tc_random、tc_equiv）。
    // 行为契约见 behavior.yaml（INV-001/002/003）。

endmodule

// ============================================================================
// incrementer_decrementer_impl_ripple — 半加器进位链（O(W) 深，面积最小）
//   c[0]=inc_en|dec_en；dout[i]=din[i]^c[i]；c[i+1]=inc_en ? (din[i]&c[i]) : (~din[i]&c[i])
//   递增：进位传播条件 din[i]=1；递减：借位传播条件 din[i]=0（统一链结构）。
//
//   CG_EN=1（自动 CG）：active=inc_en|dec_en；
//     · 进位链强制 0（c[i+1]=active&…，不依赖 c[0] 传播）→ hold 零翻转（carry gating）；
//     · XOR 输入 c[i]&active=0 → XOR 退化为直通（operand isolation / data gating）。
//   CG_EN=0：原始结构（进位链由 c[0] 起止，XOR 直连）。
// ============================================================================
module incrementer_decrementer_impl_ripple #(
    parameter int DATA_W = 32,
    parameter int CG_EN  = 1
) (
    input  logic [DATA_W-1:0] din,
    input  logic              inc_en,
    input  logic              dec_en,
    output logic [DATA_W-1:0] dout,
    output logic              carry_out
);
    localparam int W = DATA_W;

    logic active;
    assign active = inc_en | dec_en;

    logic [W:0] c;
    generate
        if (CG_EN == 1) begin : g_cg
            assign c[0] = active;
            for (genvar i = 0; i < W; i++) begin : g_chain
                assign dout[i] = din[i] ^ (c[i] & active);
                assign c[i+1]  = active & (inc_en ? (din[i] & c[i]) : (~din[i] & c[i]));
            end
        end else begin : g_nocg
            assign c[0] = inc_en | dec_en;
            for (genvar i = 0; i < W; i++) begin : g_chain
                assign dout[i] = din[i] ^ c[i];
                assign c[i+1]  = inc_en ? (din[i] & c[i]) : (~din[i] & c[i]);
            end
        end
    endgenerate
    assign carry_out = c[W];
endmodule

// ============================================================================
// incrementer_decrementer_impl_segmented — 分段进位 carry-skip（O(SEG+W/SEG) 深）
//   段内 ripple 半加器链 + 段间进位预计算：
//     P[k]=inc_en ? (&seg[k]) : (~|seg[k])；c_seg[k+1]=c_seg[k] & P[k]
//   末段不足 SEG_W 时高位补 0（不影响模回绕语义）。
//   CG_EN=1（自动 CG）：active 门控段内链与段间 skip（hold 零翻转 + XOR 直通）。
// ============================================================================
module incrementer_decrementer_impl_segmented #(
    parameter int DATA_W = 32,
    parameter int SEG_W  = 4,
    parameter int CG_EN  = 1
) (
    input  logic [DATA_W-1:0] din,
    input  logic              inc_en,
    input  logic              dec_en,
    output logic [DATA_W-1:0] dout,
    output logic              carry_out
);
    localparam int W       = DATA_W;
    localparam int N_SEG   = (W + SEG_W - 1) / SEG_W;
    localparam int FULL_W  = N_SEG * SEG_W;      // 扩展后全宽（末段高位补 0）

    logic active;
    assign active = inc_en | dec_en;

    // 输入扩展到 FULL_W（保证所有部分选择宽度恒为 SEG_W，防零宽/越界）
    logic [FULL_W-1:0] din_full;
    assign din_full = {{(FULL_W - W){1'b0}}, din};

    // 段间进位链（CG_EN=1 时 active 门控：hold 模式强制 0，carry-skip 零翻转）
    logic [N_SEG:0] c_seg;

    generate
        if (CG_EN == 1) begin : g_cg
            assign c_seg[0] = active;
            for (genvar k = 0; k < N_SEG; k++) begin : g_seg
                logic [SEG_W-1:0] seg_din;
                logic [SEG_W:0]   seg_c;
                logic             seg_prop;

                assign seg_din = din_full[k*SEG_W +: SEG_W];
                assign seg_c[0] = c_seg[k];
                for (genvar i = 0; i < SEG_W; i++) begin : g_segbit
                    assign dout[k*SEG_W + i] = seg_din[i] ^ (seg_c[i] & active);
                    assign seg_c[i+1] = active & (inc_en ? (seg_din[i] & seg_c[i]) : (~seg_din[i] & seg_c[i]));
                end
                assign seg_prop    = inc_en ? (&seg_din) : (~|seg_din);
                assign c_seg[k+1]  = active & (c_seg[k] & seg_prop);
            end
        end else begin : g_nocg
            assign c_seg[0] = inc_en | dec_en;
            for (genvar k = 0; k < N_SEG; k++) begin : g_seg
                logic [SEG_W-1:0] seg_din;
                logic [SEG_W:0]   seg_c;
                logic             seg_prop;

                assign seg_din = din_full[k*SEG_W +: SEG_W];
                assign seg_c[0] = c_seg[k];
                for (genvar i = 0; i < SEG_W; i++) begin : g_segbit
                    assign dout[k*SEG_W + i] = seg_din[i] ^ seg_c[i];
                    assign seg_c[i+1] = inc_en ? (seg_din[i] & seg_c[i]) : (~seg_din[i] & seg_c[i]);
                end
                assign seg_prop    = inc_en ? (&seg_din) : (~|seg_din);
                assign c_seg[k+1]  = c_seg[k] & seg_prop;
            end
        end
    endgenerate

    assign carry_out = c_seg[N_SEG];
endmodule
