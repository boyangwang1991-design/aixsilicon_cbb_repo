// ============================================================================
// popcount_wallace_d32 — popcount Wallace tree（3:2 FA + 2:1 HA 归约） (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[31:0]，输出: popcnt[5:0]（NBITS=clog2(32+1)，结果 0..32）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 6 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 32
// ============================================================================

module popcount_wallace_d32 (
    input  logic [31:0] din,
    output logic [5:0] popcnt
);

    // ---- 中间信号 ----------------
    logic wf_s1_0, wf_c1_0, wf_s1_1, wf_c1_1;
    logic wf_s1_2, wf_c1_2, wf_s1_3, wf_c1_3;
    logic wf_s1_4, wf_c1_4, wf_s1_5, wf_c1_5;
    logic wf_s1_6, wf_c1_6, wf_s1_7, wf_c1_7;
    logic wf_s1_8, wf_c1_8, wf_s1_9, wf_c1_9;
    logic wh_s1_0, wh_c1_0, wf_s2_10, wf_c2_10;
    logic wf_s2_11, wf_c2_11, wf_s2_12, wf_c2_12;
    logic wh_s2_1, wh_c2_1, wf_s2_13, wf_c2_13;
    logic wf_s2_14, wf_c2_14, wf_s2_15, wf_c2_15;
    logic wh_s2_2, wh_c2_2, wf_s3_16, wf_c3_16;
    logic wf_s3_17, wf_c3_17, wf_s3_18, wf_c3_18;
    logic wh_s3_3, wh_c3_3, wf_s3_19, wf_c3_19;
    logic wh_s4_4, wh_c4_4, wf_s4_20, wf_c4_20;
    logic wf_s4_21, wf_c4_21, wh_s4_5, wh_c4_5;
    logic wf_s5_22, wf_c5_22, wf_s5_23, wf_c5_23;
    logic wf_s5_24, wf_c5_24;

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
    assign wf_s1_5 = (din[15] ^ din[16] ^ din[17]); // FA sum  w=0
    assign wf_c1_5 = ((din[15] & din[16]) | (din[15] & din[17]) | (din[16] & din[17])); // FA carry w=1
    assign wf_s1_6 = (din[18] ^ din[19] ^ din[20]); // FA sum  w=0
    assign wf_c1_6 = ((din[18] & din[19]) | (din[18] & din[20]) | (din[19] & din[20])); // FA carry w=1
    assign wf_s1_7 = (din[21] ^ din[22] ^ din[23]); // FA sum  w=0
    assign wf_c1_7 = ((din[21] & din[22]) | (din[21] & din[23]) | (din[22] & din[23])); // FA carry w=1
    assign wf_s1_8 = (din[24] ^ din[25] ^ din[26]); // FA sum  w=0
    assign wf_c1_8 = ((din[24] & din[25]) | (din[24] & din[26]) | (din[25] & din[26])); // FA carry w=1
    assign wf_s1_9 = (din[27] ^ din[28] ^ din[29]); // FA sum  w=0
    assign wf_c1_9 = ((din[27] & din[28]) | (din[27] & din[29]) | (din[28] & din[29])); // FA carry w=1
    assign wh_s1_0 = (din[30] ^ din[31]); // HA sum  w=0
    assign wh_c1_0 = (din[30] & din[31]); // HA carry w=1
    assign wf_s2_10 = (wf_s1_0 ^ wf_s1_1 ^ wf_s1_2); // FA sum  w=0
    assign wf_c2_10 = ((wf_s1_0 & wf_s1_1) | (wf_s1_0 & wf_s1_2) | (wf_s1_1 & wf_s1_2)); // FA carry w=1
    assign wf_s2_11 = (wf_s1_3 ^ wf_s1_4 ^ wf_s1_5); // FA sum  w=0
    assign wf_c2_11 = ((wf_s1_3 & wf_s1_4) | (wf_s1_3 & wf_s1_5) | (wf_s1_4 & wf_s1_5)); // FA carry w=1
    assign wf_s2_12 = (wf_s1_6 ^ wf_s1_7 ^ wf_s1_8); // FA sum  w=0
    assign wf_c2_12 = ((wf_s1_6 & wf_s1_7) | (wf_s1_6 & wf_s1_8) | (wf_s1_7 & wf_s1_8)); // FA carry w=1
    assign wh_s2_1 = (wf_s1_9 ^ wh_s1_0); // HA sum  w=0
    assign wh_c2_1 = (wf_s1_9 & wh_s1_0); // HA carry w=1
    assign wf_s2_13 = (wf_c1_0 ^ wf_c1_1 ^ wf_c1_2); // FA sum  w=1
    assign wf_c2_13 = ((wf_c1_0 & wf_c1_1) | (wf_c1_0 & wf_c1_2) | (wf_c1_1 & wf_c1_2)); // FA carry w=2
    assign wf_s2_14 = (wf_c1_3 ^ wf_c1_4 ^ wf_c1_5); // FA sum  w=1
    assign wf_c2_14 = ((wf_c1_3 & wf_c1_4) | (wf_c1_3 & wf_c1_5) | (wf_c1_4 & wf_c1_5)); // FA carry w=2
    assign wf_s2_15 = (wf_c1_6 ^ wf_c1_7 ^ wf_c1_8); // FA sum  w=1
    assign wf_c2_15 = ((wf_c1_6 & wf_c1_7) | (wf_c1_6 & wf_c1_8) | (wf_c1_7 & wf_c1_8)); // FA carry w=2
    assign wh_s2_2 = (wf_c1_9 ^ wh_c1_0); // HA sum  w=1
    assign wh_c2_2 = (wf_c1_9 & wh_c1_0); // HA carry w=2
    assign wf_s3_16 = (wf_s2_10 ^ wf_s2_11 ^ wf_s2_12); // FA sum  w=0
    assign wf_c3_16 = ((wf_s2_10 & wf_s2_11) | (wf_s2_10 & wf_s2_12) | (wf_s2_11 & wf_s2_12)); // FA carry w=1
    assign wf_s3_17 = (wf_c2_10 ^ wf_c2_11 ^ wf_c2_12); // FA sum  w=1
    assign wf_c3_17 = ((wf_c2_10 & wf_c2_11) | (wf_c2_10 & wf_c2_12) | (wf_c2_11 & wf_c2_12)); // FA carry w=2
    assign wf_s3_18 = (wh_c2_1 ^ wf_s2_13 ^ wf_s2_14); // FA sum  w=1
    assign wf_c3_18 = ((wh_c2_1 & wf_s2_13) | (wh_c2_1 & wf_s2_14) | (wf_s2_13 & wf_s2_14)); // FA carry w=2
    assign wh_s3_3 = (wf_s2_15 ^ wh_s2_2); // HA sum  w=1
    assign wh_c3_3 = (wf_s2_15 & wh_s2_2); // HA carry w=2
    assign wf_s3_19 = (wf_c2_13 ^ wf_c2_14 ^ wf_c2_15); // FA sum  w=2
    assign wf_c3_19 = ((wf_c2_13 & wf_c2_14) | (wf_c2_13 & wf_c2_15) | (wf_c2_14 & wf_c2_15)); // FA carry w=3
    assign wh_s4_4 = (wf_s3_16 ^ wh_s2_1); // HA sum  w=0
    assign wh_c4_4 = (wf_s3_16 & wh_s2_1); // HA carry w=1
    assign wf_s4_20 = (wf_c3_16 ^ wf_s3_17 ^ wf_s3_18); // FA sum  w=1
    assign wf_c4_20 = ((wf_c3_16 & wf_s3_17) | (wf_c3_16 & wf_s3_18) | (wf_s3_17 & wf_s3_18)); // FA carry w=2
    assign wf_s4_21 = (wf_c3_17 ^ wf_c3_18 ^ wh_c3_3); // FA sum  w=2
    assign wf_c4_21 = ((wf_c3_17 & wf_c3_18) | (wf_c3_17 & wh_c3_3) | (wf_c3_18 & wh_c3_3)); // FA carry w=3
    assign wh_s4_5 = (wf_s3_19 ^ wh_c2_2); // HA sum  w=2
    assign wh_c4_5 = (wf_s3_19 & wh_c2_2); // HA carry w=3
    assign wf_s5_22 = (wh_c4_4 ^ wf_s4_20 ^ wh_s3_3); // FA sum  w=1
    assign wf_c5_22 = ((wh_c4_4 & wf_s4_20) | (wh_c4_4 & wh_s3_3) | (wf_s4_20 & wh_s3_3)); // FA carry w=2
    assign wf_s5_23 = (wf_c4_20 ^ wf_s4_21 ^ wh_s4_5); // FA sum  w=2
    assign wf_c5_23 = ((wf_c4_20 & wf_s4_21) | (wf_c4_20 & wh_s4_5) | (wf_s4_21 & wh_s4_5)); // FA carry w=3
    assign wf_s5_24 = (wf_c4_21 ^ wh_c4_5 ^ wf_c3_19); // FA sum  w=3
    assign wf_c5_24 = ((wf_c4_21 & wh_c4_5) | (wf_c4_21 & wf_c3_19) | (wh_c4_5 & wf_c3_19)); // FA carry w=4

    assign wf_rs0 = (wh_s4_4 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign wf_rc0 = ((wh_s4_4 & 1'b0) | (1'b0 & (wh_s4_4 ^ 1'b0))); // final carry bit0
    assign wf_rs1 = (wf_s5_22 ^ 1'b0 ^ wf_rc0); // final sum  bit1
    assign wf_rc1 = ((wf_s5_22 & 1'b0) | (wf_rc0 & (wf_s5_22 ^ 1'b0))); // final carry bit1
    assign wf_rs2 = (wf_c5_22 ^ wf_s5_23 ^ wf_rc1); // final sum  bit2
    assign wf_rc2 = ((wf_c5_22 & wf_s5_23) | (wf_rc1 & (wf_c5_22 ^ wf_s5_23))); // final carry bit2
    assign wf_rs3 = (wf_c5_23 ^ wf_s5_24 ^ wf_rc2); // final sum  bit3
    assign wf_rc3 = ((wf_c5_23 & wf_s5_24) | (wf_rc2 & (wf_c5_23 ^ wf_s5_24))); // final carry bit3
    assign wf_rs4 = (wf_c5_24 ^ 1'b0 ^ wf_rc3); // final sum  bit4
    assign wf_rc4 = ((wf_c5_24 & 1'b0) | (wf_rc3 & (wf_c5_24 ^ 1'b0))); // final carry bit4
    assign wf_rs5 = (1'b0 ^ 1'b0 ^ wf_rc4); // final sum  bit5
    assign wf_rc5 = ((1'b0 & 1'b0) | (wf_rc4 & (1'b0 ^ 1'b0))); // final carry bit5

    assign popcnt[0] = wf_rs0;
    assign popcnt[1] = wf_rs1;
    assign popcnt[2] = wf_rs2;
    assign popcnt[3] = wf_rs3;
    assign popcnt[4] = wf_rs4;
    assign popcnt[5] = wf_rs5;

endmodule
