// Copyright (c) 2026 AIXSILICON
// SPDX-License-Identifier: Apache-2.0
//
// hac_stream_adapter: HAC-STREAM 到 AXI4-Stream Adapter。
// 状态：骨架（实现待填充）。

module hac_stream_adapter #(
  parameter int unsigned DATA_W = 128,
  parameter int unsigned ID_W   = 4,
  parameter int unsigned USER_W = 8
) (
  input  logic clk,
  input  logic rst_n,

  // HAC-STREAM（producer 视角）
  output logic               hac_valid,
  input  logic               hac_ready,
  output logic [DATA_W-1:0]  hac_data,
  output logic [DATA_W/8-1:0] hac_keep,
  output logic               hac_last,
  output logic [ID_W-1:0]    hac_id,
  output logic [USER_W-1:0]  hac_user,

  // AXI4-Stream Master
  output logic               axis_tvalid,
  input  logic               axis_tready,
  output logic [DATA_W-1:0]  axis_tdata,
  output logic [DATA_W/8-1:0] axis_tkeep,
  output logic               axis_tlast,
  output logic [ID_W-1:0]    axis_tid,
  output logic [USER_W-1:0]  axis_tuser
);

  // 骨架：直通
  assign hac_valid     = axis_tvalid;
  assign hac_data      = axis_tdata;
  assign hac_keep      = axis_tkeep;
  assign hac_last      = axis_tlast;
  assign hac_id        = axis_tid;
  assign hac_user      = axis_tuser;
  assign axis_tready   = hac_ready;

endmodule : hac_stream_adapter
