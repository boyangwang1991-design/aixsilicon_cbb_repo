# CBB 运行日志（唯一）

- `2026-08-28 09:29:03` | **intake** | G0 | Intake(C0): skid_buffer QUE-007 边界判定 CBB-A3, 查重命中已登记条目, 无嵌套依赖 | 结果(PASS)
- `2026-08-28 09:29:03` | **specify** | G1 | Specify(C1): cbb.yaml/behavior.yaml/cbb_spec.md + config-gen(9)+rtm(11), check --strict 全绿 | 结果(PASS)
- `2026-08-28 09:29:03` | **design** | G2 | Design(G2): design.md + detail-design/skid.md(微架构/守恒/PPA优化点) | 结果(PASS)
- `2026-08-28 09:29:04` | **implement** | G3 | Implement(G3): 保序 skid buffer RTL+SVA+core, VCS 编译矩阵5档+负向拦截全过 | 结果(PASS)
- `2026-08-28 09:29:04` | **verify** | G4 | Verify(G4): VCS 功能仿真 tc_random+tc_backpressure+tc_edge DATA_W∈{32,1} PASS, SVA 无失败 | 结果(PASS)
- `2026-08-28 09:31:45` | **verify** | G5 | Config-space(G5): config-gen 去重+约束过滤(mandatory1/boundary8/pairwise0单参数/negative2), rtm 11条 check --strict 全绿 | 结果(PASS)
- `2026-08-28 09:31:45` | **characterize** | G6 | PPA(G6): pdk-scan PDK_READY, DC 400MHz tt corner 真实综合 run-20260828-01(W8/32/128), 面积线性~252um2@W32 时序余量充裕 | 结果(PASS)
- `2026-08-29 01:00:51` | **characterize** | G6 | PPA 主判据修正(2026-08-29): skid buffer 非纯组合→用 reg→reg 最差 setup slack 判时序(create_clock 绑定 clk 端口), run-20260828-07 全 MET(0.39/0.81/1.35ns @400MHz); 完整报告集+extract_ppa.py 独立抽取 | 结果(PASS)
