// ============================================================================
// popcount_compressor_d16 — popcount 4:2 compressor（cin/cout 列间链）+FA/HA 归约 (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[15:0]，输出: popcnt[4:0]（NBITS=clog2(16+1)，结果 0..16）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 5 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 16
// ============================================================================

module popcount_compressor_d16 (
    input  logic [15:0] din,
    output logic [4:0] popcnt
);

    // ---- 中间信号 ----------------
    logic cs_s1_1_0, cs_co_1_0, cs_s_1_0, cs_c_1_0;
    logic cf_s1_1, cf_c1_1, cf_s1_2, cf_c1_2;
    logic cf_s1_3, cf_c1_3, cf_s1_4, cf_c1_4;
    logic cs_s1_2_5, cs_co_2_5, cs_s_2_5, cs_c_2_5;
    logic cs_s1_2_6, cs_co_2_6, cs_s_2_6, cs_c_2_6;
    logic ch_s2_7, ch_c2_7, ch_s3_8, ch_c3_8;
    logic cf_s3_9, cf_c3_9, cf_s3_10, cf_c3_10;

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
    assign cs_s1_2_5 = (cs_s_1_0 ^ cf_s1_1 ^ 1'b0); // 4:2 s1  w=0
    assign cs_co_2_5 = ((cs_s_1_0 & cf_s1_1) | (cs_s_1_0 & 1'b0) | (cf_s1_1 & 1'b0)); // 4:2 cout w=1
    assign cs_s_2_5 = (cs_s1_2_5 ^ cf_s1_2 ^ cf_s1_3); // 4:2 sum  w=0
    assign cs_c_2_5 = ((cs_s1_2_5 & cf_s1_2) | (cs_s1_2_5 & cf_s1_3) | (cf_s1_2 & cf_s1_3)); // 4:2 carry w=1
    assign cs_s1_2_6 = (cs_c_1_0 ^ cs_co_1_0 ^ cs_co_2_5); // 4:2 s1  w=1
    assign cs_co_2_6 = ((cs_c_1_0 & cs_co_1_0) | (cs_c_1_0 & cs_co_2_5) | (cs_co_1_0 & cs_co_2_5)); // 4:2 cout w=2
    assign cs_s_2_6 = (cs_s1_2_6 ^ cf_c1_1 ^ cf_c1_2); // 4:2 sum  w=1
    assign cs_c_2_6 = ((cs_s1_2_6 & cf_c1_1) | (cs_s1_2_6 & cf_c1_2) | (cf_c1_1 & cf_c1_2)); // 4:2 carry w=2
    assign ch_s2_7 = (cf_c1_3 ^ cf_c1_4); // HA sum  w=1
    assign ch_c2_7 = (cf_c1_3 & cf_c1_4); // HA carry w=2
    assign ch_s3_8 = (cs_s_2_5 ^ cf_s1_4); // HA sum  w=0
    assign ch_c3_8 = (cs_s_2_5 & cf_s1_4); // HA carry w=1
    assign cf_s3_9 = (cs_c_2_5 ^ cs_s_2_6 ^ ch_s2_7); // FA sum  w=1
    assign cf_c3_9 = ((cs_c_2_5 & cs_s_2_6) | (cs_c_2_5 & ch_s2_7) | (cs_s_2_6 & ch_s2_7)); // FA carry w=2
    assign cf_s3_10 = (cs_c_2_6 ^ cs_co_2_6 ^ ch_c2_7); // FA sum  w=2
    assign cf_c3_10 = ((cs_c_2_6 & cs_co_2_6) | (cs_c_2_6 & ch_c2_7) | (cs_co_2_6 & ch_c2_7)); // FA carry w=3

    assign cf_rs0 = (ch_s3_8 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign cf_rc0 = ((ch_s3_8 & 1'b0) | (1'b0 & (ch_s3_8 ^ 1'b0))); // final carry bit0
    assign cf_rs1 = (ch_c3_8 ^ cf_s3_9 ^ cf_rc0); // final sum  bit1
    assign cf_rc1 = ((ch_c3_8 & cf_s3_9) | (cf_rc0 & (ch_c3_8 ^ cf_s3_9))); // final carry bit1
    assign cf_rs2 = (cf_c3_9 ^ cf_s3_10 ^ cf_rc1); // final sum  bit2
    assign cf_rc2 = ((cf_c3_9 & cf_s3_10) | (cf_rc1 & (cf_c3_9 ^ cf_s3_10))); // final carry bit2
    assign cf_rs3 = (cf_c3_10 ^ 1'b0 ^ cf_rc2); // final sum  bit3
    assign cf_rc3 = ((cf_c3_10 & 1'b0) | (cf_rc2 & (cf_c3_10 ^ 1'b0))); // final carry bit3
    assign cf_rs4 = (1'b0 ^ 1'b0 ^ cf_rc3); // final sum  bit4
    assign cf_rc4 = ((1'b0 & 1'b0) | (cf_rc3 & (1'b0 ^ 1'b0))); // final carry bit4

    assign popcnt[0] = cf_rs0;
    assign popcnt[1] = cf_rs1;
    assign popcnt[2] = cf_rs2;
    assign popcnt[3] = cf_rs3;
    assign popcnt[4] = cf_rs4;

endmodule
