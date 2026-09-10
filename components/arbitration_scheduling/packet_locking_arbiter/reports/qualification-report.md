# Packet locking arbiter 验收报告

结论：本地实现候选验收完成；29配置×3seed、1029075周期通过。正式发布和生产消费者签核不在本次结论范围。

| 项目 | 结果与证据 |
|---|---|
| G0–G2 | 规格确认、依赖查重、单实现详设；契约strict/RTM检查通过 |
| G3 | 所有功能点VCS编译；5个非法参数按PC诊断拒绝；两模式SpyGlass 0 Fatal/0 Error；warning审查见lint_waivers |
| G4–G5 | 87次仿真、4个变异杀死；20生成配置+9风险配置；独立模型+消费者mux数据/顺序检查 |
| Formal | 10个参数点RTL到真实映射网表的Formality等价通过；非无界活性证明 |
| G6 | 10点DC工艺绑定PPA，面积/时序/功耗/漏电和父子贡献见ppa-report |
| 构建 | FuseSoC实际依赖闭包setup/build/run通过，使用包内VCS时间尺度选项 |
| G7 | 参数抽样范围验收；非生产消费者完整签核、非Stable产品认定 |
| G8 | 仅本地SemVer/SBOM/hash候选包，不发布Catalog或远端 |

## 验证矩阵

| 配置 | 集合 | seeds | 结果 |
|---|---|---|---|
| cfg_num_req4_lock_mode0_len_w8 | mandatory | 101,2027,65537 | pass |
| cfg_num_req1_lock_mode0_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req64_lock_mode0_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req32_lock_mode0_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req2_lock_mode0_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req3_lock_mode0_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req8_lock_mode0_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req17_lock_mode0_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req4_lock_mode1_len_w8 | boundary | 101,2027,65537 | pass |
| cfg_num_req4_lock_mode0_len_w1 | boundary | 101,2027,65537 | pass |
| cfg_num_req4_lock_mode0_len_w16 | boundary | 101,2027,65537 | pass |
| cfg_num_req4_lock_mode0_len_w2 | boundary | 101,2027,65537 | pass |
| cfg_num_req1_lock_mode1_len_w8 | pairwise | 101,2027,65537 | pass |
| cfg_num_req2_lock_mode1_len_w8 | pairwise | 101,2027,65537 | pass |
| cfg_num_req1_lock_mode0_len_w1 | pairwise | 101,2027,65537 | pass |
| cfg_num_req1_lock_mode0_len_w16 | pairwise | 101,2027,65537 | pass |
| cfg_num_req2_lock_mode0_len_w1 | pairwise | 101,2027,65537 | pass |
| cfg_num_req2_lock_mode0_len_w16 | pairwise | 101,2027,65537 | pass |
| cfg_num_req4_lock_mode1_len_w1 | pairwise | 101,2027,65537 | pass |
| cfg_num_req4_lock_mode1_len_w16 | pairwise | 101,2027,65537 | pass |
| cfg_num_req3_lock_mode1_len_w1 | risk | 101,2027,65537 | pass |
| cfg_num_req3_lock_mode1_len_w8 | risk | 101,2027,65537 | pass |
| cfg_num_req3_lock_mode1_len_w16 | risk | 101,2027,65537 | pass |
| cfg_num_req17_lock_mode1_len_w1 | risk | 101,2027,65537 | pass |
| cfg_num_req17_lock_mode1_len_w8 | risk | 101,2027,65537 | pass |
| cfg_num_req17_lock_mode1_len_w16 | risk | 101,2027,65537 | pass |
| cfg_num_req64_lock_mode1_len_w1 | risk | 101,2027,65537 | pass |
| cfg_num_req64_lock_mode1_len_w8 | risk | 101,2027,65537 | pass |
| cfg_num_req64_lock_mode1_len_w16 | risk | 101,2027,65537 | pass |

## 限制与验收范围

- NUM_REQ=1..64、LEN_W=1..16是合法参数域；上表是实测功能域，其他组合保持experimental，不能将抽样声明为全笛卡尔验证。
- 生产axis_mux/stream_interconnect仍为planned。本次独立可综合示例实际例化本CBB，且核对数据来源、序号与接受顺序；不宣称两个独立IP消费者通过。
- 公平性按完成包数计，依赖owner/下游最终进展；无超时恢复或按字节公平。
- 工具探测未发现VC Formal/Jasper/SymbiYosys；实际执行Formality等价和VCS关键SVA，未把等价工具冒称性质证明器。
- 本地working tree以输入SHA绑定；正式clean Git基线、生产消费者与Catalog发布由后续发布流程完成。
- 集成Owner负责同步释放reset；lint waiver在参数配置、依赖、状态结构或reset契约改变时失效。
- 生产消费者缺口由integration-owner负责，首次生产IP集成时必须重跑smoke并关闭；替代证据为本次真实例化mux及数据scoreboard。

资产cbb.yaml成熟度保持E0候选元数据，独立证据可供Workflow评定E2；不由SKILL自动提升为qualified/released。

可复现入口见README；JSON报告提供具体配置、seed、输入和原始日志SHA。
