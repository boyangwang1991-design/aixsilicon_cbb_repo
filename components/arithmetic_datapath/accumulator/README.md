# accumulator

Accumulator（A2, P0）— 参数化整数/定点累加器 CBB（ARI-006）

## 功能

核心递推 `A_next = A ± X`，支持清零（clear_i）、初值装载（load_i）、有效使能（ce_i）、
回绕/饱和（OVERFLOW_MODE）与溢出状态（event/sticky）。单时钟、同步复位、II=1。

| 参数 | 默认 | 合法域 | 语义 |
|---|---|---|---|
| INPUT_WIDTH | 16 | 1~128 | 输入 X 位宽 |
| ACC_WIDTH | 32 | 1~256 | 状态/输出位宽 |
| SIGNED | true | bool | 有符号（符号扩展）/无符号（零扩展） |
| OP_MODE | 0 | [0,1,2] | ADD_ONLY/SUB_ONLY/ADD_SUB |
| OVERFLOW_MODE | 0 | [0,1] | WRAP/SATURATE |
| LOAD_EN / STATUS_EN | true | bool | 装载使能 / 状态输出使能 |
| OPERAND_ISOLATION | 0 | [0,1] | 操作数隔离（PPA 选项） |

## 文档与契约

- SSOT 契约：[`cbb.yaml`](cbb.yaml)（+[`behavior.yaml`](behavior.yaml)、[`profiles.yaml`](profiles.yaml)）
- 可读规格：[`docs/cbb_spec.md`](docs/cbb_spec.md)（派生视图）
- 架构设计：[`docs/design.md`](docs/design.md)（C2）
- 需求追踪：[`trace/rtm.yaml`](trace/rtm.yaml)（工具生成）
- 需求入口：[`accumulator_contract.md`](accumulator_contract.md)（G0 需求草案）

## 实现与验证状态

- **RTL**：[`rtl/accumulator.sv`](rtl/accumulator.sv)（极简单文件，参数检查 generate `$error`）
- **FuseSoC Core**：[`fusesoc/aixsilicon_cbb_accumulator.core`](fusesoc/aixsilicon_cbb_accumulator.core)
- **功能仿真（G4）**：`verification/scripts/run_functional_sim.sh` → `build/eda/evidence/g4_functional/functional_sim.txt`
  （穷举/随机/边界/连续/隔离等价全 PASS，4393 checks / 0 errors）
- **负向校验（G3）**：`verification/scripts/run_negative_elab.sh` → `build/eda/evidence/g3_static/negative_elab.txt`
  （8 个非法参数 case 全部 PC 报错拦截）
- **编译基线（G3）**：VCS compile → `build/eda/evidence/g3_static/compile.txt`

实现状态以 [`registry.yaml`](../../../registry.yaml) 为准（planned）；Gate 结论需 Workflow 依据证据转换，
本文不替代 Gate。PPA 表征（G6）与资格（G7/G8）未执行，不得据此宣称支持域。
