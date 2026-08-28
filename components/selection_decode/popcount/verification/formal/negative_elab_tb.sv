// ============================================================================
// negative_elab_tb — 非法参数 elaboration 拦截验证 (tc_negative_elab, REQ-005)
// 本 TB 顶层即为 DUT：以非法参数实例化 popcount，期望在 elaboration 期触发
// $error（PC-001/002/003/004），vcs 编译/elab 返回非零退出码。
// 由 verification/scripts/run_static_checks.sh 以 vcs -top negative_elab_tb 调用。
// 注意：合法参数也会被 $error 阻断的模块不能放同一顶层；故本 TB 仅含非法实例。
// ============================================================================
`timescale 1ns/1ps

module negative_elab_tb;
    logic [2047:0] din;
    wire [10:0] cnt;

    // 非法：DATA_W 越界（PC-001: <2 / PC-002: >1024）
    popcount #(.DATA_W(1),  .PC_IMPL(1)) u_bad_w1  (.din(din[0:0]),    .popcnt(cnt[0:0]));
    popcount #(.DATA_W(1025),.PC_IMPL(1)) u_bad_w1025 (.din(din[1024:0]),.popcnt(cnt[10:0]));

    // 非法：PC_IMPL 越界（PC-003: {0..4}）
    popcount #(.DATA_W(8), .PC_IMPL(5)) u_bad_impl (.din(din[7:0]), .popcnt(cnt[3:0]));

    // 非法：PC_IMPL=WALLACE/COMP4_2 但 DATA_W 非 {8,16,32,64}（PC-004）
    popcount #(.DATA_W(12), .PC_IMPL(2)) u_bad_wallace12 (.din(din[11:0]), .popcnt(cnt[3:0]));
    popcount #(.DATA_W(20), .PC_IMPL(3)) u_bad_comp20    (.din(din[19:0]), .popcnt(cnt[4:0]));

    initial begin
        $display("negative_elab_tb: illegal parameter instances instantiated; expecting $error at elaboration");
        $finish;
    end
endmodule
