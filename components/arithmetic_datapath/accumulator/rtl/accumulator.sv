// ============================================================================
// accumulator — 参数化整数/定点累加器（ARI-006, A2/P0）
// VLNV: aixsilicon:cbb:accumulator:0.1.0
// ----------------------------------------------------------------------------
// 核心递推：A_next = A ± X
//   rst_ni=0           → A=0（同步复位，清所有状态/事件输出）
//   clear_i=1          → A=0，sticky 清零，update_o=1
//   ce_i=0             → A 保持（load/valid 不被接收）
//   LOAD_EN && load_i  → A=load_data_i，sticky 清零，update_o=1
//   valid_i=1          → A=A±X，update_o=1，产生本次 overflow
//   其它               → A 保持
// 优先级：rst_ni > clear_i > ce_i=0 > LOAD > valid > 保持（ACC-CTL-001）
//
// 数值语义（ACC-NUM-001..006）：
//   · 按 SIGNED 对 X 做符号/零扩展；
//   · 以无限精度整数计算 T=A+X 或 T=A-X，再映射到状态范围；
//   · 统一用 ACC_WIDTH+2 位有符号中间值，避免无符号大正数之和被误判为负数；
//   · WRAP    ：保存 T 的低 ACC_WIDTH 位（模 2^W 回绕）；
//   · SATURATE：钳位到状态可表示范围（signed[−2^(W−1),2^(W−1)−1] /
//                unsigned[0,2^W−1]）；
//   · overflow_event 当且仅当本次 T 越界（含无符号下溢）；signed overflow
//     不能以 carry-out 直接替代；
//   · overflow_sticky 自复位/CLR/LOAD/status_clear 以来是否发生溢出；
//     status_clear_i 与新生溢出同拍时置位优先（ACC-CTL-003）。
//
// 时序（ACC-CTL-002/005）：单状态每根时钟沿处理一个样本，II=1；
//   update_o/overflow_event_o 每沿重新赋值、无事件时为 0；接收边沿后
//   acc_o 立即体现本次更新。无 ready、无内部排队。
//
// OPERAND_ISOLATION（PPA-04）：仅真正执行算术时把 data_i 送入加减法器，
//   其余钳零（组合使能条件，不直接与时钟相与）：
//     arith_accept = rst_ni && !clear_i && ce_i && !(LOAD_EN && load_i) && valid_i
//   idle 时 data_i 高翻转场景可降低无效翻转；满吞吐下可能增加面积/延迟，
//   默认关闭（0）并实测后选择。
// ============================================================================

module accumulator #(
    parameter int INPUT_WIDTH        = 16,   // 输入 X 位宽 [1..128]
    parameter int ACC_WIDTH          = 32,   // 状态和完整输出位宽 [1..256]
    parameter bit SIGNED             = 1'b1, // 1=有符号（符号扩展），0=无符号（零扩展）
    parameter int OP_MODE            = 0,    // {0=ADD_ONLY, 1=SUB_ONLY, 2=ADD_SUB}
    parameter int OVERFLOW_MODE      = 0,    // {0=WRAP, 1=SATURATE}
    parameter bit LOAD_EN            = 1'b1, // 支持全 ACC_WIDTH 位初值装载
    parameter bit STATUS_EN          = 1'b1, // 生成事件与 sticky 溢出状态
    parameter int OPERAND_ISOLATION  = 0     // {0=关闭, 1=开启操作数隔离}
) (
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     ce_i,
    input  logic                     clear_i,
    input  logic                     load_i,
    input  logic [ACC_WIDTH-1:0]     load_data_i,
    input  logic                     valid_i,
    input  logic [INPUT_WIDTH-1:0]   data_i,
    input  logic                     sub_i,
    input  logic                     status_clear_i,
    output logic [ACC_WIDTH-1:0]     acc_o,
    output logic                     update_o,
    output logic                     overflow_event_o,
    output logic                     overflow_sticky_o
);
    localparam int IW = INPUT_WIDTH;
    localparam int AW = ACC_WIDTH;

    // ---- 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..008）----
    generate
        if (IW < 1 || IW > 128) begin : g_param_iw
            $error("accumulator PC-001/007 violation: INPUT_WIDTH=%0d outside [1..128]", IW);
        end
        if (AW < 1 || AW > 256) begin : g_param_aw
            $error("accumulator PC-003/008 violation: ACC_WIDTH=%0d outside [1..256]", AW);
        end
        if (IW > AW) begin : g_param_ratio
            $error("accumulator PC-002 violation: INPUT_WIDTH(%0d) > ACC_WIDTH(%0d)", IW, AW);
        end
        if (OP_MODE < 0 || OP_MODE > 2) begin : g_param_op
            $error("accumulator PC-004 violation: OP_MODE=%0d not in {0,1,2}", OP_MODE);
        end
        if (OVERFLOW_MODE < 0 || OVERFLOW_MODE > 1) begin : g_param_ovf
            $error("accumulator PC-005 violation: OVERFLOW_MODE=%0d not in {0,1}", OVERFLOW_MODE);
        end
        if (OPERAND_ISOLATION < 0 || OPERAND_ISOLATION > 1) begin : g_param_iso
            $error("accumulator PC-006 violation: OPERAND_ISOLATION=%0d not in {0,1}", OPERAND_ISOLATION);
        end
    endgenerate

    // ---- 状态与事件寄存器 ----
    logic [AW-1:0] a_q;
    logic          sticky_q;

    // ---- 操作数扩展与算术（统一 ACC_WIDTH+2 位有符号中间值）----
    // 中间位宽 MW = AW + 2：
    //   signed 输入符号扩展到 MW；unsigned 输入零扩展（最高位 0，不会被误判为负）
    localparam int MW = AW + 2;

    // 控制优先级折叠（ACC-CTL-001）
    logic        do_load;
    logic        do_arith;
    logic        do_clear;
    logic        hold;
    assign do_load  = LOAD_EN && load_i && ce_i && !clear_i;
    assign do_arith = valid_i && ce_i && !clear_i && !do_load;
    assign do_clear = clear_i;               // 独立于 ce_i（优先级高于 ce）
    assign hold     = rst_ni && !do_clear && !do_load && !do_arith;

    // 操作数隔离：仅在真正执行算术时把 data_i 送入加减法器
    logic        arith_accept;
    assign arith_accept = rst_ni && !clear_i && ce_i && !do_load && valid_i;

    // 扩展后的操作数（隔离时钳零）
    logic [MW-1:0] x_ext;
    always_comb begin
        if (OPERAND_ISOLATION == 1) begin
            if (arith_accept) begin
                if (SIGNED)
                    x_ext = {{(MW - IW){data_i[IW-1]}}, data_i};
                else
                    x_ext = {{(MW - IW){1'b0}}, data_i};
            end else begin
                x_ext = '0;
            end
        end else begin
            if (SIGNED)
                x_ext = {{(MW - IW){data_i[IW-1]}}, data_i};
            else
                x_ext = {{(MW - IW){1'b0}}, data_i};
        end
    end

    // 累加状态 a_q 扩展为 MW 位（SIGNED→符号扩展，unsigned→零扩展），
    // 保证与 x_ext 的同宽度有符号/无符号运算正确（ACC-NUM-001）。
    // 关键：若不扩展，a_q 会按无符号零扩展参与 MW 位运算，最高两位
    // 溢出判定将失效（实测 WRAP 溢出漏检，见 G4 仿真回归）。
    logic [MW-1:0] a_ext;
    assign a_ext = SIGNED ? {{(MW - AW){a_q[AW-1]}}, a_q} : {{(MW - AW){1'b0}}, a_q};

    // 操作选择（OP_MODE 编译期裁剪）
    // 统一以 MW 位有符号中间值运算：无符号下溢（如 0-1）需正确表达为负，
    // 不能用无符号向量回绕（否则下溢与上溢无法区分，ACC-NUM-001）。
    logic [MW-1:0] t_sum;      // 本次算术的无限精度结果（映射前）
    logic          t_neg_sel;  // 本次执行减法
    always_comb begin
        t_neg_sel = 1'b0;
        if (OP_MODE == 1)
            t_neg_sel = 1'b1;              // SUB_ONLY
        else if (OP_MODE == 2)
            t_neg_sel = sub_i;             // ADD_SUB
        t_sum = (t_neg_sel) ? ($signed(a_ext) - $signed(x_ext))
                            : ($signed(a_ext) + $signed(x_ext));
    end

    // ---- 数值语义：WRAP / SATURATE + 溢出判定（ACC-NUM-002/003/004）----
    // 有符号数值上下界（无限精度视角）
    logic          t_ovf_signed;   // 有符号越界（含无符号下溢/上溢统一表达）
    logic          t_ovf;          // 本次算术溢出事件
    logic [AW-1:0] a_next;         // 算术更新后的状态值
    always_comb begin
        // 默认：WRAP 取低 AW 位
        a_next   = t_sum[AW-1:0];
        t_ovf    = 1'b0;
        t_ovf_signed = 1'b0;

        if (SIGNED) begin
            // 有符号：T 应能放进 AW 位有符号范围 [−2^(AW−1), 2^(AW−1)−1]。
            // MW 位中间值 T 无溢出 ⟺ 扩展高位 (MW-1..AW) 全部等于符号位 T[AW-1]。
            // 任一扩展位与符号位不同即越界（ACC-NUM-003/004）。
            t_ovf_signed = (|t_sum[MW-1:AW] != t_sum[AW-1])
                        || (&t_sum[MW-1:AW] != t_sum[AW-1]);
            t_ovf = t_ovf_signed;
            if (OVERFLOW_MODE == 1) begin // SATURATE
                // 正/负溢出方向用 MW 位符号位 T[MW-1] 判断（AW 位截断后符号已失真）
                if (t_ovf_signed && t_sum[MW-1] == 1'b0)
                    a_next = {1'b0, {AW-1{1'b1}}};          // 正饱和 2^(AW-1)-1
                else if (t_ovf_signed && t_sum[MW-1] == 1'b1)
                    a_next = {1'b1, {AW-1{1'b0}}};          // 负饱和 -2^(AW-1)
            end
        end else begin
            // 无符号：T 应能在 [0, 2^AW−1]。
            // 下溢：T 的 MW 位有符号解释 < 0（最高位为 1，减法借位）；
            // 上溢：T > 2^AW−1（扩展高位非零且符号位为 0，即正值超宽）。
            t_ovf_signed = t_sum[MW-1];                       // 无符号下溢
            t_ovf = (|t_sum[MW-1:AW]) | t_ovf_signed;         // 上溢或下溢
            if (OVERFLOW_MODE == 1) begin // SATURATE
                if (t_ovf_signed) a_next = '0;                // 下溢钳零（优先）
                else if (|t_sum[MW-1:AW]) a_next = {AW{1'b1}};// 正饱和 2^AW−1
            end
        end
    end

    // ---- 状态更新（优先级折叠后的选择 MUX）----
    logic [AW-1:0] a_sel;
    always_comb begin
        if (!rst_ni)            a_sel = '0;             // 复位
        else if (do_clear)      a_sel = '0;             // 清零
        else if (do_load)       a_sel = load_data_i;    // 装载（原样，无溢出）
        else if (do_arith)      a_sel = a_next;         // 算术更新
        else                    a_sel = a_q;            // 保持
    end

    always_ff @(posedge clk_i) begin
        if (!rst_ni) begin
            a_q      <= '0;
            sticky_q <= '0;
        end else begin
            a_q <= a_sel;
            // sticky 清除优先规则（ACC-CTL-003）：
            //   复位/CLR/LOAD 清零；新算术溢出置 1（优先于 status_clear）；
            //   否则 status_clear_i 清 0；否则保持
            if (do_clear || do_load)
                sticky_q <= 1'b0;
            else if (do_arith && t_ovf)
                sticky_q <= 1'b1;
            else if (status_clear_i)
                sticky_q <= 1'b0;
        end
    end

    // ---- 事件输出（每沿重新赋值，无事件为 0；ACC-CTL-002）----
    assign update_o        = rst_ni && (do_clear || do_load || do_arith);
    assign overflow_event_o = STATUS_EN && rst_ni && do_arith && t_ovf;
    assign overflow_sticky_o = STATUS_EN ? sticky_q : 1'b0;

    assign acc_o = a_q;

    // ---- 就近 SVA（关键不变量；仅综合目标文件，bind 于验证台使用）----
    // PROP-ACC_RESET-005：复位释放后状态与 sticky 清零
    property p_acc_reset;
        @(posedge clk_i)
            $rose(rst_ni) |=> (a_q == '0) && (sticky_q == 1'b0);
    endproperty
    // PROP-ACC_TIMING-004：无更新（保持）时下一拍 update_o 为 0
    property p_acc_event_idle;
        @(posedge clk_i)
            rst_ni && !(do_clear || do_load || do_arith) |=> !update_o;
    endproperty
    // PROP-ACC_OVERFLOW-003：有效算术且未越界时下一拍 overflow_event_o 为 0
    property p_acc_event_ovf;
        @(posedge clk_i)
            rst_ni && do_arith && !t_ovf |=> !overflow_event_o;
    endproperty

    generate if (1) begin : g_sva
        assert property (p_acc_reset);
        assert property (p_acc_event_idle);
        assert property (p_acc_event_ovf);
    end endgenerate

endmodule
