# CBB 运行日志（唯一）

- `2026-08-26 03:25:56` | **intake** | G0 | G0 Intake: QUE-012 width_conversion_fifo 判定为 CBB (A2/A3, P1)，无重复，边界清晰 | 结果(PASS)
    边界判定: 无CSR/软件契约, 参数化+端口定制, 多IP复用, FIFO不变量+宽度转换语义可完整描述; 查重: registry QUE-012 planned, 与 QUE-001/STR-014 边界无重叠; 支持范围: 整数比宽度转换, 单时钟同步复位, 深度以窄字计; 风险 P1; 消费者: 窄总线写/宽读分拍/DMA数据整形; 执行深度: Standard Loop
- `2026-08-26 03:26:46` | **intake** | G0 | 修正: 本机原生 EDA 工具链完整可用（VCS/DC/Formality/SpyGlass），此前 OPTIONAL_UNAVAILABLE 结论作废 | 结果(PASS)
    实测确认: VCS W-2024.09-SP1 (/home/eda/app/synopsys/vcs), dc_shell V-2023.12-SP3, fm_shell V-2023.12-SP3, SpyGlass X-2025.06, Verdi; 仅 workflow 侧 aix tool cbb-* action 域未注册（不影响直接调用原生 EDA）; 验证路径: VCS 编译+仿真+SVA, SpyGlass Lint, DC 综合 PPA, Formality 等价
- `2026-08-26 03:30:39` | **specify** | G1 | G1 Contract: cbb.yaml+behavior.yaml 完成，check PASS，RTM 生成 16 条 | 结果(PASS)
    参数: DIRECTION/NARROW_WIDTH(1-512)/RATIO(2-64)/DEPTH(2-1024); 约束 PC-001..004; 宽侧位宽上限 4096 用分段可求值约束+RTM  双层拦截(求值器不支持乘法); behavior: INV-001..006 无丢失/无重复/保序/N2W拼接/W2N拆分/满空安全; REQ-001..004; ASM-001..002; check 退出码 0
- `2026-08-26 03:31:32` | **design** | G2 | G2 Architecture: design.md + profiles.yaml 完成，check PASS | 结果(PASS)
    模块划分: 单模块+方向generate; 时钟复位: 单时钟同步复位, 满空安全; 错误模型: 满时输入ready拉低, 空时输出valid拉低, X语义明确; profiles: area_opt(supported)/fmax_opt(supported)/low_power(experimental), 共享 impl_pointer_count; 可验证性: 每个不变量映射SVA+仿真路径; 非目标: 非整比gearbox/CDC/乱序
- `2026-08-26 03:49:18` | **implement** | G3 | G3 RTL Static: VCS compile/elab (N2W+W2N) + 负向$error拦截 + SpyGlass lint 通过 | 结果(PASS)
    VCS -full64 compile+elab: N2W/W2N 均通过(0 error); 负向: DEPTH=1 触发 PC-003+PC-005 elaboration $error (vcs rc=255); SpyGlass lint/lint_rtl: 0 Fatal/0 Error (7 Warning/4 Info, 已 waiver 为方向分支预期, 见 verification/lint_waivers.md); 修复: beat_idx 同拍 push+pop 多次赋值(W415a)已合并; 证据: evidence/g3_static/ (compile_n2w.log/compile_w2n.log/negative_depth1.txt/moresimple.rpt/spyglass_lint.txt); 生成物: RTL+core+验证脚本 run_static_checks.sh
- `2026-08-26 04:02:21` | **verify** | G4 | G4 Functional: VCS 仿真 N2W/W2N 通过 + SVA 断言 + 变异测试有效 | 结果(PASS)
    N2W: 9 宽字拼接与参考一致(小端), 无丢失; W2N: 44 窄字序列与参考一致, 保序; 用 $sampled 对齐握手时序(domain-rules 3.1.1 坑); SVA: PROP-WC-* 全程无触发; 断言变异: count<=DEPTH 反转为 count>DEPTH 后 89 次断言失败(检测能力有效); 证据: evidence/g4_functional/{n2w_sim,w2n_sim,mutation_failures}.txt; 测试台: verification/simulation/width_conversion_fifo_tb.sv + run_functional_sim.sh
- `2026-08-26 04:02:58` | **verify** | G5 | G5 Config Space: 分层配置集生成完整（mandatory 1/boundary 24/pairwise 6/negative 6） | 结果(PASS)
    config-gen 确定性生成: mandatory=默认N2W 8b/4/8; boundary 覆盖 min/max/临界/非2次幂(DIRECTION×NARROW_WIDTH×RATIO×DEPTH); pairwise 6 组二元交互; negative 含非法值(NARROW_WIDTH 0/513, RATIO 1, DEPTH 越界)由 RTL $error elaboration 拦截(G3 已验证); manifest.yaml 记录集合; 配置 ID 稳定 cfg_*
- `2026-08-26 05:38:08` | **characterize** | G6 | G6 PPA: OPTIONAL_UNAVAILABLE（无标准单元库/PDK，无法门级综合） | 结果(BLOCKED)
    尝试: dc_shell V-2023.12-SP3 + lsi_10k/class/gtech 等候选库全部为 DesignWare/教学软库, get_lib_cells 无法枚举门级单元, DC 无法产生门级网表/面积/时序报告; 本机无 PDK/标准单元 .db; 按 optimize-cbb-ppa 纪律不伪造综合数据; 已输出 characterization/plan.yaml (benchmark_profiles + E0 定性趋势 + 恢复条件: 提供 SAED32/Nangate45/freePDK45 后跑 synth_dc.tcl Sweep+Pareto); 证据等级 E0 exploratory
- `2026-08-26 05:38:51` | **qualify** | G7 | G7 Qualification: 支持矩阵+限制+Waiver+Qualification Report 完成（candidate，成熟度 E2） | 结果(PASS)
    支持矩阵: 两方向+参数域+非法拦截一致; Gate G0-G5 pass, G6 blocked(库缺失,E0), G7/G8 candidate; Waiver: G6 PPA(缺库,替代E0趋势) + SpyGlass W240/W528(方向generate预期); 成熟度: E2(Implemented+Verified), 未达E3(缺PPA/消费者/全链); 已知限制 5 项; 输出 docs/qualification-report.md
- `2026-08-26 05:38:51` | **release** | G8 | G8 Release: manifest/CHANGELOG/OWNERS 候选产出（qualified/released 待 Workflow Gate） | 结果(PASS)
    release/manifest.yaml(status=candidate, version=0.1.0, vlnv=aixsilicon:cbb:width_conversion_fifo:0.1.0, maturity=E2, SBOM: Apache-2.0 无依赖); CHANGELOG 0.1.0; OWNERS; 发布需 Workflow Gate 确认后固化 artifact SHA-256
- `2026-08-26 08:22:20` | **specify** | G1 | QUE-001 sync_fifo G1 契约通过：cbb.yaml/behavior.yaml Schema+约束+稳定ID校验 OK，RTM 13 条唯一 | 结果(PASS)
    check --cbb sync_fifo PASS；rtm 生成 trace/rtm.yaml（5 REQ + 5 INV + 3 ASM 去重后 13 条）并 --check-only 通过；config-gen 生成 mandatory(1)/boundary(18)/pairwise(3)/negative(4)
- `2026-08-26 08:23:02` | **design** | G2 | QUE-001 sync_fifo G2 架构通过：单微架构 impl_pointer_count（指针+计数+可选输出寄存），3 个 Profile 覆盖 area/fmax/deep | 结果(PASS)
    profiles.yaml 声明 impl_pointer_count + area_opt(fmax_opt/deep_buffer)；design.md 定义端口/状态更新/时钟复位/可验证性论证；存储交综合推断，G6 标 E0 OPTIONAL_UNAVAILABLE
- `2026-08-26 08:43:09` | **implement** | G3 | QUE-001 sync_fifo G3 静态基线：RTL+core+SDC 就绪，VCS 正向/负向 compile PASS（12 参数矩阵），Lint 环境阻塞 | 结果(PASS)
    RTL：rtl/interface/sync_fifo_pkg.svh + rtl/impl/impl_pointer_count/sync_fifo.sv（内嵌 5 条 SVA）。VCS -full64 compile/elaborate：默认 + dw∈{1,8,64,1024}×dep∈{2,16,4096} 12 点全 PASS；负向 DEPTH=1 hex EEST $error 拦截 exit 255。证据 evidence/g3_static/compile_sync_fifo.txt。SpyGlass batch lint 初始化卡死（>4min）-> Lint BLOCKED（环境）；aix tool cbb-core-gen OPTIONAL_UNAVAILABLE（tool_repo 未装），core 按模板人工填充
- `2026-08-26 10:06:25` | **verify** | G4 | QUE-001 sync_fifo G4 Functional 通过：3 场景仿真全 PASS + SVA 0 失败 + 故障注入 checker 有效 + OUTPUT_REG 双模式 | 结果(PASS)
    发现并修复 RTL bug：OUTPUT_REG=1 的 pop_ev 绑定寄存 rd_valid_q（滞后）→ 空拍误弹致 count 下溢回绕 DEPTH；修复为 pop_ev=~empty&&rd_ready。tc_order sent32/recv32、tc_backpressure 15/15（满拒收）、tc_stress 701/701（随机背压800拍）全保序无丢失无重复；OUTPUT_REG=0 8/8 PASS；fault inject 满时 force wr_ready → full|->~wr_ready 断言触发。Formal 证明工具 vcst/JasperGold 缺失 OPTIONAL_UNAVAILABLE，SVA+随机仿真支撑 needs_verification。证据 evidence/g4_functional/functional_sim.txt
- `2026-08-26 10:06:26` | **verify** | G5 | QUE-001 sync_fifo G5 配置空间：mandatory/boundary/pairwise/negative 4 组 set 覆盖齐全 | 结果(PASS)
    config-gen 确定性生成 mandatory(1)/boundary(18)/pairwise(3)/negative(4)；边界含 min/max/临界/非2幂(DATA_WIDTH×DEPTH×OUTPUT_REG)；negative 非法值由 elaboration $error 拦截（G3 已证）；验证计划 verification/plan.yaml 声明配置矩阵与用例映射
- `2026-08-26 10:51:34` | **implement** | G3 | sync_fifo 轻量布局扁平化：rtl/interface+impl → 单一 rtl/sync_fifo.sv，全量回归 PASS | 结果(PASS)
    按 artifact-contract §2 轻量选项：pkg 与 impl 合并为单文件（参数检查用 generate $error）；cbb.yaml/.core 同步更新；9 点参数矩阵 compile PASS + 负向 DEPTH=1 拦截 + G4 三场景仿真全 PASS；width_conversion_fifo 核查：无 sync_fifo 类 bug（组合输出无寄存 valid 滞后），现成 N2W/W2N/变异证据全绿，维持原结构与 E2
