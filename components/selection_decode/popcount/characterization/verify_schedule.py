#!/usr/bin/env python3
# ============================================================================
# verify_schedule.py — 压缩树调度正确性验证器（Change C2, 2026-08-27）
# ----------------------------------------------------------------------------
# 镜像 impl_wallace / impl_dadda 的编译期（localparam 函数）调度数学：
#   FA@col_c：吃 3 dot → SUM 留本列(-2 净变化) + CARRY 进右列(+1 dot 权 2^(c+1))
#   权值守恒律：Σ h[c]·2^c 恒等于初始 W（初始 W 个 dot 全部位于列 0）
# 验证目标（每参数点）：
#   1) 收敛性：最终各列高度 ≤ 2（可两行收尾）
#   2) 守恒性：Σ h[c]·2^c == W
#   3) 可行性：每处 3f ≤ n（FA 数不超过可用 dot 数）
#   4) 列界安全：任意中间态任一列高度 ≤ W（保证 RTL [W-1:0] 平面够宽）
# 用法：python3 verify_schedule.py            # 全宽度扫描 W∈{4..256}
#       python3 verify_schedule.py 64         # 单点详表
# ============================================================================
from __future__ import annotations
import sys

DTBL = [2, 3, 4, 6, 9, 13, 19, 28, 42, 63, 94, 141, 211, 316]


def seq_hi(w: int) -> int:
    for k, d in enumerate(DTBL):
        if d >= w:
            return k
    return len(DTBL) - 1


def pol_f(mode: str, n: int, r: int) -> tuple[int, int]:
    """返回 (FA 数, 本列净剩)。mode: wallace|dadda"""
    if mode == "wallace":
        f = n // 3
        return f, n - 2 * f
    # dadda: target = DTBL[HI-1-r] 下降段之后恒 2
    hi = seq_hi_cur[0]
    nrung = hi
    tgt = DTBL[hi - 1 - r] if r < nrung else 2
    if n <= tgt:
        return 0, n
    diff = n - tgt
    f = min((diff + 1) // 2, n // 3)   # ceil(diff/2)，可行性钳制 floor(n/3)
    return f, n - 2 * f


def sim(mode: str, W: int, verbose=False):
    """返回 (rounds, 终态列高列表)；断言守恒/可行/列界"""
    seq_hi_cur[0] = seq_hi(W)
    cols = W.bit_length()                     # CNT_W = $clog2(W+1)
    hi = seq_hi_cur[0]
    nrung = hi                                # dadda 下降轮数
    cap = nrung + cols + 4                    # 安全上限（含 CLEAR 收尾）
    h = [0] * cols
    h[0] = W
    rnd = 0
    trace = []
    while rnd < cap:
        if mode == "wallace":
            if max(h) <= 2:
                break
        else:
            # dadda: 下降段耗尽且已全 ≤2 即收敛
            if rnd >= nrung and max(h) <= 2:
                break
        pend = 0
        nh = []
        for c in range(cols):
            eff = h[c] + pend
            f, rem = pol_f(mode, eff, rnd)
            assert 3 * f <= eff, f"feasibility broken r{rnd} c{c}: 3*{f}>{eff}"
            assert eff <= W, f"column bound broken r{rnd} c{c}: {eff}>W"
            nh.append(rem)
            pend = f
        # 尾差论证：最后一列 n<3 ⇒ f=0 ⇒ 无越界 carry
        assert pend == 0 or h[-1] >= 3, f"unexpected tail carry r{rnd}"
        h = nh
        rnd += 1
        if verbose:
            trace.append(list(h))
    wsum = sum(v << c for c, v in enumerate(h))
    ok_conv = max(h) <= 2
    ok_cons = (wsum == W)
    return ok_conv and ok_cons, rnd, h, wsum, trace


seq_hi_cur = [0]


def main() -> int:
    if len(sys.argv) == 2 and sys.argv[1].isdigit():
        W_list = [int(sys.argv[1])]
        verbose = True
    else:
        W_list = list(range(4, 257))
        verbose = False

    fails = []
    for W in W_list:
        for mode in ("wallace", "dadda"):
            ok, rnd, h, wsum, tr = sim(mode, W, verbose)
            status = "PASS" if ok else "FAIL"
            detail = f"W={W:3d} {mode:7s} rounds={rnd:2d} final={h} wsum={wsum}"
            print(detail + ("" if ok else f"  <<< {status}"))
            if verbose:
                for i, t in enumerate(tr):
                    print(f"    r{i}: {t}")
            if not ok:
                fails.append((W, mode))

    n_total = len(W_list) * 2
    print(f"\nschedule validation: {n_total - len(fails)}/{n_total} PASS")
    return 10 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
