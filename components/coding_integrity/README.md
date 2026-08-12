# coding_integrity — CRC、编码、压缩与数据完整性算法

对应 cbb_repo_list.md 第 5 节。

| ID | 构件族 | 级别 | 优先级 | PPA 关注点 |
| --- | --- | --- | --- | --- |
| COD-001 | Parity Generator/Checker | A1 | P0 | XOR树平衡 |
| COD-002 | CRC Generator/Checker | A2 | P1 | 多项式、数据宽度、吞吐 |
| COD-003 | SECDED ECC | A2 | P0 | 校验位、纠错延迟 |
| COD-004 | Configurable Hamming ECC | A2 | P1 | 参数合法域 |
| COD-005 | BCH/RS Codec Wrapper | A2 | P3 | 算法复杂度与授权边界 |
| COD-006 | Gray/Binary Converter | A1 | P0 | CDC计数器复用 |
| COD-007 | Scrambler/Descrambler | A2 | P2 | 并行展开与吞吐 |
| COD-008 | LFSR/PRBS | A1/A2 | P1 | 多项式与切换功耗 |
| COD-009 | Run-length Encoder/Decoder | A2 | P3 | 数据相关吞吐 |
| COD-010 | Zero Suppression/Bitmap Codec | A2 | P3 | 元数据开销与活动率 |
| COD-011 | Byte/Bit Order Converter | A1 | P0 | 固定连线优先 |
| COD-012 | Data Packer/Unpacker | A2 | P1 | Mux规模与时序 |

> 各 CBB 目录以**功能名**命名；当前为**空工程包 + README 需求说明**，开发时按 [docs/cbb_spec](../../docs/cbb_spec/README.md) 展开标准工程包。
