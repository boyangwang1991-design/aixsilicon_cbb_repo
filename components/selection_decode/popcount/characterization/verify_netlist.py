#!/usr/bin/env python3
# ============================================================================
# verify_netlist.py — Change C2 阶段①：Python bit-exact 全参数验证
# ----------------------------------------------------------------------------
# 层次化测试策略（用户指令顺序）：Python 先行 → 可视化 → SV 回归。
#
# L1 调度级   : verify_schedule.py   （506/506 PASS——高度序列守恒/收敛）
# L2 网表级   : 本文件——用 gen_schedule.build_netlist 生成的 FA 网表做
#               **bit-exact 仿真**：
#                 - 每个 dot 是真值 0/1 的信号；
#                 - FA(a,b,c) = (maj, xor) 逐门计算；
#                 - 输入位流全遍历(W≤14)或定 seed 随机(大 W) 比对 popcount。
# L3 RTL 级   : VCS exhaust_w8/edge/random3000 + fm_shell LEC（既存证据链）
#
# 用法: uv run python verify_netlist.py [W1,W2,...]   # 缺省 {8,14,33,64,127,256}
# ============================================================================
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_schedule import build_netlist  # noqa: E402


def sim_netlist(assigns, finals, val, W):
    """对给定输入值位精确求值网表。assigns: [(co,s,a,b,c)名], finals:[(sig,col)]"""
    env = {}
    for i in range(W):
        env["data_i[%d]" % i] = (val >> i) & 1

    # 网表天然拓扑序（生成按轮推进、列间自左向右，carry 只向右/向后传）
    for co, s, a, b, c in assigns:
        av, bv, cv = env[a], env[b], env[c]
        env[s] = av ^ bv ^ cv
        env[co] = (av & bv) | (av & cv) | (bv & cv)

    total = 0
    for nm, c in finals:
        if nm.startswith("data_i"):
            v = env[nm]
        else:
            v = env.get(nm, 0)
        total += v << c
    return total


def golden(v):
    return bin(v).count("1")


def main():
    ws = [int(x) for x in sys.argv[1].split(",")] if len(sys.argv) > 1 \
        else [4, 7, 8, 12, 14, 16, 33, 64, 127, 256]

    rng = random.Random(0xC0FFEE)
    fails = 0
    total = 0
    for W in ws:
        for mode in ("wallace", "dadda"):
            assigns, finals = build_netlist(mode, W)
            nfa = len(assigns)
            cases = []
            if W <= 14:
                cases = list(range(1 << W))
            else:
                cases = [0, ~0 & ((1 << W) - 1)] + \
                        [rng.randrange(1 << W) for _ in range(2000)]
                cases += [1 << k for k in range(W)]           # one-hot 扫描
            bad = 0
            for v in cases[:60000]:
                got = sim_netlist(assigns, finals, v, W)
                exp = bin(v).count("1")
                if got != exp:
                    bad += 1
                    if bad <= 2:
                        print("FAIL %s W=%d v=0x%x got=%d exp=%d"
                              % (mode, W, v, got, exp))
            ok = (bad == 0)
            total += 1
            fails += (not ok)
            print("%s W=%-3d %-7s FA=%-4d vectors=%-6d %s"
                  % ("PASS" if ok else "FAIL", W, mode, nfa,
                     len(cases[:60000]), "" if ok else "<<<"))

    print("\nnetlist validation: %d/%d PASS" % (total - fails, total))
    return 10 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
