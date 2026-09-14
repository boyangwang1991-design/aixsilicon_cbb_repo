# Constant Multiplier

单输入、编译期常系数的精确整数乘法与可选量化。需求见 [原始契约](constant_multiplier_contract.md)，架构及参数承载见 [设计说明](docs/design.md)。当前为开发候选，支持范围及未完成验收见 [验证报告](reports/verification-report.md)。

- `rtl/constant_multiplier.sv`：参数化 NATIVE/AUTO 基线，FULL 位宽自动推导。
- `tools/generate.py`：BINARY、CSD、有预算上限的 ADDER_GRAPH，以及 NATIVE/AUTO；输出独立单文件 RTL、DAG、配置、接口清单、Core 与验证入口。
- `model/reference.py`：独立 Python 任意精度参考模型。
- `verification/run.py`：VCS 数值、周期、负向及故障注入回归；`verification/formal/run_equivalence.py`：限定配置的 Formality 证明。
- `characterization/run_ppa.py`：固定库代表点综合；`characterization/report.py`：抽取报告和比较图。
- `characterization/diagnose_failure.py`：关联 DC 子进程与内核 OOM 证据；`characterization/retry_ppa.py`：有内存与时间上限的隔离重试。

当前固定库综合完成 11/12 点。W128/L0、`COEFF=-(2^127-1)`、BINARY 在算术映射阶段因系统内存不足被 OOM killer 杀死，随后 DC 报告内部错误；该点 PPA 保持 unavailable。降低 datapath 优化等级的重试也耗尽内存，传统 compile 重试按本次收尾要求终止。该配置已有 RTL 功能仿真通过记录，不能将其等同于综合或时序通过。详见 [PPA 报告](reports/ppa-report.md) 与 [失败诊断](reports/ppa-failure-diagnosis.json)。

从组件目录执行（工作区使用根 uv 环境；独立环境需 Python 3.11+、PyYAML，画图另需 matplotlib）：

```sh
uv run --no-sync python tools/generate.py examples/default.yaml --out build/example
uv run --no-sync python verification/run.py --quick
uv run --no-sync python verification/run.py
uv run --no-sync python verification/run.py --matrix --out build/eda/matrix_regression
uv run --no-sync python verification/static.py
uv run --no-sync python verification/formal/run_equivalence.py
uv run --no-sync python tools/package.py
uv run --no-sync fusesoc --cores-root . run --target=sim --build-root build/fusesoc aixsilicon:cbb:constant_multiplier:0.1.0
uv run --no-sync python characterization/run_ppa.py --library /path/to/selected.db
uv run --no-sync python characterization/report.py
```

生成配置使用源契约中的大写名称；COEFF 推荐十进制字符串，拒绝浮点。FULL 不接受右移、舍入或饱和修改，输出宽度及符号自动计算。QUANTIZED 必须显式指定 OUTPUT_WIDTH/OUTPUT_SIGNED。`cbb.yaml` 中枚举以整数编码供套件约束器使用，`encoding` 给出名称映射；生成器同时接受名称与对应编码。YAML 整数也以任意精度解析。

SV `OUTPUT_MODE`：0=FULL、1=QUANTIZED；`ROUND_MODE`：0=FLOOR、1=TOWARD_ZERO、2=NEAREST_EVEN；`OVERFLOW_MODE`：0=WRAP、1=SATURATE。直接实例化的 `IMPL` 只接受 0=NATIVE 或 4=AUTO；其余结构通过生成器输出固定配置独立模块。COEFF 为 129 位 signed 参数，COEFF_WIDTH 自动推导并限制为 1–128；超出承载的值须在 SV 截断前由配置入口拒绝。

LATENCY 以 ce=1 的推进边沿计数，L=1 在接收边沿后输出。同步低有效复位优先于 ce，仅清 valid；无效数据及 overflow 无功能保证。接收方必须按 ce 推进，不能重复消费暂停期间保持的 valid。无运行时系数端口或 ready。流水生成图包括分支配平和最终输出寄存器；NATIVE 的延迟由输出寄存器满足，不宣称算术切分。

固定模块端口输出为位向量，其符号解释由生成清单 `output_signed` 指明。生成产物不依赖私有 skill；重新生成必须使用同版本脚本与配置。`build/` 中保留本地原始证据与工艺路径，不作为发布内容。
