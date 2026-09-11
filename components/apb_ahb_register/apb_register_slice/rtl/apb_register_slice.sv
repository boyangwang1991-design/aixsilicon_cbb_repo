// ============================================================================
// apb_register_slice — APB 寄存切片 (A3, BUS-003)
// VLNV: aixsilicon:cbb:apb_register_slice:0.1.0
// ----------------------------------------------------------------------------
// SLICE_MODE 打拍位置（前向 main→sub / 反馈 sub→main，割断长组合路径）：
//   0 = REQUEST   前向 1 拍（地址/写数据/控制），反馈组合直通（PREADY 即时）
//   1 = RESPONSE  前向组合直通，反馈 1 拍（PREADY/PRDATA/PSLVERR 返回路径割断）
//   2 = FULL      前向 1 拍 + 反馈 RESP_STAGES 拍（两侧均割断）
// RESP_STAGES: 反馈寄存级数 {1..2}（仅 SLICE_MODE!=0 有效；=0 时参数忽略）
// 语义：纯透传——不产生/终止事务，不改变 SETUP→ACCESS 相位与事务顺序；
//       pready/prdata/pslverr 同组寄存（完成与数据/错误对齐）；
//       paddr/pprot/pwrite/pwdata/pstrb 与 psel/penable 同组寄存（原子前向）。
// X 输入不作承诺（ASM-001）。协议检查归 VIP（非目标）。
// ============================================================================

module apb_register_slice #(
    parameter int ADDR_WIDTH  = 16,
    parameter int DATA_WIDTH  = 32,
    parameter int SLICE_MODE  = 2,     // {0=request, 1=response, 2=full}
    parameter int RESP_STAGES = 1      // 反馈寄存级数 {1..2}
) (
    input  logic                     clk,
    input  logic                     rst_n,
    // 主侧（APB 上游 master 视角的从接口）
    input  logic                     psel_main,
    input  logic                     penable_main,
    input  logic [ADDR_WIDTH-1:0]    paddr_main,
    input  logic [2:0]               pprot_main,
    input  logic                     pwrite_main,
    input  logic [DATA_WIDTH-1:0]    pwdata_main,
    input  logic [DATA_WIDTH/8-1:0]  pstrb_main,
    output logic                     pready_main,
    output logic [DATA_WIDTH-1:0]    prdata_main,
    output logic                     pslverr_main,
    // 子侧（APB 下游从设备）
    output logic                     psel_sub,
    output logic                     penable_sub,
    output logic [ADDR_WIDTH-1:0]    paddr_sub,
    output logic [2:0]               pprot_sub,
    output logic                     pwrite_sub,
    output logic [DATA_WIDTH-1:0]    pwdata_sub,
    output logic [DATA_WIDTH/8-1:0]  pstrb_sub,
    input  logic                     pready_sub,
    input  logic [DATA_WIDTH-1:0]    prdata_sub,
    input  logic                     pslverr_sub
);
    localparam int AW = ADDR_WIDTH;
    localparam int DW = DATA_WIDTH;
    localparam int SW = DATA_WIDTH/8;   // pstrb 位宽（DW>=8 由 PC-003 保证）

    // ---- 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..006）----
    generate
        if (AW < 8 || AW > 32) begin : g_param_aw
            $error("apb_register_slice PC-001/002 violation: ADDR_WIDTH=%0d outside [8..32]", AW);
        end
        if (DW < 8 || DW > 64) begin : g_param_dw
            $error("apb_register_slice PC-003/004 violation: DATA_WIDTH=%0d outside [8..64]", DW);
        end
        if (SLICE_MODE < 0 || SLICE_MODE > 2) begin : g_param_mode
            $error("apb_register_slice PC-005 violation: SLICE_MODE=%0d not in [0..2]", SLICE_MODE);
        end
        if (RESP_STAGES < 1 || RESP_STAGES > 2) begin : g_param_rs
            $error("apb_register_slice PC-006 violation: RESP_STAGES=%0d not in [1..2]", RESP_STAGES);
        end
    endgenerate

    // ------------------------------------------------------------------
    // 前向通路（main → sub）
    //   SLICE_MODE=0/2：1 拍寄存（psel/penable 与地址/数据/控制同组原子寄存）
    //   SLICE_MODE=1  ：组合直通
    // ------------------------------------------------------------------
    generate
        if (SLICE_MODE == 1) begin : g_fwd_combo
            assign psel_sub    = psel_main;
            assign penable_sub = penable_main;
            assign paddr_sub   = paddr_main;
            assign pprot_sub   = pprot_main;
            assign pwrite_sub  = pwrite_main;
            assign pwdata_sub  = pwdata_main;
            assign pstrb_sub   = pstrb_main;
        end else begin : g_fwd_reg
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    psel_sub    <= 1'b0;
                    penable_sub <= 1'b0;
                    paddr_sub   <= '0;
                    pprot_sub   <= '0;
                    pwrite_sub  <= 1'b0;
                    pwdata_sub  <= '0;
                    pstrb_sub   <= '0;
                end else begin
                    psel_sub    <= psel_main;
                    penable_sub <= penable_main;
                    paddr_sub   <= paddr_main;
                    pprot_sub   <= pprot_main;
                    pwrite_sub  <= pwrite_main;
                    pwdata_sub  <= pwdata_main;
                    pstrb_sub   <= pstrb_main;
                end
            end
        end
    endgenerate

    // ------------------------------------------------------------------
    // 反馈通路（sub → main）
    //   SLICE_MODE=1/2：RESP_STAGES 级寄存（pready/prdata/pslverr 同组对齐）
    //   SLICE_MODE=0  ：组合直通
    // ------------------------------------------------------------------
    generate
        if (SLICE_MODE == 0) begin : g_resp_combo
            assign pready_main  = pready_sub;
            assign prdata_main  = prdata_sub;
            assign pslverr_main = pslverr_sub;
        end else if (RESP_STAGES == 1) begin : g_resp_reg1
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    pready_main  <= 1'b0;
                    prdata_main  <= '0;
                    pslverr_main <= 1'b0;
                end else begin
                    pready_main  <= pready_sub;
                    prdata_main  <= prdata_sub;
                    pslverr_main <= pslverr_sub;
                end
            end
        end else begin : g_resp_reg2
            // 两级反馈流水（RESP_STAGES=2）：级 1 捕获，级 2 呈现
            logic              s1_ready;
            logic [DW-1:0]     s1_data;
            logic              s1_err;
            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    s1_ready     <= 1'b0;
                    s1_data      <= '0;
                    s1_err       <= 1'b0;
                    pready_main  <= 1'b0;
                    prdata_main  <= '0;
                    pslverr_main <= 1'b0;
                end else begin
                    s1_ready     <= pready_sub;
                    s1_data      <= prdata_sub;
                    s1_err       <= pslverr_sub;
                    pready_main  <= s1_ready;
                    prdata_main  <= s1_data;
                    pslverr_main <= s1_err;
                end
            end
        end
    endgenerate

    // ------------------------------------------------------------------
    // 就近 SVA（关键不变量；@(posedge clk) 并发断言，综合忽略）
    // 驱动约定：TB 全部激励在 negedge 更新（主侧驱动 + 从设备模型），时钟沿
    // preponed 采样到的都是稳定值（对齐 fpa_tb 实践，杜绝 active 区竞态）。
    // 含 $past 的断言用 $past(rst_n[,RS]) 门控——跳过复位释放后 $past 历史仍含
    // 复位期值的管道填充拍（实测坑：release 首拍 $past 取复位期旧值误报）。
    // 断言 label 用下划线 PROP_ARS_*_00x（SV 标识符）；SVA 失败报告中 label
    // 出现原始行，供 run_functional_sim.sh grep 检出（变异测试）。
    // ------------------------------------------------------------------
    generate
        if (SLICE_MODE == 1 || SLICE_MODE == 2) begin : g_sva_resp
            // INV-001 相位使能保持（mode=1 直通同拍 / mode=2 寄存 1 拍滞后）
            if (SLICE_MODE == 1) begin : g_sva_phase_c
                // PROP-ARS_PHASE-001：前向直通——相位逐拍一致
                PROP_ARS_PHASE_001: assert property (@(posedge clk) disable iff(!rst_n)
                    psel_sub == psel_main && penable_sub == penable_main);
            end else begin : g_sva_phase_r
                // PROP-ARS_PHASE-001：前向打拍——相位延迟 1 拍且原子
                PROP_ARS_PHASE_001: assert property (@(posedge clk) disable iff(!rst_n)
                    $past(rst_n) |-> ((psel_sub == $past(psel_main)) &&
                                      (penable_sub == $past(penable_main))));
            end
            // PROP-ARS_RESPDLY-002：固定反馈延迟——子完成沿捕获后恰 RESP_STAGES 拍呈现
            // PROP-ARS_ALIGN-003：反馈对齐——数据/错误与完成同拍同源（同组寄存）
            if (RESP_STAGES == 1) begin : g_sva_rs1
                PROP_ARS_RESPDLY_002: assert property (@(posedge clk) disable iff(!rst_n)
                    $past(rst_n) |-> (pready_main == $past(pready_sub)));
                PROP_ARS_ALIGN_003: assert property (@(posedge clk) disable iff(!rst_n)
                    $past(rst_n) |-> ((prdata_main == $past(prdata_sub)) &&
                                      (pslverr_main == $past(pslverr_sub))));
            end else begin : g_sva_rs2
                // RS=2 的 $past 历史窗口跨 3 拍：要求最近 3 拍 rst_n 均为 1
                //（$past(rst_n,2) && $past(rst_n) && rst_n 经 disable iff 已保证），
                // 排除复位释放后历史窗口仍含复位期旧值的边界拍（$past 管道填充）。
                PROP_ARS_RESPDLY_002: assert property (@(posedge clk) disable iff(!rst_n)
                    ($past(rst_n, 2) && $past(rst_n)) |-> (pready_main == $past(pready_sub, 2)));
                PROP_ARS_ALIGN_003: assert property (@(posedge clk) disable iff(!rst_n)
                    ($past(rst_n, 2) && $past(rst_n)) |-> ((prdata_main == $past(prdata_sub, 2)) &&
                                                           (pslverr_main == $past(pslverr_sub, 2))));
            end
            // PROP-ARS_FULL-005（mode=2）：前向打拍 1 拍——地址/写数据原子滞后
            if (SLICE_MODE == 2) begin : g_sva_full
                PROP_ARS_FULL_005: assert property (@(posedge clk) disable iff(!rst_n)
                    $past(rst_n) |-> ((paddr_sub == $past(paddr_main)) &&
                                      (pwrite_sub == $past(pwrite_main))));
            end
        end else begin : g_sva_req
            // PROP-ARS_REQDLY-004：request 模式——前向 1 拍、反馈组合直通
            PROP_ARS_REQDLY_004A: assert property (@(posedge clk) disable iff(!rst_n)
                $past(rst_n) |-> ((psel_sub == $past(psel_main)) &&
                                  (penable_sub == $past(penable_main))));
            PROP_ARS_REQDLY_004B: assert property (@(posedge clk) disable iff(!rst_n)
                $past(rst_n) |-> ((paddr_sub == $past(paddr_main)) &&
                                  (pwdata_sub == $past(pwdata_main))));
            PROP_ARS_REQDLY_004C: assert property (@(posedge clk) disable iff(!rst_n)
                (pready_main == pready_sub) && (pslverr_main == pslverr_sub));
        end
    endgenerate

    // PROP-ARS_RESET-006：复位清洁——寄存输出由异步复位清零（RTL 结构保证）；
    // 组合直通输出随输入，无存储。端到端复位清洁（空闲期主/子侧选中/完成全 0）
    // 由 TB tc_reset 端到端检查（RTL 侧无可断言的恒定输入条件，不放置占位断言）。
    // 注：$past(,2) 断言在复位释放后 2 拍内的历史窗口仍含复位期旧值，
    //     属复位边界合法现象（非契约违反）——由 $past(rst_n,2) 前提排除释放拍本身，
    //     释放后窗口残余由 TB 复位隔离（场景间 rst_n 脉冲）+ 空闲基线保证无观测影响。

endmodule
