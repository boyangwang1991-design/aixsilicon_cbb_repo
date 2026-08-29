// ============================================================================
// negative_elab_tb — 非法参数 elaboration 拦截验证 (tc_negative_elab, REQ-005)
// 本 TB 顶层直接以非法参数实例化 DUT，期望在 elaboration 期触发 $error
// （PC-001/002/003/004），vcs 编译/elab 返回非零退出码 + 命中报错 ID。
// 由 verification/scripts/run_static_checks.sh 以 vcs -top negative_elab_tb 调用。
// 注意：合法参数也会被 $error 阻断的模块不能放同一顶层；故本 TB 仅含非法实例。
// ============================================================================
`timescale 1ns/1ps

module negative_elab_tb;
    logic [2047:0] din;
    logic          inc_en, dec_en;
    wire [1023:0]  dout;
    wire           carry_out;

    // 非法：DATA_W 越界（PC-001: <2 / PC-002: >1024）
    incrementer_decrementer #(.DATA_W(1),   .ID_IMPL(0)) u_bad_w1   (.din(din[0:0]),     .inc_en(inc_en), .dec_en(dec_en), .dout(dout[0:0]),     .carry_out(carry_out));
    incrementer_decrementer #(.DATA_W(1025),.ID_IMPL(0)) u_bad_w1025 (.din(din[1024:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(dout[1024:0]), .carry_out(carry_out));

    // 非法：ID_IMPL 越界（PC-003: {0,1}）
    incrementer_decrementer #(.DATA_W(8), .ID_IMPL(2)) u_bad_impl (.din(din[7:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(dout[7:0]), .carry_out(carry_out));

    // 非法：SEG_W 越界（PC-004: [2,16]）
    incrementer_decrementer #(.DATA_W(32), .ID_IMPL(1), .SEG_W(1))  u_bad_seg1  (.din(din[31:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(dout[31:0]), .carry_out(carry_out));
    incrementer_decrementer #(.DATA_W(32), .ID_IMPL(1), .SEG_W(17)) u_bad_seg17 (.din(din[31:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(dout[31:0]), .carry_out(carry_out));

    // 非法：CG_EN 越界（PC-005: {0,1}）
    incrementer_decrementer #(.DATA_W(32), .ID_IMPL(0), .CG_EN(2)) u_bad_cg (.din(din[31:0]), .inc_en(inc_en), .dec_en(dec_en), .dout(dout[31:0]), .carry_out(carry_out));

    initial begin
        $display("negative_elab_tb: illegal parameter instances instantiated; expecting $error at elaboration");
        $finish;
    end
endmodule
