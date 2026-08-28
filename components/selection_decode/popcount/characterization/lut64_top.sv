// auto-generated wrapper for LUT W64 synthesis (PC_IMPL=2 fixed)
module popcount_lut64 (
    input  logic [63:0] data_i,
    output logic [6:0]  cnt_o
);
    popcount #(.INPUT_WIDTH(64), .PC_IMPL(2)) u_core (.data_i(data_i), .cnt_o(cnt_o));
endmodule
