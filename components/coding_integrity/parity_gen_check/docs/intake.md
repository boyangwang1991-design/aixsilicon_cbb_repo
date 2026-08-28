# parity_gen_check — Intake（G0）

## 1. 边界判定：CBB（非 IP）

| 判定维度 | 结论 | 依据 |
|---|---|---|
| 参数与端口定制 | 仅 DATA_WIDTH / PARITY_TYPE | 无 CSR、无软件契约、无独立寄存器模型 |
| 抽象粒度 | A1 原子机制 | 单输出奇偶归约（reduction XOR），无状态 |
| 复用面 | 多消费者 | ECC 保护、总线协议 parity、存储校验、安全监控 |
| 生命周期 | 轻量 CBB | 不涉及系统级生命周期，无 IP 级验证环境需求 |

## 2. 查重（registry / Catalog）

- `registry.yaml` COD-001 parity_gen_check：**planned、无物理目录** —— 本次为其首次物化；
- 同族 COD-002 crc_gen_check（多项式，A2）为不同构件，不重叠；
- 全库无同名/同义已实现构件；SEL-014 popcount（计数类，已移除）不同族。

## 3. 依赖解析（composition，C0/C1 前置）

- 运行时 dependencies=[]，验证依赖=[] —— 本构件不嵌套调用其它 CBB，无需子 Agent 委派；
- 结论：**无嵌套依赖**，登记为无。

## 4. Owner / 范围 / 风险

| 项 | 值 |
|---|---|
| Owner | aixsilicon:cbb |
| 范围 | 纯组合奇偶校验（tree/reduction/linear 三实现 + PPA 对比） |
| 风险级别 | P0（低风险：A1 原子、函数可全枚举验证） |
| 非目标 | CRC/多项式、掩码奇偶、流水化（消费侧职责，ASM-002） |

## 5. 执行深度

Standard Loop（新 CBB）；G6 PPA 以 W∈{8,16,32,64,128,256} × {tree,reduction,linear} 对比。
