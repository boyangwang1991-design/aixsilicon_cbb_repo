// Copyright (c) 2026 AIXSILICON
// SPDX-License-Identifier: Apache-2.0
//
// hac_ap_ctrl_adapter: 将 Xilinx ap_ctrl_hs / ap_ctrl_chain 映射到 HAC-CTRL。
// 状态：骨架（实现待填充）。
//
// 映射：
//   ap_start   -> cmd_valid（或 Shell 内部启动脉冲）
//   ap_ready   -> 命令可接收/启动已采样
//   ap_done    -> 生成 cpl_valid
//   ap_idle    -> idle
//   ap_continue-> 对应完成接收或流水继续许可
//
// 约束：
//   - AP 接口没有 job_id，Adapter 限制为单任务（max_inflight_jobs = 1）；
//   - ap_ctrl_none 核不伪造单任务完成语义。

module hac_ap_ctrl_adapter (
  input  logic clk,
  input  logic rst_n,

  // Xilinx AP 控制接口
  input  logic ap_start,
  input  logic ap_done,
  input  logic ap_idle,
  input  logic ap_continue,
  output logic ap_ready,

  // HAC-CTRL（shell 视角）
  output logic        cmd_valid,
  input  logic        cmd_ready,
  output logic [7:0]  cmd_job_id,
  output logic [7:0]  cmd_opcode,
  output logic [63:0] cmd_desc_addr,

  input  logic        cpl_valid,
  output logic        cpl_ready,
  input  logic [7:0]  cpl_job_id,
  input  logic [15:0] cpl_status,

  output logic busy,
  output logic idle,
  output logic quiescent
);

  // 骨架：单任务模型
  assign cmd_job_id   = 8'h0;
  assign cmd_opcode   = 8'h0;
  assign cmd_desc_addr = '0;
  assign ap_ready     = cmd_ready;
  assign cmd_valid    = ap_start;
  assign cpl_ready    = 1'b1; // ap_continue 语义
  assign busy         = ap_start & ~ap_done;
  assign idle         = ap_idle;
  assign quiescent    = ap_idle;

endmodule : hac_ap_ctrl_adapter
