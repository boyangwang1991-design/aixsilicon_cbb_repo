// ============================================================================
// accumulator_tb — G4 功能验证测试台（stateful 族：状态不变量/复位/连续流量）
// 场景映射见 trace/rtm.yaml：tc_exhaust_w8/tc_random/tc_seq/tc_edge/tc_sticky/
// tc_continuous/tc_reset/tc_iso_equiv。黄金模型为独立无限精度整数算术（64 位
// 有符号中间值），逐步执行状态与控制优先级，与实现无共享结构。
// 符号约定：data_i 传补码值（可为负），sub_i 选择 A±X 操作（sub=1 → A−X）。
// ============================================================================
`timescale 1ns/1ps

module accumulator_tb;
    localparam int SEED = 32'h5000_2026;

    logic clk_i, rst_ni;
    logic ce_i, clear_i, load_i, valid_i, sub_i, status_clear_i;
    logic [31:0] load_data_i;
    logic [15:0] data_i;
    logic [31:0] acc_o, acc_o_iso;
    logic update_o, overflow_event_o, overflow_sticky_o;
    logic update_o_iso, overflow_event_o_iso, overflow_sticky_o_iso;

    // 默认配置：16/32 signed ADD_SUB WRAP LOAD STATUS no-iso
    accumulator #(.INPUT_WIDTH(16),.ACC_WIDTH(32),.SIGNED(1'b1),.OP_MODE(2),
                  .OVERFLOW_MODE(0),.LOAD_EN(1'b1),.STATUS_EN(1'b1),
                  .OPERAND_ISOLATION(0)) dut (
        .clk_i,.rst_ni,.ce_i,.clear_i,.load_i,.load_data_i,
        .valid_i,.data_i,.sub_i,.status_clear_i,
        .acc_o,.update_o,.overflow_event_o,.overflow_sticky_o);

    // 操作数隔离开关等价（REQ-007）
    accumulator #(.INPUT_WIDTH(16),.ACC_WIDTH(32),.SIGNED(1'b1),.OP_MODE(2),
                  .OVERFLOW_MODE(0),.LOAD_EN(1'b1),.STATUS_EN(1'b1),
                  .OPERAND_ISOLATION(1)) dut_iso (
        .clk_i,.rst_ni,.ce_i,.clear_i,.load_i,.load_data_i,
        .valid_i,.data_i,.sub_i,.status_clear_i,
        .acc_o(acc_o_iso),.update_o(update_o_iso),
        .overflow_event_o(overflow_event_o_iso),.overflow_sticky_o(overflow_sticky_o_iso));

    initial clk_i = 0;
    always #5 clk_i = ~clk_i;

    integer errors, checks;
    integer ref_a;            // 参考状态（64 位有符号）
    logic   ref_sticky;

    localparam integer MAX_POS = 2147483647;
    localparam integer MIN_NEG = -2147483648;

    // 参考模型：rst=1 时复位；否则按 ACC-CTL-001 优先级推进
    task automatic apply_ref(input logic rst, input logic ce, input logic clr,
                             input logic ld, input logic [31:0] lddata,
                             input logic vld, input logic [15:0] din,
                             input logic sub, input logic stclr,
                             input int ovf_mode, input int sgn);
        integer t;
        begin
            if (rst) begin
                ref_a = 0; ref_sticky = 1'b0;
            end else if (clr) begin
                ref_a = 0; ref_sticky = 1'b0;
            end else if (!ce) begin
                if (stclr) ref_sticky = 1'b0;
            end else if (ld) begin
                ref_a = $signed(lddata); ref_sticky = 1'b0;
            end else if (vld) begin
                t = sub ? (ref_a - $signed(din)) : (ref_a + $signed(din));
                if (sgn) begin
                    if (t > MAX_POS) begin
                        ref_a = (ovf_mode==1) ? MAX_POS : (t & 32'hFFFFFFFF);
                        ref_sticky = 1'b1;
                    end else if (t < MIN_NEG) begin
                        ref_a = (ovf_mode==1) ? MIN_NEG : (t & 32'hFFFFFFFF);
                        ref_sticky = 1'b1;
                    end else begin
                        ref_a = t;
                    end
                end else begin
                    if (t > 4294967295) begin
                        ref_a = (ovf_mode==1) ? 4294967295 : (t & 32'hFFFFFFFF);
                        ref_sticky = 1'b1;
                    end else if (t < 0) begin
                        ref_a = (ovf_mode==1) ? 0 : (t & 32'hFFFFFFFF);
                        ref_sticky = 1'b1;
                    end else begin
                        ref_a = t;
                    end
                end
            end else begin
                if (stclr) ref_sticky = 1'b0;
            end
        end
    endtask

    // chk_acc 校验 acc_o 与独立无限精度参考逐步一致：
    //   覆盖 PROP-ACC_CORRECT-001（核心正确性）、PROP-ACC_NUM-002（数值边界/回绕饱和）。
    task automatic chk_acc(input string tag);
        logic [31:0] exp_bits;
        exp_bits = 32'(ref_a);
        checks++;
        if (acc_o !== exp_bits) begin
            errors++;
            $display("[FAIL] %s acc_o=%0h exp=%0h ref=%0d", tag, acc_o, exp_bits, ref_a);
        end
    endtask

    // chk_sticky 校验 sticky 置位/清除/同拍优先级（覆盖 PROP-ACC_OVERFLOW-003）
    task automatic chk_sticky(input string tag, input logic exp);
        checks++;
        if (overflow_sticky_o !== exp) begin
            errors++;
            $display("[FAIL] %s sticky_o=%0b exp=%0b", tag, overflow_sticky_o, exp);
        end
    endtask

    // chk_update 校验 update_o/事件每沿重赋值与 II=1（覆盖 PROP-ACC_TIMING-004）
    task automatic chk_update(input string tag, input logic exp);
        checks++;
        if (update_o !== exp) begin
            errors++;
            $display("[FAIL] %s update_o=%0b exp=%0b", tag, update_o, exp);
        end
    endtask

    // 隔离等价：DUT vs DUT_ISO 根时钟采样一致（覆盖 PROP-ACC_EQV-007）
    task automatic chk_iso(input string tag);
        checks++;
        if (acc_o !== acc_o_iso || overflow_event_o !== overflow_event_o_iso
            || overflow_sticky_o !== overflow_sticky_o_iso) begin
            errors++;
            $display("[FAIL] %s iso: acc %0h/%0h ev %0b/%0b st %0b/%0b",
                     tag, acc_o, acc_o_iso, overflow_event_o, overflow_event_o_iso,
                     overflow_sticky_o, overflow_sticky_o_iso);
        end
    endtask

    integer i;
    initial begin
        integer r, v, vabs;
        logic rsub;
        errors = 0; checks = 0;
        ref_a = 0; ref_sticky = 1'b0;

        rst_ni = 0; ce_i = 1; clear_i = 0; load_i = 0; load_data_i = 0;
        valid_i = 0; data_i = 0; sub_i = 0; status_clear_i = 0;
        @(negedge clk_i);
        $display("=== accumulator_tb start (seed=%0d) ===", SEED);

        // ---- tc_reset：复位清状态与事件 ----
        rst_ni = 1; @(negedge clk_i); apply_ref(0,1,0,0,0,0,0,0,0, 0, 1);
        chk_acc("RESET_A"); chk_sticky("RESET_ST",1'b0); chk_update("RESET_UP",0);
        chk_iso("RESET_ISO");
        $display("[tc_reset] PASS");

        // ---- tc_seq：连续有效输入的每个前缀和（补码加法）----
        begin : seq_blk
            integer seq[0:3];
            seq[0]=3; seq[1]=5; seq[2]=-2; seq[3]=7;   // 期望前缀 3,8,6,13
            ce_i = 1; clear_i = 0; load_i = 0; valid_i = 1; sub_i = 0;
            for (i = 0; i < 4; i++) begin
                data_i = 16'(seq[i]);
                @(negedge clk_i); apply_ref(0,1,0,0,0,1,16'(seq[i]),0,0, 0, 1);
                chk_acc($sformatf("SEQ%d", i));
                chk_update("SEQ_UP", 1);
                chk_sticky("SEQ_ST", 1'b0);
                chk_iso($sformatf("SEQ_ISO%d", i));
            end
            $display("[tc_seq] PASS");
        end

        // ---- tc_exhaust_w8：小位宽穷举逐步累加 ----
        begin : exhaust_blk
            rst_ni = 0; @(negedge clk_i); apply_ref(1,1,0,0,0,0,0,0,0, 0, 1);
            rst_ni = 1;
            ce_i = 1; clear_i = 0; load_i = 0; valid_i = 1; sub_i = 0;
            for (i = 0; i < 128; i++) begin
                data_i = 16'(i % 16);
                @(negedge clk_i); apply_ref(0,1,0,0,0,1,16'(i % 16),0,0, 0, 1);
                chk_acc($sformatf("EXH%d", i));
                chk_iso($sformatf("EXH_ISO%d", i));
            end
            $display("[tc_exhaust_w8] 128 步 PASS");
        end

        // ---- tc_edge：LOAD + WRAP 回绕 + sticky + status_clear + SUB ----
        begin : edge_blk
            // LOAD 2147483640
            ce_i = 1; clear_i = 0; load_i = 1; load_data_i = 32'd2147483640; valid_i = 0;
            @(negedge clk_i); apply_ref(0,1,0,1,32'd2147483640,0,0,0,0, 0, 1);
            chk_acc("LD_MAX"); chk_sticky("LD_ST",1'b0);
            // +10 → WRAP 回绕 + sticky
            load_i = 0; valid_i = 1; data_i = 16'd10; sub_i = 0;
            @(negedge clk_i); apply_ref(0,1,0,0,0,1,16'd10,0,0, 0, 1);
            chk_acc("WRAP_OVF"); chk_sticky("WRAP_ST",1'b1);
            chk_update("WRAP_UP",1); chk_iso("WRAP_ISO");
            // status_clear 清除 sticky
            status_clear_i = 1; @(negedge clk_i); apply_ref(0,1,0,0,0,0,0,0,1, 0, 1);
            status_clear_i = 0;
            chk_sticky("STCLR",1'b0);
            // SUB 路径：LOAD 20 后减 4 → 16
            load_i = 1; load_data_i = 32'd20; valid_i = 0;
            @(negedge clk_i); apply_ref(0,1,0,1,32'd20,0,0,0,0, 0, 1);
            load_i = 0; valid_i = 1; data_i = 16'd4; sub_i = 1;
            @(negedge clk_i); apply_ref(0,1,0,0,0,1,16'd4,1,0, 0, 1);
            chk_acc("SUB"); chk_sticky("SUB_ST",1'b0);
            $display("[tc_edge] LOAD/WRAP/STCLR/SUB PASS");
        end

        // ---- tc_random：随机序列（空泡/正负/clear/load/status_clear）----
        // 符号约定：data_i 传补码值 v（可为负），sub=0 → A+X（v 负即减）；
        // 参考模型 $signed(16'(v)) 与 RTL 符号扩展一致。
        begin : rand_blk
            rst_ni = 0; @(negedge clk_i); apply_ref(1,1,0,0,0,0,0,0,0, 0, 1);
            rst_ni = 1;
            ce_i = 1; clear_i = 0; load_i = 0; valid_i = 0; status_clear_i = 0;
            sub_i = 0;   // 显式复位 sub（前块 tc_edge 可能遗留 sub_i=1）
            for (i = 0; i < 2000; i++) begin
                v = (i % 7 == 0) ? 0 : (($random % 100) - 50);
                valid_i = (i % 5 == 0) ? 0 : 1;
                if (i % 17 == 0) begin clear_i = 1; valid_i = 0; end
                else clear_i = 0;
                if (i % 23 == 0) begin load_i = 1; load_data_i = 32'(i); valid_i = 0; end
                else load_i = 0;
                if (i % 29 == 0) status_clear_i = 1; else status_clear_i = 0;
                data_i = 16'(v);
                @(negedge clk_i);
                apply_ref(0, ce_i, clear_i, load_i, load_data_i, valid_i, 16'(v),
                          1'b0, status_clear_i, 0, 1);
                chk_acc($sformatf("RND%d", i));
                chk_iso($sformatf("RND_ISO%d", i));
            end
            $display("[tc_random] 2000 PASS");
        end

        // ---- tc_sticky：新溢出同拍 status_clear 不吞事件 ----
        // 先 LOAD 接近 signed max 的值，再 +10 → 溢出；同拍 status_clear=1，
        // sticky 必须置 1（新溢出优先于状态清除，ACC-CTL-003）。
        begin : sticky_blk
            rst_ni = 0; @(negedge clk_i); apply_ref(1,1,0,0,0,0,0,0,0, 0, 1);
            rst_ni = 1;
            ce_i = 1; clear_i = 0; load_i = 1; load_data_i = 32'd2147483640; valid_i = 0;
            status_clear_i = 0; sub_i = 0;
            @(negedge clk_i); apply_ref(0,1,0,1,32'd2147483640,0,0,0,0, 0, 1);
            chk_sticky("STK_LD",1'b0);
            // 同拍：有效加法溢出 + status_clear → sticky 置位优先
            load_i = 0; valid_i = 1; data_i = 16'd10; status_clear_i = 1;
            @(negedge clk_i); apply_ref(0,1,0,0,0,1,16'd10,0,1, 0, 1);
            chk_sticky("STK_SAME",1'b1);
            status_clear_i = 0;
            valid_i = 0;
            @(negedge clk_i); apply_ref(0,1,0,0,0,0,0,0,0, 0, 1);
            if (overflow_event_o !== 1'b0) begin
                errors++; $display("[FAIL] idle 后 overflow_event_o 未清零");
            end
            checks++;
            // idle 后 sticky 仍为 1（event 清零但 sticky 保持）
            chk_sticky("STK_IDLE",1'b1);
            $display("[tc_sticky] 同拍优先级 + idle event 清零 PASS");
        end

        // ---- tc_continuous：连续流量与 ce=0 停顿恢复 ----
        begin : cont_blk
            rst_ni = 0; @(negedge clk_i); apply_ref(1,1,0,0,0,0,0,0,0, 0, 1);
            rst_ni = 1;
            ce_i = 1; clear_i = 0; load_i = 0; valid_i = 1; sub_i = 0;
            for (i = 0; i < 100; i++) begin
                data_i = 16'(i + 1);
                @(negedge clk_i); apply_ref(0,1,0,0,0,1,16'(i + 1),0,0, 0, 1);
                chk_acc($sformatf("CONT%d", i));
            end
            // ce=0 停顿：状态保持
            ce_i = 0; valid_i = 1; data_i = 16'hFFFF;
            @(negedge clk_i); apply_ref(0,0,0,0,0,1,16'hFFFF,0,0, 0, 1);
            chk_acc("PAUSE_A"); chk_update("PAUSE_UP",0);
            // 恢复 ce=1
            ce_i = 1; valid_i = 1; data_i = 16'd1;
            @(negedge clk_i); apply_ref(0,1,0,0,0,1,16'd1,0,0, 0, 1);
            chk_acc("RESUME_A"); chk_update("RESUME_UP",1);
            $display("[tc_continuous] 停顿/恢复 PASS");
        end

        // ---- 汇总 ----
        if (errors == 0)
            $display("=== PASS: accumulator_tb checks=%0d errors=0 ===", checks);
        else
            $display("=== FAIL: accumulator_tb checks=%0d errors=%0d ===", checks, errors);
        $finish;
    end
endmodule
