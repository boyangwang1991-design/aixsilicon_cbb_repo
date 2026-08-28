// ===========================================================================
// popcount_compressed.sv — Wallace/Dadda 显式 FA 网表（gen_schedule.py 产物）
// ===========================================================================
`ifndef POPCOUNT_COMPRESSED_SVH
`define POPCOUNT_COMPRESSED_SVH

// ---------------------------------------------------------------------------
// popcount_impl_wallace — 显式 FA 网表核（gen_schedule.py 物化 W=64，勿手改）
// 每个 assign = 一个真全加器；收尾为各列 dot 按常量移位后的连加。
// ---------------------------------------------------------------------------
module popcount_impl_wallace #(
    parameter int INPUT_WIDTH = 64,
    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1)
) (
    input  logic [INPUT_WIDTH-1:0] data_i,
    output logic [CNT_W-1:0]       cnt_o
);
    generate
        if (INPUT_WIDTH != 64) begin : g_fixed_w
            $error("popcount_impl_wallace: 生成版本仅物化 INPUT_WIDTH=64");
        end
    endgenerate
    logic fa_c_10;
    logic fa_c_100;
    logic fa_c_102;
    logic fa_c_104;
    logic fa_c_106;
    logic fa_c_108;
    logic fa_c_110;
    logic fa_c_112;
    logic fa_c_114;
    logic fa_c_12;
    logic fa_c_14;
    logic fa_c_16;
    logic fa_c_18;
    logic fa_c_2;
    logic fa_c_20;
    logic fa_c_22;
    logic fa_c_24;
    logic fa_c_26;
    logic fa_c_28;
    logic fa_c_30;
    logic fa_c_32;
    logic fa_c_34;
    logic fa_c_36;
    logic fa_c_38;
    logic fa_c_4;
    logic fa_c_40;
    logic fa_c_42;
    logic fa_c_44;
    logic fa_c_46;
    logic fa_c_48;
    logic fa_c_50;
    logic fa_c_52;
    logic fa_c_54;
    logic fa_c_56;
    logic fa_c_58;
    logic fa_c_6;
    logic fa_c_60;
    logic fa_c_62;
    logic fa_c_64;
    logic fa_c_66;
    logic fa_c_68;
    logic fa_c_70;
    logic fa_c_72;
    logic fa_c_74;
    logic fa_c_76;
    logic fa_c_78;
    logic fa_c_8;
    logic fa_c_80;
    logic fa_c_82;
    logic fa_c_84;
    logic fa_c_86;
    logic fa_c_88;
    logic fa_c_90;
    logic fa_c_92;
    logic fa_c_94;
    logic fa_c_96;
    logic fa_c_98;
    logic fa_s_1;
    logic fa_s_101;
    logic fa_s_103;
    logic fa_s_105;
    logic fa_s_107;
    logic fa_s_109;
    logic fa_s_11;
    logic fa_s_111;
    logic fa_s_113;
    logic fa_s_13;
    logic fa_s_15;
    logic fa_s_17;
    logic fa_s_19;
    logic fa_s_21;
    logic fa_s_23;
    logic fa_s_25;
    logic fa_s_27;
    logic fa_s_29;
    logic fa_s_3;
    logic fa_s_31;
    logic fa_s_33;
    logic fa_s_35;
    logic fa_s_37;
    logic fa_s_39;
    logic fa_s_41;
    logic fa_s_43;
    logic fa_s_45;
    logic fa_s_47;
    logic fa_s_49;
    logic fa_s_5;
    logic fa_s_51;
    logic fa_s_53;
    logic fa_s_55;
    logic fa_s_57;
    logic fa_s_59;
    logic fa_s_61;
    logic fa_s_63;
    logic fa_s_65;
    logic fa_s_67;
    logic fa_s_69;
    logic fa_s_7;
    logic fa_s_71;
    logic fa_s_73;
    logic fa_s_75;
    logic fa_s_77;
    logic fa_s_79;
    logic fa_s_81;
    logic fa_s_83;
    logic fa_s_85;
    logic fa_s_87;
    logic fa_s_89;
    logic fa_s_9;
    logic fa_s_91;
    logic fa_s_93;
    logic fa_s_95;
    logic fa_s_97;
    logic fa_s_99;

    assign { fa_c_2, fa_s_1 } = data_i[0] + data_i[1] + data_i[2];
    assign { fa_c_4, fa_s_3 } = data_i[3] + data_i[4] + data_i[5];
    assign { fa_c_6, fa_s_5 } = data_i[6] + data_i[7] + data_i[8];
    assign { fa_c_8, fa_s_7 } = data_i[9] + data_i[10] + data_i[11];
    assign { fa_c_10, fa_s_9 } = data_i[12] + data_i[13] + data_i[14];
    assign { fa_c_12, fa_s_11 } = data_i[15] + data_i[16] + data_i[17];
    assign { fa_c_14, fa_s_13 } = data_i[18] + data_i[19] + data_i[20];
    assign { fa_c_16, fa_s_15 } = data_i[21] + data_i[22] + data_i[23];
    assign { fa_c_18, fa_s_17 } = data_i[24] + data_i[25] + data_i[26];
    assign { fa_c_20, fa_s_19 } = data_i[27] + data_i[28] + data_i[29];
    assign { fa_c_22, fa_s_21 } = data_i[30] + data_i[31] + data_i[32];
    assign { fa_c_24, fa_s_23 } = data_i[33] + data_i[34] + data_i[35];
    assign { fa_c_26, fa_s_25 } = data_i[36] + data_i[37] + data_i[38];
    assign { fa_c_28, fa_s_27 } = data_i[39] + data_i[40] + data_i[41];
    assign { fa_c_30, fa_s_29 } = data_i[42] + data_i[43] + data_i[44];
    assign { fa_c_32, fa_s_31 } = data_i[45] + data_i[46] + data_i[47];
    assign { fa_c_34, fa_s_33 } = data_i[48] + data_i[49] + data_i[50];
    assign { fa_c_36, fa_s_35 } = data_i[51] + data_i[52] + data_i[53];
    assign { fa_c_38, fa_s_37 } = data_i[54] + data_i[55] + data_i[56];
    assign { fa_c_40, fa_s_39 } = data_i[57] + data_i[58] + data_i[59];
    assign { fa_c_42, fa_s_41 } = data_i[60] + data_i[61] + data_i[62];
    assign { fa_c_44, fa_s_43 } = fa_c_2 + fa_c_4 + fa_c_6;
    assign { fa_c_46, fa_s_45 } = fa_c_8 + fa_c_10 + fa_c_12;
    assign { fa_c_48, fa_s_47 } = fa_c_14 + fa_c_16 + fa_c_18;
    assign { fa_c_50, fa_s_49 } = fa_c_20 + fa_c_22 + fa_c_24;
    assign { fa_c_52, fa_s_51 } = fa_c_26 + fa_c_28 + fa_c_30;
    assign { fa_c_54, fa_s_53 } = fa_c_32 + fa_c_34 + fa_c_36;
    assign { fa_c_56, fa_s_55 } = fa_c_38 + fa_c_40 + fa_c_42;
    assign { fa_c_58, fa_s_57 } = fa_c_44 + fa_c_46 + fa_c_48;
    assign { fa_c_60, fa_s_59 } = fa_c_50 + fa_c_52 + fa_c_54;
    assign { fa_c_62, fa_s_61 } = fa_s_1 + fa_s_3 + fa_s_5;
    assign { fa_c_64, fa_s_63 } = fa_s_7 + fa_s_9 + fa_s_11;
    assign { fa_c_66, fa_s_65 } = fa_s_13 + fa_s_15 + fa_s_17;
    assign { fa_c_68, fa_s_67 } = fa_s_19 + fa_s_21 + fa_s_23;
    assign { fa_c_70, fa_s_69 } = fa_s_25 + fa_s_27 + fa_s_29;
    assign { fa_c_72, fa_s_71 } = fa_s_31 + fa_s_33 + fa_s_35;
    assign { fa_c_74, fa_s_73 } = fa_s_37 + fa_s_39 + fa_s_41;
    assign { fa_c_76, fa_s_75 } = fa_c_62 + fa_c_64 + fa_c_66;
    assign { fa_c_78, fa_s_77 } = fa_c_68 + fa_c_70 + fa_c_72;
    assign { fa_c_80, fa_s_79 } = fa_c_74 + fa_s_43 + fa_s_45;
    assign { fa_c_82, fa_s_81 } = fa_s_47 + fa_s_49 + fa_s_51;
    assign { fa_c_84, fa_s_83 } = fa_c_76 + fa_c_78 + fa_c_80;
    assign { fa_c_86, fa_s_85 } = fa_c_82 + fa_s_57 + fa_s_59;
    assign { fa_c_88, fa_s_87 } = fa_c_84 + fa_c_86 + fa_c_58;
    assign { fa_c_90, fa_s_89 } = fa_s_61 + fa_s_63 + fa_s_65;
    assign { fa_c_92, fa_s_91 } = fa_s_67 + fa_s_69 + fa_s_71;
    assign { fa_c_94, fa_s_93 } = fa_c_90 + fa_c_92 + fa_s_75;
    assign { fa_c_96, fa_s_95 } = fa_s_77 + fa_s_79 + fa_s_81;
    assign { fa_c_98, fa_s_97 } = fa_c_94 + fa_c_96 + fa_s_83;
    assign { fa_c_100, fa_s_99 } = fa_c_98 + fa_s_87 + fa_c_60;
    assign { fa_c_102, fa_s_101 } = fa_s_89 + fa_s_91 + fa_s_73;
    assign { fa_c_104, fa_s_103 } = fa_c_102 + fa_s_93 + fa_s_95;
    assign { fa_c_106, fa_s_105 } = fa_c_104 + fa_s_97 + fa_s_85;
    assign { fa_c_108, fa_s_107 } = fa_s_103 + fa_s_53 + fa_s_55;
    assign { fa_c_110, fa_s_109 } = fa_c_108 + fa_s_105 + fa_c_56;
    assign { fa_c_112, fa_s_111 } = fa_c_110 + fa_c_106 + fa_s_99;
    assign { fa_c_114, fa_s_113 } = fa_c_112 + fa_c_100 + fa_c_88;

    // ---- 终态：各列剩余 dot 常量左移连加（权重 2^col；CNT_W 位宽无溢出）----
    wire [CNT_W-1:0] term_0 = fa_s_101;
    wire [CNT_W-1:0] term_1 = data_i[63];
    wire [CNT_W-1:0] term_2 = fa_s_107 << 1;
    wire [CNT_W-1:0] term_3 = fa_s_109 << 2;
    wire [CNT_W-1:0] term_4 = fa_s_111 << 3;
    wire [CNT_W-1:0] term_5 = fa_s_113 << 4;
    wire [CNT_W-1:0] term_6 = fa_c_114 << 5;
    assign cnt_o = term_0
                 + term_1
                 + term_2
                 + term_3
                 + term_4
                 + term_5
                 + term_6;
endmodule`endif
