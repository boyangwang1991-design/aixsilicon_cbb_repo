// ============================================================
// skid_buffer —— Valid-Ready 打拍模块（QUE-007, A3）多实现 wrapper
// 参数化分派：
//   BYPASS=1  ：组合零延迟直通（out=in、in_ready=out_ready，忽略 IMPL）
//   IMPL=0    ：skid_buffer_forward（简单打拍，ready 组合透传，面积最小）
//   IMPL=1    ：skid_buffer_full（OUT 寄存 + SKID 槽，满吞吐无气泡，默认）
// 参数检查：DATA_W/IMPL/BYPASS 越界在 generate 块 $error（elaboration 期拦截，PC-001..004）
// 极简单文件：无 package/interface；子实现独立文件（rtl/impl/<impl>/，各自极简单）
// ============================================================

module skid_buffer #(
    parameter int DATA_W = 32,   // 数据位宽（PC-001: >=1; PC-002: <=1024）
    parameter int IMPL   = 1,    // 微架构（PC-003: 0=forward / 1=full）
    parameter int BYPASS = 0     // 直通（PC-004: 0=打拍 / 1=组合直通）
) (
    input  logic              clk,
    input  logic              rst_n,
    // ---- 输入 valid-ready 握手 ----
    input  logic              in_valid,
    input  logic [DATA_W-1:0] in_data,
    output logic              in_ready,
    // ---- 输出 valid-ready 握手 ----
    output logic              out_valid,
    output logic [DATA_W-1:0] out_data,
    input  logic              out_ready
);

    localparam int DW = DATA_W;

    // ------------------------------------------------------------------
    // 参数检查（generate 块内 $error，elaboration 期拦截；PC-001..004）
    // ------------------------------------------------------------------
    generate
        if (DATA_W < 1 || DATA_W > 1024) begin : g_bad_data_w
            $error("skid_buffer: DATA_W=%0d 越界 [1,1024] (PC-001/PC-002)", DATA_W);
        end
        if (IMPL < 0 || IMPL > 1) begin : g_bad_impl
            $error("skid_buffer: IMPL=%0d 越界 {0,1} (PC-003)", IMPL);
        end
        if (BYPASS < 0 || BYPASS > 1) begin : g_bad_bypass
            $error("skid_buffer: BYPASS=%0d 越界 {0,1} (PC-004)", BYPASS);
        end
    endgenerate

    // ------------------------------------------------------------------
    // 分派：BYPASS 直通 > IMPL 微架构
    // ------------------------------------------------------------------
    generate
        if (BYPASS) begin : g_bypass
            // 组合零延迟直通（INV-006）
            assign in_ready  = out_ready;
            assign out_valid = in_valid;
            assign out_data  = in_data;
        end else if (IMPL == 0) begin : g_fwd
            skid_buffer_forward #(.DATA_W(DW)) u_fwd (
                .clk       (clk),
                .rst_n     (rst_n),
                .in_valid  (in_valid),
                .in_data   (in_data),
                .in_ready  (in_ready),
                .out_valid (out_valid),
                .out_data  (out_data),
                .out_ready (out_ready)
            );
        end else begin : g_full
            skid_buffer_full #(.DATA_W(DW)) u_full (
                .clk       (clk),
                .rst_n     (rst_n),
                .in_valid  (in_valid),
                .in_data   (in_data),
                .in_ready  (in_ready),
                .out_valid (out_valid),
                .out_data  (out_data),
                .out_ready (out_ready)
            );
        end
    endgenerate

    // ------------------------------------------------------------------
    // SVA：BYPASS 直通属性（INV-006，仅 BYPASS=1 生效）——稳定 ID PROP-BYP_DIRECT-001
    // 组合直通：out_valid==in_valid、out_data==in_data、in_ready==out_ready（同拍）
    // ------------------------------------------------------------------
    property p_byp_direct;
        @(posedge clk) disable iff (~rst_n)
            (BYPASS) |-> (in_valid === out_valid) && (in_data === out_data) && (in_ready === out_ready);
    endproperty
    PROP_BYP_DIRECT_001: assert property (p_byp_direct);

endmodule
