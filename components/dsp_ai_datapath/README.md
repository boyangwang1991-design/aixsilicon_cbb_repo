# dsp_ai_datapath — DSP、图像与 AI 数据搬运公共构件

对应 cbb_repo_list.md 第 19 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| DSP-001 | Lane Packer/Unpacker | A2/A3 | P2 | 布线和有效位 |
| DSP-002 | Vector Reduction | A2 | P2 | 树形、流水、精度 |
| DSP-003 | Dot-product Tree | A2 | P2 | MAC数量与吞吐 |
| DSP-004 | Sliding Window Generator | A2/A3 | P2 | 存储带宽和边界 |
| DSP-005 | Tensor Layout Converter | A3 | P3 | Buffer和地址生成 |
| DSP-006 | Tile Address Generator | A2 | P2 | 乘法消除、增量地址 |
| DSP-007 | Stride/Dilation Address Generator | A2 | P2 | 控制面积和吞吐 |
| DSP-008 | Scatter/Gather Index Generator | A2 | P3 | 随机访存和队列 |
| DSP-009 | DMA Descriptor Walker Core | A4 | P3 | 若含完整DMA则升级为IP |
| DSP-010 | Quantization Pipeline | A2/A3 | P2 | 位宽、乘法与流水 |
| DSP-011 | Activation Approximation | A2 | P3 | 精度/面积 |
| DSP-012 | Sparse Bitmap/Index Decoder | A2/A3 | P3 | 控制分支与吞吐 |
| DSP-013 | Accumulator Bank | A2 | P2 | 写冲突和位宽 |
| DSP-014 | Double-buffer Controller | A2 | P2 | 计算搬运重叠 |
| DSP-015 | Loop/Nested-counter Generator | A2 | P2 | 控制复用 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
