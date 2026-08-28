// ============================================================================
// popcount_compressor_d32 — popcount 4:2 compressor（cin/cout 列间链）+FA/HA 归约 (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[31:0]，输出: popcnt[5:0]（NBITS=clog2(32+1)，结果 0..32）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 6 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 32
// ============================================================================

module popcount_compressor_d32 (
    input  logic [31:0] din,
    output logic [5:0] popcnt
);

    // ---- 中间信号 ----------------
    logic cs_s1_1_0, cs_co_1_0, cs_s_1_0, cs_c_1_0;
    logic cf_s1_1, cf_c1_1, cf_s1_2, cf_c1_2;
    logic cf_s1_3, cf_c1_3, cf_s1_4, cf_c1_4;
    logic cf_s1_5, cf_c1_5, cf_s1_6, cf_c1_6;
    logic cf_s1_7, cf_c1_7, cf_s1_8, cf_c1_8;
    logic cf_s1_9, cf_c1_9, cs_s1_2_10, cs_co_2_10;
    logic cs_s_2_10, cs_c_2_10, cs_s1_2_11, cs_co_2_11;
    logic cs_s_2_11, cs_c_2_11, cf_s2_12, cf_c2_12;
    logic cf_s2_13, cf_c2_13, cf_s2_14, cf_c2_14;
    logic cf_s2_15, cf_c2_15, cs_s1_3_16, cs_co_3_16;
    logic cs_s_3_16, cs_c_3_16, cs_s1_3_17, cs_co_3_17;
    logic cs_s_3_17, cs_c_3_17, cs_s1_3_18, cs_co_3_18;
    logic cs_s_3_18, cs_c_3_18, cf_s3_19, cf_c3_19;
    logic cf_s4_20, cf_c4_20, cf_s4_21, cf_c4_21;
    logic ch_s4_22, ch_c4_22;

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
    assign cs_s1_2_10 = (cs_s_1_0 ^ cf_s1_1 ^ 1'b0); // 4:2 s1  w=0
    assign cs_co_2_10 = ((cs_s_1_0 & cf_s1_1) | (cs_s_1_0 & 1'b0) | (cf_s1_1 & 1'b0)); // 4:2 cout w=1
    assign cs_s_2_10 = (cs_s1_2_10 ^ cf_s1_2 ^ cf_s1_3); // 4:2 sum  w=0
    assign cs_c_2_10 = ((cs_s1_2_10 & cf_s1_2) | (cs_s1_2_10 & cf_s1_3) | (cf_s1_2 & cf_s1_3)); // 4:2 carry w=1
    assign cs_s1_2_11 = (cs_c_1_0 ^ cs_co_1_0 ^ cs_co_2_10); // 4:2 s1  w=1
    assign cs_co_2_11 = ((cs_c_1_0 & cs_co_1_0) | (cs_c_1_0 & cs_co_2_10) | (cs_co_1_0 & cs_co_2_10)); // 4:2 cout w=2
    assign cs_s_2_11 = (cs_s1_2_11 ^ cf_c1_1 ^ cf_c1_2); // 4:2 sum  w=1
    assign cs_c_2_11 = ((cs_s1_2_11 & cf_c1_1) | (cs_s1_2_11 & cf_c1_2) | (cf_c1_1 & cf_c1_2)); // 4:2 carry w=2
    assign cf_s2_12 = (cf_s1_4 ^ cf_s1_5 ^ cf_s1_6); // FA sum  w=0
    assign cf_c2_12 = ((cf_s1_4 & cf_s1_5) | (cf_s1_4 & cf_s1_6) | (cf_s1_5 & cf_s1_6)); // FA carry w=1
    assign cf_s2_13 = (cf_s1_7 ^ cf_s1_8 ^ cf_s1_9); // FA sum  w=0
    assign cf_c2_13 = ((cf_s1_7 & cf_s1_8) | (cf_s1_7 & cf_s1_9) | (cf_s1_8 & cf_s1_9)); // FA carry w=1
    assign cf_s2_14 = (cf_c1_3 ^ cf_c1_4 ^ cf_c1_5); // FA sum  w=1
    assign cf_c2_14 = ((cf_c1_3 & cf_c1_4) | (cf_c1_3 & cf_c1_5) | (cf_c1_4 & cf_c1_5)); // FA carry w=2
    assign cf_s2_15 = (cf_c1_6 ^ cf_c1_7 ^ cf_c1_8); // FA sum  w=1
    assign cf_c2_15 = ((cf_c1_6 & cf_c1_7) | (cf_c1_6 & cf_c1_8) | (cf_c1_7 & cf_c1_8)); // FA carry w=2
    assign cs_s1_3_16 = (cs_s_2_10 ^ cf_s2_12 ^ 1'b0); // 4:2 s1  w=0
    assign cs_co_3_16 = ((cs_s_2_10 & cf_s2_12) | (cs_s_2_10 & 1'b0) | (cf_s2_12 & 1'b0)); // 4:2 cout w=1
    assign cs_s_3_16 = (cs_s1_3_16 ^ cf_s2_13 ^ din[31]); // 4:2 sum  w=0
    assign cs_c_3_16 = ((cs_s1_3_16 & cf_s2_13) | (cs_s1_3_16 & din[31]) | (cf_s2_13 & din[31])); // 4:2 carry w=1
    assign cs_s1_3_17 = (cs_c_2_10 ^ cs_s_2_11 ^ cs_co_3_16); // 4:2 s1  w=1
    assign cs_co_3_17 = ((cs_c_2_10 & cs_s_2_11) | (cs_c_2_10 & cs_co_3_16) | (cs_s_2_11 & cs_co_3_16)); // 4:2 cout w=2
    assign cs_s_3_17 = (cs_s1_3_17 ^ cf_c2_12 ^ cf_c2_13); // 4:2 sum  w=1
    assign cs_c_3_17 = ((cs_s1_3_17 & cf_c2_12) | (cs_s1_3_17 & cf_c2_13) | (cf_c2_12 & cf_c2_13)); // 4:2 carry w=2
    assign cs_s1_3_18 = (cs_c_2_11 ^ cs_co_2_11 ^ cs_co_3_17); // 4:2 s1  w=2
    assign cs_co_3_18 = ((cs_c_2_11 & cs_co_2_11) | (cs_c_2_11 & cs_co_3_17) | (cs_co_2_11 & cs_co_3_17)); // 4:2 cout w=3
    assign cs_s_3_18 = (cs_s1_3_18 ^ cf_c2_14 ^ cf_c2_15); // 4:2 sum  w=2
    assign cs_c_3_18 = ((cs_s1_3_18 & cf_c2_14) | (cs_s1_3_18 & cf_c2_15) | (cf_c2_14 & cf_c2_15)); // 4:2 carry w=3
    assign cf_s3_19 = (cf_s2_14 ^ cf_s2_15 ^ cf_c1_9); // FA sum  w=1
    assign cf_c3_19 = ((cf_s2_14 & cf_s2_15) | (cf_s2_14 & cf_c1_9) | (cf_s2_15 & cf_c1_9)); // FA carry w=2
    assign cf_s4_20 = (cs_c_3_16 ^ cs_s_3_17 ^ cf_s3_19); // FA sum  w=1
    assign cf_c4_20 = ((cs_c_3_16 & cs_s_3_17) | (cs_c_3_16 & cf_s3_19) | (cs_s_3_17 & cf_s3_19)); // FA carry w=2
    assign cf_s4_21 = (cs_c_3_17 ^ cs_s_3_18 ^ cf_c3_19); // FA sum  w=2
    assign cf_c4_21 = ((cs_c_3_17 & cs_s_3_18) | (cs_c_3_17 & cf_c3_19) | (cs_s_3_18 & cf_c3_19)); // FA carry w=3
    assign ch_s4_22 = (cs_c_3_18 ^ cs_co_3_18); // HA sum  w=3
    assign ch_c4_22 = (cs_c_3_18 & cs_co_3_18); // HA carry w=4

    assign cf_rs0 = (cs_s_3_16 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign cf_rc0 = ((cs_s_3_16 & 1'b0) | (1'b0 & (cs_s_3_16 ^ 1'b0))); // final carry bit0
    assign cf_rs1 = (cf_s4_20 ^ 1'b0 ^ cf_rc0); // final sum  bit1
    assign cf_rc1 = ((cf_s4_20 & 1'b0) | (cf_rc0 & (cf_s4_20 ^ 1'b0))); // final carry bit1
    assign cf_rs2 = (cf_c4_20 ^ cf_s4_21 ^ cf_rc1); // final sum  bit2
    assign cf_rc2 = ((cf_c4_20 & cf_s4_21) | (cf_rc1 & (cf_c4_20 ^ cf_s4_21))); // final carry bit2
    assign cf_rs3 = (cf_c4_21 ^ ch_s4_22 ^ cf_rc2); // final sum  bit3
    assign cf_rc3 = ((cf_c4_21 & ch_s4_22) | (cf_rc2 & (cf_c4_21 ^ ch_s4_22))); // final carry bit3
    assign cf_rs4 = (ch_c4_22 ^ 1'b0 ^ cf_rc3); // final sum  bit4
    assign cf_rc4 = ((ch_c4_22 & 1'b0) | (cf_rc3 & (ch_c4_22 ^ 1'b0))); // final carry bit4
    assign cf_rs5 = (1'b0 ^ 1'b0 ^ cf_rc4); // final sum  bit5
    assign cf_rc5 = ((1'b0 & 1'b0) | (cf_rc4 & (1'b0 ^ 1'b0))); // final carry bit5

    assign popcnt[0] = cf_rs0;
    assign popcnt[1] = cf_rs1;
    assign popcnt[2] = cf_rs2;
    assign popcnt[3] = cf_rs3;
    assign popcnt[4] = cf_rs4;
    assign popcnt[5] = cf_rs5;

endmodule
