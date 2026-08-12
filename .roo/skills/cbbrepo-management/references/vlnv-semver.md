# VLNV 命名与 SemVer 规范

## VLNV 标识符

### 概述

VLNV（Vendor:Library:Name:Version）是 FuseSoC 中标识 IP core 的唯一命名规范。

### 格式定义

```
<vendor>:<library>:<name>:<version>
```

| 组成部分 | 说明 | 示例 |
|----------|------|------|
| Vendor | 供应商/组织标识 | `rtl-team`, `opencores`, `user` |
| Library | 库名/分类 | `rtl`, `verification`, `test` |
| Name | IP 名称 | `apb_gpio_lite`, `mect` |
| Version | 版本号（SemVer） | `1.0.0`, `2.3.4` |

### 命名规则

```
Vendor:
  - 允许字符：小写字母、数字、连字符（-）、下划线（_）
  - 建议使用组织名或团队名
  - 示例：rtl-team, opencores, lowrisc

Library:
  - 允许字符：小写字母、数字、下划线（_）
  - 用于区分同一 vendor 下的不同库
  - 示例：rtl, verification, ips, soc

Name:
  - 允许字符：小写字母、数字、下划线（_）
  - 与 IP 名称一致
  - 示例：apb_gpio_lite, mect, conv2d_accel

Version:
  - 必须符合 SemVer 格式：major.minor.patch
  - 示例：1.0.0, 0.1.0, 2.1.3
```

### 示例

```
# 有效 VLNV
rtl-team:rtl:apb_gpio_lite:1.0.0
rtl-team:rtl:mect:1.0.0
opencores:rtl:uart:2.0.0
lowrisc:ip:uart:0.1.0

# 无效 VLNV（错误原因）
RTL-Team:rtl:gpio:1.0.0      # Vendor 包含大写（应为小写）
rtl-team:RTL:gpio:1.0.0      # Library 包含大写
rtl-team:rtl:gpio-lite:1.0.0 # Name 包含连字符（应使用下划线）
rtl-team:rtl:gpio:v1         # Version 不符合 SemVer
```

## 语义化版本（SemVer）

### 格式定义

```
MAJOR.MINOR.PATCH

MAJOR - 主版本号（不兼容的重大变更）
MINOR - 次版本号（向后兼容的功能新增）
PATCH - 补丁版本号（向后兼容的问题修复）
```

### 版本递增规则

| 变更类型 | MAJOR | MINOR | PATCH | 示例 |
|----------|-------|-------|-------|------|
| 重大变更（不兼容 API） | +1 | 0 | 0 | 1.0.0 → 2.0.0 |
| 新增功能（向后兼容） | - | +1 | 0 | 1.0.0 → 1.1.0 |
| Bug 修复（向后兼容） | - | - | +1 | 1.0.0 → 1.0.1 |

### 预发布版本

```
1.0.0-alpha      # Alpha 版本
1.0.0-alpha.1    # Alpha 第 1 次迭代
1.0.0-beta       # Beta 版本
1.0.0-beta.2     # Beta 第 2 次迭代
1.0.0-rc.1       # Release Candidate
```

### 版本比较

```
1.0.0 < 1.0.1 < 1.1.0 < 2.0.0

预发布版本排序：
1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-beta < 1.0.0-rc.1 < 1.0.0
```

## 版本约束

### 支持的操作符

| 操作符 | 含义 | 约束 | 匹配版本示例 | 不匹配版本示例 |
|--------|------|------|--------------|----------------|
| `=` | 精确匹配 | `=1.0.0` | `1.0.0` | `1.0.1`, `0.9.0` |
| `>` | 大于 | `>1.0.0` | `1.0.1`, `2.0.0` | `1.0.0`, `0.9.0` |
| `>=` | 大于等于 | `>=1.0.0` | `1.0.0`, `1.1.0` | `0.9.0` |
| `<` | 小于 | `<2.0.0` | `1.9.9`, `1.0.0` | `2.0.0`, `2.1.0` |
| `<=` | 小于等于 | `<=1.5.0` | `1.5.0`, `1.4.0` | `1.5.1`, `2.0.0` |
| `^` | Caret | `^1.2.3` | `>=1.2.3 <2.0.0` | - |
| `~` | Tilde | `~1.2.3` | `>=1.2.3 <1.3.0` | - |

### Caret 约束（^）

Caret 约束允许更新到下一个主版本之前的任何版本。

```
^1.2.3  →  >=1.2.3 <2.0.0    （允许 1.x.x 的任何更新）
^1.2    →  >=1.2.0 <2.0.0    （省略 patch）
^1      →  >=1.0.0 <2.0.0    （省略 minor 和 patch）
^0.2.3  →  >=0.2.3 <0.3.0    （0.x 特殊处理）
^0.0.3  →  =0.0.3            （0.0.x 必须精确匹配）
```

### Tilde 约束（~）

Tilde 约束允许补丁级别更新。

```
~1.2.3  →  >=1.2.3 <1.3.0    （允许 patch 更新）
~1.2    →  >=1.2.0 <1.3.0    （等同于 ~1.2.0）
~1      →  >=1.0.0 <2.0.0    （允许 minor 和 patch 更新）
```

### 组合约束

```yaml
# 多个约束条件（AND 关系）
depend:
  - ">=1.0.0 <2.0.0"  # 1.x.x 系列
  - "!=1.5.0"         # 排除特定版本
```

## 在 IP 开发中的应用

### 版本规划

```
0.x.x  - 开发阶段（API 不稳定）
  0.1.0 - 初始原型
  0.2.0 - 功能验证
  0.9.0 - 准发布版本

1.x.x  - 稳定版本（API 稳定）
  1.0.0 - 首次正式发布
  1.1.0 - 新增功能（向后兼容）
  1.0.1 - Bug 修复

2.x.x  - 重大更新（可能不兼容）
  2.0.0 - 重大架构变更
```

### 发布策略

| 发布类型 | 版本规则 | G5 要求 | Git Tag | 说明 |
|----------|----------|---------|---------|------|
| Snapshot | 0.x.x-dev | 不要求 | 无 | 开发快照 |
| Candidate | x.y.z-rc.N | 要求 | 无 | 发布候选 |
| Formal | x.y.z | 要求 | 有 | 正式发布 |

### 依赖声明示例

```yaml
# manifest.yaml 中的依赖声明
dependencies:
  # 精确版本
  - name: apb_gpio_lite
    version: "=1.0.0"
    vendor: rtl-team
    library: rtl

  # 兼容更新
  - name: mect
    version: "^1.0.0"
    vendor: rtl-team
    library: rtl

  # 补丁更新
  - name: common_lib
    version: "~1.2.0"
    vendor: rtl-team
    library: rtl

  # 范围约束
  - name: axi_interconnect
    version: ">=1.0.0 <2.0.0"
    vendor: vendor-team
    library: interconnect
```

## 版本验证脚本

```python
#!/usr/bin/env python3
"""版本号验证工具"""

import re
import sys
from typing import Tuple

SEMVER_PATTERN = re.compile(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'  # MAJOR.MINOR.PATCH
    r'(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)'  # pre-release
    r'(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?'
    r'(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'  # build metadata
)

def parse_version(version: str) -> Tuple[int, int, int]:
    """解析版本号为 (major, minor, patch)"""
    match = SEMVER_PATTERN.match(version)
    if not match:
        raise ValueError(f"Invalid SemVer: {version}")
    
    major, minor, patch = int(match.group(1)), int(match.group(2)), int(match.group(3))
    return major, minor, patch

def compare_versions(v1: str, v2: str) -> int:
    """比较两个版本号：返回 -1, 0, 1"""
    m1 = parse_version(v1)
    m2 = parse_version(v2)
    
    if m1 < m2:
        return -1
    elif m1 > m2:
        return 1
    else:
        return 0

def satisfies_constraint(version: str, constraint: str) -> bool:
    """检查版本是否满足约束"""
    # 解析约束操作符
    if constraint.startswith('>='):
        return compare_versions(version, constraint[2:]) >= 0
    elif constraint.startswith('<='):
        return compare_versions(version, constraint[2:]) <= 0
    elif constraint.startswith('>'):
        return compare_versions(version, constraint[1:]) > 0
    elif constraint.startswith('<'):
        return compare_versions(version, constraint[1:]) < 0
    elif constraint.startswith('='):
        return version == constraint[1:]
    elif constraint.startswith('^'):
        base = constraint[1:]
        major, minor, patch = parse_version(base)
        if major == 0:
            if minor == 0:
                # ^0.0.x → =0.0.x
                return version == base
            else:
                # ^0.x.y → >=0.x.y <0.(x+1).0
                return (compare_versions(version, base) >= 0 and 
                        compare_versions(version, f"0.{minor+1}.0") < 0)
        else:
            # ^x.y.z → >=x.y.z <(x+1).0.0
            return (compare_versions(version, base) >= 0 and 
                    compare_versions(version, f"{major+1}.0.0") < 0)
    elif constraint.startswith('~'):
        base = constraint[1:]
        major, minor, patch = parse_version(base)
        # ~x.y.z → >=x.y.z <x.(y+1).0
        return (compare_versions(version, base) >= 0 and 
                compare_versions(version, f"{major}.{minor+1}.0") < 0)
    else:
        # 无操作符 = 精确匹配
        return version == constraint

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: version_tool.py <version> <constraint>")
        sys.exit(1)
    
    version = sys.argv[1]
    constraint = sys.argv[2]
    
    try:
        result = satisfies_constraint(version, constraint)
        print(f"{version} satisfies {constraint}: {result}")
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)
```

## 参考资料

- [Semantic Versioning 2.0.0](https://semver.org/)
- [FuseSoC Dependencies](https://fusesoc.readthedocs.io/en/latest/user/build_system/dependencies.html)
- [Cargo SemVer](https://doc.rust-lang.org/cargo/reference/semver.html)