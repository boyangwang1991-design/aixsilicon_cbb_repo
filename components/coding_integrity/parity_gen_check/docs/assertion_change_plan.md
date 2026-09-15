# INV-001 组合采样修复计划

2026-09-14，apb_secure_demux 的真实 VCS 联调发现数据切换后 XOR 树尚未稳定时，就近即时断言先被求值。稳定输出及 IP 周期 checker 正确，原生断言仍报错。原始失败保存在消费者 build/sim/run/uvm/batch_1789375153075512869。

本次为已授权 IP 依赖问题的 partial-task，写入范围限 RTL 中 INV-001 的采样方式、对应回归和本变更记录。保持既有 G2 架构和函数契约；采用 postponed 区域的 final deferred immediate assertion，按 ASM-001 跳过 X/Z 输入，已知输入的错误/未知输出仍失败。综合排除验证构造，不改变 XOR 网络或参数。AI 已核对 behavior.yaml、G2 架构及现有原始断言。

验证包括三种实现、奇偶模式、最小/最大/非二幂及消费者宽度的动态向量，强制错误输出的负向检测，以及修复后的实际 IP UVM 联调。该局部回归不重新声明旧 G4–G8/PPA/发布证据有效，也不提升成熟度。稳定 ID 为 F-PG-ASSERT-001；执行结果保留在本组件 build/，完成后追加至既有 run_log。
