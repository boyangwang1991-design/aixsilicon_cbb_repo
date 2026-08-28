// ============================================================================
// popcount_compressor_d8 — popcount 4:2 compressor（cin/cout 列间链）+FA/HA 归约 (SEL-014)，由 tools/gen_popcount.py 生成
// 输入: din[7:0]，输出: popcnt[3:0]（NBITS=clog2(8+1)，结果 0..8）
// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2
//       → 4 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。
// 重新生成: python3 tools/gen_popcount.py --widths 8
// ============================================================================

module popcount_compressor_d8 (
    input  logic [7:0] din,
    output logic [3:0] popcnt
);

    // ---- 中间信号 ----------------
    logic cs_s1_1_0, cs_co_1_0, cs_s_1_0, cs_c_1_0;
    logic cf_s1_1, cf_c1_1, cf_s2_2, cf_c2_2;
    logic cf_s2_3, cf_c2_3;

    // ---- 归约 / 收尾 ----------------

    assign cs_s1_1_0 = (din[0] ^ din[1] ^ 1'b0); // 4:2 s1  w=0
    assign cs_co_1_0 = ((din[0] & din[1]) | (din[0] & 1'b0) | (din[1] & 1'b0)); // 4:2 cout w=1
    assign cs_s_1_0 = (cs_s1_1_0 ^ din[2] ^ din[3]); // 4:2 sum  w=0
    assign cs_c_1_0 = ((cs_s1_1_0 & din[2]) | (cs_s1_1_0 & din[3]) | (din[2] & din[3])); // 4:2 carry w=1
    assign cf_s1_1 = (din[4] ^ din[5] ^ din[6]); // FA sum  w=0
    assign cf_c1_1 = ((din[4] & din[5]) | (din[4] & din[6]) | (din[5] & din[6])); // FA carry w=1
    assign cf_s2_2 = (cs_s_1_0 ^ cf_s1_1 ^ din[7]); // FA sum  w=0
    assign cf_c2_2 = ((cs_s_1_0 & cf_s1_1) | (cs_s_1_0 & din[7]) | (cf_s1_1 & din[7])); // FA carry w=1
    assign cf_s2_3 = (cs_c_1_0 ^ cs_co_1_0 ^ cf_c1_1); // FA sum  w=1
    assign cf_c2_3 = ((cs_c_1_0 & cs_co_1_0) | (cs_c_1_0 & cf_c1_1) | (cs_co_1_0 & cf_c1_1)); // FA carry w=2

    assign cf_rs0 = (cf_s2_2 ^ 1'b0 ^ 1'b0); // final sum  bit0
    assign cf_rc0 = ((cf_s2_2 & 1'b0) | (1'b0 & (cf_s2_2 ^ 1'b0))); // final carry bit0
    assign cf_rs1 = (cf_c2_2 ^ cf_s2_3 ^ cf_rc0); // final sum  bit1
    assign cf_rc1 = ((cf_c2_2 & cf_s2_3) | (cf_rc0 & (cf_c2_2 ^ cf_s2_3))); // final carry bit1
    assign cf_rs2 = (cf_c2_3 ^ 1'b0 ^ cf_rc1); // final sum  bit2
    assign cf_rc2 = ((cf_c2_3 & 1'b0) | (cf_rc1 & (cf_c2_3 ^ 1'b0))); // final carry bit2
    assign cf_rs3 = (1'b0 ^ 1'b0 ^ cf_rc2); // final sum  bit3
    assign cf_rc3 = ((1'b0 & 1'b0) | (cf_rc2 & (1'b0 ^ 1'b0))); // final carry bit3

    assign popcnt[0] = cf_rs0;
    assign popcnt[1] = cf_rs1;
    assign popcnt[2] = cf_rs2;
    assign popcnt[3] = cf_rs3;

endmodule
