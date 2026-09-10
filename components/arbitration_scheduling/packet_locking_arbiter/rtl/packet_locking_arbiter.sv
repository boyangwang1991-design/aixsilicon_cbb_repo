// SPDX-License-Identifier: Apache-2.0
// Packet-granular round robin. grant_o denotes ownership, not a transfer.
module packet_locking_arbiter #(
    parameter int NUM_REQ = 4,
    parameter int LOCK_MODE = 0,
    parameter int LEN_W = 8
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [NUM_REQ-1:0] req_i,
    input  logic ready_i,
    input  logic [NUM_REQ-1:0] eop_i,
    input  logic [NUM_REQ*LEN_W-1:0] length_i,
    output logic [NUM_REQ-1:0] grant_o
);
    localparam int IW = (NUM_REQ > 1) ? $clog2(NUM_REQ) : 1;
    if (NUM_REQ < 1 || NUM_REQ > 64) begin : g_bad_n
        $error("PC-001 NUM_REQ must be 1..64");
    end
    if (LOCK_MODE < 0 || LOCK_MODE > 1) begin : g_bad_mode
        $error("PC-002 LOCK_MODE must be 0 or 1");
    end
    if (LEN_W < 1 || LEN_W > 16) begin : g_bad_len
        $error("PC-003 LEN_W must be 1..16");
    end

    logic locked_q;
    logic [IW-1:0] owner_q, next_q, selected;
    logic [NUM_REQ-1:0] eligible, masked, all_grant, mask_grant, candidate;
    logic [LEN_W-1:0] remaining_q, selected_length, effective_remaining;
    logic fire, done, selected_eop;

    for (genvar i = 0; i < NUM_REQ; i++) begin : g_eligible
        assign eligible[i] = req_i[i] && ((LOCK_MODE == 0) || (|length_i[i*LEN_W +: LEN_W]));
        assign masked[i] = eligible[i] && (IW'(i) >= next_q);
    end
    if (NUM_REQ == 1) begin : g_single
        assign all_grant = eligible;
        assign mask_grant = masked;
    end else begin : g_select
        fixed_priority_arbiter #(.NUM_REQ(NUM_REQ), .PRIORITY(0), .REQ_TYPE(0),
            .FAST_GRANT(0), .PC_IMPL(1)) u_all (
            .clk(clk), .rst_n(rst_n), .req_i(eligible), .grant_ack_i(1'b0), .grant_o(all_grant));
        fixed_priority_arbiter #(.NUM_REQ(NUM_REQ), .PRIORITY(0), .REQ_TYPE(0),
            .FAST_GRANT(0), .PC_IMPL(1)) u_mask (
            .clk(clk), .rst_n(rst_n), .req_i(masked), .grant_ack_i(1'b0), .grant_o(mask_grant));
    end
    assign candidate = (|masked) ? mask_grant : all_grant;
    always_comb begin
        grant_o = '0;
        if (rst_n) begin
            if (locked_q) grant_o[owner_q] = 1'b1;
            else grant_o = candidate;
        end
        selected = '0;
        selected_length = '0;
        for (int i = 0; i < NUM_REQ; i++) begin
            selected = selected | ({IW{grant_o[i]}} & IW'(i));
            selected_length = selected_length | ({LEN_W{grant_o[i]}} & length_i[i*LEN_W +: LEN_W]);
        end
    end
    assign fire = ready_i && (|(grant_o & req_i));
    assign selected_eop = |(grant_o & eop_i);
    assign effective_remaining = locked_q ? remaining_q : selected_length;
    assign done = fire && ((LOCK_MODE == 0) ? selected_eop : (effective_remaining == LEN_W'(1)));

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            locked_q <= 1'b0;
            owner_q <= '0;
            next_q <= '0;
        end else if (done) begin
            locked_q <= 1'b0;
            next_q <= (selected == IW'(NUM_REQ-1)) ? '0 : selected + IW'(1);
        end else if (!locked_q && (|candidate)) begin
            locked_q <= 1'b1;
            owner_q <= selected;
        end
    end
    if (LOCK_MODE == 1) begin : g_length
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n) remaining_q <= '0;
            else if (done) remaining_q <= '0;
            else if (!locked_q && (|candidate)) remaining_q <= selected_length - LEN_W'(fire);
            else if (locked_q && fire) remaining_q <= remaining_q - LEN_W'(1);
        end
    end else begin : g_eop
        assign remaining_q = '0;
    end

    // synopsys translate_off
    // PROP-PLA_MUTEX-001
    ap_mutex: assert property (@(posedge clk) $onehot0(grant_o))
        else $fatal(1, "PROP-PLA_MUTEX-001");
    // PROP-PLA_HOLD-002: reservation holds even before first accepted beat.
    ap_hold: assert property (@(posedge clk) disable iff (!rst_n)
        ((|grant_o) && !done) |=> $stable(grant_o))
        else $fatal(1, "PROP-PLA_HOLD-002");
    // PROP-PLA_RR-005
    ap_rotate: assert property (@(posedge clk) disable iff (!rst_n)
        done |=> (!locked_q && next_q == (($past(selected) == IW'(NUM_REQ-1)) ? IW'(0) : $past(selected)+IW'(1))))
        else $fatal(1, "PROP-PLA_RR-005");
    ap_no_rotate: assert property (@(posedge clk) disable iff (!rst_n)
        !done |=> $stable(next_q)) else $fatal(1, "PROP-PLA_RR-005 stable");
    if (LOCK_MODE == 0) begin : g_eop_assert
        // PROP-PLA_EOP-003
        ap_eop: assert property (@(posedge clk) disable iff (!rst_n)
            done == (fire && selected_eop)) else $fatal(1, "PROP-PLA_EOP-003");
    end else begin : g_len_assert
        // PROP-PLA_LENGTH-004
        ap_nonzero: assert property (@(posedge clk) disable iff (!rst_n)
            locked_q |-> remaining_q != 0) else $fatal(1, "PROP-PLA_LENGTH-004 nonzero");
        ap_count: assert property (@(posedge clk) disable iff (!rst_n)
            (locked_q && fire && !done) |=> remaining_q == $past(remaining_q)-LEN_W'(1))
            else $fatal(1, "PROP-PLA_LENGTH-004 count");
    end
    // PROP-PLA_FAIR-006 checked by independent packet-completion scoreboard in TB.
    // synopsys translate_on
endmodule
