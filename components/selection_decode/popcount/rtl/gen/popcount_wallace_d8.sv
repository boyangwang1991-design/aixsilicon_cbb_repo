// ============================================================================
// popcount_wallace_d8 — popcount Wallace tree（3:2 FA + 2:1 HA 归约） (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[7:0]，输出: popcnt[3:0]（NBITS=clog2(8+1)，结果 0..8）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 4 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 8
// ============================================================================

module popcount_wallace_d8 (
    input  logic [7:0] din,
    output logic [3:0] popcnt
);

    // ---- 中间信号 ----------------
    logic wf_s1_0, wf_c1_0, wf_s1_1, wf_c1_1;
    logic wh_s1_0, wh_c1_0, wf_s2_2, wf_c2_2;
    logic wf_s2_3, wf_c2_3;

    // ---- 归约 / 收尾 ----------------

    assign wf_s1_0 = (din[0] ^ din[1] ^ din[2]); // FA sum  w=0
    assign wf_c1_0 = ((din[0] & din[1]) | (din[0] & din[2]) | (din[1] & din[2])); // FA carry w=1
    assign wf_s1_1 = (din[3] ^ din[4] ^ din[5]); // FA sum  w=0
    assign wf_c1_1 = ((din[3] & din[4]) | (din[3] & din[5]) | (din[4] & din[5])); // FA carry w=1
    assign wh_s1_0 = (din[6] ^ din[7]); // HA sum  w=0
    assign wh_c1_0 = (din[6] & din[7]); // HA carry w=1
    assign wf_s2_2 = (wf_s1_0 ^ wf_s1_1 ^ wh_s1_0); // FA sum  w=0
    assign wf_c2_2 = ((wf_s1_0 & wf_s1_1) | (wf_s1_0 & wh_s1_0) | (wf_s1_1 & wh_s1_0)); // FA carry w=1
    assign wf_s2_3 = (wf_c1_0 ^ wf_c1_1 ^ wh_c1_0); // FA sum  w=1
    assign wf_c2_3 = ((wf_c1_0 & wf_c1_1) | (wf_c1_0 & wh_c1_0) | (wf_c1_1 & wh_c1_0)); // FA carry w=2

    assign wf_rs0 = (wf_s2_2 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign wf_rc0 = ((wf_s2_2 & 1'b0) | (1'b0 & (wf_s2_2 ^ 1'b0))); // final carry bit0
    assign wf_rs1 = (wf_c2_2 ^ wf_s2_3 ^ wf_rc0); // final sum  bit1
    assign wf_rc1 = ((wf_c2_2 & wf_s2_3) | (wf_rc0 & (wf_c2_2 ^ wf_s2_3))); // final carry bit1
    assign wf_rs2 = (wf_c2_3 ^ 1'b0 ^ wf_rc1); // final sum  bit2
    assign wf_rc2 = ((wf_c2_3 & 1'b0) | (wf_rc1 & (wf_c2_3 ^ 1'b0))); // final carry bit2
    assign wf_rs3 = (1'b0 ^ 1'b0 ^ wf_rc2); // final sum  bit3
    assign wf_rc3 = ((1'b0 & 1'b0) | (wf_rc2 & (1'b0 ^ 1'b0))); // final carry bit3

    assign popcnt[0] = wf_rs0;
    assign popcnt[1] = wf_rs1;
    assign popcnt[2] = wf_rs2;
    assign popcnt[3] = wf_rs3;

endmodule
