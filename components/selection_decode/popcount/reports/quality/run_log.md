# CBB 运行日志（唯一）

- `2026-08-28 00:49:27` | **design** | Change C3: dadda 移除(用户裁定其调度策略在单列退化场景实现有误风险且无 PPA 增益, 与 wallace 综合趋同 271μm²); 定稿三实现 TREE(0)/WALLACE(1)/LUT(2); wallace 网表回归 PASS | 结果(PASS)
    wrapper PC_IMPL 语义 0=TREE/1=WALLACE/2=LUT; gen_schedule.py 仅发射 wallace 网表; 契约 cbb.yaml/profiles.yaml 清理; 回归: 三路编译矩阵 PASS + wallace 网表 TB 锚点+500随机 PASS
