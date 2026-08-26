# Qualification Report（G7 候选）— width_conversion_fifo

> 状态：`qualification_candidate`（只有 Workflow Gate G7/G8 可确认 `qualified`/`released`）
> 执行深度：Standard Loop key 覆盖已完成；G6 PPA 受库缺失阻断（E0）。

## 1. 支持矩阵（与真实验证矩阵一致）

| 参数/配置 | 支持值 | 验证状态 |
|---|---|---|
| `DIRECTION=NARROW_TO_WIDE` | 8b/4/8 等 | 已验证（G4 仿真 + SVA） |
| `DIRECTION=WIDE_TO_NARROW` | 8b/4/8 等 | 已验证（G4 仿真 + SVA） |
| `NARROW_WIDTH` | 1–512（合法域） | 边界抽样（config boundary 24 点） |
| `RATIO` | 2–64（合法域） | 代表点验证（2/4/8） |
| `DEPTH` | 2–1024，`DEPTH>=RATIO`（PC-005） | 代表点验证 |
| 非法参数 | 宽侧>4096 / DEPTH<RATIO | elaboration `$error` 拦截（G3 负向） |

## 2. Gate 证据完整性

| Gate | 结果 | 证据 |
|---|---|---|
| G0 | pass | `docs/intake.md` |
| G1 | pass | `cbb.yaml`+`behavior.yaml`+`trace/rtm.yaml`（check PASS） |
| G2 | pass | `docs/design.md`+`profiles.yaml` |
| G3 | pass | VCS compile/elab（N2W+W2N）+ SpyGlass lint（0F/0E）+ 负向 `$error`；`evidence/g3_static/` |
| G4 | pass | N2W/W2N 仿真 + SVA + 变异测试；`evidence/g4_functional/` |
| G5 | pass | 配置集 mandatory/boundary/pairwise/negative（`verification/configs/`） |
| G6 | blocked | `OPTIONAL_UNAVAILABLE`（无标准单元库/PDK），E0；`characterization/plan.yaml` |
| G7 | candidate | 本报告（支持矩阵/限制/Waiver） |
| G8 | candidate | `release/manifest.yaml`（candidate） |

## 3. Waiver 清单

| Waiver | Owner | 范围 | 风险 | 替代证据 | 失效条件 |
|---|---|---|---|---|---|
| G6 PPA 缺失 | ppa-owner | 面积/时序/功耗门级数据 | 低-中（未做门级综合） | RTL 结构定性趋势（E0） | 提供标准单元库后须补 Sweep+Pareto |
| SpyGlass W240/W528 | rtl-owner | 方向 generate 未用端口/信号 | 低（参数化方向分支预期） | 编译/仿真通过 | 改用统一双向数据路径后复审 |

## 4. 成熟度判定

- **候选成熟度：E2（Implemented + Verified）**——功能契约明确、G3/G4/G5 通过；
- **未达 E3/Stable**：缺 G6 PPA 门级证据、缺 ≥2 独立消费者、缺 Golden 全链。
- 建议状态：`experimental → pilot` 过渡（待 PPA 补齐 + 消费者 Smoke 后升级）。

## 5. 已知限制（Known Limitations）

1. 仅整数比宽度转换；非整比 gearbox 不支持（非目标）。
2. 单时钟域同步复位；无 CDC。
3. `DEPTH >= RATIO` 强制（PC-005），否则死锁。
4. 宽侧位宽上限 4096 bit（PC-004）。
5. W2N 按低段→高段 FIFO 顺序输出（保序契约 REQ-002）。

## 6. Release 建议（candidate）

- SemVer：`0.1.0`
- FuseSoC Core：`aixsilicon:cbb:width_conversion_fifo:0.1.0`
- 消费者 Smoke：尚未执行（需真实下游实例化，依赖 Workflow/消费者）
- 开源发布清理：无需 PDK/内部路径（RTL 纯 SystemVerilog 可移植）