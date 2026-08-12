# ip-package.yaml Schema (统一建仓 v2.0)

`ip-package.yaml` 是统一仓内 `ips/<vendor>/<ip>/<version>/` 目录的包描述文件，由
`ipkg stage` 从 ip-development-suite 构建结果 `manifest.yaml` 自动生成，`ipkg index`
读取并写入统一仓内嵌 `registry.yaml`。

## 顶层字段

```yaml
schema_version: "2.0"        # 必需：schema 版本（统一建仓）
name: apb_gpio_lite          # 必需：IP 名称（与 VLNV 中 Name 一致）
version: "1.0.0"             # 必需：SemVer 版本
vendor: rtl-team             # 必需：VLNV 中 Vendor
library: rtl                 # 必需：VLNV 中 Library
description: string          # 可选：IP 描述
license: MIT                 # 必需：许可证（MIT|Apache-2.0|BSD-3-Clause|Proprietary）
path: "ips/rtl-team/apb_gpio_lite/1.0.0"   # 必需：统一仓内相对目录
manifest_sha256: string      # 可选：冻结清单 manifest.yaml 的 SHA-256
quality:                     # 可选：质量门禁（来自构建结果）
  gates:                     # G0-G5 状态
    G0: pass
    G1: pass
    G2: pass
    G3: pass
    G4: pass
    G5: pass
dependencies: []             # 可选：依赖列表
fusesoc:                     # 必需：FuseSoC 信息
  core: "rtl-team:rtl:apb_gpio_lite:1.0.0"  # VLNV 标识
  cores: "ips/rtl-team/apb_gpio_lite/1.0.0/fusesoc"  # 可选：core 目录相对路径
```

## 字段说明

### name
- 小写、下划线命名（与 IP 工作区 `ip_<name>` 中的 `<name>` 一致）
- 示例：`apb_gpio_lite`, `conv2d_accel`

### version
- 严格 SemVer 2.0.0：`major.minor.patch`，可选 `-pre` 和 `+build`
- 示例：`1.0.0`, `1.0.0-rc.1`

### vendor / library
- 与 `fusesoc.vendor` / `fusesoc.library` 配置一致
- 示例：`rtl-team` / `rtl`

### path
- IP 版本在统一仓内的相对目录（`ips/<vendor>/<ip>/<version>`）
- 不再有 per-IP 独立仓库的 `repository` URL；所有 IP 都在统一仓内

### license
- 必须是受支持的值之一，否则 `stage` 回退到 MIT
- `MIT` | `Apache-2.0` | `BSD-3-Clause` | `Proprietary`

### quality.gates
- 每个门禁的值：`pass` | `fail` | `unknown`
- 来自构建结果 `manifest.yaml` 的 quality 段（G5 formal 必须全 pass）

### dependencies
- 列表，每项包含 `name`、`version`（约束）、`vendor`、`library`
- 与 FuseSoC `depend` 语义一致（`^`、`~`、`>=` 等）

## 生成与消费

| 阶段 | 动作 |
|------|------|
| `ipkg stage` | 从构建结果 `release/<ip>_<ver>/manifest.yaml` 生成 |
| `ipkg index` | 从该文件生成 registry.yaml 条目（统一仓内嵌索引） |
| `ipkg publish` | 从 registry 决定 tag |
| 用户 / FuseSoC | 通过统一仓 `fusesoc/*.core` 消费（复用构建结果，不重建） |

## 完整示例

```yaml
schema_version: "2.0"
name: apb_gpio_lite
version: "1.0.0"
vendor: rtl-team
library: rtl
description: |
  APB GPIO Lite Controller: 8-bit GPIO output data, output enable,
  input readback and rising-edge interrupt on an APB slave interface.
license: MIT
path: ips/rtl-team/apb_gpio_lite/1.0.0
manifest_sha256: a1b2c3...
quality:
  gates:
    G0: pass
    G1: pass
    G2: pass
    G3: pass
    G4: pass
    G5: pass
dependencies: []
fusesoc:
  core: rtl-team:rtl:apb_gpio_lite:1.0.0
  cores: ips/rtl-team/apb_gpio_lite/1.0.0/fusesoc
```
