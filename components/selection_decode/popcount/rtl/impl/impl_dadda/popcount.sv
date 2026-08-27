// ============================================================================
// popcount_impl_dadda — Dadda 调度列压缩 (Change C1, 2026-08-27 定稿)
// ----------------------------------------------------------------------------
// 数学内核（权值守恒律 Σ m[c]·2^c 恒定，FA: -2@本列 +1 carry 权 2^c+1）：
//   轮内顺序处理各列: eff(c) = m[r][c] + pend(左邻本轮 FA 数)
//                     f(c)   = Dadda 调度 FA 数 ∈ [0, floor(eff/3)]
//                     m[r+1][c] = eff - 2*f(c)     # 残位(eff-3f)+SUM(f)
//                     下列 pend = f(c)             # CARRY 每FA恰1个
//   Dadda 目标序列 DTBL 升序覆盖 ≥W；下降轮 tgt=DTBL[HI-1-r]，CLEAR 轮 tgt=2。
//   f = ceil((eff-tgt)/2)，可行性钳制 3f<=eff（回退魔数 floor(eff/3)=
//   (eff*17'hAAAB)>>17，eff<2^17 精确——无除法网络）。
// 判据：终态全列 ≤2 且 wsum==W（Python 原型 W∈{4,8,16,31,64,127,256} 全通过）。
// 极简单文件：无 package/interface。
// ============================================================================

module popcount_impl_dadda #(
    parameter int INPUT_WIDTH = 64,
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1)
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);
    localparam int W    = INPUT_WIDTH;
    localparam int COLS = CNT_W;
    localparam int MW   = $clog2(W) + 2;         // 富余 1 位防中间态回绕

    localparam int DTBL [14] = '{2,3,4,6,9,13,19,28,42,63,94,141,211,316};

    function automatic int seq_hi();
        for (int k = 0; k < 14; k++) if (DTBL[k] >= W) return k;
        return 13;
    endfunction
    localparam int HI    = seq_hi();
    localparam int NRUNG = HI;
    localparam int RND   = NRUNG + COLS + 4;      // CLEAR 收尾轮富余

    function automatic int tgt_of(input int r);
        if (r < NRUNG) return DTBL[HI - 1 - r];
        return 2;
    endfunction

    generate
        if (INPUT_WIDTH < 4 || INPUT_WIDTH > 256) begin : g_illegal_w
            $error("popcount_impl_dadda: INPUT_WIDTH=%0d outside legal [4..256]", INPUT_WIDTH);
        end
        if (CNT_W != $clog2(INPUT_WIDTH + 1)) begin : g_cntw_mismatch
            $error("popcount_impl_dadda: CNT_W=%0d inconsistent", CNT_W);
        end
    endgenerate

    logic [MW-1:0] m [RND+1][COLS];

    function automatic int unsigned popcnt_w(input logic [W-1:0] v);
        int unsigned acc;
        acc = 0;
        for (int b = 0; b < W; b++) if (v[b]) acc++;
        return acc;
    endfunction

    always_comb begin
        // ---- 初态：W 个同权 bit 位于列 0 ----
        m[0][0] = MW'(popcnt_w(data_i));
        for (int c = 1; c < COLS; c++) m[0][c] = '0;

        // ---- 逐轮原子推进 ----
        for (int r = 0; r < RND; r++) begin
            int h;
            int pend;
            int eff;
            int diff;
            int f;
            int three_f;

            h    = tgt_of(r);
            pend = 0;
            for (int c = 0; c < COLS; c++) begin
                eff  = $unsigned(m[r][c]) + pend;
                diff = eff - h;
                if (diff <= 0) begin
                    f = 0;
                end else begin
                    f       = (diff + 1) >> 1;                 // ceil(diff/2)
                    three_f = (f << 1) + f;                    // 3f
                    if (three_f > eff)
                        f = (eff * 17'hAAAB) >> 17;            // floor(eff/3) 精确
                    three_f = (f << 1) + f;
                    if (three_f > eff)
                        f = eff / 3;                           // 双保险兜底
                end
                m[r+1][c] = MW'(eff - 2 * f);
                pend      = f;
            end
            // 链尾吸收：最后一列之后的 pending 并入末列（MW 有富余位）
            m[r+1][COLS-1] = m[r+1][COLS-1] + MW'(pend);
        end
    end

    // ---- 终态两行收尾（位权已编码于列位置）----
    logic [COLS-1:0] row_a, row_b;
    always_comb begin
        for (int c = 0; c < COLS; c++) begin
            row_a[c] = (m[RND][c] >= MW'(1));
            row_b[c] = (m[RND][c] >= MW'(2));
        end
    end
    assign cnt_o = row_a + row_b;

endmodule
