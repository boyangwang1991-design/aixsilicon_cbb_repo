# popcount Lint Waivers

SpyGlass lint/lint_rtl 的已知 warning/info 与豁免理由。Fatal/Error 一律阻断（见
`verification/scripts/run_static_checks.sh`），本文件仅记录不阻断项。

| Rule / Category | Level | 豁免理由 |
|---|---|---|
| `W165` (Combinational loop) | info | 生成网表/参考计数均为纯组合；`assert` 内 `ref_cnt` 仅验证期，综合忽略，无硬件环。 |
| `W120` (Latch) | info | 无锁存：所有实现为组合 assign 或 generate；LUT `case` 带 `default` 全项覆盖。 |
| `W227` (Constant 0/1) | warning | 归约/收尾中显式 `1'b0` 常量（ripple-carry 进位链、pad），为结构表达所需。 |
| `W237` (Mux) | warning | LUT 的 4:2/4:3 真值表在综合后映射为复用逻辑/查找表，符合设计意图。 |
| `W396` (Unused signal) | warning | 收尾进位 `wf_rc3/cf_rc3` 等最高位进位在 `popcnt` 位宽外，属安全余量，综合会去除。 |
| `W433` (Assignment width) | warning | `acc[i+1] = acc[i] + din[i]` 中加法器位宽扩展由 `+` 自动处理，无精度丢失。 |
