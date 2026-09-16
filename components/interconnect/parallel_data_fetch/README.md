# parallel_data_fetch

Parallel Data Fetch （A3, P2, INT-001）

单请求远端原子快照经窄链路连续回传并在请求端重组；以传输时延换取长距布线资源。
不承担地址选择、标准总线协议、多 outstanding、packet/credit/路由/CRC 重传与软件寄存器。

见 registry.yaml（SSOT）。CBB 工程包规范见 cbb-development-suite。

需求入口：[parallel_data_fetch 需求合同](parallel_data_fetch_contract.md)。文档齐全不代表实现或 Gate 通过。