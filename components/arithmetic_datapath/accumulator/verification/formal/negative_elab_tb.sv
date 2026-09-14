// ============================================================================
// negative_elab_tb.sv — 负向参数 elaboration $error 拦截（REQ-006 / tc_negative_elab）
// 通过 `ifdef NEG_<CASE> 注入非法参数，expect elaboration 阶段 $error（PC-xxx）：
//   NEG_IW0      INPUT_WIDTH=0        (PC-001)
//   NEG_IW129    INPUT_WIDTH=129      (PC-007)
//   NEG_AW0      ACC_WIDTH=0          (PC-003)
//   NEG_AW257    ACC_WIDTH=257        (PC-008)
//   NEG_IWGT     INPUT_WIDTH=32>ACC_WIDTH=16 (PC-002)
//   NEG_OP3      OP_MODE=3            (PC-004)
//   NEG_OVF2     OVERFLOW_MODE=2      (PC-005)
//   NEG_ISO2     OPERAND_ISOLATION=2  (PC-006)
// 每个 case 仅激活一个 define（脚本保证）；非法值在 elaboration 触发 $error。
// ============================================================================
`timescale 1ns/1ps

module negative_elab_tb;
    logic clk_i, rst_ni;
    logic ce_i, clear_i, load_i, valid_i, sub_i, status_clear_i;
    logic [255:0] load_data_i, data_i;
    logic [255:0] acc_o;
    logic update_o, overflow_event_o, overflow_sticky_o;

    localparam int T_IW =
        `ifdef NEG_IW0
            0
        `elsif NEG_IW129
            129
        `elsif NEG_IWGT
            32
        `else
            16
        `endif;
    localparam int T_AW =
        `ifdef NEG_AW0
            0
        `elsif NEG_AW257
            257
        `elsif NEG_IWGT
            16
        `else
            32
        `endif;
    localparam int T_OP  = `ifdef NEG_OP3  3 `else 0 `endif;
    localparam int T_OVF = `ifdef NEG_OVF2 2 `else 0 `endif;
    localparam int T_ISO = `ifdef NEG_ISO2 2 `else 0 `endif;

    accumulator #(
        .INPUT_WIDTH(T_IW), .ACC_WIDTH(T_AW), .SIGNED(1'b1),
        .OP_MODE(T_OP), .OVERFLOW_MODE(T_OVF),
        .LOAD_EN(1'b1), .STATUS_EN(1'b1), .OPERAND_ISOLATION(T_ISO)
    ) dut (
        .clk_i, .rst_ni, .ce_i, .clear_i, .load_i, .load_data_i,
        .valid_i, .data_i, .sub_i, .status_clear_i,
        .acc_o, .update_o, .overflow_event_o, .overflow_sticky_o
    );

    initial begin
        clk_i = 0; rst_ni = 0; ce_i = 0; clear_i = 0; load_i = 0;
        valid_i = 0; sub_i = 0; status_clear_i = 0; load_data_i = 0; data_i = 0;
        #10;
        // 若非法参数未被 $error 拦截而进入仿真，则失败（负向期望 elaboration 阶段退出）
        $display("[NEG] FAIL: illegal parameter did NOT abort elaboration");
        $finish;
    end
endmodule
