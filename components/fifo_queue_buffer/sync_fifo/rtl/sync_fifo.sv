// ============================================================
// sync_fifo —— 同步 FIFO（QUE-001, A2/P0）单文件极简实现
// 参数化分派（IMPL×OUTPUT_REG 四分支，if/else 静态单分支生成，单一驱动）：
//   IMPL=0 register：读写指针 + 寄存器堆（任意深度，默认）
//   IMPL=1 shift   ：移位寄存器存储（条目紧排 [0..cnt-1]，头=index0，无读 mux）
//   OUTPUT_REG=0 comb：单级输出（rd_valid_o=~empty_o 同拍、rd_data_o=头组合，0 读延迟）
//   OUTPUT_REG=1 reg ：两级输出（存储 + 输出级 FF；refill 预取、consume 消费，
//                       整体非空 → 下拍输出级必有效；弹空后稳定为 0）
// 计数语义（count_o，整体未读条目 ∈ [0,DEPTH]）：
//   comb：存储条目数；reg：存储 + 输出级（count_q + rd_valid_q）
// 满/空由 count 派生（组合深度 ≤1）；pop/refill 判定基于沿前非空（防下溢）。
// 极简单文件：无 package/interface；参数检查 generate $error（PC-001..006）
// ============================================================

module sync_fifo #(
    parameter int DATA_W     = 32,    // 数据位宽（PC-001: >=1; PC-002: <=1024）
    parameter int DEPTH      = 16,    // 队列深度（PC-003: >=2; PC-004: <=256）
    parameter int OUTPUT_REG = 0,     // 输出级（PC-005: 0=comb / 1=reg）
    parameter int IMPL       = 0      // 存储微架构（PC-006: 0=register / 1=shift）
) (
    input  logic              clk,
    input  logic              rst_n,
    // ---- 写侧（push）----
    input  logic              push_i,
    input  logic [DATA_W-1:0] data_i,
    output logic              full_o,
    // ---- 读侧（pop）----
    input  logic              pop_i,
    output logic              rd_valid_o,
    output logic [DATA_W-1:0] rd_data_o,
    output logic              empty_o,
    // ---- 占用计数（整体未读条目数 ∈ [0,DEPTH]）----
    output logic [$clog2(DEPTH+1)-1:0] count_o
);

    localparam int DW    = DATA_W;
    localparam int CNT_W = $clog2(DEPTH + 1);   // 覆盖 0..DEPTH
    localparam int PTR_W = (DEPTH > 1) ? $clog2(DEPTH) : 1;  // 指针位宽（DEPTH≥2 安全）

    // ------------------------------------------------------------------
    // 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..006）
    // ------------------------------------------------------------------
    generate
        if (DATA_W < 1 || DATA_W > 1024) begin : g_bad_data_w
            $error("sync_fifo: DATA_W=%0d 越界 [1,1024] (PC-001/PC-002)", DATA_W);
        end
        if (DEPTH < 2 || DEPTH > 256) begin : g_bad_depth
            $error("sync_fifo: DEPTH=%0d 越界 [2,256] (PC-003/PC-004)", DEPTH);
        end
        if (OUTPUT_REG < 0 || OUTPUT_REG > 1) begin : g_bad_outreg
            $error("sync_fifo: OUTPUT_REG=%0d 越界 {0,1} (PC-005)", OUTPUT_REG);
        end
        if (IMPL < 0 || IMPL > 1) begin : g_bad_impl
            $error("sync_fifo: IMPL=%0d 越界 {0,1} (PC-006)", IMPL);
        end
    endgenerate

    // ==================================================================
    // 实现：四分支（IMPL × OUTPUT_REG）
    // ==================================================================
    generate
        // ================= IMPL=0 register =================
        if (IMPL == 0 && OUTPUT_REG == 0) begin : g_reg_comb
            // ---------------- 状态 ----------------
            logic [CNT_W-1:0]  count_q;
            logic [PTR_W-1:0]  wptr_q;
            logic [PTR_W-1:0]  rptr_q;
            logic [DATA_W-1:0] mem [DEPTH];
            // ---------------- 派生 ----------------
            wire full_c  = (count_q == CNT_W'(DEPTH));
            wire empty_c = (count_q == 0);
            wire push_ok = push_i && ~full_c;
            wire pop_ev  = pop_i && ~empty_c;          // 沿前非空 → 读指针推进/计数减

            assign full_o     = full_c;
            assign empty_o    = empty_c;
            assign count_o    = count_q;
            assign rd_valid_o = ~empty_c;
            assign rd_data_o  = ~empty_c ? mem[rptr_q] : '0;   // 组合头（沿前）

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    count_q <= '0;
                    wptr_q  <= '0;
                    rptr_q  <= '0;
                end else begin
                    if (push_ok) begin
                        mem[wptr_q] <= data_i;
                        wptr_q <= (wptr_q == PTR_W'(DEPTH - 1)) ? '0 : wptr_q + 1'b1;
                    end
                    if (pop_ev)
                        rptr_q <= (rptr_q == PTR_W'(DEPTH - 1)) ? '0 : rptr_q + 1'b1;
                    count_q <= count_q + (push_ok ? 1'b1 : 1'b0) - (pop_ev ? 1'b1 : 1'b0);
                end
            end

            // ---- SVA（register × comb）----
            property p_cnt_ubound;
                @(posedge clk) disable iff (~rst_n)
                    (count_o <= CNT_W'(DEPTH));
            endproperty
            PROP_SYNC_CNT_002: assert property (p_cnt_ubound);
            property p_full_nopush;
                @(posedge clk) disable iff (~rst_n)
                    (full_c && push_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_FULL_003: assert property (p_full_nopush);
            property p_empty_nopop;
                @(posedge clk) disable iff (~rst_n)
                    (empty_c && pop_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_EMPTY_004: assert property (p_empty_nopop);
            property p_comb_valid;
                @(posedge clk) disable iff (~rst_n)
                    (~empty_c) |-> rd_valid_o;
            endproperty
            PROP_SYNC_COMB_005: assert property (p_comb_valid);
            property p_comb_valid_empty;
                @(posedge clk) disable iff (~rst_n)
                    empty_c |-> ~rd_valid_o;
            endproperty
            PROP_SYNC_COMB_005E: assert property (p_comb_valid_empty);

        end else if (IMPL == 0 && OUTPUT_REG == 1) begin : g_reg_regout
            // ---------------- 状态 ----------------
            logic [CNT_W-1:0]  count_q;          // 存储条目数
            logic [PTR_W-1:0]  wptr_q;
            logic [PTR_W-1:0]  rptr_q;
            logic [DATA_W-1:0] mem [DEPTH];
            logic              rd_valid_q;       // 输出级有效
            logic [DATA_W-1:0] rd_data_q;
            // ---------------- 派生 ----------------
            wire [CNT_W-1:0] total_c = count_q + rd_valid_q;   // 整体未读（含输出级）
            wire full_c  = (total_c >= CNT_W'(DEPTH));
            wire empty_c = (total_c == 0);
            wire push_ok = push_i && ~full_c;
            wire consume = rd_valid_q && pop_i;               // 消费者取走输出级词
            wire refill  = (count_q > 0) && (~rd_valid_q || consume); // 输出级空/将空且存储有货

            assign full_o     = full_c;
            assign empty_o    = empty_c;
            assign count_o    = total_c;
            assign rd_valid_o = rd_valid_q;
            assign rd_data_o  = rd_data_q;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    count_q    <= '0;
                    wptr_q     <= '0;
                    rptr_q     <= '0;
                    rd_valid_q <= 1'b0;
                    rd_data_q  <= '0;
                end else begin
                    // 写：整体非满入存储
                    if (push_ok) begin
                        mem[wptr_q] <= data_i;
                        wptr_q <= (wptr_q == PTR_W'(DEPTH - 1)) ? '0 : wptr_q + 1'b1;
                    end
                    if (refill) begin
                        // 存储头 → 输出级（存储物理移出 1 项，rptr 推进、count_q -1）
                        rptr_q     <= (rptr_q == PTR_W'(DEPTH - 1)) ? '0 : rptr_q + 1'b1;
                        count_q    <= count_q + (push_ok ? 1'b1 : 1'b0) - 1'b1;
                        rd_valid_q <= 1'b1;
                        rd_data_q  <= mem[rptr_q];           // refill 沿前头
                    end else begin
                        count_q <= count_q + (push_ok ? 1'b1 : 1'b0);
                        if (consume)
                            rd_valid_q <= 1'b0;
                    end
                end
            end

            // ---- SVA（register × reg）----
            property p_cnt_ubound;
                @(posedge clk) disable iff (~rst_n)
                    (count_o <= CNT_W'(DEPTH));
            endproperty
            PROP_SYNC_CNT_002: assert property (p_cnt_ubound);
            property p_full_nopush;
                @(posedge clk) disable iff (~rst_n)
                    (full_c && push_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_FULL_003: assert property (p_full_nopush);
            property p_empty_nopop;
                @(posedge clk) disable iff (~rst_n)
                    (empty_c && ~rd_valid_q && pop_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_EMPTY_004: assert property (p_empty_nopop);
            property p_outreg_prefetch;
                @(posedge clk) disable iff (~rst_n)
                    (count_q > 0) |=> rd_valid_o;            // 存储非空 → 下拍输出级必有效（refill 预取）
            endproperty
            PROP_SYNC_OUTREG_006: assert property (p_outreg_prefetch);
            property p_outreg_empty;
                @(posedge clk) disable iff (~rst_n)
                    (empty_c && ~rd_valid_q) |-> ~rd_valid_o; // 空且输出级无缓存 → 有效为 0
            endproperty
            PROP_SYNC_OUTREG_006E: assert property (p_outreg_empty);

        // ================= IMPL=1 shift =================
        end else if (IMPL == 1 && OUTPUT_REG == 0) begin : g_shift_comb
            // ---------------- 状态 ----------------
            logic [CNT_W-1:0]  count_q;
            logic [DATA_W-1:0] shift_mem [DEPTH];   // 条目紧排 [0..count-1]，头=index0
            // ---------------- 派生 ----------------
            wire full_c  = (count_q == CNT_W'(DEPTH));
            wire empty_c = (count_q == 0);
            wire push_ok = push_i && ~full_c;
            wire pop_ev  = pop_i && ~empty_c;
            wire [CNT_W-1:0] tail_c = count_q - (pop_ev ? 1'b1 : 1'b0);  // push 写入尾索引

            assign full_o     = full_c;
            assign empty_o    = empty_c;
            assign count_o    = count_q;
            assign rd_valid_o = ~empty_c;
            assign rd_data_o  = ~empty_c ? shift_mem[0] : '0;   // 组合头（固定位，无 mux）

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    count_q <= '0;
                    for (int i = 0; i < DEPTH; i++)
                        shift_mem[i] <= '0;
                end else begin
                    for (int i = 0; i < DEPTH; i++) begin
                        logic [DATA_W-1:0] nv;
                        if (pop_ev && (i < DEPTH - 1))
                            nv = shift_mem[i + 1];             // 左移（头 index0 移出）
                        else
                            nv = shift_mem[i];
                        if (push_ok && (CNT_W'(i) == tail_c))  // 同拍 pop 尾前移后写入新尾
                            nv = data_i;
                        shift_mem[i] <= nv;
                    end
                    count_q <= count_q + (push_ok ? 1'b1 : 1'b0) - (pop_ev ? 1'b1 : 1'b0);
                end
            end

            // ---- SVA（shift × comb）----
            property p_cnt_ubound;
                @(posedge clk) disable iff (~rst_n)
                    (count_o <= CNT_W'(DEPTH));
            endproperty
            PROP_SYNC_CNT_002: assert property (p_cnt_ubound);
            property p_full_nopush;
                @(posedge clk) disable iff (~rst_n)
                    (full_c && push_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_FULL_003: assert property (p_full_nopush);
            property p_empty_nopop;
                @(posedge clk) disable iff (~rst_n)
                    (empty_c && pop_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_EMPTY_004: assert property (p_empty_nopop);
            property p_comb_valid;
                @(posedge clk) disable iff (~rst_n)
                    (~empty_c) |-> rd_valid_o;
            endproperty
            PROP_SYNC_COMB_005: assert property (p_comb_valid);
            property p_comb_valid_empty;
                @(posedge clk) disable iff (~rst_n)
                    empty_c |-> ~rd_valid_o;
            endproperty
            PROP_SYNC_COMB_005E: assert property (p_comb_valid_empty);

        end else begin : g_shift_regout   // IMPL == 1 && OUTPUT_REG == 1
            // ---------------- 状态 ----------------
            logic [CNT_W-1:0]  count_q;          // 存储条目数
            logic [DATA_W-1:0] shift_mem [DEPTH];
            logic              rd_valid_q;
            logic [DATA_W-1:0] rd_data_q;
            // ---------------- 派生 ----------------
            wire [CNT_W-1:0] total_c = count_q + rd_valid_q;
            wire full_c  = (total_c >= CNT_W'(DEPTH));
            wire empty_c = (total_c == 0);
            wire push_ok = push_i && ~full_c;
            wire consume = rd_valid_q && pop_i;
            wire refill  = (count_q > 0) && (~rd_valid_q || consume);
            wire [CNT_W-1:0] tail_c = count_q - (refill ? 1'b1 : 1'b0); // push 写入尾索引

            assign full_o     = full_c;
            assign empty_o    = empty_c;
            assign count_o    = total_c;
            assign rd_valid_o = rd_valid_q;
            assign rd_data_o  = rd_data_q;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    count_q    <= '0;
                    rd_valid_q <= 1'b0;
                    rd_data_q  <= '0;
                    for (int i = 0; i < DEPTH; i++)
                        shift_mem[i] <= '0;
                end else begin
                    // 存储：refill 整体左移（头 index0 移入输出级）；push 写入新尾
                    for (int i = 0; i < DEPTH; i++) begin
                        logic [DATA_W-1:0] nv;
                        if (refill && (i < DEPTH - 1))
                            nv = shift_mem[i + 1];
                        else
                            nv = shift_mem[i];
                        if (push_ok && (CNT_W'(i) == tail_c))
                            nv = data_i;
                        shift_mem[i] <= nv;
                    end
                    // 计数/输出级
                    if (refill) begin
                        rd_data_q  <= shift_mem[0];             // refill 沿前头（最老项）
                        rd_valid_q <= 1'b1;
                        count_q    <= count_q + (push_ok ? 1'b1 : 1'b0) - 1'b1;
                    end else begin
                        count_q <= count_q + (push_ok ? 1'b1 : 1'b0);
                        if (consume)
                            rd_valid_q <= 1'b0;
                    end
                end
            end

            // ---- SVA（shift × reg）----
            property p_cnt_ubound;
                @(posedge clk) disable iff (~rst_n)
                    (count_o <= CNT_W'(DEPTH));
            endproperty
            PROP_SYNC_CNT_002: assert property (p_cnt_ubound);
            property p_full_nopush;
                @(posedge clk) disable iff (~rst_n)
                    (full_c && push_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_FULL_003: assert property (p_full_nopush);
            property p_empty_nopop;
                @(posedge clk) disable iff (~rst_n)
                    (empty_c && ~rd_valid_q && pop_i) |=> (count_o == $past(count_o));
            endproperty
            PROP_SYNC_EMPTY_004: assert property (p_empty_nopop);
            property p_outreg_prefetch;
                @(posedge clk) disable iff (~rst_n)
                    (count_q > 0) |=> rd_valid_o;    // 存储非空 → 下拍输出级必有效（refill 预取）
            endproperty
            PROP_SYNC_OUTREG_006: assert property (p_outreg_prefetch);
            property p_outreg_empty;
                @(posedge clk) disable iff (~rst_n)
                    (empty_c && ~rd_valid_q) |-> ~rd_valid_o;
            endproperty
            PROP_SYNC_OUTREG_006E: assert property (p_outreg_empty);
        end
    endgenerate

    // ==================================================================
    // 保序/无丢无重（PROP-SYNC_ORDER-001）：由参考模型仿真 TB 整体比对覆盖
    // （RTL 单文件内不复制参考模型，避免双实现漂移）
    // ==================================================================

endmodule
