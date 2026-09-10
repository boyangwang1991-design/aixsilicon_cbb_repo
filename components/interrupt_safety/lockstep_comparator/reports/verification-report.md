# SAF-005 验证报告

## 结论

最终 RTL 的 147 个配置全部通过，共 220,794 次沿前/沿后检查。
其中 103 个配置由套件 config-gen 生成，44 个风险补充点由可重放 runner 根据缺失值对及三元风险组合生成。
当前采样域全部值对已覆盖；这不代表所有合法整数参数组合的穷尽证明。

## 范围与方法

| 维度 | 已测范围 |
|---|---|
| WIDTH | 1、8、32、128 |
| LOCKSTEP_DELAY | 0、1、2、3 |
| STARTUP_GUARD_CYCLES | 0、1、3 |
| CMP_PIPE_STAGES | 0、1 |
| LCL_REDUNDANCY_LEVEL | 0、1、2 |
| STATIC_COMPARE_MASK | 全 1、全 0、最低位有效 |
| Runtime/Valid/FI 支持 | 各自启用和关闭；另覆盖三者同时关闭 |

SV 独立状态计分板对真实 RTL 逐周期比较全部输出，固定 seed=5005+配置序号。
覆盖合约 CC-001～CC-012：匹配/差异、两路 FI、延迟故障、复位启动、掩码、sticky 和清除。
附加单路归约 stuck-at-0、连续 fault/clear、流水输出控制撤销、随机复位、数据/掩码/活动条件交互。
RTL SVA 检查安全汇总、复位屏蔽和有效数据 unknown；两路数据同为 X/Z 也会报错。

## 负向与变异

- 8 个生成非法配置在宿主预检被拒绝，103 个生成合法配置通过预检。
- VCS 对 WIDTH=0、CMP_PIPE_STAGES=2/-1、LCL_REDUNDANCY_LEVEL=3/-1 在展开阶段报告指定参数诊断。
- Main/Shadow 同 X、同 Z 均触发 PROP-LCL_KNOWN-003；完全被 runtime mask 屏蔽的 X/Z 用例通过。
- 将最终 OR 改为 AND，以及反转安全断言，均触发预期失败，证明检查器可以发现这些错误。
- 共 10 项 VCS 对抗性测试通过。VCS `$fatal` 在本机可能返回 0，判据同时检查指定 Fatal 终止块及正常完成标记缺失。

负延迟、负保护周期和掩码域外值在进入 SV unsigned/位向量转换前由 `tools/validate_config.py` 拒绝。
直接绕过宿主校验将无法恢复转换前的原值，因此这些输入不能仅依赖 RTL 诊断。

## 综合等价与静态检查

六个主要 PPA 配置的 Formality RTL→映射网表等价通过；补充两个配置见独立 extra 结果。
该证据证明综合保持行为，不是无界时序安全属性证明。
VCS lint 和 DC check_design 完成；参数裁剪类诊断按 [限定说明](../verification/lint_waivers.md) 解释。
未声称独立 SpyGlass/CDC/RDC 或物理安全签核通过。

独立导出的 FuseSoC 包完成 setup/build/run，并命中 LCL_CORE_PASS，无私有 skill 运行依赖。
工作区 make check 全部通过（124 项测试），全文件 pre-commit 通过。

## 证据索引

- [功能回归](verification-result.json)：最终 RTL/TB/runner 输入 hash、147 个配置检查计数与日志 hash。
- [负向/变异](adversarial-result.json)与[宿主配置拒绝](negative-config-result.json)。
- [六点等价](formal-result.json)、[补充等价](formal-extra-result.json)。
- [独立 Core 构建](core-result.json)与 [PPA 指标](ppa-summary.json)。

原始输入快照、配置细目、命令和日志位于各 run_id 对应 build/eda 子目录。
最初的 WIDTH=0 诊断顺序问题及 VCS 退出码判据已修复；原失败记录保留，未覆盖原始证据。
