// ============================================================================
// popcount_wallace_d64 — popcount Wallace tree（3:2 FA + 2:1 HA 归约） (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[63:0]，输出: popcnt[6:0]（NBITS=clog2(64+1)，结果 0..64）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 7 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 64
// ============================================================================

module popcount_wallace_d64 (
    input  logic [63:0] din,
    output logic [6:0] popcnt
);

    // ---- 中间信号 ----------------
    logic wf_s1_0, wf_c1_0, wf_s1_1, wf_c1_1;
    logic wf_s1_2, wf_c1_2, wf_s1_3, wf_c1_3;
    logic wf_s1_4, wf_c1_4, wf_s1_5, wf_c1_5;
    logic wf_s1_6, wf_c1_6, wf_s1_7, wf_c1_7;
    logic wf_s1_8, wf_c1_8, wf_s1_9, wf_c1_9;
    logic wf_s1_10, wf_c1_10, wf_s1_11, wf_c1_11;
    logic wf_s1_12, wf_c1_12, wf_s1_13, wf_c1_13;
    logic wf_s1_14, wf_c1_14, wf_s1_15, wf_c1_15;
    logic wf_s1_16, wf_c1_16, wf_s1_17, wf_c1_17;
    logic wf_s1_18, wf_c1_18, wf_s1_19, wf_c1_19;
    logic wf_s1_20, wf_c1_20, wf_s2_21, wf_c2_21;
    logic wf_s2_22, wf_c2_22, wf_s2_23, wf_c2_23;
    logic wf_s2_24, wf_c2_24, wf_s2_25, wf_c2_25;
    logic wf_s2_26, wf_c2_26, wf_s2_27, wf_c2_27;
    logic wf_s2_28, wf_c2_28, wf_s2_29, wf_c2_29;
    logic wf_s2_30, wf_c2_30, wf_s2_31, wf_c2_31;
    logic wf_s2_32, wf_c2_32, wf_s2_33, wf_c2_33;
    logic wf_s2_34, wf_c2_34, wf_s3_35, wf_c3_35;
    logic wf_s3_36, wf_c3_36, wh_s3_0, wh_c3_0;
    logic wf_s3_37, wf_c3_37, wf_s3_38, wf_c3_38;
    logic wf_s3_39, wf_c3_39, wf_s3_40, wf_c3_40;
    logic wh_s3_1, wh_c3_1, wf_s3_41, wf_c3_41;
    logic wf_s3_42, wf_c3_42, wf_s4_43, wf_c4_43;
    logic wf_s4_44, wf_c4_44, wf_s4_45, wf_c4_45;
    logic wh_s4_2, wh_c4_2, wf_s4_46, wf_c4_46;
    logic wf_s4_47, wf_c4_47, wh_s4_3, wh_c4_3;
    logic wh_s4_4, wh_c4_4, wf_s5_48, wf_c5_48;
    logic wf_s5_49, wf_c5_49, wf_s5_50, wf_c5_50;
    logic wf_s5_51, wf_c5_51, wh_s6_5, wh_c6_5;
    logic wf_s6_52, wf_c6_52, wf_s6_53, wf_c6_53;
    logic wh_s6_6, wh_c6_6, wh_s7_7, wh_c7_7;
    logic wf_s7_54, wf_c7_54, wh_s7_8, wh_c7_8;

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
    assign wf_s1_10 = (din[30] ^ din[31] ^ din[32]); // FA sum  w=0
    assign wf_c1_10 = ((din[30] & din[31]) | (din[30] & din[32]) | (din[31] & din[32])); // FA carry w=1
    assign wf_s1_11 = (din[33] ^ din[34] ^ din[35]); // FA sum  w=0
    assign wf_c1_11 = ((din[33] & din[34]) | (din[33] & din[35]) | (din[34] & din[35])); // FA carry w=1
    assign wf_s1_12 = (din[36] ^ din[37] ^ din[38]); // FA sum  w=0
    assign wf_c1_12 = ((din[36] & din[37]) | (din[36] & din[38]) | (din[37] & din[38])); // FA carry w=1
    assign wf_s1_13 = (din[39] ^ din[40] ^ din[41]); // FA sum  w=0
    assign wf_c1_13 = ((din[39] & din[40]) | (din[39] & din[41]) | (din[40] & din[41])); // FA carry w=1
    assign wf_s1_14 = (din[42] ^ din[43] ^ din[44]); // FA sum  w=0
    assign wf_c1_14 = ((din[42] & din[43]) | (din[42] & din[44]) | (din[43] & din[44])); // FA carry w=1
    assign wf_s1_15 = (din[45] ^ din[46] ^ din[47]); // FA sum  w=0
    assign wf_c1_15 = ((din[45] & din[46]) | (din[45] & din[47]) | (din[46] & din[47])); // FA carry w=1
    assign wf_s1_16 = (din[48] ^ din[49] ^ din[50]); // FA sum  w=0
    assign wf_c1_16 = ((din[48] & din[49]) | (din[48] & din[50]) | (din[49] & din[50])); // FA carry w=1
    assign wf_s1_17 = (din[51] ^ din[52] ^ din[53]); // FA sum  w=0
    assign wf_c1_17 = ((din[51] & din[52]) | (din[51] & din[53]) | (din[52] & din[53])); // FA carry w=1
    assign wf_s1_18 = (din[54] ^ din[55] ^ din[56]); // FA sum  w=0
    assign wf_c1_18 = ((din[54] & din[55]) | (din[54] & din[56]) | (din[55] & din[56])); // FA carry w=1
    assign wf_s1_19 = (din[57] ^ din[58] ^ din[59]); // FA sum  w=0
    assign wf_c1_19 = ((din[57] & din[58]) | (din[57] & din[59]) | (din[58] & din[59])); // FA carry w=1
    assign wf_s1_20 = (din[60] ^ din[61] ^ din[62]); // FA sum  w=0
    assign wf_c1_20 = ((din[60] & din[61]) | (din[60] & din[62]) | (din[61] & din[62])); // FA carry w=1
    assign wf_s2_21 = (wf_s1_0 ^ wf_s1_1 ^ wf_s1_2); // FA sum  w=0
    assign wf_c2_21 = ((wf_s1_0 & wf_s1_1) | (wf_s1_0 & wf_s1_2) | (wf_s1_1 & wf_s1_2)); // FA carry w=1
    assign wf_s2_22 = (wf_s1_3 ^ wf_s1_4 ^ wf_s1_5); // FA sum  w=0
    assign wf_c2_22 = ((wf_s1_3 & wf_s1_4) | (wf_s1_3 & wf_s1_5) | (wf_s1_4 & wf_s1_5)); // FA carry w=1
    assign wf_s2_23 = (wf_s1_6 ^ wf_s1_7 ^ wf_s1_8); // FA sum  w=0
    assign wf_c2_23 = ((wf_s1_6 & wf_s1_7) | (wf_s1_6 & wf_s1_8) | (wf_s1_7 & wf_s1_8)); // FA carry w=1
    assign wf_s2_24 = (wf_s1_9 ^ wf_s1_10 ^ wf_s1_11); // FA sum  w=0
    assign wf_c2_24 = ((wf_s1_9 & wf_s1_10) | (wf_s1_9 & wf_s1_11) | (wf_s1_10 & wf_s1_11)); // FA carry w=1
    assign wf_s2_25 = (wf_s1_12 ^ wf_s1_13 ^ wf_s1_14); // FA sum  w=0
    assign wf_c2_25 = ((wf_s1_12 & wf_s1_13) | (wf_s1_12 & wf_s1_14) | (wf_s1_13 & wf_s1_14)); // FA carry w=1
    assign wf_s2_26 = (wf_s1_15 ^ wf_s1_16 ^ wf_s1_17); // FA sum  w=0
    assign wf_c2_26 = ((wf_s1_15 & wf_s1_16) | (wf_s1_15 & wf_s1_17) | (wf_s1_16 & wf_s1_17)); // FA carry w=1
    assign wf_s2_27 = (wf_s1_18 ^ wf_s1_19 ^ wf_s1_20); // FA sum  w=0
    assign wf_c2_27 = ((wf_s1_18 & wf_s1_19) | (wf_s1_18 & wf_s1_20) | (wf_s1_19 & wf_s1_20)); // FA carry w=1
    assign wf_s2_28 = (wf_c1_0 ^ wf_c1_1 ^ wf_c1_2); // FA sum  w=1
    assign wf_c2_28 = ((wf_c1_0 & wf_c1_1) | (wf_c1_0 & wf_c1_2) | (wf_c1_1 & wf_c1_2)); // FA carry w=2
    assign wf_s2_29 = (wf_c1_3 ^ wf_c1_4 ^ wf_c1_5); // FA sum  w=1
    assign wf_c2_29 = ((wf_c1_3 & wf_c1_4) | (wf_c1_3 & wf_c1_5) | (wf_c1_4 & wf_c1_5)); // FA carry w=2
    assign wf_s2_30 = (wf_c1_6 ^ wf_c1_7 ^ wf_c1_8); // FA sum  w=1
    assign wf_c2_30 = ((wf_c1_6 & wf_c1_7) | (wf_c1_6 & wf_c1_8) | (wf_c1_7 & wf_c1_8)); // FA carry w=2
    assign wf_s2_31 = (wf_c1_9 ^ wf_c1_10 ^ wf_c1_11); // FA sum  w=1
    assign wf_c2_31 = ((wf_c1_9 & wf_c1_10) | (wf_c1_9 & wf_c1_11) | (wf_c1_10 & wf_c1_11)); // FA carry w=2
    assign wf_s2_32 = (wf_c1_12 ^ wf_c1_13 ^ wf_c1_14); // FA sum  w=1
    assign wf_c2_32 = ((wf_c1_12 & wf_c1_13) | (wf_c1_12 & wf_c1_14) | (wf_c1_13 & wf_c1_14)); // FA carry w=2
    assign wf_s2_33 = (wf_c1_15 ^ wf_c1_16 ^ wf_c1_17); // FA sum  w=1
    assign wf_c2_33 = ((wf_c1_15 & wf_c1_16) | (wf_c1_15 & wf_c1_17) | (wf_c1_16 & wf_c1_17)); // FA carry w=2
    assign wf_s2_34 = (wf_c1_18 ^ wf_c1_19 ^ wf_c1_20); // FA sum  w=1
    assign wf_c2_34 = ((wf_c1_18 & wf_c1_19) | (wf_c1_18 & wf_c1_20) | (wf_c1_19 & wf_c1_20)); // FA carry w=2
    assign wf_s3_35 = (wf_s2_21 ^ wf_s2_22 ^ wf_s2_23); // FA sum  w=0
    assign wf_c3_35 = ((wf_s2_21 & wf_s2_22) | (wf_s2_21 & wf_s2_23) | (wf_s2_22 & wf_s2_23)); // FA carry w=1
    assign wf_s3_36 = (wf_s2_24 ^ wf_s2_25 ^ wf_s2_26); // FA sum  w=0
    assign wf_c3_36 = ((wf_s2_24 & wf_s2_25) | (wf_s2_24 & wf_s2_26) | (wf_s2_25 & wf_s2_26)); // FA carry w=1
    assign wh_s3_0 = (wf_s2_27 ^ din[63]); // HA sum  w=0
    assign wh_c3_0 = (wf_s2_27 & din[63]); // HA carry w=1
    assign wf_s3_37 = (wf_c2_21 ^ wf_c2_22 ^ wf_c2_23); // FA sum  w=1
    assign wf_c3_37 = ((wf_c2_21 & wf_c2_22) | (wf_c2_21 & wf_c2_23) | (wf_c2_22 & wf_c2_23)); // FA carry w=2
    assign wf_s3_38 = (wf_c2_24 ^ wf_c2_25 ^ wf_c2_26); // FA sum  w=1
    assign wf_c3_38 = ((wf_c2_24 & wf_c2_25) | (wf_c2_24 & wf_c2_26) | (wf_c2_25 & wf_c2_26)); // FA carry w=2
    assign wf_s3_39 = (wf_c2_27 ^ wf_s2_28 ^ wf_s2_29); // FA sum  w=1
    assign wf_c3_39 = ((wf_c2_27 & wf_s2_28) | (wf_c2_27 & wf_s2_29) | (wf_s2_28 & wf_s2_29)); // FA carry w=2
    assign wf_s3_40 = (wf_s2_30 ^ wf_s2_31 ^ wf_s2_32); // FA sum  w=1
    assign wf_c3_40 = ((wf_s2_30 & wf_s2_31) | (wf_s2_30 & wf_s2_32) | (wf_s2_31 & wf_s2_32)); // FA carry w=2
    assign wh_s3_1 = (wf_s2_33 ^ wf_s2_34); // HA sum  w=1
    assign wh_c3_1 = (wf_s2_33 & wf_s2_34); // HA carry w=2
    assign wf_s3_41 = (wf_c2_28 ^ wf_c2_29 ^ wf_c2_30); // FA sum  w=2
    assign wf_c3_41 = ((wf_c2_28 & wf_c2_29) | (wf_c2_28 & wf_c2_30) | (wf_c2_29 & wf_c2_30)); // FA carry w=3
    assign wf_s3_42 = (wf_c2_31 ^ wf_c2_32 ^ wf_c2_33); // FA sum  w=2
    assign wf_c3_42 = ((wf_c2_31 & wf_c2_32) | (wf_c2_31 & wf_c2_33) | (wf_c2_32 & wf_c2_33)); // FA carry w=3
    assign wf_s4_43 = (wf_s3_35 ^ wf_s3_36 ^ wh_s3_0); // FA sum  w=0
    assign wf_c4_43 = ((wf_s3_35 & wf_s3_36) | (wf_s3_35 & wh_s3_0) | (wf_s3_36 & wh_s3_0)); // FA carry w=1
    assign wf_s4_44 = (wf_c3_35 ^ wf_c3_36 ^ wh_c3_0); // FA sum  w=1
    assign wf_c4_44 = ((wf_c3_35 & wf_c3_36) | (wf_c3_35 & wh_c3_0) | (wf_c3_36 & wh_c3_0)); // FA carry w=2
    assign wf_s4_45 = (wf_s3_37 ^ wf_s3_38 ^ wf_s3_39); // FA sum  w=1
    assign wf_c4_45 = ((wf_s3_37 & wf_s3_38) | (wf_s3_37 & wf_s3_39) | (wf_s3_38 & wf_s3_39)); // FA carry w=2
    assign wh_s4_2 = (wf_s3_40 ^ wh_s3_1); // HA sum  w=1
    assign wh_c4_2 = (wf_s3_40 & wh_s3_1); // HA carry w=2
    assign wf_s4_46 = (wf_c3_37 ^ wf_c3_38 ^ wf_c3_39); // FA sum  w=2
    assign wf_c4_46 = ((wf_c3_37 & wf_c3_38) | (wf_c3_37 & wf_c3_39) | (wf_c3_38 & wf_c3_39)); // FA carry w=3
    assign wf_s4_47 = (wf_c3_40 ^ wh_c3_1 ^ wf_s3_41); // FA sum  w=2
    assign wf_c4_47 = ((wf_c3_40 & wh_c3_1) | (wf_c3_40 & wf_s3_41) | (wh_c3_1 & wf_s3_41)); // FA carry w=3
    assign wh_s4_3 = (wf_s3_42 ^ wf_c2_34); // HA sum  w=2
    assign wh_c4_3 = (wf_s3_42 & wf_c2_34); // HA carry w=3
    assign wh_s4_4 = (wf_c3_41 ^ wf_c3_42); // HA sum  w=3
    assign wh_c4_4 = (wf_c3_41 & wf_c3_42); // HA carry w=4
    assign wf_s5_48 = (wf_c4_43 ^ wf_s4_44 ^ wf_s4_45); // FA sum  w=1
    assign wf_c5_48 = ((wf_c4_43 & wf_s4_44) | (wf_c4_43 & wf_s4_45) | (wf_s4_44 & wf_s4_45)); // FA carry w=2
    assign wf_s5_49 = (wf_c4_44 ^ wf_c4_45 ^ wh_c4_2); // FA sum  w=2
    assign wf_c5_49 = ((wf_c4_44 & wf_c4_45) | (wf_c4_44 & wh_c4_2) | (wf_c4_45 & wh_c4_2)); // FA carry w=3
    assign wf_s5_50 = (wf_s4_46 ^ wf_s4_47 ^ wh_s4_3); // FA sum  w=2
    assign wf_c5_50 = ((wf_s4_46 & wf_s4_47) | (wf_s4_46 & wh_s4_3) | (wf_s4_47 & wh_s4_3)); // FA carry w=3
    assign wf_s5_51 = (wf_c4_46 ^ wf_c4_47 ^ wh_c4_3); // FA sum  w=3
    assign wf_c5_51 = ((wf_c4_46 & wf_c4_47) | (wf_c4_46 & wh_c4_3) | (wf_c4_47 & wh_c4_3)); // FA carry w=4
    assign wh_s6_5 = (wf_s5_48 ^ wh_s4_2); // HA sum  w=1
    assign wh_c6_5 = (wf_s5_48 & wh_s4_2); // HA carry w=2
    assign wf_s6_52 = (wf_c5_48 ^ wf_s5_49 ^ wf_s5_50); // FA sum  w=2
    assign wf_c6_52 = ((wf_c5_48 & wf_s5_49) | (wf_c5_48 & wf_s5_50) | (wf_s5_49 & wf_s5_50)); // FA carry w=3
    assign wf_s6_53 = (wf_c5_49 ^ wf_c5_50 ^ wf_s5_51); // FA sum  w=3
    assign wf_c6_53 = ((wf_c5_49 & wf_c5_50) | (wf_c5_49 & wf_s5_51) | (wf_c5_50 & wf_s5_51)); // FA carry w=4
    assign wh_s6_6 = (wf_c5_51 ^ wh_c4_4); // HA sum  w=4
    assign wh_c6_6 = (wf_c5_51 & wh_c4_4); // HA carry w=5
    assign wh_s7_7 = (wh_c6_5 ^ wf_s6_52); // HA sum  w=2
    assign wh_c7_7 = (wh_c6_5 & wf_s6_52); // HA carry w=3
    assign wf_s7_54 = (wf_c6_52 ^ wf_s6_53 ^ wh_s4_4); // FA sum  w=3
    assign wf_c7_54 = ((wf_c6_52 & wf_s6_53) | (wf_c6_52 & wh_s4_4) | (wf_s6_53 & wh_s4_4)); // FA carry w=4
    assign wh_s7_8 = (wf_c6_53 ^ wh_s6_6); // HA sum  w=4
    assign wh_c7_8 = (wf_c6_53 & wh_s6_6); // HA carry w=5

    assign wf_rs0 = (wf_s4_43 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign wf_rc0 = ((wf_s4_43 & 1'b0) | (1'b0 & (wf_s4_43 ^ 1'b0))); // final carry bit0
    assign wf_rs1 = (wh_s6_5 ^ 1'b0 ^ wf_rc0); // final sum  bit1
    assign wf_rc1 = ((wh_s6_5 & 1'b0) | (wf_rc0 & (wh_s6_5 ^ 1'b0))); // final carry bit1
    assign wf_rs2 = (wh_s7_7 ^ 1'b0 ^ wf_rc1); // final sum  bit2
    assign wf_rc2 = ((wh_s7_7 & 1'b0) | (wf_rc1 & (wh_s7_7 ^ 1'b0))); // final carry bit2
    assign wf_rs3 = (wh_c7_7 ^ wf_s7_54 ^ wf_rc2); // final sum  bit3
    assign wf_rc3 = ((wh_c7_7 & wf_s7_54) | (wf_rc2 & (wh_c7_7 ^ wf_s7_54))); // final carry bit3
    assign wf_rs4 = (wf_c7_54 ^ wh_s7_8 ^ wf_rc3); // final sum  bit4
    assign wf_rc4 = ((wf_c7_54 & wh_s7_8) | (wf_rc3 & (wf_c7_54 ^ wh_s7_8))); // final carry bit4
    assign wf_rs5 = (wh_c7_8 ^ wh_c6_6 ^ wf_rc4); // final sum  bit5
    assign wf_rc5 = ((wh_c7_8 & wh_c6_6) | (wf_rc4 & (wh_c7_8 ^ wh_c6_6))); // final carry bit5
    assign wf_rs6 = (1'b0 ^ 1'b0 ^ wf_rc5); // final sum  bit6
    assign wf_rc6 = ((1'b0 & 1'b0) | (wf_rc5 & (1'b0 ^ 1'b0))); // final carry bit6

    assign popcnt[0] = wf_rs0;
    assign popcnt[1] = wf_rs1;
    assign popcnt[2] = wf_rs2;
    assign popcnt[3] = wf_rs3;
    assign popcnt[4] = wf_rs4;
    assign popcnt[5] = wf_rs5;
    assign popcnt[6] = wf_rs6;

endmodule
