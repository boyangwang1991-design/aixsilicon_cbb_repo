# CBB 运行日志（唯一）

- `2026-08-28 04:33:28` | **intake** | G0 | G0 Intake: COD-001 parity_gen_check 判定为 CBB(A1/P0) 查重无重复 无嵌套依赖 | 结果(PASS)
    边界: 单输出 XOR 归约原子, 无 CSR/软件契约, ECC/总线 parity 多消费者; 查重: registry planned 无物理目录, 本次物化; 依赖: dependencies=[]; 风险 P0; 执行深度 Standard Loop
- `2026-08-28 04:33:28` | **specify** | G1 | G1 契约定稿: cbb.yaml(DATA_WIDTH[4..512]/PARITY_TYPE{0,1}/PC-001..002) + behavior + profiles(tree/linear) | 结果(PASS)
    参数 int 枚举(VER-700 教训: DC 不支持 string); REQ-001..004 映射 PROP/tc_* 落地; check --strict PASS; RTM 生成
- `2026-08-28 04:33:28` | **implement** | G3 | G3 静态基线: VCS 编译矩阵 12/12 + 双负向拦截(DATA_WIDTH=3/PC_IMPL=2) | 结果(PASS)
    rtl/parity_gen_check.sv tree/linear 双实现 + SVA immediate; EDA 产物约束 build/eda(csrc 不入库); PARITY_TYPE string→int 修复; fusesoc core
- `2026-08-28 04:33:28` | **verify** | G4 | G4 功能验证: PARITY_TB PASS(穷举W8+edge even/odd+random3000+tree≡linear等价) | 结果(PASS)
    黄金 XOR 归约独立比对; 证据 build/eda/evidence; 跨实现一致 REQ-003
- `2026-08-28 04:33:28` | **characterize** | G6 | G6 PPA run-20260828-03 全 Sweep(2实现×6宽度): tree/linear 综合完全收敛(面积一致), 单输出 XOR 归约 PPA 空间确认小 | 结果(PASS)
    tree=linear 各宽度 area/slack 一致(DC 重排线性链为树), 小宽度功耗差~9%; 图 reports/ppa-*.png; 报告 reports/ppa-report.md + reports/qualification-report.md(用户指令); SKILL 固化 PPA 合理性/多扫描点/绘图/报告 reports/ + EDA 产物 build/
- `2026-08-28 05:58:03` | **observe** | G6 | SV 优先 + arrival 时序收尾: impl_tree 简化为一行 reduction XOR(综合器自动最优); PPA 时序主指标= data arrival time; scaffold 不建 evidence/(改 build/eda/evidence) | 结果(PASS)
    生成方式决策(design-cbb SKILL §2): Python/SV 均可时倾向 SV; parity 复盘 —  由 DC/Genus 生成最优平衡树, tree/linear 综合收敛本质; 删除 gen_parity.py + rtl/parity_impl_tree.sv; 时序报告/绘图用 arrival(独立于虚拟时钟); scaffold.py evidence->build/eda/evidence; 两仓已推送
