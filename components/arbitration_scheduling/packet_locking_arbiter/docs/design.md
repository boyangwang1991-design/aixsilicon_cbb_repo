# Packet locking arbiter 架构与变更计划

2026-09-10：规格已确认；用户明确本次不再停下来确认，连续完成所有设计验证验收。
单实现 `impl_mask_lock`，手写参数化SV单文件，不建package，不生成RTL。

复用 `aixsilicon:cbb:fixed_priority_arbiter:0.1.0` 顶层两次，均配置
PRIORITY=0、REQ_TYPE=0、FAST_GRANT=0、PC_IMPL=1：一路选择全部有效请求，
一路选择索引大于等于RR起点的有效请求。有后半区请求时选后半区，否则回绕到全局最低位。
依赖源码不复制、不修改。NUM_REQ=1采用直通分支，避免子CBB最小NUM_REQ=2的非法实例化。
父CBB只维护包归属、轮转起点和接受拍计数。依赖图为本构件→固定优先级仲裁器，无环。
已有RR顶层的ACK/free两模式无法提供本规格的首拍完成语义，故复用其更小粒度的优先选择功能。

两个用途profile绑定同一实现，不宣称两个微架构；消费者当前为规划项，
本次提供真实例化本构件的数据mux示例验证，不能替代两个独立生产IP验收。
详见[详设](detail-design/impl_mask_lock.md)。

变更范围：本CBB契约、RTL、验证、示例、约束、工具生成core、报告和发布候选；
完成后同步registry的implemented状态及派生README；SKILL源不改，改进建议写workflow reports。
验证/综合运行目录统一build/eda，正式发布/Catalog不属于本次本地实现验收。
