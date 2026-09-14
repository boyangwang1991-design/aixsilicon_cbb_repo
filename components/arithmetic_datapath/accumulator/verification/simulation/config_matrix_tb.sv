// ============================================================================
// config_matrix_tb.sv — G5 配置空间验证（RTL 功能仿真 × 配置矩阵）
// 由 run_config_matrix_sim.sh 以 +define+PARAM=VALUE 注入配置编译本 TB。
// 检查项（语义与 SIGNED 匹配）：
//   · 复位清零（rst_ni 保持多个周期确保生效）
//   · 连续加 +1 前缀和（无符号视角；signed 模式下用足够宽的 +1 补码，
//     IW=1 时跳过前缀和检查——signed 1 位无法表示 +1）
//   · 减法（ADD_SUB 且 LOAD_EN）：LOAD 20 - 4 → 16
//   · 回绕（WRAP 且 LOAD_EN）：LOAD 全1 + 1 → 0
//   · 隔离等价（ISO=0 vs 1 同输入逐拍一致）
// 失败打印 CONFIG_FAIL；脚本据 grep 判定。
// ============================================================================
`timescale 1ns/1ps

module config_matrix_tb;
    localparam int T_IW  = `ifdef INPUT_WIDTH  `INPUT_WIDTH  `else 16 `endif;
    localparam int T_AW  = `ifdef ACC_WIDTH    `ACC_WIDTH    `else 32 `endif;
    localparam int T_SGN = `ifdef SIGNED       `SIGNED       `else 1  `endif;
    localparam int T_OP  = `ifdef OP_MODE      `OP_MODE      `else 0  `endif;
    localparam int T_OVF = `ifdef OVERFLOW_MODE `OVERFLOW_MODE `else 0 `endif;
    localparam int T_LD  = `ifdef LOAD_EN      `LOAD_EN      `else 1  `endif;
    localparam int T_ST  = `ifdef STATUS_EN    `STATUS_EN    `else 1  `endif;
    localparam int T_ISO = `ifdef ISO          `ISO          `else 0  `endif;

    logic clk_i, rst_ni;
    logic ce_i, clear_i, load_i, valid_i, sub_i, status_clear_i;
    logic [255:0] load_data_i, data_i;
    logic [255:0] acc_o, acc_o_iso;
    logic update_o, overflow_event_o, overflow_sticky_o;
    logic update_o_iso, overflow_event_o_iso, overflow_sticky_o_iso;

    accumulator #(
        .INPUT_WIDTH(T_IW), .ACC_WIDTH(T_AW), .SIGNED(T_SGN[0]),
        .OP_MODE(T_OP), .OVERFLOW_MODE(T_OVF),
        .LOAD_EN(T_LD[0]), .STATUS_EN(T_ST[0]), .OPERAND_ISOLATION(T_ISO)
    ) dut (
        .clk_i(clk_i), .rst_ni(rst_ni), .ce_i(ce_i), .clear_i(clear_i),
        .load_i(load_i), .load_data_i(load_data_i[T_AW-1:0]),
        .valid_i(valid_i), .data_i(data_i[T_IW-1:0]), .sub_i(sub_i),
        .status_clear_i(status_clear_i),
        .acc_o(acc_o[T_AW-1:0]), .update_o(update_o),
        .overflow_event_o(overflow_event_o), .overflow_sticky_o(overflow_sticky_o));

    accumulator #(
        .INPUT_WIDTH(T_IW), .ACC_WIDTH(T_AW), .SIGNED(T_SGN[0]),
        .OP_MODE(T_OP), .OVERFLOW_MODE(T_OVF),
        .LOAD_EN(T_LD[0]), .STATUS_EN(T_ST[0]), .OPERAND_ISOLATION(1)
    ) dut_iso (
        .clk_i(clk_i), .rst_ni(rst_ni), .ce_i(ce_i), .clear_i(clear_i),
        .load_i(load_i), .load_data_i(load_data_i[T_AW-1:0]),
        .valid_i(valid_i), .data_i(data_i[T_IW-1:0]), .sub_i(sub_i),
        .status_clear_i(status_clear_i),
        .acc_o(acc_o_iso[T_AW-1:0]), .update_o(update_o_iso),
        .overflow_event_o(overflow_event_o_iso), .overflow_sticky_o(overflow_sticky_o_iso));

    initial clk_i = 0;
    always #5 clk_i = ~clk_i;

    integer errors;
    initial begin
        integer i;
        errors = 0;
        rst_ni = 0; ce_i = 1; clear_i = 0; load_i = 0; load_data_i = 0;
        valid_i = 0; data_i = 0; sub_i = 0; status_clear_i = 0;
        // 复位保持 3 拍确保 DUT 在 rst_ni=0 的 posedge 被清零
        repeat (3) @(negedge clk_i);
        $display("[CM] cfg IW=%0d AW=%0d SGN=%0d OP=%0d OVF=%0d LD=%0d ST=%0d ISO=%0d",
                 T_IW, T_AW, T_SGN, T_OP, T_OVF, T_LD, T_ST, T_ISO);

        // 复位释放后 acc 应为 0
        rst_ni = 1; @(negedge clk_i);
        if (acc_o[T_AW-1:0] !== '0) begin
            errors++; $display("[CM] CONFIG_FAIL: reset acc=%0h exp=0", acc_o[T_AW-1:0]);
        end

        // 连续前缀和：OP_MODE=0 加 +1；OP_MODE=1 减 1（A-1 递减）；OP_MODE=2 用 sub=0 加 +1
        // signed 且 IW>=2 时 +1 可表示；IW=1 signed 时唯一非零输入是 -1（递减）
        begin
            logic use_sub;
            ce_i = 1; clear_i = 0; load_i = 0; valid_i = 1; status_clear_i = 0;
            use_sub = (T_OP == 1);
            sub_i = use_sub;
            if (T_OP == 2) sub_i = 0;   // ADD_SUB：sub=0 → 加
            if (T_SGN == 1 && T_IW == 1 && T_OP != 1) begin
                // IW=1 signed：+1 不可表示，输入 1'b1 解释为 -1（递减）
                data_i = T_IW'(1);
                @(negedge clk_i);
                if (acc_o[T_AW-1:0] !== {T_AW{1'b1}}) begin
                    errors++; $display("[CM] CONFIG_FAIL: iw1 add got=%0h exp=all1", acc_o[T_AW-1:0]);
                end
            end else begin
                for (i = 0; i < 8; i++) begin
                    data_i = T_IW'(1);
                    @(negedge clk_i);
                    if (use_sub) begin
                        // SUB_ONLY：A-1 → A 递减（0,-1,-2,...） = 2 的补码
                        if (acc_o[T_AW-1:0] !== T_AW'(0 - (i + 1))) begin
                            errors++; $display("[CM] CONFIG_FAIL: sub prefix i=%0d got=%0h exp=%0h",
                                               i, acc_o[T_AW-1:0], 0-(i+1));
                        end
                    end else begin
                        if (acc_o[T_AW-1:0] !== T_AW'(i + 1)) begin
                            errors++; $display("[CM] CONFIG_FAIL: prefix sum i=%0d got=%0h exp=%0h",
                                               i, acc_o[T_AW-1:0], i+1);
                        end
                    end
                    if (acc_o[T_AW-1:0] !== acc_o_iso[T_AW-1:0]) begin
                        errors++; $display("[CM] CONFIG_FAIL: iso mismatch i=%0d", i);
                    end
                end
            end
        end

        // 减法（ADD_SUB 且 LOAD_EN）：LOAD 20 后 -4 → 16
        if (T_OP == 2 && T_LD == 1) begin
            load_i = 1; load_data_i = T_AW'(20); valid_i = 0;
            @(negedge clk_i);
            load_i = 0; valid_i = 1; data_i = T_IW'(4); sub_i = 1;
            @(negedge clk_i);
            if (acc_o[T_AW-1:0] !== T_AW'(16)) begin
                errors++; $display("[CM] CONFIG_FAIL: sub got=%0h exp=16", acc_o[T_AW-1:0]);
            end
            if (acc_o[T_AW-1:0] !== acc_o_iso[T_AW-1:0]) begin
                errors++; $display("[CM] CONFIG_FAIL: iso mismatch sub");
            end
        end

        // 回绕（WRAP 且 LOAD_EN 且非 signed-iw1 冲突）：
        //   OP_MODE=0/2 加 +1：LOAD 全1 + 1 → 0
        //   OP_MODE=1 减 1：LOAD 0 后 -1 → 全1（下溢回绕）
        if (T_LD == 1 && T_OVF == 0 && !(T_SGN == 1 && T_IW == 1)) begin
            if (T_OP == 1) begin
                // SUB_ONLY：LOAD 0 后 -1 → 全1（下溢回绕）
                load_i = 1; load_data_i = '0; valid_i = 0; sub_i = 1;
                @(negedge clk_i);
                load_i = 0; valid_i = 1; data_i = T_IW'(1);
                @(negedge clk_i);
                if (acc_o[T_AW-1:0] !== {T_AW{1'b1}}) begin
                    errors++; $display("[CM] CONFIG_FAIL: sub wrap got=%0h exp=all1", acc_o[T_AW-1:0]);
                end
            end else begin
                // ADD：LOAD 全1 + 1 → 0
                load_i = 1; load_data_i = {T_AW{1'b1}}; valid_i = 0; sub_i = 0;
                @(negedge clk_i);
                load_i = 0; valid_i = 1; data_i = T_IW'(1);
                @(negedge clk_i);
                if (acc_o[T_AW-1:0] !== '0) begin
                    errors++; $display("[CM] CONFIG_FAIL: wrap got=%0h exp=0", acc_o[T_AW-1:0]);
                end
            end
            if (acc_o[T_AW-1:0] !== acc_o_iso[T_AW-1:0]) begin
                errors++; $display("[CM] CONFIG_FAIL: iso mismatch wrap");
            end
        end

        if (errors == 0)
            $display("[CM] PASS config IW=%0d AW=%0d SGN=%0d OP=%0d OVF=%0d LD=%0d ST=%0d ISO=%0d",
                     T_IW, T_AW, T_SGN, T_OP, T_OVF, T_LD, T_ST, T_ISO);
        else
            $display("[CM] CONFIG_FAIL: %0d errors", errors);
        $finish;
    end
endmodule
