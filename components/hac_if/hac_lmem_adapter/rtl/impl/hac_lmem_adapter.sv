// Copyright (c) 2026 AIXSILICON
// SPDX-License-Identifier: Apache-2.0
//
// hac_lmem_adapter: HAC-LMEM 到 SRAM/Bank/ECC Adapter。
// 状态：骨架（实现待填充）。
// 支持 LMEM-FIXED（固定 1/2 周期）与 LMEM-DECOUPLED（请求/响应解耦）。

module hac_lmem_adapter #(
  parameter int unsigned DATA_W  = 64,
  parameter int unsigned ADDR_W  = 16,
  parameter int unsigned BANK_W  = 2,
  parameter logic         EN_ECC  = 1'b0,
  parameter logic         EN_BANK = 1'b0
) (
  input  logic clk,
  input  logic rst_n,

  // HAC-LMEM（core 视角）
  input  logic               hac_req_valid,
  output logic               hac_req_ready,
  input  logic               hac_write,
  input  logic [BANK_W-1:0]  hac_bank,
  input  logic [ADDR_W-1:0]  hac_addr,
  input  logic [DATA_W-1:0]  hac_wdata,
  input  logic [DATA_W/8-1:0] hac_wstrb,
  output logic               hac_rsp_valid,
  input  logic               hac_rsp_ready,
  output logic [DATA_W-1:0]  hac_rdata,
  output logic               hac_ecc_corrected,
  output logic               hac_ecc_uncorrectable,

  // SRAM Macro
  output logic              sram_req,
  input  logic              sram_gnt,
  output logic              sram_write,
  output logic [ADDR_W-1:0] sram_addr,
  output logic [DATA_W-1:0] sram_wdata,
  output logic [DATA_W/8-1:0] sram_wstrb,
  input  logic [DATA_W-1:0] sram_rdata
);

  // 骨架：直通占位（未实现 ECC/Bank 仲裁）
  assign sram_req     = hac_req_valid;
  assign sram_write   = hac_write;
  assign sram_addr    = hac_addr;
  assign sram_wdata   = hac_wdata;
  assign sram_wstrb   = hac_wstrb;
  assign hac_req_ready = sram_gnt;
  assign hac_rsp_valid = sram_req;
  assign hac_rdata    = sram_rdata;
  assign hac_ecc_corrected     = 1'b0;
  assign hac_ecc_uncorrectable = 1'b0;

endmodule : hac_lmem_adapter
