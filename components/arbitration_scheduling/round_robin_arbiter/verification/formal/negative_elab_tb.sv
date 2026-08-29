// ============================================================================
// negative_elab_tb — G3 负向参数 Elaboration 拦截（tc_negative_elab，REQ-008）
// 各 DUT 用非法参数实例化，期望 VCS elaboration 阶段 generate 内 $error 触发
// 非零退出；脚本 run_static_checks.sh 校验非零 + 命中报错 ID。
// ============================================================================
`timescale 1ns/1ps

module negative_elab_tb;
    logic clk, rst_n, ack;
    logic [63:0] req;
    wire [63:0] g;

    // NUM_REQ=1（PC-001 越界下界）
    round_robin_arbiter #(.NUM_REQ(1), .REQ_TYPE(0), .FAST_GRANT(0), .PC_IMPL(0), .GRANT_ACK_EN(0))
        dut_n1 (.clk(clk), .rst_n(rst_n), .req_i(req[0:0]), .grant_ack_i(ack), .grant_o(g[0:0]));
    // NUM_REQ=65（PC-002 越界上界）
    round_robin_arbiter #(.NUM_REQ(65), .REQ_TYPE(0), .FAST_GRANT(0), .PC_IMPL(0), .GRANT_ACK_EN(0))
        dut_n65 (.clk(clk), .rst_n(rst_n), .req_i(req[64:0]), .grant_ack_i(ack), .grant_o(g[64:0]));
    // REQ_TYPE=2（PC-003）
    round_robin_arbiter #(.NUM_REQ(4), .REQ_TYPE(2), .FAST_GRANT(0), .PC_IMPL(0), .GRANT_ACK_EN(0))
        dut_rt2 (.clk(clk), .rst_n(rst_n), .req_i(req[3:0]), .grant_ack_i(ack), .grant_o(g[3:0]));
    // FAST_GRANT=2（PC-004）
    round_robin_arbiter #(.NUM_REQ(4), .REQ_TYPE(0), .FAST_GRANT(2), .PC_IMPL(0), .GRANT_ACK_EN(0))
        dut_fg2 (.clk(clk), .rst_n(rst_n), .req_i(req[3:0]), .grant_ack_i(ack), .grant_o(g[3:0]));
    // PC_IMPL=3（PC-005）
    round_robin_arbiter #(.NUM_REQ(4), .REQ_TYPE(0), .FAST_GRANT(0), .PC_IMPL(3), .GRANT_ACK_EN(0))
        dut_impl3 (.clk(clk), .rst_n(rst_n), .req_i(req[3:0]), .grant_ack_i(ack), .grant_o(g[3:0]));
    // GRANT_ACK_EN=2（PC-006）
    round_robin_arbiter #(.NUM_REQ(4), .REQ_TYPE(0), .FAST_GRANT(0), .PC_IMPL(0), .GRANT_ACK_EN(2))
        dut_ack2 (.clk(clk), .rst_n(rst_n), .req_i(req[3:0]), .grant_ack_i(ack), .grant_o(g[3:0]));

    initial begin
        clk = 0; rst_n = 0; ack = 0; req = '0;
        #1000 $finish;
    end
    always #5 clk = ~clk;
endmodule
