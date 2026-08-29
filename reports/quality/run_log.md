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
- `2026-08-27 03:53:32` | **observe** | reset | 仓库重置：删除 QUE-001 sync_fifo 与 QUE-012 width_conversion_fifo 物理工程包，registry 条目回退 planned（等待重新开发） | 结果(PASS)
    移除 components/fifo_queue_buffer/{sync_fifo,width_conversion_fifo}；registry.yaml status=implemented -> planned ×2 并更新 updated 时间戳；README 已交付清单同步为暂无；历史经验已沉淀于 skill 仓复盘文档，不受本次删除影响
- `2026-08-27 07:57:30` | **intake** | G0 | G0 Intake: SEL-014 popcount 判定为 CBB(A1/P1) 查重无重复 无嵌套子依赖 | 结果(PASS)
    边界判定: 纯组合Hamming计数原子构件, 无CSR/软件契约, 参数化+端口定制, ECC/性能计数/调度权重/DSP稀疏度等多消费者复用; 查重: registry SEL-014 planned 无物理目录, 同组及全库无同名/同义已实现构件, ARI-003/004 planned 且本构件不需嵌套调用; 依赖解析: dependencies=[] 验证依赖=[], 无需子Agent委派; 风险 P1; 执行深度 Standard Loop
- `2026-08-27 08:18:00` | **specify** | G1 | 方案冻结为文档（用户决策 D）：docs/{design,intake,cbb_spec}.md 完成，RTL 实施待线下评审 | 结果(PASS)
    用户明确选择"先冻结为文档、线下评审后再动 RTL"; design.md 固化三实现方案 impl_tree(默认)/impl_column_compress(fmax候选)/impl_lookup(Pareto左端点)+纯组合无时钟接口+全精度输出 $clog2(W+1); cbb_spec.md 候选契约 INPUT_WIDTH 4~256 默认64 / CHUNK_W 4~8 仅lookup / PC-001~002 / REQ-001~004 / PROP-PC_FUNC-001·PROP-PC_BOUND-002·PROP-PC_EQV-003 / tc_exhaust_w8·tc_edge·tc_random·tc_equiv_lec; 验证策略 fm_shell LEC 两两等价(W∈{8,33,64,127})+W8全空间穷举+变异测试; G6 计划 GF CMOS28LP+ARM SC9 400MHz 起步 {impl}×{8,16,32,64,128} Pareto; 待裁决关注点: ①三实现是否裁剪 ②CHUNK_W 参数去留 ③Pareto 消费优先级; G1 YAML 契约与 G2 profiles.yaml 待评审通过后写入并 check
- `2026-08-27 08:06:11` | **intake** | G0 | SEL-014 popcount G0 Intake: 判定为 CBB(A1/P1) 查重无重复 无嵌套子依赖 | 结果(PASS)
    边界判定: 纯组合Hamming计数原子构件, 无CSR/软件契约, 参数化+端口定制, ECC/性能计数/调度权重等多消费者复用; 查重: registry SEL-014 planned 无物理目录, 同组(sel_decode)及全库无同名/同义已实现构件, ARI-003 carry_save_adder/ARI-004 multi_operand_adder 均 planned 且本构件不需嵌套调用; 依赖解析: 运行时 dependencies=[] 验证依赖=[], 无需子Agent委派; 消费者: ECC编码器/带宽仲裁/事件统计/DSP峰值检测; 风险 P1; 执行深度: Standard Loop(新增CBB)
- `2026-08-27 08:56:54` | **implement** | G3 | SEL-014 popcount G3 静态基线 PASS: VCS 编译矩阵18/18 + 负向拦截×2 + SpyGlass lint 0E/0W | 结果(PASS)
    VCS -full64 compile/elab: {tree,colcmp,lookup}×W∈{4,8,33,64,127,256} 含非2幂全PASS; 负向 INPUT_WIDTH=3/CHUNK_W=9 elaboration $error 拦截 RC=255 且报错ID命中PC-001/002; SpyGlass lint_rtl(GuideWare rtl_handoff): 0 Fatal/0 Error/0 Warning/2 Info(需 enableSV09); 证据 evidence/g3_static/{param_matrix,negative_w3,negative_cw9,spyglass_lint}.txt
- `2026-08-27 08:58:38` | **implement** | SKILL 优化: popcount 运行经验沉淀至 domain-rules §3.1.1/§3.1.3/§3.2 (5 条新坑) validate_suite PASS | 结果(PASS)
    新增: wrapper派生端口宽度localparam→parameter化 / 列压缩逐列always_comb多驱动ICPD→单进程原子快照+列计数不变式递推 / 守恒递推漏SUM项黄金模型检出 / tee+grep -q SIGPIPE误判→先落盘再grep / SpyGlass read_file type=verilog+enableSV09 / fm_shell V-2023.12 set_top形态; 新增§3.2 Popcount/压缩树结构专项行
- `2026-08-27 09:47:10` | **characterize** | G6 | G6 PPA: PDK_READY 真实综合 15点×SC9/HVT/tt 完成 area+slack 全落盘 run-20260827-01 | 结果(PASS)
    GF CMOS28LP sc9_base_hvt tt_1p00v_25c 虚拟时钟2.5ns; 结果: W≤32 三impl≤65μm²全MET; W=64 tree 124μm²(+0.09) vs colcmp 1258μm²(−1.11违例); W=128 249 vs 2551(−2.20); lookup与tree趋同=DC case表折叠为同构树(预期); Pareto结论: tree_default 为推荐Profile, fmax_opt 降级experimental, 显式FA网表登记为后续Change Plan; 教训沉淀: dc_shell generate-case参数覆盖不生效→子模块直证; 证据 evidence/ppa/run-20260827-01/(60文件)+characterization/plan.yaml
- `2026-08-27 09:49:45` | **qualify** | G7 | G7 Qualification candidate(E2): 支持矩阵+5限制+waiver 齐备; registry SEL-014 物化 implemented; G8 候选待 Workflow Gate 固化 sha256 | 结果(PASS)
    docs/qualification-report.md §1-§5; release/manifest.yaml(status=candidate, SBOM runtime=[] verification=[], license Apache-2.0); gate 8pass+G8blocked; 消费者 smoke 待首个消费者 IP 接入(不阻塞候选)
- `2026-08-27 09:50:00` | **release** | G8 | G8 Release 候选齐备: manifest(status=candidate)+CHANGELOG+core+SBOM零依赖; sha256 固化与 status=released 仅待 Workflow Gate 确认 | 结果(BLOCKED)
    最终复核: rtm --check-only PASS / check --strict PASS / gate 8pass+1blocked; 全链证据 evidence/{g3_static,g4_functional,ppa/run-20260827-01}; SKILL 经验沉淀 domain-rules(validate_suite PASS)
- `2026-08-27 09:53:11` | **characterize** | PPA 分析报告成形: characterization/ppa-report.md (矩阵+Pareto图+profile推荐+可复现说明) | 结果(PASS)
    补齐功耗维度: colcmp W64 691μW vs tree 72μW (~10×), W128 1392μW vs 155μW; Pareto前沿由tree完全主导; fmax_opt experimental 结论经报告固化
- `2026-08-27 12:12:06` | **characterize** | Change C1: impl_lookup→impl_dadda 完成(全回归PASS); G6 run-20260827-02 补充表征 dadda_w8=27.7μm²(+130% vs tree); 大宽度点 DC 超时登记待补; PNG Pareto 图经 Python 生成 | 结果(PASS)
    RTL: rtl/impl/impl_dadda/popcount.sv (权值守恒律Σm[c]·2^c, FA=-2本列+1carry, Dadda目标序列 DTBL[14], 魔数floor(eff/3)=(eff*17hAAAB)>>17 无除法网络); 验证: 编译矩阵18/18+exhaust_w8+edge+random3000+变异全PASS; 结论: tree_default 推荐地位不变, dadda_sched/colcmp 均 experimental; ppa-report.md §0/§2' 增补; plot_pareto.py 固化绘图管线
- `2026-08-27 12:12:58` | **observe** | SKILL 图表纪律固化: ppa-evidence.md §0 新增(PNG禁ASCII图/脚本程序化读数/--with matplotlib注入/resolve锚定与Agg后端坑) | 结果(PASS)
    plot_pareto.py 经验: Path(root).resolve()防相对拼接错位; pareto_run-20260827-01.png 已归档并嵌入 ppa-report.md; validate_suite PASS
- `2026-08-27 12:19:35` | **release** | GitHub 发布完成: commit 787c2cd pushed to origin/main (boyangwang1991-design/aixsilicon_cbb_repo); popcount 成为仓库首个 implemented CBB 上线 | 结果(PASS)
    220 files changed(10541+/6190-), 含 fifo_queue_buffer 两个旧包的 reset 删除与本批 .gitignore EDA 残留规则; gitignore 验证: csrc/alib-52/FM_INFO/lint_work/ucli.key 全部隔离, lint.prj 白名单保留
- `2026-08-27 12:31:00` | **design** | Change C2 重构设计定稿: 四实现(TREE/WALLACE/DADDA/LUT) 显式FA结构化核方案; 调度数学验证器 verify_schedule.py 506/506 PASS(W4-256×wallace/dadda 权值守恒+收敛+可行+列界); RTL 打平规范回归 rtl/ 单层(用户指令) | 结果(PASS)
    编译期 localparam 函数固化的调度常量替代运行时 % / 除法(对常量的整数除法合法不生成除法器), 数据通路仅 xor/maj 门; Wallace r4 收敛 vs Dadda r10(DTBL序列约束下FA更省但轮多); LUT 分级 nibble->chunk->归并树; 方案表决采纳: 平衡加法树默认+显式FA压缩+分级LUT 为28nm@1GHz推荐组合
- `2026-08-27 13:14:05` | **design** | Change C2 四实现重构(设计+验证): TREE/WALLACE/DADDA/LUT; Python先行验证链(调度506/506+网表bit-exact 20/20); Graphviz架构图(rank同rank FA行+S/C双色边+W16/W64); SV网表TB锚点+500随机PASS | 结果(PASS)
    rtln打平布局(popcount.sv wrapper+tree/lut 直写; popcount_compressed.sv gen产物显式FA网表 W=64物化; pc_sched_table.svh 调度常量); 防软件化纪律落地: 零%//运行时除法, FA=xor/maj真门, 收尾常量移位连加; colcmp移除(其列计数递推被G6证伪); LUT分级 nibble-LUT4->byte对合并->归并树; FA正确性判定链: Python verify_netlist bit-exact(用户裁定标准)
- `2026-08-27 13:19:09` | **design** | Change C2 定稿: 四实现(TREE/WALLACE/DADDA/LUT)+打平RTL布局+Python生成验证链全绿 | 结果(PASS)
    验证顺序遵用户指令: ①Python: verify_schedule 506/506 + verify_netlist bit-exact 20/20(FA语义xor/maj逐门仿真); ②可视化: Graphviz行交替架构图(inputs行/FA行rank=same/dot输出行, SUM蓝CARRY橙, W16/W64), mpl圈版并存; ③SV: 网表TB锚点+500随机PASS, wrapper四路编译矩阵过; 契约同步 cbb.yaml 四实现打平files; SKILL固化 domain-rules §3.0 防软件化写电路红线(反模式→PPA量化→正确形态三栏)
- `2026-08-27 13:49:36` | **characterize** | G6 | G6 帕累托寻优完成(run-20260827-03): 四实现15点全落盘; tree 124μm²/+0.09 W64 支配确认; FA显式化 dadda_w64 271μm²/0.00 vs 列递推1258/−1.11(−78%+转MET); tree_default推荐不变, wallace/dadda experimental | 结果(PASS)
    Change C2 定稿全量寻优; dadda 网表固定W=64单档(其余宽度=生成器扩展项登记); 文档同步: ppa-report.md重写(§0 C2结论+§2矩阵+§4推荐)/plan.yaml run-03基线/profiles.yaml四profile/CHANGELOG 0.2.0; 校验: check --strict PASS + rtm --check-only PASS + gate 8pass/9record
- `2026-08-28 00:52:30` | **design** | SKILL 新增强制产物: 每实现一份详细设计说明书(docs/detail-design/<impl>.md, 八节骨架模板 templates/docs/cbb_impl_detail_design.md); popcount 三份落地(tree/wallace/lut) | 结果(PASS)
    骨架: 实现标识/微架构+逻辑深度推导/守恒论证/参数化/验证映射/PPA摘录/限制/变更记录; SKILL implement-cbb-rtl Procedure 首条固化; Change C3 dadda 移除后 wallace 网表 TB 回归 PASS(锚点+500随机); check --strict PASS validate_suite PASS
- `2026-08-28 00:57:16` | **characterize** | wallace W64 单点复测(C3 纯FA网表): 121.9μm²/+0.01/74.7μW — 与 tree 124μm² 打平(−1.7%面积), 推翻 run-03 dadda 中间态 271μm² 旧数据 | 结果(PASS)
    上下文同 G6 基线(SC9 HVT tt vclk2.5ns); 证据 characterization/wallace64_run/{area,timing,power}.rpt+dc.log; 文档同步: wallace.md §6 PPA摘录 + ppa-report.md §0 核心发现更新; 结论: W=64 档 wallace 与 tree 同为 Pareto 有效解
- `2026-08-28 01:10:58` | **characterize** | LUT SWAR 重构修复资源爆炸 + W64 三实现综合对照: wallace 121.9/tree 124.0/lut(SWAR) 183.0μm² 全MET; 递推1258 淘汰结论维持 | 结果(PASS)
    LUT 反模式实证: ROM×genvar复制+段隔离mux 资源爆炸→SWAR shift/mask/add 183μm²/MET; wallace 纯FA网表单点复测 121.9μm²/+0.01/74.7μW 与 tree 打平(−1.7%面积/+3.5%功耗); W64 Pareto: wallace(面积)与tree(通用+功耗)双有效解; 文档: ppa-report §0 三连实证 + lut.md §6 PPA反思表; TB: LUT-SWAR 1000随机+锚点 PASS; 综合脚本 lut64_synth.tcl 固化
- `2026-08-28 01:19:13` | **implement** | build/ 目录纪律落地: EDA 中间产物(dc alib/cksum/svf/pvl/syn/mr + vcs csrc/WORK/ucli.key + formality FM_INFO + spyglass lint_work + logs)统一迁移 build/; .gitignore 强制 build/+**/build/+ucli.key; git rm 已入库残留; 脚本 OUT 路径改指 build/; SKILL artifact-contract §2 固化 | 结果(PASS)
    交付件目录回归纯净: popcount 根仅剩 yaml/rtl/docs/evidence/...; characterization 仅留 tcl/py/png/md/pdk/plan; validate_suite + check --strict PASS
- `2026-08-28 04:12:21` | **observe** | 用户指令移除 SEL-014 popcount 工程包：目录 git rm -rf（47 tracked + 本地生成物全清）；registry 条目回退 planned；README 交付清单同步 | 结果(PASS)
    删除范围: components/selection_decode/popcount/ 全量移除（含本次 Change C4 的 4:2 compressor 演进产物）；registry.yaml SEL-014 status implemented->planned; README.md 交付清单更新; evidence 67 个生成物此前已 git rm --cached 一并清理
- `2026-08-28 07:02:43` | **intake** | G0 | G0 Intake: ARB-001 fixed_priority_arbiter 边界判定=A2 CBB(无CSR/无软件契约/参数定制/被多IP复用); registry 查重无重复; 无嵌套子CBB依赖 | 结果(PASS)
    Owner=aixsilicon:cbb; consumers=SoC interconnect/axi_mux/request arbiter; risk=P0; 非目标=RR/WRR/multi-grant; 多实现 linear/tree/grouped(registry ARB-001 定义); scaffold 骨架已生成
- `2026-08-28 07:04:30` | **specify** | G1 | G1 Contract: cbb.yaml+behavior.yaml Schema通过; 参数 NUM_REQ/PRIORITY/REQ_TYPE/FAST_GRANT/PC_IMPL 合法域与约束明确; REQ-001..007 可验证 | 结果(PASS)
    check 仅 warn(测试未落地, G4补齐); 无嵌套子CBB依赖; HWIF=原生 req/grant 无需引用
- `2026-08-28 07:04:30` | **design** | G2 | G2 Architecture: profiles.yaml 5个Profile(linear/tree/grouped×FAST_GRANT/latched)对应真实UseCase; 详设三文件(linear/tree/grouped)含PPA优化点与生成方式(SV手写) | 结果(PASS)
    时钟复位: FAST_GRANT=1需clk/rst_n(异步复位清零); REQ_TYPE=1锁存外围; 错误模型: 无X承诺; 可验证性: 每Profile有验证路径
- `2026-08-28 07:19:21` | **implement** | G3 | G3 RTL Static: fixed_priority_arbiter.sv 极简单文件(wrapper+三实现+SVA) 编译/elab 矩阵18点PASS; 负向elaboration拦截5参数; SpyGlass lint 0F/0E; FuseSoC Core已建 | 结果(PASS)
    VCS矩阵 impl{0,1,2}xN{2,4,8,16,32,64}; 负向 NUM_REQ=1/PRIORITY=2/REQ_TYPE=2/FAST_GRANT=2/PC_IMPL=3; lint waiver(断言/===/参数化裁剪)见 lint_waivers.md; 证据 build/eda/evidence/g3_static/
- `2026-08-28 07:29:47` | **verify** | G4 | G4 Functional: FPA_TB PASS(穷举N4x6DUT+优先级+边界+随机2000xN64+三实现等价+锁存+寄存); SVA改为@(posedge clk)并发断言(规避组合中间态/VCS @(*)NYI) | 结果(PASS)
    负向 tc_negative_elab: 5非法参数 elaboration  拦截; 变异 tc_mutation: 断言可检测破坏语义(SVA有效性); 证据 build/eda/evidence/g4_functional/functional_sim.txt
- `2026-08-28 07:29:47` | **verify** | G5 | G5 Config Space: config-gen 生成 mandatory1+boundary8+pairwise3+negative2=14配置(去重+约束过滤); RTM 16条; check --strict PASS 引用完整 | 结果(PASS)
    配置集 verification/configs/*.yaml; trace/rtm.yaml 16 条; REQ->PROP/tests/configs 全落地
- `2026-08-28 07:35:08` | **characterize** | G6 | G6 PPA: pdk-scan PDK_READY(sc9_cmos28lp tt_1p00v_25c); DC sweep 三实现xN{4,8,16,32,64}=15点; 三实现综合收敛(差异<3%); reports/ppa-report.md | 结果(PASS)
    area 2.34~89.62um2; arrival 0.84~2.00ns(400MHz); 优先级编码器综合最优; FAST_GRANT=1 价值=寄存授权解耦时序(未单独表征); 证据 build/eda/ppa/run-20260828-01/
- `2026-08-28 07:38:07` | **qualify** | G7 | G7 Qualification: 支持矩阵(参数x验证状态) + Gate证据G0-G6 pass + Waiver清单(断言/===/综合收敛) 完整; 候选成熟度 E2 | 结果(PASS)
    qualification-report.md; 消费者Smoke/多corner STA/FAST_GRANT单独PPA 为E3缺口
- `2026-08-28 07:38:07` | **release** | G8 | G8 Release(候选): SemVer 0.1.0; release/manifest.yaml(SBOM无依赖); registry ARB-001=implemented; README/CHANGELOG/OWNERS 齐全 | 结果(PASS)
    check --strict PASS; rtm --check-only PASS; registry build_cbb_structure 校验通过(implemented=2); 正式 Release 需 Workflow Gate 确认
- `2026-08-28 07:41:11` | **observe** | 收尾: 清理 DC 产物至 build/eda/dc_sweep; 回归 G3(18点编译+lint 0F/0E) + G4(FPA_TB PASS) 重放通过; check --strict + rtm --check-only PASS; gate 9/9 pass | 结果(PASS)
    skill_result: aixsilicon:cbb:fixed_priority_arbiter status=implemented(G3-G6 pass)/qualification_candidate(G7/G8); E2; 参数 NUM_REQ/PRIORITY/REQ_TYPE/FAST_GRANT/PC_IMPL 全覆盖
- `2026-08-28 07:47:12` | **verify** | G5 | 修复 RTM 空内容: cbb.yaml 枚举参数补 partitions(PRIORITY/REQ_TYPE/FAST_GRANT/PC_IMPL) 使 config-gen 有区分度(boundary8->13, pairwise3->19); REQ-001..007 补 configs+evidence 引用 | 结果(PASS)
    trace/rtm.yaml 16条: REQ 全部有 configs+evidence; check --strict PASS; rtm --check-only PASS; 派生视图 docs/cbb_spec.md REQ表同步
- `2026-08-28 07:50:51` | **observe** | 修复 run_static_checks.sh 误删负向 TB 源文件 bug(rm $NEG_TB 删了正式 verification/formal/negative_elab_tb.sv); 重建源文件+脚本不再清理; G3重跑PASS; check --strict PASS | 结果(PASS)
- `2026-08-28 08:54:14` | **characterize** | G6 | G6 功耗证据管线修复: synth_sweep.tcl summary 提取补 dyn_power_uW/leak_power_nW 正则; extract_power_summary.py 从既有 raw power.rpt 回填 20/20 summary(无需重跑综合); ppa-report.md 补动态功耗表+漏电说明+activity 上下文声明+时序收敛天花板脚注; 新增 plot_ppa_comparison.py 生成 reports/ppa_run-20260828-01.png(面积/时序/功耗三联图,300dpi,已嵌入报告); SKILL optimize-cbb-ppa 固化功耗全链路强制纪律(skill repo 源仓已改并重新物化) | 结果(PASS)
    根因: 早期 synth_sweep.tcl 只抓 area/arrival/slack 三字段, power.rpt 完整存在但 summary/报告漏抓=证据管线断链; 数据: W64 动态功耗 direct/tree=71.95 wallace=79.08 lut=80.11 comp4_2=100.97uW(+40% vs tree); 漏电<0.04%动态主导; 结论: tree_default 推荐不变, comp4_2 W64 面积+54%/功耗+40% 双差; 回填脚本可重放: uv run python characterization/extract_power_summary.py --run-dir build/eda/ppa/run-20260828-01
- `2026-08-28 09:10:30` | **verify** | G5 | G5 配置空间修复: config-gen 集合约束表达式求值 bug 修复(PC-004 花括号 fail-closed 致 mandatory/boundary/pairwise 全空) -> 生成 1+12+4+2=19 配置; plan.yaml/cbb.yaml REQ 引用对齐自动命名 config_id 消除悬空断链; cbb.yaml dependencies 移除非 VLNV 文件项(生成器为构建期工具); check --strict PASS + rtm check-only PASS | 结果(PASS)
    skill 仓 cbb_common.py eval_constraint_expr: _EXPR_ALLOWED 补 {} 与逗号, _EXPR_FORBIDDEN 补 for/while/** 封堵推导式/解包注入面(源仓已改并 --force 重物化); tc_negative_elab 场景索引补入 popcount_tb.sv 头注释; gate G5/G7/G8 candidate 非法状态遗留待 Workflow 裁决后更新
- `2026-08-29 03:55:03` | **intake** | G0 | G0 Intake：ARB-002 round_robin_arbiter 边界判定 CBB/A2，查重命中已登记 planned 条目，本次物化；无嵌套依赖 | 结果(PASS)
- `2026-08-29 03:56:09` | **specify** | G1 | G1 规格：cbb.yaml+behavior.yaml 契约（5 参数 6 约束 8 需求）+ config-gen 配置集（mandatory/boundary/pairwise/negative）+ cbb_spec.md + RTM(19) 生成，check 通过 | 结果(PASS)
- `2026-08-29 03:57:42` | **design** | G2 | G2 设计：design.md + profiles.yaml（5 Profile）+ 三实现详设 mask/rotate_prio/pointer（含逻辑深度/PPA 优化点/生成方式 SV 手写），check 通过 | 结果(PASS)
- `2026-08-29 04:16:47` | **implement** | G3 | G3 RTL 实现：rtl/round_robin_arbiter.sv（wrapper+三实现+SVA 极简单文件）+ FuseSoC Core + 静态基线（VCS 编译矩阵 18 点 + 负向 elab 拦截 + SpyGlass lint 0F/0E） | 结果(PASS)
- `2026-08-29 04:16:47` | **verify** | G4 | G4/G5 验证：VCS 功能仿真全 PASS（穷举/轮转序/边界/随机2000×N64/等价/锁存/寄存/ack锁定）+ 负向 elab + 变异测试（互斥破坏→20078 断言失败）+ check --strict 通过（RTM 无悬空） | 结果(PASS)
- `2026-08-29 04:23:07` | **characterize** | G6 | G6 PPA：pdk-scan PDK_READY + DC 合成 15 点（mask/rotate/pointer×N4-64），Pareto：mask 面积最小、rotate/pointer 时序优 | 结果(PASS)
- `2026-08-29 05:41:34` | **characterize** | G6 | G6 PPA 绘图：plot_ppa_comparison.py 生成 reports/ppa_run-20260829-01.png（300dpi，面积/arrival/功耗×N），功耗数据补齐（mask 全 N 功耗最低） | 结果(PASS)
- `2026-08-29 05:53:02` | **qualify** | G6 | SKILL 复盘落地（2026-08-29）：7 项优化到 skill 源仓并重物化——①gate G6 证据检查器（负向验证：删 PNG 即拦截）②domain-rules 动态索引 LHS/循环移位坑 ③SVA 按功能参数模式限定 ④gate --update 语法兼容 ⑤TB 场景隔离模板 ⑥PPA summary 绘图模板；validate_suite OK | 结果(PASS)
- `2026-08-29 07:57:25` | **intake** | G0 | ARI-001 G0 Intake: A1 CBB, 查重新增, 无嵌套依赖, 消费者明确 | 结果(PASS)
- `2026-08-29 07:57:25` | **specify** | G1 | ARI-001 G1 Specify: cbb.yaml+behavior.yaml+profiles.yaml+spec, check OK, rtm 12条 | 结果(PASS)
- `2026-08-29 07:58:29` | **design** | G2 | ARI-001 G2 Design: design.md + ripple/segmented 详设, SV 手写, 无嵌套依赖 | 结果(PASS)
- `2026-08-29 08:07:10` | **implement** | G3 | ARI-001 G3: RTL+core 完成, VCS 16矩阵PASS+负向拦截, SpyGlass lint 0F/0E | 结果(PASS)
- `2026-08-29 08:07:10` | **verify** | G4 | ARI-001 G4: 穷举+边界+随机4000+等价 PASS, 变异256/256检测(checker有效) | 结果(PASS)
- `2026-08-29 08:07:45` | **verify** | G5 | ARI-001 G5: config-gen 27配置(mand1+bound14+pairwise8+neg4), requirements回填, check --strict PASS | 结果(PASS)
- `2026-08-29 08:12:36` | **characterize** | G6 | ARI-001 G6: pdk-scan PDK_READY, DC sweep 16点全完成, PPA报告+profiles回填 | 结果(PASS)
- `2026-08-29 08:13:02` | **qualify** | G7 | ARI-001 G7: 支持矩阵+资格报告, 已知限制(ss/ff corner, toggle) waiver, candidate | 结果(PASS)
- `2026-08-29 08:13:33` | **qualify** | G7 | ARI-001 G7: 支持矩阵+资格报告, waiver(ss/ff corner+toggle), G8 release manifest candidate | 结果(PASS)
- `2026-08-29 08:14:05` | **release** | G8 | ARI-001 G8: release/manifest.yaml+SBOM(无依赖), registry implemented, README 状态总览同步 | 结果(PASS)
