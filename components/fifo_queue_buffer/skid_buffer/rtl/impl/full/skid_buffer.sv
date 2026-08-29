// ============================================================
// skid_buffer_full — impl_full（IMPL=1）
// full register slice：OUT 寄存级 + SKID 槽（bubble-free 满吞吐）
// - 切断 ready 组合链：out_valid/out_data 完全寄存，in_ready 只组合依赖
//   寄存状态（out_valid_r, buf_valid_r）与下游 out_ready（深度 ≤1 级）；
// - 满吞吐无气泡：背压时 SKID 槽吸收输入，恢复后无额外空泡；
// - 保序：输出级腾出时槽数据优先（FIFO 顺序），新输入仅在槽空时直达。
// 契约：behavior.yaml INV-001..004；参数 DATA_W ∈ [1,1024]（wrapper 层 PC-001/002 拦截）
// ============================================================

module skid_buffer_full #(
    parameter int DATA_W = 32
) (
    input  logic              clk,
    input  logic              rst_n,
    // ---- 输入 valid-ready 握手 ----
    input  logic              in_valid,
    input  logic [DATA_W-1:0] in_data,
    output logic              in_ready,
    // ---- 输出 valid-ready 握手（寄存）----
    output logic              out_valid,
    output logic [DATA_W-1:0] out_data,
    input  logic              out_ready
);

    localparam int DW = DATA_W;

    // ------------------------------------------------------------------
    // 状态：OUT 寄存级 + SKID 槽
    // ------------------------------------------------------------------
    logic              out_valid_r;
    logic [DW-1:0]     out_data_r;
    logic              buf_valid_r;
    logic [DW-1:0]     buf_data_r;

    // in_ready：全满（out_valid && ~out_ready && buf_valid）才反压（INV-002）
    assign in_ready  = ~out_valid_r | out_ready | ~buf_valid_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid_r <= 1'b0;
            out_data_r  <= {DW{1'b0}};
            buf_valid_r <= 1'b0;
            buf_data_r  <= {DW{1'b0}};
        end else begin
            // ---- OUT 级 next：槽优先于输入直达（FIFO 保序）----
            // 输出级腾出（下游消费或为空）时：先补槽数据，槽空才直达输入，无来源则置空
            if (out_ready | ~out_valid_r) begin
                if (buf_valid_r) begin
                    out_valid_r <= 1'b1;
                    out_data_r  <= buf_data_r;
                end else if (in_valid) begin
                    out_valid_r <= 1'b1;
                    out_data_r  <= in_data;
                end else begin
                    out_valid_r <= 1'b0;
                end
            end
            // ---- SKID 槽 next：输入被接受时必须被捕获（直达或进槽）----
            if (in_valid & in_ready) begin
                if (out_ready | ~out_valid_r) begin
                    // 输出级腾出：槽（若有）补输出级，新输入替换槽数据（槽保持 valid）
                    if (buf_valid_r) buf_data_r <= in_data;
                    // else：槽空，输入直达输出级，槽仍空
                end else begin
                    // 输出级满且未腾出：输入进槽（槽必空，in_ready 保证）
                    buf_valid_r <= 1'b1;
                    buf_data_r  <= in_data;
                end
            end else if (out_ready | ~out_valid_r) begin
                // 无输入接受且输出级腾出：槽补输出级后清空
                if (buf_valid_r) buf_valid_r <= 1'b0;
            end
        end
    end

    // 输出级直接给到端口（寄存值）
    assign out_valid = out_valid_r;
    assign out_data  = out_data_r;

    // ------------------------------------------------------------------
    // SVA（就近放置，PROP ID 见 behavior.yaml / RTM）
    // ------------------------------------------------------------------
    // 全满反压（INV-002）——稳定 ID PROP-SKID_READY-001（label 用下划线，SV 标识符限制）
    property p_skid_ready_full;
        @(posedge clk) disable iff (~rst_n)
            (out_valid_r & ~out_ready & buf_valid_r) |-> ~in_ready;
    endproperty
    PROP_SKID_READY_001: assert property (p_skid_ready_full);

    // 输出级空 → 必可接受输入（INV-002）——稳定 ID PROP-SKID_READY-002
    property p_skid_ready_empty;
        @(posedge clk) disable iff (~rst_n)
            (~out_valid_r) |-> in_ready;
    endproperty
    PROP_SKID_READY_002: assert property (p_skid_ready_empty);

    // 满吞吐：输入被接受后下一拍必有输出，无气泡（INV-001）——稳定 ID PROP-SKID_ACCEPT-003
    property p_skid_accept;
        @(posedge clk) disable iff (~rst_n)
            (in_valid & in_ready) |-> ##1 out_valid;
    endproperty
    PROP_SKID_ACCEPT_003: assert property (p_skid_accept);

    // 空槽直达：空态输入直达输出级，数据一致（INV-003）——稳定 ID PROP-SKID_DATA-004
    // then 分支采样 in_data 用 $past(in_data,1)（否则取 ##1 沿的值，与前提沿错位）
    property p_skid_data_direct;
        @(posedge clk) disable iff (~rst_n)
            (in_valid & in_ready & ~out_valid_r & ~buf_valid_r) |-> ##1 (out_data === $past(in_data, 1));
    endproperty
    PROP_SKID_DATA_004: assert property (p_skid_data_direct);

endmodule
