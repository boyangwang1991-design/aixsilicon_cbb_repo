// ============================================================
// skid_buffer_backward — impl_backward（IMPL=2）
// backward registered slice：ready 路径寄存 + valid/data 组合透传
// - in_ready 由 FF（in_ready_r）驱动 → **切断反压组合链**（深流水反压路径时序改善）
// - valid/data 组合透传（out_valid=in_valid、out_data=in_data，0 数据延迟）
// - 反压 1 拍延迟传导（~out_ready && in_valid |-> ##1 ~in_ready）
// - 无缓冲槽：背压恢复有 1 拍气泡；保序无丢（in_ready=0 时输入不被采样）
// 契约：behavior.yaml INV-007；参数 DATA_W ∈ [1,1024]（wrapper 层 PC-001/002 拦截）
// ============================================================

module skid_buffer_backward #(
    parameter int DATA_W = 32
) (
    input  logic              clk,
    input  logic              rst_n,
    // ---- 输入 valid-ready 握手 ----
    input  logic              in_valid,
    input  logic [DATA_W-1:0] in_data,
    output logic              in_ready,
    // ---- 输出 valid-ready 握手（透传）----
    output logic              out_valid,
    output logic [DATA_W-1:0] out_data,
    input  logic              out_ready
);

    localparam int DW = DATA_W;

    // in_ready 寄存（FF 输出，切断反压组合链；INV-007）
    logic in_ready_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_ready_r <= 1'b1;                 // 复位后 ready
        end else begin
            in_ready_r <= out_ready | ~in_valid; // 下游可接受 或 输入无效 → 下一拍 ready
        end
    end

    // 输出
    assign in_ready  = in_ready_r;
    assign out_valid = in_valid;                 // 组合透传（0 数据延迟）
    assign out_data  = in_data;

    // ------------------------------------------------------------------
    // SVA（就近放置，PROP ID 见 behavior.yaml / RTM）
    // ------------------------------------------------------------------
    // 反压 1 拍传导（INV-007）——稳定 ID PROP-BWD_READY-001
    property p_bwd_ready;
        @(posedge clk) disable iff (~rst_n)
            (~out_ready & in_valid) |-> ##1 ~in_ready;
    endproperty
    PROP_BWD_READY_001: assert property (p_bwd_ready);

    // 透传：接受时同拍输出 valid（INV-007）——稳定 ID PROP-BWD_ACCEPT-002
    property p_bwd_accept;
        @(posedge clk) disable iff (~rst_n)
            (in_valid & in_ready) |-> out_valid;
    endproperty
    PROP_BWD_ACCEPT_002: assert property (p_bwd_accept);

    // 透传数据一致（INV-007）——稳定 ID PROP-BWD_DATA-003
    property p_bwd_data;
        @(posedge clk) disable iff (~rst_n)
            (in_valid & in_ready) |-> (out_data === in_data);
    endproperty
    PROP_BWD_DATA_003: assert property (p_bwd_data);

endmodule
