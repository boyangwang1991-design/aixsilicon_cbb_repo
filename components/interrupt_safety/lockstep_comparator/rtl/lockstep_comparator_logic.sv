// SPDX-License-Identifier: Apache-2.0
// SAF-005: synchronous observation only; see behavior.yaml for sampling semantics.
module lockstep_comparator_logic #(
    parameter int unsigned WIDTH = 32,
    parameter int unsigned LOCKSTEP_DELAY = 2,
    parameter int unsigned STARTUP_GUARD_CYCLES = 0,
    parameter int unsigned CMP_PIPE_STAGES = 0,
    parameter int unsigned LCL_REDUNDANCY_LEVEL = 2,
    parameter logic [((WIDTH > 0) ? WIDTH : 1)-1:0] STATIC_COMPARE_MASK = '1,
    parameter bit SUPPORT_RUNTIME_MASK = 1'b1,
    parameter bit SUPPORT_VALID_MASK = 1'b1,
    parameter bit SUPPORT_FAULT_INJECTION = 1'b1
) (
    input logic clk_i, rst_ni,
    input logic [((WIDTH > 0) ? WIDTH : 1)-1:0] main_i, shadow_i,
    input logic compare_enable_i, main_active_i, shadow_active_i,
    input logic [((WIDTH > 0) ? WIDTH : 1)-1:0] runtime_mask_i, valid_mask_i,
    input logic error_clear_i, fi_enable_i,
    input logic [1:0] fi_target_i,
    input logic [((WIDTH > 0) ? WIDTH : 1)-1:0] fi_mask_i,
    output logic alignment_valid_o,
    output logic main_shadow_mismatch_o, main_shadow_mismatch_pulse_o,
    output logic main_shadow_mismatch_latched_o,
    output logic lcl_internal_fault_o, lcl_internal_fault_latched_o,
    output logic [((WIDTH > 0) ? WIDTH : 1)-1:0] mismatch_vector_o, mismatch_vector_sticky_o,
    output logic safety_fault_o
);
    localparam int unsigned W = (WIDTH > 0) ? WIDTH : 1;
    localparam int PATHS = (LCL_REDUNDANCY_LEVEL == 0) ? 1 : 2;
    localparam logic [63:0] WAIT_CYCLES = 64'(LOCKSTEP_DELAY) + 64'(STARTUP_GUARD_CYCLES);
    localparam int COUNT_W = (WAIT_CYCLES == 0) ? 1 : $clog2(WAIT_CYCLES + 64'd1);
    wire [W-1:0] aligned [0:PATHS-1];
    wire [W-1:0] diff [0:PATHS-1];
    wire [PATHS-1:0] valid_path, mismatch_path;

    if (WIDTH < 1) begin : g_bad_width
        $error("LCL_PARAM_WIDTH: WIDTH must be positive");
    end
    if (CMP_PIPE_STAGES > 1) begin : g_bad_pipe
        $error("LCL_PARAM_PIPE: CMP_PIPE_STAGES must be 0 or 1");
    end
    if (LCL_REDUNDANCY_LEVEL > 2) begin : g_bad_level
        $error("LCL_PARAM_LEVEL: LCL_REDUNDANCY_LEVEL must be 0, 1 or 2");
    end

    for (genvar p=0; p<PATHS; p++) begin : g_path
        wire [W-1:0] shared_data;
        wire shared_valid;
        if (p == 1 && LCL_REDUNDANCY_LEVEL == 1) begin : g_shared_input
            assign shared_data = aligned[0];
            assign shared_valid = valid_path[0];
        end else begin : g_no_shared_input
            assign shared_data = '0;
            assign shared_valid = 1'b0;
        end
        // 同文件私有子模块提供可保留的综合边界，不构成独立 CBB 依赖。
        lockstep_comparator_logic_path #(
            .WIDTH(W), .LOCKSTEP_DELAY(LOCKSTEP_DELAY),
            .STARTUP_GUARD_CYCLES(STARTUP_GUARD_CYCLES), .CMP_PIPE_STAGES(CMP_PIPE_STAGES),
            .STATIC_COMPARE_MASK(STATIC_COMPARE_MASK), .SUPPORT_RUNTIME_MASK(SUPPORT_RUNTIME_MASK),
            .SUPPORT_VALID_MASK(SUPPORT_VALID_MASK), .SUPPORT_FAULT_INJECTION(SUPPORT_FAULT_INJECTION),
            .PATH_INDEX(p), .SHARED_DELAY(p == 1 && LCL_REDUNDANCY_LEVEL == 1)
        ) u_path (
            .clk_i(clk_i), .rst_ni(rst_ni), .main_i(main_i), .shadow_i(shadow_i),
            .compare_enable_i(compare_enable_i), .main_active_i(main_active_i), .shadow_active_i(shadow_active_i),
            .runtime_mask_i(runtime_mask_i), .valid_mask_i(valid_mask_i),
            .fi_enable_i(fi_enable_i), .fi_target_i(fi_target_i), .fi_mask_i(fi_mask_i),
            .shared_aligned_i(shared_data), .shared_valid_i(shared_valid),
            .aligned_o(aligned[p]), .alignment_o(valid_path[p]), .diff_o(diff[p]), .mismatch_o(mismatch_path[p])
        );
    end
    assign alignment_valid_o = rst_ni & (&valid_path);
    if (PATHS == 2) begin : g_dual
        assign mismatch_vector_o = diff[0] | diff[1];
        assign main_shadow_mismatch_o = mismatch_path[0] | mismatch_path[1];
        assign lcl_internal_fault_o = mismatch_path[0] ^ mismatch_path[1];
    end else begin : g_single
        assign mismatch_vector_o = diff[0];
        assign main_shadow_mismatch_o = mismatch_path[0];
        assign lcl_internal_fault_o = 1'b0;
    end
    assign safety_fault_o = main_shadow_mismatch_o | lcl_internal_fault_o;
    assign main_shadow_mismatch_pulse_o = main_shadow_mismatch_o & ~main_shadow_mismatch_latched_o;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            main_shadow_mismatch_latched_o <= 1'b0;
            lcl_internal_fault_latched_o <= 1'b0;
            mismatch_vector_sticky_o <= '0;
        end else begin
            main_shadow_mismatch_latched_o <= main_shadow_mismatch_o
                | (main_shadow_mismatch_latched_o & ~error_clear_i);
            lcl_internal_fault_latched_o <= lcl_internal_fault_o
                | (lcl_internal_fault_latched_o & ~error_clear_i);
            mismatch_vector_sticky_o <= mismatch_vector_o
                | (error_clear_i ? {W{1'b0}} : mismatch_vector_sticky_o);
        end
    end
`ifndef SYNTHESIS
    // PROP-LCL_SAFE-001
    ap_safe: assert property (@(posedge clk_i)
        $isunknown({main_shadow_mismatch_o, lcl_internal_fault_o}) ||
        safety_fault_o == (main_shadow_mismatch_o | lcl_internal_fault_o))
        else $fatal(1, "PROP-LCL_SAFE-001: safety aggregation");
    // PROP-LCL_RESET-002
    ap_reset: assert property (@(posedge clk_i) !rst_ni |->
        (!alignment_valid_o && !main_shadow_mismatch_o && !main_shadow_mismatch_pulse_o))
        else $fatal(1, "PROP-LCL_RESET-002: reset suppression");
`endif
endmodule

// 私有通道；A/B 的掩码、资格限定、延迟和比较逻辑在独立综合边界内实现。
module lockstep_comparator_logic_path #(
    parameter int unsigned WIDTH=32, LOCKSTEP_DELAY=2, STARTUP_GUARD_CYCLES=0, CMP_PIPE_STAGES=0,
    parameter logic [WIDTH-1:0] STATIC_COMPARE_MASK='1,
    parameter bit SUPPORT_RUNTIME_MASK=1, SUPPORT_VALID_MASK=1, SUPPORT_FAULT_INJECTION=1,
    parameter int PATH_INDEX=0,
    parameter bit SHARED_DELAY=0
)(
    input wire clk_i,rst_ni,
    input wire [WIDTH-1:0] main_i,shadow_i,runtime_mask_i,valid_mask_i,fi_mask_i,shared_aligned_i,
    input wire compare_enable_i,main_active_i,shadow_active_i,fi_enable_i,shared_valid_i,
    input wire [1:0] fi_target_i,
    output wire [WIDTH-1:0] aligned_o,diff_o,
    output wire alignment_o,mismatch_o
);
    localparam int unsigned W=WIDTH;
    localparam logic [63:0] WAIT_CYCLES = 64'(LOCKSTEP_DELAY) + 64'(STARTUP_GUARD_CYCLES);
    localparam int COUNT_W = (WAIT_CYCLES == 0) ? 1 : $clog2(WAIT_CYCLES + 64'd1);
        localparam logic [1:0] CMP_TARGET = 2'(PATH_INDEX);
        localparam logic [1:0] DELAY_TARGET = 2'(PATH_INDEX+2);
        wire [W-1:0] mask = STATIC_COMPARE_MASK
            & (SUPPORT_RUNTIME_MASK ? runtime_mask_i : {W{1'b1}})
            & (SUPPORT_VALID_MASK ? valid_mask_i : {W{1'b1}});
        wire [W-1:0] cmp_inject =
            (SUPPORT_FAULT_INJECTION && fi_enable_i && fi_target_i == CMP_TARGET)
            ? fi_mask_i : {W{1'b0}};
        wire [W-1:0] delay_inject =
            (SUPPORT_FAULT_INJECTION && fi_enable_i && fi_target_i == DELAY_TARGET)
            ? fi_mask_i : {W{1'b0}};
        wire active = rst_ni & alignment_o & compare_enable_i & main_active_i & shadow_active_i;
        wire [W-1:0] operand = aligned_o ^ cmp_inject;
        wire [W-1:0] raw_diff = active ? ((operand ^ shadow_i) & mask) : {W{1'b0}};

        if (SHARED_DELAY) begin : g_shared
            assign aligned_o = shared_aligned_i;
            assign alignment_o = shared_valid_i;
        end else begin : g_independent
            if (LOCKSTEP_DELAY == 0) begin : g_bypass
                assign aligned_o = main_i ^ delay_inject;
            end else begin : g_delay
                // Preserve independent banks in synthesis; see constraints/preserve_redundancy.tcl.
                (* keep = "true", dont_touch = "true" *) logic [W-1:0] data_q [0:LOCKSTEP_DELAY-1];
                always_ff @(posedge clk_i or negedge rst_ni) begin
                    if (!rst_ni) begin
                        for (int unsigned k=0; k<LOCKSTEP_DELAY; k++) data_q[k] <= '0;
                    end else begin
                        data_q[0] <= main_i ^ delay_inject;
                        for (int unsigned k=1; k<LOCKSTEP_DELAY; k++) data_q[k] <= data_q[k-1];
                    end
                end
                assign aligned_o = data_q[LOCKSTEP_DELAY-1];
            end
            if (WAIT_CYCLES == 0) begin : g_no_wait
                assign alignment_o = rst_ni;
            end else begin : g_wait
                (* keep = "true", dont_touch = "true" *) logic [COUNT_W-1:0] count_q;
                always_ff @(posedge clk_i or negedge rst_ni) begin
                    if (!rst_ni) count_q <= '0;
                    else if (count_q != COUNT_W'(WAIT_CYCLES)) count_q <= count_q + 1'b1;
                end
                assign alignment_o = rst_ni & (count_q == COUNT_W'(WAIT_CYCLES));
            end
        end
        if (CMP_PIPE_STAGES == 1) begin : g_pipe
            (* keep = "true", dont_touch = "true" *) logic [W-1:0] diff_q;
            always_ff @(posedge clk_i or negedge rst_ni) begin
                if (!rst_ni) diff_q <= '0;
                else diff_q <= raw_diff;
            end
            assign diff_o = rst_ni ? diff_q : {W{1'b0}};
        end else begin : g_comb
            assign diff_o = raw_diff;
        end
        assign mismatch_o = |diff_o;

`ifndef SYNTHESIS
        // PROP-LCL_KNOWN-003: identical X/Z on both inputs is never assumed safe.
        ap_known: assert property (@(posedge clk_i) disable iff (!rst_ni)
            active |-> !$isunknown({operand & mask, shadow_i & mask, mask}))
            else $fatal(1, "PROP-LCL_KNOWN-003: unknown qualified comparison data");
`endif
endmodule
