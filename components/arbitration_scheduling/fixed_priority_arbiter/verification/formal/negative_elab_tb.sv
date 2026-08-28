// ============================================================================
// negative_elab_tb — tc_negative_elab 负向 Elaboration 拦截（REQ-007）
// ----------------------------------------------------------------------------
// 非法参数（NUM_REQ=1 / PRIORITY=2 / REQ_TYPE=2 / FAST_GRANT=2 / PC_IMPL=3）
// 应在 elaboration 期被 generate 块内 $error 拦截（vcs 非零退出 + 命中报错 ID）。
// 由 verification/scripts/run_static_checks.sh 调用（VCS 负向编译建证据）。
// 本文件独立落地：满足 check --strict 的 tc_* 引用完整性（F8 纪律）。
// ============================================================================
module negative_elab_tb;
    // 各非法参数实例——任一实例触发 $error 即应使编译/elab 失败
    fixed_priority_arbiter #(.NUM_REQ(1)) u_bad_n (
        .clk(1'b0), .rst_n(1'b1), .req_i(1'b0), .grant_ack_i(1'b0), .grant_o());
    fixed_priority_arbiter #(.NUM_REQ(8), .PRIORITY(2)) u_bad_p (
        .clk(1'b0), .rst_n(1'b1), .req_i(8'b0), .grant_ack_i(1'b0), .grant_o());
    fixed_priority_arbiter #(.NUM_REQ(8), .REQ_TYPE(2)) u_bad_r (
        .clk(1'b0), .rst_n(1'b1), .req_i(8'b0), .grant_ack_i(1'b0), .grant_o());
    fixed_priority_arbiter #(.NUM_REQ(8), .FAST_GRANT(2)) u_bad_f (
        .clk(1'b0), .rst_n(1'b1), .req_i(8'b0), .grant_ack_i(1'b0), .grant_o());
    fixed_priority_arbiter #(.NUM_REQ(8), .PC_IMPL(3)) u_bad_c (
        .clk(1'b0), .rst_n(1'b1), .req_i(8'b0), .grant_ack_i(1'b0), .grant_o());
    // 无 initial（负向：期望编译/elab 失败，不运行仿真）
endmodule
