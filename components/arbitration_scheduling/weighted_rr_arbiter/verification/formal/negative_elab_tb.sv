// ============================================================================
// negative_elab_tb — 负向 Elaboration 测试台（tc_negative_elab，REQ-008）
// 目标：非法参数组合必须在 Elaboration 期被 generate $error 拦截（vcs 非零退出）
//   - NUM_REQ=1（PC-001：仲裁至少 2 路）
//   - NUM_REQ=65（PC-002：超 64 路上界）
//   - WEIGHT_WIDTH=1（PC-003：权重至少 2 位）
//   - WEIGHT_WIDTH=17（PC-004：权重超 16 位上界）
//   命中任一 PC ID 即认为负向测试通过（elab 期拦截）。
// 注意：本文件不做任何功能，仅作编译/elaboration 负向证据。
// ============================================================================
module negative_elab_tb;

    localparam int WW = 17;                     // 触发 PC-004（>16）
    localparam int WWV = 1;                     // 触发 PC-003（<2）
    localparam int NR_LO = 1;                   // 触发 PC-001（<2）
    localparam int NR_HI = 65;                  // 触发 PC-002（>64）

    logic clk = 0;
    logic rst_n = 1'b1;

    // 非法组合 1：NUM_REQ=1（PC-001）
    weighted_rr_arbiter #(
        .NUM_REQ      (NR_LO),
        .WEIGHT_WIDTH (4),
        .WMODE        (0),
        .FAST_GRANT   (0),
        .GRANT_ACK_EN (0),
        .PC_IMPL      (0)
    ) u_bad_n (
        .clk(clk), .rst_n(rst_n),
        .req_i('0), .weight_i('0), .grant_ack_i(1'b0), .grant_o()
    );

    // 非法组合 2：WEIGHT_WIDTH=1（PC-003）
    weighted_rr_arbiter #(
        .NUM_REQ      (8),
        .WEIGHT_WIDTH (WWV),
        .WMODE        (0),
        .FAST_GRANT   (0),
        .GRANT_ACK_EN (0),
        .PC_IMPL      (0)
    ) u_bad_ww (
        .clk(clk), .rst_n(rst_n),
        .req_i('0), .weight_i('0), .grant_ack_i(1'b0), .grant_o()
    );

    // 非法组合 3：WEIGHT_WIDTH=17（PC-004）
    weighted_rr_arbiter #(
        .NUM_REQ      (8),
        .WEIGHT_WIDTH (WW),
        .WMODE        (0),
        .FAST_GRANT   (0),
        .GRANT_ACK_EN (0),
        .PC_IMPL      (0)
    ) u_bad_wwh (
        .clk(clk), .rst_n(rst_n),
        .req_i('0), .weight_i('0), .grant_ack_i(1'b0), .grant_o()
    );

    // 非法组合 4：NUM_REQ=65（PC-002）
    weighted_rr_arbiter #(
        .NUM_REQ      (NR_HI),
        .WEIGHT_WIDTH (4),
        .WMODE        (0),
        .FAST_GRANT   (0),
        .GRANT_ACK_EN (0),
        .PC_IMPL      (0)
    ) u_bad_nh (
        .clk(clk), .rst_n(rst_n),
        .req_i('0), .weight_i('0), .grant_ack_i(1'b0), .grant_o()
    );

    // 运行少量拍（负向验证只看 compile/elab，不关心功能）
    initial begin
        #1000;
        $finish;
    end
endmodule
