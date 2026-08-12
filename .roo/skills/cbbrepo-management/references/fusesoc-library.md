# FuseSoC Core Library 参考

## 概述

FuseSoC Core Library 是存储和管理 FuseSoC cores 的目录结构。本参考文档详细说明 Core Library 的组成和操作。

## Core Library 结构

### 标准目录布局

```
core-library/
├── fusesoc.conf              # 库配置文件
├── <vendor>/
│   └── <library>/
│       └── <core-name>/
│           ├── <version>/
│           │   └── <core-name>.core
│           └── latest -> <version>  # 符号链接（可选）
└── ...
```

### 示例：RTL Team 统一仓（monorepo）

本套件采用**统一仓**：所有 IP 内容集中在唯一 GitHub 仓库，按
`ips/<vendor>/<ip>/<version>/` 组织，FuseSoC 只 add 这一个仓。

```
ip-unified/
├── registry.yaml                 # 内嵌索引（IP 元数据）
└── ips/
    └── rtl-team/
        └── rtl/
            ├── apb_gpio_lite/
            │   ├── 1.0.0/
            │   │   └── fusesoc/apb_gpio_lite.core
            │   └── 1.1.0/
            │       └── fusesoc/apb_gpio_lite.core
            ├── mect/
            │   └── 1.0.0/
            │       └── fusesoc/mect.core
            └── conv2d_accel/
                └── 1.0.0/
                    └── fusesoc/conv2d_accel.core
```

> 说明：`fusesoc/*.core` 复用 ip-development-suite `08-fusesoc-packager`
> 的构建结果，**不**在本套件重新生成。

## fusesoc.conf 配置

### 基本格式

```ini
# FuseSoC 配置文件
# 位置：Core Library 根目录

[library.<name>]
# 库位置（必需）
location = /path/to/cores

# 是否自动同步（可选，默认 true）
auto-sync = true

# 远程仓库 URL（可选）
sync-uri = https://github.com/org/ip-repository.git

# 同步类型：git | local（可选，默认 local）
sync-type = git

# 同步分支（可选，默认 default branch）
sync-branch = main
```

### 多库配置示例

```ini
# 本地开发库
[library.local]
location = /home/user/ip_dev
auto-sync = false

# 团队中央库
[library.central]
sync-uri = https://github.com/rtl-team/ip-repository.git
sync-type = git
auto-sync = true

# 第三方公开库
[library.fusesoc-cores]
sync-uri = https://github.com/fusesoc/fusesoc-cores.git
sync-type = git
auto-sync = false
```

## Core 文件格式（CAPI=2）

### 完整结构

```yaml
CAPI=2:
# 必需的第一行

# === 元数据 ===
name: <vendor>:<library>:<name>:<version>
description: "Brief description of this core"

# === 文件集 ===
filesets:
  <fileset-name>:
    files:
      - path/to/file1.sv
      - path/to/file2.sv:
          is_include_file: true
          file_type: systemVerilogHeader
    file_type: systemVerilogSource
    depend:
      - ">=other:vendor:lib:name:version"

# === 生成器（可选）===
generate:
  <generator-name>:
    generator: <generator-script>
    parameters:
      key: value

# === 目标 ===
targets:
  <target-name>:
    filesets:
      - <fileset-name>
    toplevel: <top-module-name>
    tools:
      <tool-name>:
        <tool-option>: <value>
    parameters:
      <param-name>: <value>

  default:
    filesets:
      - rtl
    toplevel: <top-module-name>
```

### 示例：apb_gpio_lite.core

```yaml
CAPI=2:
name: rtl-team:rtl:apb_gpio_lite:1.0.0
description: |
  APB GPIO Lite Controller: 8-bit GPIO output data, output enable,
  input readback and rising-edge interrupt on an APB slave interface.

filesets:
  rtl_includes:
    files:
      - rtl/include/apb_gpio_lite_defs.svh:
          is_include_file: true
          file_type: systemVerilogHeader

  rtl_generated:
    files:
      - rtl/generated/apb_gpio_lite_csr_pkg.sv
      - rtl/generated/apb_gpio_lite_csr.sv
    file_type: systemVerilogSource

  rtl_handwritten:
    files:
      - rtl/apb_gpio_lite_edge_detect.sv
      - rtl/apb_gpio_lite_irq_agg.sv
      - rtl/apb_gpio_lite_top.sv
    file_type: systemVerilogSource

  verif_harness:
    files:
      - verification/th/harness.sv
    file_type: systemVerilogSource

targets:
  rtl:
    filesets:
      - rtl_includes
      - rtl_generated
      - rtl_handwritten
    toplevel: apb_gpio_lite_top

  sim:
    filesets:
      - rtl_includes
      - rtl_generated
      - rtl_handwritten
      - verif_harness
    toplevel: harness
    tools:
      vcs:
        compile_args: "-ntb_opts uvm-1.2"
    default_tool: vcs

  lint:
    filesets:
      - rtl_includes
      - rtl_generated
      - rtl_handwritten
    toplevel: apb_gpio_lite_top
    tools:
      vcs:
        compile_args: "-lint -sverilog"
    default_tool: vcs

  synth:
    filesets:
      - rtl_includes
      - rtl_generated
      - rtl_handwritten
    toplevel: apb_gpio_lite_top
    tools:
      dc:
        synth_file: constraints/apb_gpio_lite.sdc
    default_tool: dc

  default:
    filesets:
      - rtl_includes
      - rtl_generated
      - rtl_handwritten
    toplevel: apb_gpio_lite_top
```

## Core 搜索与发现

### FuseSoC 搜索机制

```bash
# 1. 添加库
fusesoc library add my-ip https://github.com/rtl-team/ip-repository.git

# 2. 列出所有可用的 cores
fusesoc core list

# 3. 搜索特定 IP
fusesoc core show rtl-team:rtl:apb_gpio_lite:1.0.0

# 4. 查看 core 信息
fusesoc info rtl-team:rtl:apb_gpio_lite:1.0.0
```

### Core 文件查找规则

1. FuseSoC 从配置的库路径递归搜索 `*.core` 文件
2. 每个 `.core` 文件解析后添加到内存数据库
3. 同名 VLNV 的 core，后解析的覆盖先解析的
4. 遇到 `FUSESOC_IGNORE` 文件的目录被跳过

## 依赖解析

### 依赖图构建

```
顶层 Core
    │
    ├── depend: core-A
    │       └── depend: core-B
    │
    └── depend: core-C
            └── depend: core-B (已解析，跳过)
```

### 版本解析算法

```python
def resolve_version(constraints, available_versions):
    """
    根据约束选择最合适的版本
    
    Args:
        constraints: ["^1.0.0", ">=1.0.0 <2.0.0"]
        available_versions: ["1.0.0", "1.1.0", "1.2.0", "2.0.0"]
    
    Returns:
        最佳匹配版本: "1.2.0"
    """
    candidates = []
    for version in available_versions:
        if all(satisfies_constraint(version, c) for c in constraints):
            candidates.append(version)
    
    if not candidates:
        raise NoMatchingVersion()
    
    # 返回最高版本
    return max(candidates, key=parse_version)
```

## 文件导出

### 默认行为（导出）

```bash
fusesoc run rtl-team:rtl:apb_gpio_lite:1.0.0
# 文件复制到 build/<vlnv>/<target>/src/
```

### 不导出（引用原文件）

```bash
fusesoc run --no-export rtl-team:rtl:apb_gpio_lite:1.0.0
# 文件在原位置引用
```

## 与 IP 仓库管理套件的集成

### 统一仓消费（推荐）

本套件采用统一仓 monorepo。消费者一次性添加统一仓，即可发现全部 IP：

```bash
fusesoc library add ip-unified https://github.com/<org>/ip-unified.git
fusesoc run --target sim rtl-team:rtl:apb_gpio_lite:1.0.0
```

统一仓 CI 会扫描 `ips/**/fusesoc/*.core` 对每个 core 做 lint 验证。

### core 文件的来源

统一仓内的 `fusesoc/*.core` **复用** ip-development-suite `08-fusesoc-packager`
的构建结果（`ip_<name>/fusesoc/<vendor>_<library>_<ip>.core`），由 `ipkg stage`
原样复制入库，**不在本套件重新生成**。core 文件内 filesets 使用相对本 core 文件
的路径（如 `../rtl/...`），入库后保持目录层级不变即可正确解析。

## 参考资料

- [FuseSoC 官方文档](https://fusesoc.readthedocs.io/)
- [CAPI2 规范](https://fusesoc.readthedocs.io/en/latest/ref/capi2.html)
- [FuseSoC GitHub](https://github.com/olofk/fusesoc)