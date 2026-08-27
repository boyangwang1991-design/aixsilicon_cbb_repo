// mutation_colcmp_tb — 变异测试：colcmp 递推注入 m[c]/3 → m[c]%3 错位变异
// 预期：黄金模型比对 FAIL（checker 检测能力证明，verify-cbb §9）
`timescale 1ns/1ps
module mutation_colcmp_tb;
    logic [63:0] d64;
    wire [6:0] mut_out;

    // 变异体：参数覆写不适用——用 bind-free 方式直接实例化并 force 内部状态不可行，
    // 故采用编译期宏注入：popcount_impl_colcmp 在 +define+POPCC_MUT_DIV2MOD 下
    // 将一处递推项替换。此处 TB 只负责驱动与判定。
    popcount #(.INPUT_WIDTH(64), .PC_IMPL(1)) dut (.data_i(d64), .cnt_o(mut_out));

    function automatic int golden(input logic [63:0] v);
        int acc; acc = 0;
        for (int b = 0; b < 64; b++) if (v[b]) acc++;
        return acc;
    endfunction

    initial begin
        int mismatches;
        process::self.srandom(32'hCBB_2026_0827);
        mismatches = 0;
        for (int i = 0; i < 500; i++) begin
            void'(std::randomize(d64));
            #1;
            if (mut_out !== golden(d64)[6:0]) mismatches++;
        end
        if (mismatches > 0)
            $display("[FAIL] mutation detected: %0d/500 mismatches — checker EFFECTIVE", mismatches);
        else
            $display("[PASS-UNEXPECTED] mutation invisible — checker INEFFECTIVE");
        $finish;
    end
endmodule
