// ============================================================================
// popcount_compressor_d64 — popcount 4:2 compressor（cin/cout 列间链）+FA/HA 归约 (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[63:0]，输出: popcnt[6:0]（NBITS=clog2(64+1)，结果 0..64）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 7 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 64
// ============================================================================

module popcount_compressor_d64 (
    input  logic [63:0] din,
    output logic [6:0] popcnt
);

    // ---- 中间信号 ----------------
    logic cs_s1_1_0, cs_co_1_0, cs_s_1_0, cs_c_1_0;
    logic cf_s1_1, cf_c1_1, cf_s1_2, cf_c1_2;
    logic cf_s1_3, cf_c1_3, cf_s1_4, cf_c1_4;
    logic cf_s1_5, cf_c1_5, cf_s1_6, cf_c1_6;
    logic cf_s1_7, cf_c1_7, cf_s1_8, cf_c1_8;
    logic cf_s1_9, cf_c1_9, cf_s1_10, cf_c1_10;
    logic cf_s1_11, cf_c1_11, cf_s1_12, cf_c1_12;
    logic cf_s1_13, cf_c1_13, cf_s1_14, cf_c1_14;
    logic cf_s1_15, cf_c1_15, cf_s1_16, cf_c1_16;
    logic cf_s1_17, cf_c1_17, cf_s1_18, cf_c1_18;
    logic cf_s1_19, cf_c1_19, cf_s1_20, cf_c1_20;
    logic cs_s1_2_21, cs_co_2_21, cs_s_2_21, cs_c_2_21;
    logic cs_s1_2_22, cs_co_2_22, cs_s_2_22, cs_c_2_22;
    logic cf_s2_23, cf_c2_23, cf_s2_24, cf_c2_24;
    logic cf_s2_25, cf_c2_25, cf_s2_26, cf_c2_26;
    logic cf_s2_27, cf_c2_27, ch_s2_28, ch_c2_28;
    logic cf_s2_29, cf_c2_29, cf_s2_30, cf_c2_30;
    logic cf_s2_31, cf_c2_31, cf_s2_32, cf_c2_32;
    logic cf_s2_33, cf_c2_33, cf_s2_34, cf_c2_34;
    logic cs_s1_3_35, cs_co_3_35, cs_s_3_35, cs_c_3_35;
    logic cs_s1_3_36, cs_co_3_36, cs_s_3_36, cs_c_3_36;
    logic cs_s1_3_37, cs_co_3_37, cs_s_3_37, cs_c_3_37;
    logic cf_s3_38, cf_c3_38, cf_s3_39, cf_c3_39;
    logic cf_s3_40, cf_c3_40, cf_s3_41, cf_c3_41;
    logic cf_s3_42, cf_c3_42, cs_s1_4_43, cs_co_4_43;
    logic cs_s_4_43, cs_c_4_43, cs_s1_4_44, cs_co_4_44;
    logic cs_s_4_44, cs_c_4_44, ch_s4_45, ch_c4_45;
    logic cf_s4_46, cf_c4_46, cf_s4_47, cf_c4_47;
    logic cf_s4_48, cf_c4_48, cs_s1_5_49, cs_co_5_49;
    logic cs_s_5_49, cs_c_5_49, cs_s1_5_50, cs_co_5_50;
    logic cs_s_5_50, cs_c_5_50, cf_s5_51, cf_c5_51;
    logic ch_s6_52, ch_c6_52, ch_s6_53, ch_c6_53;
    logic cf_s6_54, cf_c6_54;

    // ---- 归约 / 收尾 ----------------

    assign cs_s1_1_0 = (din[0] ^ din[1] ^ 1'b0); // 4:2 s1  w=0
    assign cs_co_1_0 = ((din[0] & din[1]) | (din[0] & 1'b0) | (din[1] & 1'b0)); // 4:2 cout w=1
    assign cs_s_1_0 = (cs_s1_1_0 ^ din[2] ^ din[3]); // 4:2 sum  w=0
    assign cs_c_1_0 = ((cs_s1_1_0 & din[2]) | (cs_s1_1_0 & din[3]) | (din[2] & din[3])); // 4:2 carry w=1
    assign cf_s1_1 = (din[4] ^ din[5] ^ din[6]); // FA sum  w=0
    assign cf_c1_1 = ((din[4] & din[5]) | (din[4] & din[6]) | (din[5] & din[6])); // FA carry w=1
    assign cf_s1_2 = (din[7] ^ din[8] ^ din[9]); // FA sum  w=0
    assign cf_c1_2 = ((din[7] & din[8]) | (din[7] & din[9]) | (din[8] & din[9])); // FA carry w=1
    assign cf_s1_3 = (din[10] ^ din[11] ^ din[12]); // FA sum  w=0
    assign cf_c1_3 = ((din[10] & din[11]) | (din[10] & din[12]) | (din[11] & din[12])); // FA carry w=1
    assign cf_s1_4 = (din[13] ^ din[14] ^ din[15]); // FA sum  w=0
    assign cf_c1_4 = ((din[13] & din[14]) | (din[13] & din[15]) | (din[14] & din[15])); // FA carry w=1
    assign cf_s1_5 = (din[16] ^ din[17] ^ din[18]); // FA sum  w=0
    assign cf_c1_5 = ((din[16] & din[17]) | (din[16] & din[18]) | (din[17] & din[18])); // FA carry w=1
    assign cf_s1_6 = (din[19] ^ din[20] ^ din[21]); // FA sum  w=0
    assign cf_c1_6 = ((din[19] & din[20]) | (din[19] & din[21]) | (din[20] & din[21])); // FA carry w=1
    assign cf_s1_7 = (din[22] ^ din[23] ^ din[24]); // FA sum  w=0
    assign cf_c1_7 = ((din[22] & din[23]) | (din[22] & din[24]) | (din[23] & din[24])); // FA carry w=1
    assign cf_s1_8 = (din[25] ^ din[26] ^ din[27]); // FA sum  w=0
    assign cf_c1_8 = ((din[25] & din[26]) | (din[25] & din[27]) | (din[26] & din[27])); // FA carry w=1
    assign cf_s1_9 = (din[28] ^ din[29] ^ din[30]); // FA sum  w=0
    assign cf_c1_9 = ((din[28] & din[29]) | (din[28] & din[30]) | (din[29] & din[30])); // FA carry w=1
    assign cf_s1_10 = (din[31] ^ din[32] ^ din[33]); // FA sum  w=0
    assign cf_c1_10 = ((din[31] & din[32]) | (din[31] & din[33]) | (din[32] & din[33])); // FA carry w=1
    assign cf_s1_11 = (din[34] ^ din[35] ^ din[36]); // FA sum  w=0
    assign cf_c1_11 = ((din[34] & din[35]) | (din[34] & din[36]) | (din[35] & din[36])); // FA carry w=1
    assign cf_s1_12 = (din[37] ^ din[38] ^ din[39]); // FA sum  w=0
    assign cf_c1_12 = ((din[37] & din[38]) | (din[37] & din[39]) | (din[38] & din[39])); // FA carry w=1
    assign cf_s1_13 = (din[40] ^ din[41] ^ din[42]); // FA sum  w=0
    assign cf_c1_13 = ((din[40] & din[41]) | (din[40] & din[42]) | (din[41] & din[42])); // FA carry w=1
    assign cf_s1_14 = (din[43] ^ din[44] ^ din[45]); // FA sum  w=0
    assign cf_c1_14 = ((din[43] & din[44]) | (din[43] & din[45]) | (din[44] & din[45])); // FA carry w=1
    assign cf_s1_15 = (din[46] ^ din[47] ^ din[48]); // FA sum  w=0
    assign cf_c1_15 = ((din[46] & din[47]) | (din[46] & din[48]) | (din[47] & din[48])); // FA carry w=1
    assign cf_s1_16 = (din[49] ^ din[50] ^ din[51]); // FA sum  w=0
    assign cf_c1_16 = ((din[49] & din[50]) | (din[49] & din[51]) | (din[50] & din[51])); // FA carry w=1
    assign cf_s1_17 = (din[52] ^ din[53] ^ din[54]); // FA sum  w=0
    assign cf_c1_17 = ((din[52] & din[53]) | (din[52] & din[54]) | (din[53] & din[54])); // FA carry w=1
    assign cf_s1_18 = (din[55] ^ din[56] ^ din[57]); // FA sum  w=0
    assign cf_c1_18 = ((din[55] & din[56]) | (din[55] & din[57]) | (din[56] & din[57])); // FA carry w=1
    assign cf_s1_19 = (din[58] ^ din[59] ^ din[60]); // FA sum  w=0
    assign cf_c1_19 = ((din[58] & din[59]) | (din[58] & din[60]) | (din[59] & din[60])); // FA carry w=1
    assign cf_s1_20 = (din[61] ^ din[62] ^ din[63]); // FA sum  w=0
    assign cf_c1_20 = ((din[61] & din[62]) | (din[61] & din[63]) | (din[62] & din[63])); // FA carry w=1
    assign cs_s1_2_21 = (cs_s_1_0 ^ cf_s1_1 ^ 1'b0); // 4:2 s1  w=0
    assign cs_co_2_21 = ((cs_s_1_0 & cf_s1_1) | (cs_s_1_0 & 1'b0) | (cf_s1_1 & 1'b0)); // 4:2 cout w=1
    assign cs_s_2_21 = (cs_s1_2_21 ^ cf_s1_2 ^ cf_s1_3); // 4:2 sum  w=0
    assign cs_c_2_21 = ((cs_s1_2_21 & cf_s1_2) | (cs_s1_2_21 & cf_s1_3) | (cf_s1_2 & cf_s1_3)); // 4:2 carry w=1
    assign cs_s1_2_22 = (cs_c_1_0 ^ cs_co_1_0 ^ cs_co_2_21); // 4:2 s1  w=1
    assign cs_co_2_22 = ((cs_c_1_0 & cs_co_1_0) | (cs_c_1_0 & cs_co_2_21) | (cs_co_1_0 & cs_co_2_21)); // 4:2 cout w=2
    assign cs_s_2_22 = (cs_s1_2_22 ^ cf_c1_1 ^ cf_c1_2); // 4:2 sum  w=1
    assign cs_c_2_22 = ((cs_s1_2_22 & cf_c1_1) | (cs_s1_2_22 & cf_c1_2) | (cf_c1_1 & cf_c1_2)); // 4:2 carry w=2
    assign cf_s2_23 = (cf_s1_4 ^ cf_s1_5 ^ cf_s1_6); // FA sum  w=0
    assign cf_c2_23 = ((cf_s1_4 & cf_s1_5) | (cf_s1_4 & cf_s1_6) | (cf_s1_5 & cf_s1_6)); // FA carry w=1
    assign cf_s2_24 = (cf_s1_7 ^ cf_s1_8 ^ cf_s1_9); // FA sum  w=0
    assign cf_c2_24 = ((cf_s1_7 & cf_s1_8) | (cf_s1_7 & cf_s1_9) | (cf_s1_8 & cf_s1_9)); // FA carry w=1
    assign cf_s2_25 = (cf_s1_10 ^ cf_s1_11 ^ cf_s1_12); // FA sum  w=0
    assign cf_c2_25 = ((cf_s1_10 & cf_s1_11) | (cf_s1_10 & cf_s1_12) | (cf_s1_11 & cf_s1_12)); // FA carry w=1
    assign cf_s2_26 = (cf_s1_13 ^ cf_s1_14 ^ cf_s1_15); // FA sum  w=0
    assign cf_c2_26 = ((cf_s1_13 & cf_s1_14) | (cf_s1_13 & cf_s1_15) | (cf_s1_14 & cf_s1_15)); // FA carry w=1
    assign cf_s2_27 = (cf_s1_16 ^ cf_s1_17 ^ cf_s1_18); // FA sum  w=0
    assign cf_c2_27 = ((cf_s1_16 & cf_s1_17) | (cf_s1_16 & cf_s1_18) | (cf_s1_17 & cf_s1_18)); // FA carry w=1
    assign ch_s2_28 = (cf_s1_19 ^ cf_s1_20); // HA sum  w=0
    assign ch_c2_28 = (cf_s1_19 & cf_s1_20); // HA carry w=1
    assign cf_s2_29 = (cf_c1_3 ^ cf_c1_4 ^ cf_c1_5); // FA sum  w=1
    assign cf_c2_29 = ((cf_c1_3 & cf_c1_4) | (cf_c1_3 & cf_c1_5) | (cf_c1_4 & cf_c1_5)); // FA carry w=2
    assign cf_s2_30 = (cf_c1_6 ^ cf_c1_7 ^ cf_c1_8); // FA sum  w=1
    assign cf_c2_30 = ((cf_c1_6 & cf_c1_7) | (cf_c1_6 & cf_c1_8) | (cf_c1_7 & cf_c1_8)); // FA carry w=2
    assign cf_s2_31 = (cf_c1_9 ^ cf_c1_10 ^ cf_c1_11); // FA sum  w=1
    assign cf_c2_31 = ((cf_c1_9 & cf_c1_10) | (cf_c1_9 & cf_c1_11) | (cf_c1_10 & cf_c1_11)); // FA carry w=2
    assign cf_s2_32 = (cf_c1_12 ^ cf_c1_13 ^ cf_c1_14); // FA sum  w=1
    assign cf_c2_32 = ((cf_c1_12 & cf_c1_13) | (cf_c1_12 & cf_c1_14) | (cf_c1_13 & cf_c1_14)); // FA carry w=2
    assign cf_s2_33 = (cf_c1_15 ^ cf_c1_16 ^ cf_c1_17); // FA sum  w=1
    assign cf_c2_33 = ((cf_c1_15 & cf_c1_16) | (cf_c1_15 & cf_c1_17) | (cf_c1_16 & cf_c1_17)); // FA carry w=2
    assign cf_s2_34 = (cf_c1_18 ^ cf_c1_19 ^ cf_c1_20); // FA sum  w=1
    assign cf_c2_34 = ((cf_c1_18 & cf_c1_19) | (cf_c1_18 & cf_c1_20) | (cf_c1_19 & cf_c1_20)); // FA carry w=2
    assign cs_s1_3_35 = (cs_s_2_21 ^ cf_s2_23 ^ 1'b0); // 4:2 s1  w=0
    assign cs_co_3_35 = ((cs_s_2_21 & cf_s2_23) | (cs_s_2_21 & 1'b0) | (cf_s2_23 & 1'b0)); // 4:2 cout w=1
    assign cs_s_3_35 = (cs_s1_3_35 ^ cf_s2_24 ^ cf_s2_25); // 4:2 sum  w=0
    assign cs_c_3_35 = ((cs_s1_3_35 & cf_s2_24) | (cs_s1_3_35 & cf_s2_25) | (cf_s2_24 & cf_s2_25)); // 4:2 carry w=1
    assign cs_s1_3_36 = (cs_c_2_21 ^ cs_s_2_22 ^ cs_co_3_35); // 4:2 s1  w=1
    assign cs_co_3_36 = ((cs_c_2_21 & cs_s_2_22) | (cs_c_2_21 & cs_co_3_35) | (cs_s_2_22 & cs_co_3_35)); // 4:2 cout w=2
    assign cs_s_3_36 = (cs_s1_3_36 ^ cf_c2_23 ^ cf_c2_24); // 4:2 sum  w=1
    assign cs_c_3_36 = ((cs_s1_3_36 & cf_c2_23) | (cs_s1_3_36 & cf_c2_24) | (cf_c2_23 & cf_c2_24)); // 4:2 carry w=2
    assign cs_s1_3_37 = (cs_c_2_22 ^ cs_co_2_22 ^ cs_co_3_36); // 4:2 s1  w=2
    assign cs_co_3_37 = ((cs_c_2_22 & cs_co_2_22) | (cs_c_2_22 & cs_co_3_36) | (cs_co_2_22 & cs_co_3_36)); // 4:2 cout w=3
    assign cs_s_3_37 = (cs_s1_3_37 ^ cf_c2_29 ^ cf_c2_30); // 4:2 sum  w=2
    assign cs_c_3_37 = ((cs_s1_3_37 & cf_c2_29) | (cs_s1_3_37 & cf_c2_30) | (cf_c2_29 & cf_c2_30)); // 4:2 carry w=3
    assign cf_s3_38 = (cf_s2_26 ^ cf_s2_27 ^ ch_s2_28); // FA sum  w=0
    assign cf_c3_38 = ((cf_s2_26 & cf_s2_27) | (cf_s2_26 & ch_s2_28) | (cf_s2_27 & ch_s2_28)); // FA carry w=1
    assign cf_s3_39 = (cf_c2_25 ^ cf_c2_26 ^ cf_c2_27); // FA sum  w=1
    assign cf_c3_39 = ((cf_c2_25 & cf_c2_26) | (cf_c2_25 & cf_c2_27) | (cf_c2_26 & cf_c2_27)); // FA carry w=2
    assign cf_s3_40 = (ch_c2_28 ^ cf_s2_29 ^ cf_s2_30); // FA sum  w=1
    assign cf_c3_40 = ((ch_c2_28 & cf_s2_29) | (ch_c2_28 & cf_s2_30) | (cf_s2_29 & cf_s2_30)); // FA carry w=2
    assign cf_s3_41 = (cf_s2_31 ^ cf_s2_32 ^ cf_s2_33); // FA sum  w=1
    assign cf_c3_41 = ((cf_s2_31 & cf_s2_32) | (cf_s2_31 & cf_s2_33) | (cf_s2_32 & cf_s2_33)); // FA carry w=2
    assign cf_s3_42 = (cf_c2_31 ^ cf_c2_32 ^ cf_c2_33); // FA sum  w=2
    assign cf_c3_42 = ((cf_c2_31 & cf_c2_32) | (cf_c2_31 & cf_c2_33) | (cf_c2_32 & cf_c2_33)); // FA carry w=3
    assign cs_s1_4_43 = (cs_c_3_35 ^ cs_s_3_36 ^ 1'b0); // 4:2 s1  w=1
    assign cs_co_4_43 = ((cs_c_3_35 & cs_s_3_36) | (cs_c_3_35 & 1'b0) | (cs_s_3_36 & 1'b0)); // 4:2 cout w=2
    assign cs_s_4_43 = (cs_s1_4_43 ^ cf_c3_38 ^ cf_s3_39); // 4:2 sum  w=1
    assign cs_c_4_43 = ((cs_s1_4_43 & cf_c3_38) | (cs_s1_4_43 & cf_s3_39) | (cf_c3_38 & cf_s3_39)); // 4:2 carry w=2
    assign cs_s1_4_44 = (cs_c_3_36 ^ cs_s_3_37 ^ cs_co_4_43); // 4:2 s1  w=2
    assign cs_co_4_44 = ((cs_c_3_36 & cs_s_3_37) | (cs_c_3_36 & cs_co_4_43) | (cs_s_3_37 & cs_co_4_43)); // 4:2 cout w=3
    assign cs_s_4_44 = (cs_s1_4_44 ^ cf_c3_39 ^ cf_c3_40); // 4:2 sum  w=2
    assign cs_c_4_44 = ((cs_s1_4_44 & cf_c3_39) | (cs_s1_4_44 & cf_c3_40) | (cf_c3_39 & cf_c3_40)); // 4:2 carry w=3
    assign ch_s4_45 = (cs_s_3_35 ^ cf_s3_38); // HA sum  w=0
    assign ch_c4_45 = (cs_s_3_35 & cf_s3_38); // HA carry w=1
    assign cf_s4_46 = (cf_s3_40 ^ cf_s3_41 ^ cf_s2_34); // FA sum  w=1
    assign cf_c4_46 = ((cf_s3_40 & cf_s3_41) | (cf_s3_40 & cf_s2_34) | (cf_s3_41 & cf_s2_34)); // FA carry w=2
    assign cf_s4_47 = (cf_c3_41 ^ cf_s3_42 ^ cf_c2_34); // FA sum  w=2
    assign cf_c4_47 = ((cf_c3_41 & cf_s3_42) | (cf_c3_41 & cf_c2_34) | (cf_s3_42 & cf_c2_34)); // FA carry w=3
    assign cf_s4_48 = (cs_c_3_37 ^ cs_co_3_37 ^ cf_c3_42); // FA sum  w=3
    assign cf_c4_48 = ((cs_c_3_37 & cs_co_3_37) | (cs_c_3_37 & cf_c3_42) | (cs_co_3_37 & cf_c3_42)); // FA carry w=4
    assign cs_s1_5_49 = (cs_c_4_43 ^ cs_s_4_44 ^ 1'b0); // 4:2 s1  w=2
    assign cs_co_5_49 = ((cs_c_4_43 & cs_s_4_44) | (cs_c_4_43 & 1'b0) | (cs_s_4_44 & 1'b0)); // 4:2 cout w=3
    assign cs_s_5_49 = (cs_s1_5_49 ^ cf_c4_46 ^ cf_s4_47); // 4:2 sum  w=2
    assign cs_c_5_49 = ((cs_s1_5_49 & cf_c4_46) | (cs_s1_5_49 & cf_s4_47) | (cf_c4_46 & cf_s4_47)); // 4:2 carry w=3
    assign cs_s1_5_50 = (cs_c_4_44 ^ cs_co_4_44 ^ cs_co_5_49); // 4:2 s1  w=3
    assign cs_co_5_50 = ((cs_c_4_44 & cs_co_4_44) | (cs_c_4_44 & cs_co_5_49) | (cs_co_4_44 & cs_co_5_49)); // 4:2 cout w=4
    assign cs_s_5_50 = (cs_s1_5_50 ^ cf_c4_47 ^ cf_s4_48); // 4:2 sum  w=3
    assign cs_c_5_50 = ((cs_s1_5_50 & cf_c4_47) | (cs_s1_5_50 & cf_s4_48) | (cf_c4_47 & cf_s4_48)); // 4:2 carry w=4
    assign cf_s5_51 = (cs_s_4_43 ^ ch_c4_45 ^ cf_s4_46); // FA sum  w=1
    assign cf_c5_51 = ((cs_s_4_43 & ch_c4_45) | (cs_s_4_43 & cf_s4_46) | (ch_c4_45 & cf_s4_46)); // FA carry w=2
    assign ch_s6_52 = (cs_s_5_49 ^ cf_c5_51); // HA sum  w=2
    assign ch_c6_52 = (cs_s_5_49 & cf_c5_51); // HA carry w=3
    assign ch_s6_53 = (cs_c_5_49 ^ cs_s_5_50); // HA sum  w=3
    assign ch_c6_53 = (cs_c_5_49 & cs_s_5_50); // HA carry w=4
    assign cf_s6_54 = (cs_c_5_50 ^ cs_co_5_50 ^ cf_c4_48); // FA sum  w=4
    assign cf_c6_54 = ((cs_c_5_50 & cs_co_5_50) | (cs_c_5_50 & cf_c4_48) | (cs_co_5_50 & cf_c4_48)); // FA carry w=5

    assign cf_rs0 = (ch_s4_45 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign cf_rc0 = ((ch_s4_45 & 1'b0) | (1'b0 & (ch_s4_45 ^ 1'b0))); // final carry bit0
    assign cf_rs1 = (cf_s5_51 ^ 1'b0 ^ cf_rc0); // final sum  bit1
    assign cf_rc1 = ((cf_s5_51 & 1'b0) | (cf_rc0 & (cf_s5_51 ^ 1'b0))); // final carry bit1
    assign cf_rs2 = (ch_s6_52 ^ 1'b0 ^ cf_rc1); // final sum  bit2
    assign cf_rc2 = ((ch_s6_52 & 1'b0) | (cf_rc1 & (ch_s6_52 ^ 1'b0))); // final carry bit2
    assign cf_rs3 = (ch_c6_52 ^ ch_s6_53 ^ cf_rc2); // final sum  bit3
    assign cf_rc3 = ((ch_c6_52 & ch_s6_53) | (cf_rc2 & (ch_c6_52 ^ ch_s6_53))); // final carry bit3
    assign cf_rs4 = (ch_c6_53 ^ cf_s6_54 ^ cf_rc3); // final sum  bit4
    assign cf_rc4 = ((ch_c6_53 & cf_s6_54) | (cf_rc3 & (ch_c6_53 ^ cf_s6_54))); // final carry bit4
    assign cf_rs5 = (cf_c6_54 ^ 1'b0 ^ cf_rc4); // final sum  bit5
    assign cf_rc5 = ((cf_c6_54 & 1'b0) | (cf_rc4 & (cf_c6_54 ^ 1'b0))); // final carry bit5
    assign cf_rs6 = (1'b0 ^ 1'b0 ^ cf_rc5); // final sum  bit6
    assign cf_rc6 = ((1'b0 & 1'b0) | (cf_rc5 & (1'b0 ^ 1'b0))); // final carry bit6

    assign popcnt[0] = cf_rs0;
    assign popcnt[1] = cf_rs1;
    assign popcnt[2] = cf_rs2;
    assign popcnt[3] = cf_rs3;
    assign popcnt[4] = cf_rs4;
    assign popcnt[5] = cf_rs5;
    assign popcnt[6] = cf_rs6;

endmodule
