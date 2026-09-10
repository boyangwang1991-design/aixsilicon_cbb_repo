// SPDX-License-Identifier: Apache-2.0
// Integration example: control arbiter + data selection; no buffering.
module packet_mux #(
    parameter int NUM_REQ=4, LOCK_MODE=0, LEN_W=8, DATA_W=32
) (
    input logic clk, rst_n,
    input logic [NUM_REQ-1:0] valid_i, last_i,
    input logic [NUM_REQ*LEN_W-1:0] length_i,
    input logic [NUM_REQ*DATA_W-1:0] data_i,
    input logic ready_i,
    output logic [NUM_REQ-1:0] ready_o, grant_o,
    output logic valid_o, last_o,
    output logic [DATA_W-1:0] data_o
);
    packet_locking_arbiter #(.NUM_REQ(NUM_REQ), .LOCK_MODE(LOCK_MODE), .LEN_W(LEN_W)) u_arb (
        .clk(clk), .rst_n(rst_n), .req_i(valid_i), .ready_i(ready_i), .eop_i(last_i),
        .length_i(length_i), .grant_o(grant_o));
    assign valid_o = |(valid_i & grant_o);
    assign last_o = |(last_i & grant_o);
    assign ready_o = grant_o & {NUM_REQ{ready_i}};
    always_comb begin
        data_o = '0;
        for (int i=0; i<NUM_REQ; i++) data_o |= data_i[i*DATA_W +: DATA_W] & {DATA_W{grant_o[i]}};
    end
endmodule
