# 支持范围与资格状态

当前交付状态：`needs_verification` 候选；registry 实现登记为 implemented，资产成熟度维持 E0。
本地功能、负向、静态、综合与等价证据可供 Workflow 审查，不由 skill 自行提升 qualified/released 状态。

| 项目 | 本轮状态 |
|---|---|
| 规格/架构 | 完成并通过严格结构与引用检查 |
| 功能/配置 | 147 个配置通过，采样值对缺口清零 |
| 综合/PPA | 8 点固定库探索性表征，400 MHz 条件下无 setup 违例 |
| 等价 | 主要六点及补充两点分别记录 |
| 消费方式 | 独立 FuseSoC 包 smoke 通过；未绑定真实下游 IP 项目 |
| 发布/物理资格 | 未执行；不创建发布 manifest 或更新 Catalog |

限制：仅已测样本有直接证据，其余合法范围为 experimental；不支持 P2 diverse comparator 或自主后台自测 FSM。
功耗为概率传播估计，无项目 SAIF；未锁定干净发布 revision；A/B 物理隔离、DFT/故障覆盖率、共因故障和控制一致性须由项目补充。
