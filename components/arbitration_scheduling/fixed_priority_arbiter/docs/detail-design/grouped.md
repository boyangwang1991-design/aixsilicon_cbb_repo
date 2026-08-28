# 详设：impl_grouped（PC_IMPL=2）— 分组树 + 组内链（面积/时序折中）

## 微架构
- 将 N 路请求分为 `G` 组（每组合法大小 `GS = ceil(N/G)`），两级仲裁：
  1. **组内**：线性优先链（每组合法路，O(GS) 深度）；
  2. **组间**：组有效位（组内是否有请求）做**并行前缀/树**选择最高优先级组，
     同时把组内选中的 grant 通过组选择多路复用到输出。
- 典型 G = 2^ceil(log2(GS)) 或固定组大小 GS=4（分组树深度 O(log G)）。
- 组内 grant + 组间优先组 one-hot → 最终 grant = 组内grant & 组one-hot 展开。
- PRIORITY / REQ_TYPE / FAST_GRANT 与其它实现相同的外围逻辑。

## 逻辑深度推导
- 深度 = 组内链 O(GS) + 组间树 O(log G)。
- 取 GS≈sqrt(N)（如 N=16→GS=4, G=4）得深度 O(sqrt(N))：折中于 linear O(N) 与 tree O(log N)。
- 实际实现中组间选择也常被综合器折叠；grouped 的面积/时序通常落在 linear 与 tree 之间。

## 面积/时序驱动要素与理论下界
- **面积**：O(N + G·GS) ≈ O(N)（组内链 N 门 + 组间 G 个前缀节点）——接近 linear。
- **时序**：介于 O(log N)（tree）与 O(N)（linear）之间；组大小固定（如 4）时
  深度 ~O(N/4 + log 4)=O(N/4)，仍线性但常数小；G 选大时接近 tree。
- **理论下界**：介于两者之间，无独立下界（是 linear/tree 的连续族）。

## PPA 优化点
- 组大小 GS 与组数 G 是可调参数（本 CBB 用 localparam 固定 GS=4 以保持极简单文件）；
  如需更细粒度调节，消费方可选 tree（更优时序）或 linear（更小面积）。
- 组间树节点少（仅 G 个），多路复用输出 grant 是主要面积开销（每 bit 一个 mux 树）。
- 作为"中间 Pareto 点"实证：N=8~32 时 grouped 通常在面积上优于 tree、
  时序上优于 linear，适合均衡场景（profile `grouped_balanced`）。

## 生成方式决策
- **SV 手写**：分组用 generate 按组索引切分 + 组内链 for 循环 + 组间前缀树递归 generate；
  结构规整、SV 可简洁表达，符合"SV 优先"决策准则。不使用 Python 生成。
