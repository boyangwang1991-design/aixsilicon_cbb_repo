# IP Unified Repository

统一 IP 仓库（monorepo）。承载所有 IP 内容，按 `ips/<vendor>/<ip>/<version>/` 组织，
内嵌 `registry.yaml` 索引。FuseSoC 只 add 这一个仓即可发现全部 IP。

## 用法

### 添加统一仓（消费者，一次性）

```bash
fusesoc library add ip-unified https://github.com/<org>/ip-unified.git
```

### 搜索 IP

```bash
ipkg search gpio
ipkg list
ipkg info apb_gpio_lite 1.0.0
```

### 入库新 IP / 新版本（发布侧）

```bash
# 1. 从构建结果入库
ipkg stage <ip-workspace> --unified . --then-index

# 2. 提交推送（含 tag）
ipkg publish .
```

索引与内容在同一提交中更新，无需独立 PR。

## 结构

```
ip-unified/
├── README.md
├── registry.yaml                 # 内嵌索引（全部 IP 元数据）
├── ips/
│   └── <vendor>/<ip>/<version>/  # 每个版本一个目录（含 ip-package.yaml）
└── .github/workflows/
    └── ci.yml                    # 统一仓 CI：扫描全部 core 做 lint
```

## registry.yaml 条目格式

```yaml
schema_version: "2.0"
unified_repo: "https://github.com/<org>/ip-unified.git"
ips:
  - name: apb_gpio_lite
    vendor: rtl-team
    library: rtl
    description: "APB GPIO Lite Controller"
    license: "MIT"
    path: "ips/rtl-team/apb_gpio_lite"
    versions:
      - version: "1.0.0"
        tag: "apb_gpio_lite-v1.0.0"
        path: "ips/rtl-team/apb_gpio_lite/1.0.0"
        gates: {G0: pass, G1: pass, G2: pass, G3: pass, G4: pass, G5: pass}
        fusesoc:
          core: "rtl-team:rtl:apb_gpio_lite:1.0.0"
```

## 与 FuseSoC 集成

```bash
fusesoc library add ip-unified https://github.com/<org>/ip-unified.git
fusesoc run --target sim rtl-team:rtl:my_project:1.0.0
```
