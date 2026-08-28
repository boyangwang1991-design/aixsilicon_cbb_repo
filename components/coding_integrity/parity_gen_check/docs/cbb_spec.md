# parity_gen_check 规格说明（G1 可读视图）

> YAML（cbb.yaml/behavior.yaml/profiles.yaml）为唯一事实源；本文件为派生可读视图。

## 1. 身份

- 技术域：`coding_integrity`；Registry ID：COD-001；VLNV：`aixsilicon:cbb:parity_gen_check:0.1.0`
- 抽象：A1（原子机制）；优先级 P0；Owner：aixsilicon:cbb

## 2. 功能与接口

```
parity_gen_check #(.DATA_WIDTH(W), .PARITY_TYPE(even|odd))
├── data_i : [W-1:0] 输入向量
└── parity_o : 1-bit 奇偶输出（纯组合）
```

- 函数：`parity_o = ^data_i`（even）；`parity_o = ~^data_i`（odd）
- 纯组合、无时钟、无事务语义（`clock_domains=0`）

## 3. 参数

| 参数 | 域 | 默认 | 说明 |
|---|---|---|---|
| DATA_WIDTH | [4..512] | 64 | 输入向量位宽（XOR 归约树规模） |
| PARITY_TYPE | {even, odd} | even | even/odd 校验类型 |

约束：PC-001（DATA_WIDTH≥4）、PC-002（DATA_WIDTH≤512）——elaboration 期 `$error` 拦截。

## 4. 不变量与假设

- `INV-001` 函数一致性：`parity_o == ^data_i`（黄金模型，可全枚举验证）
- `INV-002` 值域封闭：输出 ∈ {0,1}
- `ASM-001` X/Z 输入不承诺；`ASM-002` 流水化属消费侧职责（A1 无时钟端口）

## 5. 接口绑定

- `interface: native_vector` —— 无总线协议语义，不引用 HWIF（A1 原子向量端口，无 ready/valid 等协议）。

## 6. 多实现

| 实现 | PC_IMPL | 结构 | 定位 |
|---|---|---|---|
| impl_tree | 0 | 显式平衡 XOR 折半树（O(log W)） | 默认推荐（结构清晰） |
| impl_reduction | 1 | 一行 reduction XOR（`^data_i`，综合器自动最优树） | experimental（SV 优先验证） |
| impl_linear | 2 | 显式线性 XOR 链（O(W) 深度） | experimental（结构教学视图） |

## 7. 验证映射

| 需求 | 手段 | 覆盖 |
|---|---|---|
| REQ-001/INV-001 | 黄金模型仿真（穷举 W≤8 + 随机） | tc_exhaust_w8 / tc_random |
| REQ-002/INV-002 | 全0/全1/one-hot 锚点 | tc_edge |
| REQ-003/INV-003 | 多实现等价（tree≡reduction≡linear） | tc_equiv |
| REQ-004 | 负向编译（非法参数拦截） | tc_negative_elab |

## 8. PPA 目标

- G6：DATA_WIDTH∈{8,16,32,64,128,256} × {tree,reduction,linear}，SC9 HVT tt / 2.5ns
- Pareto：三实现综合收敛实证（RTL 写法不影响综合最优解）；时序主指标 = data arrival time
