// ============================================================
// skid_buffer_forward — impl_forward（IMPL=0）
// forward register slice：data/valid 打拍 1 拍，ready 组合透传
// - 面积最小（DATA_W+1 FF，无 SKID 槽、无 mux）
// - in_ready == out_ready（反压直接传导上游，深流水反压链长——Pareto 权衡）
// - 无丢无重：out_ready=0 时 in_ready=0，输入不被采样
// 契约：behavior.yaml INV-005；参数 DATA_W ∈ [1,1024]（wrapper 层 PC-001/002 拦截）
// ============================================================

module skid_buffer_forward #(
    parameter int DATA_W = 32
) (
    input  logic              clk,
    input  logic              rst_n,
    // ---- 输入 valid-ready 握手 ----
    input  logic              in_valid,
    input  logic [DATA_W-1:0] in_data,
    output logic              in_ready,
    // ---- 输出 valid-ready 握手（寄存打拍）----
    output logic              out_valid,
    output logic [DATA_W-1:0] out_data,
    input  logic              out_ready
);

    localparam int DW = DATA_W;

    logic              out_valid_r;
    logic [DW-1:0]     out_data_r;

    // 打拍（每拍无条件：沿 t 捕获 in_valid/in_data，沿 t+1 输出）
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid_r <= 1'b0;
            out_data_r  <= {DW{1'b0}};
        end else begin
            out_valid_r <= in_valid;
            out_data_r  <= in_data;
        end
    end

    // ready 组合透传（INV-005）
    assign in_ready  = out_ready;
    assign out_valid = out_valid_r;
    assign out_data  = out_data_r;

    // ------------------------------------------------------------------
    // SVA（就近放置，PROP ID 见 behavior.yaml / RTM）
    // ------------------------------------------------------------------
    // 接受后下一拍输出有效（INV-005）——稳定 ID PROP-FWD_ACCEPT-001
    property p_fwd_accept;
        @(posedge clk) disable iff (~rst_n)
            (in_valid & in_ready) |-> ##1 out_valid;
    endproperty
    PROP_FWD_ACCEPT_001: assert property (p_fwd_accept);

    // 打拍数据一致：接受后下一拍 out_data 为沿 t 的 in_data（INV-003/005）
    //   ——稳定 ID PROP-FWD_DATA-002
    property p_fwd_data;
        @(posedge clk) disable iff (~rst_n)
            (in_valid & in_ready) |-> ##1 (out_data === $past(in_data, 1));
    endproperty
    PROP_FWD_DATA_002: assert property (p_fwd_data);

endmodule
