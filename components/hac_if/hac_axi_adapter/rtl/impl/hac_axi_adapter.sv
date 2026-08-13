// Copyright (c) 2026 AIXSILICON
// SPDX-License-Identifier: Apache-2.0
//
// hac_axi_adapter: HAC-MEM 到 AXI4 Master Adapter。
// 状态：骨架（实现待填充）。
//
// 职责：生成 AXI AR/AW/W 通道、请求切分/合并、4KB 边界、Burst 限制、
//       Tag→AXI ID 映射、响应重排与回压、RRESP/BRESP→HAC 状态码、
//       超时/孤儿响应/协议错误检测、可选宽度转换与 CDC。

module hac_axi_adapter #(
  parameter int unsigned ADDR_W = 64,
  parameter int unsigned DATA_W = 128,
  parameter int unsigned ID_W   = 4,
  parameter int unsigned TAG_W  = 6,
  parameter int unsigned MAX_READ_OUTSTANDING  = 8,
  parameter int unsigned MAX_WRITE_OUTSTANDING = 4,
  parameter int unsigned MAX_BURST_BEATS       = 16
) (
  input  logic clk,
  input  logic rst_n,

  // HAC-MEM（core 视角）
  input  logic               hac_req_valid,
  output logic               hac_req_ready,
  input  logic [2:0]         hac_req_opcode,
  input  logic [ADDR_W-1:0]  hac_req_addr,
  input  logic [15:0]        hac_req_len,
  input  logic [TAG_W-1:0]   hac_req_tag,
  output logic               hac_rsp_valid,
  input  logic               hac_rsp_ready,
  output logic [DATA_W-1:0]  hac_rsp_data,
  output logic [TAG_W-1:0]   hac_rsp_tag,
  output logic               hac_rsp_last,
  output logic [3:0]         hac_rsp_status,

  // AXI4 Master
  output logic              axi_awvalid,
  input  logic              axi_awready,
  output logic [ADDR_W-1:0] axi_awaddr,
  output logic [ID_W-1:0]   axi_awid,
  output logic [7:0]        axi_awlen,
  output logic [2:0]        axi_awsize,
  output logic [1:0]        axi_awburst,
  output logic              axi_wvalid,
  input  logic              axi_wready,
  output logic [DATA_W-1:0] axi_wdata,
  output logic [DATA_W/8-1:0] axi_wstrb,
  output logic              axi_wlast,
  input  logic              axi_bvalid,
  output logic              axi_bready,
  input  logic [ID_W-1:0]   axi_bid,
  input  logic [1:0]        axi_bresp,
  output logic              axi_arvalid,
  input  logic              axi_arready,
  output logic [ADDR_W-1:0] axi_araddr,
  output logic [ID_W-1:0]   axi_arid,
  output logic [7:0]        axi_arlen,
  output logic [2:0]        axi_arsize,
  output logic [1:0]        axi_arburst,
  input  logic              axi_rvalid,
  output logic              axi_rready,
  input  logic [ID_W-1:0]   axi_rid,
  input  logic [DATA_W-1:0] axi_rdata,
  input  logic [1:0]        axi_rresp,
  input  logic              axi_rlast
);

  // 骨架：直通占位（未实现 AXI 状态机 / 切分 / 重排）
  assign axi_awvalid = 1'b0;
  assign axi_awaddr  = '0;
  assign axi_awid    = '0;
  assign axi_awlen   = '0;
  assign axi_awsize  = '0;
  assign axi_awburst = 2'b01;
  assign axi_wvalid  = 1'b0;
  assign axi_wdata   = '0;
  assign axi_wstrb   = '0;
  assign axi_wlast   = 1'b0;
  assign axi_bready  = 1'b1;
  assign axi_arvalid = 1'b0;
  assign axi_araddr  = '0;
  assign axi_arid    = '0;
  assign axi_arlen   = '0;
  assign axi_arsize  = '0;
  assign axi_arburst = 2'b01;
  assign axi_rready  = 1'b1;

  assign hac_req_ready = 1'b1;
  assign hac_rsp_valid = 1'b0;
  assign hac_rsp_data  = '0;
  assign hac_rsp_tag   = '0;
  assign hac_rsp_last  = 1'b0;
  assign hac_rsp_status = 4'h0;

endmodule : hac_axi_adapter
