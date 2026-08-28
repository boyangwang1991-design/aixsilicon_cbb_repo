// ============================================================================
// popcount_wallace_d16 — popcount Wallace tree（3:2 FA + 2:1 HA 归约） (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[15:0]，输出: popcnt[4:0]（NBITS=clog2(16+1)，结果 0..16）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 5 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 16
// ============================================================================

module popcount_wallace_d16 (
    input  logic [15:0] din,
    output logic [4:0] popcnt
);

    // ---- 中间信号 ----------------
    logic wf_s1_0, wf_c1_0, wf_s1_1, wf_c1_1;
    logic wf_s1_2, wf_c1_2, wf_s1_3, wf_c1_3;
    logic wf_s1_4, wf_c1_4, wf_s2_5, wf_c2_5;
    logic wf_s2_6, wf_c2_6, wf_s2_7, wf_c2_7;
    logic wh_s2_0, wh_c2_0, wh_s3_1, wh_c3_1;
    logic wf_s3_8, wf_c3_8, wh_s3_2, wh_c3_2;
    logic wf_s4_9, wf_c4_9, wh_s4_3, wh_c4_3;

    // ---- 归约 / 收尾 ----------------

    assign wf_s1_0 = (din[0] ^ din[1] ^ din[2]); // FA sum  w=0
    assign wf_c1_0 = ((din[0] & din[1]) | (din[0] & din[2]) | (din[1] & din[2])); // FA carry w=1
    assign wf_s1_1 = (din[3] ^ din[4] ^ din[5]); // FA sum  w=0
    assign wf_c1_1 = ((din[3] & din[4]) | (din[3] & din[5]) | (din[4] & din[5])); // FA carry w=1
    assign wf_s1_2 = (din[6] ^ din[7] ^ din[8]); // FA sum  w=0
    assign wf_c1_2 = ((din[6] & din[7]) | (din[6] & din[8]) | (din[7] & din[8])); // FA carry w=1
    assign wf_s1_3 = (din[9] ^ din[10] ^ din[11]); // FA sum  w=0
    assign wf_c1_3 = ((din[9] & din[10]) | (din[9] & din[11]) | (din[10] & din[11])); // FA carry w=1
    assign wf_s1_4 = (din[12] ^ din[13] ^ din[14]); // FA sum  w=0
    assign wf_c1_4 = ((din[12] & din[13]) | (din[12] & din[14]) | (din[13] & din[14])); // FA carry w=1
    assign wf_s2_5 = (wf_s1_0 ^ wf_s1_1 ^ wf_s1_2); // FA sum  w=0
    assign wf_c2_5 = ((wf_s1_0 & wf_s1_1) | (wf_s1_0 & wf_s1_2) | (wf_s1_1 & wf_s1_2)); // FA carry w=1
    assign wf_s2_6 = (wf_s1_3 ^ wf_s1_4 ^ din[15]); // FA sum  w=0
    assign wf_c2_6 = ((wf_s1_3 & wf_s1_4) | (wf_s1_3 & din[15]) | (wf_s1_4 & din[15])); // FA carry w=1
    assign wf_s2_7 = (wf_c1_0 ^ wf_c1_1 ^ wf_c1_2); // FA sum  w=1
    assign wf_c2_7 = ((wf_c1_0 & wf_c1_1) | (wf_c1_0 & wf_c1_2) | (wf_c1_1 & wf_c1_2)); // FA carry w=2
    assign wh_s2_0 = (wf_c1_3 ^ wf_c1_4); // HA sum  w=1
    assign wh_c2_0 = (wf_c1_3 & wf_c1_4); // HA carry w=2
    assign wh_s3_1 = (wf_s2_5 ^ wf_s2_6); // HA sum  w=0
    assign wh_c3_1 = (wf_s2_5 & wf_s2_6); // HA carry w=1
    assign wf_s3_8 = (wf_c2_5 ^ wf_c2_6 ^ wf_s2_7); // FA sum  w=1
    assign wf_c3_8 = ((wf_c2_5 & wf_c2_6) | (wf_c2_5 & wf_s2_7) | (wf_c2_6 & wf_s2_7)); // FA carry w=2
    assign wh_s3_2 = (wf_c2_7 ^ wh_c2_0); // HA sum  w=2
    assign wh_c3_2 = (wf_c2_7 & wh_c2_0); // HA carry w=3
    assign wf_s4_9 = (wh_c3_1 ^ wf_s3_8 ^ wh_s2_0); // FA sum  w=1
    assign wf_c4_9 = ((wh_c3_1 & wf_s3_8) | (wh_c3_1 & wh_s2_0) | (wf_s3_8 & wh_s2_0)); // FA carry w=2
    assign wh_s4_3 = (wf_c3_8 ^ wh_s3_2); // HA sum  w=2
    assign wh_c4_3 = (wf_c3_8 & wh_s3_2); // HA carry w=3

    assign wf_rs0 = (wh_s3_1 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign wf_rc0 = ((wh_s3_1 & 1'b0) | (1'b0 & (wh_s3_1 ^ 1'b0))); // final carry bit0
    assign wf_rs1 = (wf_s4_9 ^ 1'b0 ^ wf_rc0); // final sum  bit1
    assign wf_rc1 = ((wf_s4_9 & 1'b0) | (wf_rc0 & (wf_s4_9 ^ 1'b0))); // final carry bit1
    assign wf_rs2 = (wf_c4_9 ^ wh_s4_3 ^ wf_rc1); // final sum  bit2
    assign wf_rc2 = ((wf_c4_9 & wh_s4_3) | (wf_rc1 & (wf_c4_9 ^ wh_s4_3))); // final carry bit2
    assign wf_rs3 = (wh_c4_3 ^ wh_c3_2 ^ wf_rc2); // final sum  bit3
    assign wf_rc3 = ((wh_c4_3 & wh_c3_2) | (wf_rc2 & (wh_c4_3 ^ wh_c3_2))); // final carry bit3
    assign wf_rs4 = (1'b0 ^ 1'b0 ^ wf_rc3); // final sum  bit4
    assign wf_rc4 = ((1'b0 & 1'b0) | (wf_rc3 & (1'b0 ^ 1'b0))); // final carry bit4

    assign popcnt[0] = wf_rs0;
    assign popcnt[1] = wf_rs1;
    assign popcnt[2] = wf_rs2;
    assign popcnt[3] = wf_rs3;
    assign popcnt[4] = wf_rs4;

endmodule
