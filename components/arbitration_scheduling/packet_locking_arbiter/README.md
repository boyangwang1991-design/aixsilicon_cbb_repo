# packet_locking_arbiter

ARB-010，0.1.0实现候选。支持EOP或接受拍长度结束的整包RR调度，
背压和包内空拍期间保持归属，末拍接受后下一周期可立即选择下一包。

- 参数：NUM_REQ=1..64、LOCK_MODE=0(EOP)/1(长度)、LEN_W=1..16。
- `grant_o`表示归属；实际传输是`ready_i && |(grant_o & req_i)`。
- 长度模式在首次归属沿采样总拍数；长度0不参与空闲仲裁；已锁定后的length变化忽略。
- 单时钟、异步低有效复位、外部同步释放；无payload缓存、无abort、无超时。
- RR按完成包数公平；不承诺按字节公平或无条件的周期等待上界。

契约：`cbb.yaml`/`behavior.yaml`；[规格](docs/cbb_spec.md)、[详设](docs/detail-design/impl_mask_lock.md)、
[验收报告](reports/qualification-report.md)、[PPA](reports/ppa-report.md)。
资产成熟度保持候选状态；生产IP集成和正式发布单独治理。

## 依赖与集成

依赖`aixsilicon:cbb:fixed_priority_arbiter:0.1.0`：N>=2时通过其稳定顶层接口例化两路
组合树选择器。N=1不实例化该子模块。请使用本次附带的修正Core（补全FuseSoC参数类型），
其RTL内容未改。示例`examples/packet_mux.sv`展示数据/valid/ready/last绑定；它不是生产AXI VIP。
源码可直接用VCS编译，构建和回归不依赖私有SKILL。

## 重放

从workflow工作区根运行（复用根uv环境）；将`CBB`指向本目录：

```bash
export UV_CACHE_DIR="$PWD/cache/uv"
CBB=repos/aixsilicon_cbb_repo/components/arbitration_scheduling/packet_locking_arbiter
uv run --no-sync python "$CBB/verification/scripts/run_verification.py" --phase all
uv run --no-sync --with matplotlib python "$CBB/characterization/run_ppa.py" --run-id NEW_RUN_ID
uv run --no-sync python "$CBB/verification/scripts/run_formal.py" --run-id NEW_RUN_ID
```

脱离本工作区时Python依赖是PyYAML（构建元数据/验证）和matplotlib（画图），
可用`uv run --with PyYAML ...`及`uv run --with PyYAML --with matplotlib ...`提供；
依赖目录可通过验证/PPA脚本`--dep`指定。Formality脚本使用并排的依赖目录。
PPA必须提供本机`build/eda/pdk.local.yaml`，不能从发布包获取商业库；
本工作区由pdk-scan生成，精确库路径不入库。原始EDA结果保存在`build/eda`。
FuseSoC示例：分别将本构件和固定优先级构件目录传入`--cores-root`，然后
`run --target=sim --setup --build --run aixsilicon:cbb:packet_locking_arbiter:0.1.0`。
