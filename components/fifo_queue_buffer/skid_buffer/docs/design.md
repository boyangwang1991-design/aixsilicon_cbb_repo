# 架构（Design）— skid_buffer

> 本文件为**可读派生视图**；SSOT 以 [`../cbb.yaml`](../cbb.yaml) 与 [`../behavior.yaml`](../behavior.yaml) 为准。

## 1. 设计目标

在 valid-ready 数据通路上插入一级打拍，同时：
1. **切断 ready 组合链**（输出侧完全寄存，ready 只依赖寄存状态，深度 ≤1 级）；
2. **满吞吐无气泡**（背压不丢数据、不产生空泡）；
3. **保序**（FIFO 顺序，无丢无重）。

## 2. 微架构（impl_output_registered）

两级 bubble-free 拓扑：

```
                +-------------------+
  in_valid ────▶│                   │───▶ out_valid (FF out_valid_r)
  in_data  ────▶│  OUT 级(out_sel)  │───▶ out_data  (FF out_data_r)
                │   +  SKID 槽       │
  out_ready───▶ │                   │───▶ in_ready (组合，深度≤1)
                +-------------------+
```

- **OUT 级**：`out_valid_r`/`out_data_r`（输出寄存，FF 驱动）；
- **SKID 槽**：`buf_valid_r`/`buf_data_r`（背压吸收槽）；
- **控制**：`in_ready = ~out_valid_r | out_ready | ~buf_valid_r`（全满才反压）；
  **槽优先**——输出级腾出（`out_ready | ~out_valid_r`）时先补槽数据（FIFO 保序），
  槽空才输入直达；输入被接受（`in_valid & in_ready`）时必被捕获：直达输出级
  或替换槽数据 / 进槽（槽必空）。

## 3. 守恒论证

- **满吞吐**：`in_valid && in_ready |-> ##1 out_valid`——输入被接受后下一拍输出级必有效；
- **不丢数据**：输入仅在 `in_ready` 时被接受；全满（反压）时输入不被采样；
- **保序**：输出级腾出时**槽数据优先**于新输入（FIFO 顺序），不越序；
- **无重复**：输出级每拍最多装载一次（槽补或直达二选一）；
- **槽容量守恒**：槽写入仅在 `in_valid && in_ready` 且输出级满未腾出（槽必空）或
  槽补输出级时被新输入替换（保持 1 槽）；清空仅在槽补输出级且无输入替换时，
  无溢出/下溢。

## 4. 时钟/复位/DFT

- 单时钟域；低有效异步复位（negedge），同步释放由集成层保证；
- 无 ICG/ISO/Retention/多电源域（A3 默认不引入低功耗结构；白名单外不改写）。

## 5. 依赖

- 无运行时子 CBB 依赖（`implementations[].dependencies[] = []`）；
- 无 HWIF 接口文件（原生 valid-ready，无总线协议语义）。

## 6. 非目标

BYPASS 直通（STR-007）、多级打拍（QUE-008）、fall-through、CDC/RDC。
