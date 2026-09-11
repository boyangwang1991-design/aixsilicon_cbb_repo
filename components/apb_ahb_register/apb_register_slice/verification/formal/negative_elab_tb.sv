// ============================================================================
// negative_elab_tb — tc_negative_elab 负向 Elaboration 拦截（REQ-007）
// ----------------------------------------------------------------------------
// 非法参数（ADDR_WIDTH=7/33、DATA_WIDTH=7/65、SLICE_MODE=3、RESP_STAGES=0/3）
// 应在 elaboration 期被 generate 块内 $error 拦截（vcs 非零退出 + 命中报错 ID）。
// 由 verification/scripts/run_static_checks.sh 调用（VCS 负向编译建证据）。
// 本文件独立落地：满足 check --strict 的 tc_* 引用完整性（F8 纪律）。
// ============================================================================
module negative_elab_tb;
    // 各非法参数实例——任一实例触发 $error 即应使编译/elab 失败
    apb_register_slice #(.ADDR_WIDTH(7)) u_bad_aw_lo (
        .clk(1'b0), .rst_n(1'b1),
        .psel_main(1'b0), .penable_main(1'b0), .paddr_main('0), .pprot_main('0),
        .pwrite_main(1'b0), .pwdata_main('0), .pstrb_main('0),
        .pready_main(), .prdata_main(), .pslverr_main(),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(1'b0), .prdata_sub('0), .pslverr_sub(1'b0));
    apb_register_slice #(.ADDR_WIDTH(33)) u_bad_aw_hi (
        .clk(1'b0), .rst_n(1'b1),
        .psel_main(1'b0), .penable_main(1'b0), .paddr_main('0), .pprot_main('0),
        .pwrite_main(1'b0), .pwdata_main('0), .pstrb_main('0),
        .pready_main(), .prdata_main(), .pslverr_main(),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(1'b0), .prdata_sub('0), .pslverr_sub(1'b0));
    apb_register_slice #(.DATA_WIDTH(7)) u_bad_dw_lo (
        .clk(1'b0), .rst_n(1'b1),
        .psel_main(1'b0), .penable_main(1'b0), .paddr_main('0), .pprot_main('0),
        .pwrite_main(1'b0), .pwdata_main('0), .pstrb_main('0),
        .pready_main(), .prdata_main(), .pslverr_main(),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(1'b0), .prdata_sub('0), .pslverr_sub(1'b0));
    apb_register_slice #(.DATA_WIDTH(65)) u_bad_dw_hi (
        .clk(1'b0), .rst_n(1'b1),
        .psel_main(1'b0), .penable_main(1'b0), .paddr_main('0), .pprot_main('0),
        .pwrite_main(1'b0), .pwdata_main('0), .pstrb_main('0),
        .pready_main(), .prdata_main(), .pslverr_main(),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(1'b0), .prdata_sub('0), .pslverr_sub(1'b0));
    apb_register_slice #(.SLICE_MODE(3)) u_bad_mode (
        .clk(1'b0), .rst_n(1'b1),
        .psel_main(1'b0), .penable_main(1'b0), .paddr_main('0), .pprot_main('0),
        .pwrite_main(1'b0), .pwdata_main('0), .pstrb_main('0),
        .pready_main(), .prdata_main(), .pslverr_main(),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(1'b0), .prdata_sub('0), .pslverr_sub(1'b0));
    apb_register_slice #(.RESP_STAGES(0)) u_bad_rs_lo (
        .clk(1'b0), .rst_n(1'b1),
        .psel_main(1'b0), .penable_main(1'b0), .paddr_main('0), .pprot_main('0),
        .pwrite_main(1'b0), .pwdata_main('0), .pstrb_main('0),
        .pready_main(), .prdata_main(), .pslverr_main(),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(1'b0), .prdata_sub('0), .pslverr_sub(1'b0));
    apb_register_slice #(.RESP_STAGES(3)) u_bad_rs_hi (
        .clk(1'b0), .rst_n(1'b1),
        .psel_main(1'b0), .penable_main(1'b0), .paddr_main('0), .pprot_main('0),
        .pwrite_main(1'b0), .pwdata_main('0), .pstrb_main('0),
        .pready_main(), .prdata_main(), .pslverr_main(),
        .psel_sub(), .penable_sub(), .paddr_sub(), .pprot_sub(),
        .pwrite_sub(), .pwdata_sub(), .pstrb_sub(),
        .pready_sub(1'b0), .prdata_sub('0), .pslverr_sub(1'b0));
    // 无 initial（负向：期望编译/elab 失败，不运行仿真）
endmodule
