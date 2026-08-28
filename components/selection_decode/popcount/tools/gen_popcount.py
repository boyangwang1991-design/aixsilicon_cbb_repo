#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ============================================================================
# gen_popcount.py — popcount Wallace tree / 4:2 compressor 电路生成器 (SEL-014)
# ----------------------------------------------------------------------------
# 动态生成理由：popcount 的归约级数、每级列高、4:2 列间 cin/cout 链随 DATA_W
# 变化，用 generate 写参数化模板冗长易错且结构不可预测；本脚本按位宽显式
# 展开为扁平 `assign` 网表（结构完全确定，综合/STA 结果可复现），落入 rtl/gen/。
#
# 归约模型（正确性）：
#   * popcount = 把 DATA_W 个输入位求和（每输入位权重 1）。故初始仅“权重 0
#     列”含 DATA_W 个计数位，其余列为空。
#   * 每轮归约对每列（由低到高）压缩：3 个同列 bit→FA{sum 同列, carry 高列}，
#     2 个→HA{sum 同列, carry 高列}；4:2 compressor{sum 同列, carry 高列,
#     cout 传给高列 4:2 的 cin（列间链），链末 cout 作为普通进位进高列}。
#   * 权重列守恒：任一列的 bit 数 × 2^权重 之和恒等于输入中 1 的个数。
#   * 归约至每列 ≤2 → 两行 → NBITS 位 ripple-carry（含 carry-in 链）收尾，
#     NBITS = clog2(DATA_W+1)。
#
# 生成的模块（端口一致，非参数化）：
#   popcount_wallace_d<W>   : FA(3:2)+HA(2:1) Wallace 归约
#   popcount_compressor_d<W>: 4:2 compressor（cin/cout 列间链）+FA/HA 归约
#
# 用法: python3 tools/gen_popcount.py [--widths 8 16 32 64] [--out rtl/gen]
# 依赖: 仅标准库（兼容 python3.6）
# ============================================================================
import argparse
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT = os.path.join(ROOT, "rtl", "gen")


def clog2(n):
    return (n - 1).bit_length()


def majority3(a, b, c):
    """三输入多数门表达式（FA carry）。"""
    return "((%s & %s) | (%s & %s) | (%s & %s))" % (a, b, a, c, b, c)


def fmt_wire(names):
    """把信号列表排版为 4 列 logic 声明文本。"""
    if not names:
        return ""
    per_line = 4
    out = []
    for i in range(0, len(names), per_line):
        grp = names[i:i + per_line]
        out.append("    logic %s;" % ", ".join(grp))
    return "\n".join(out)


def build_cols(w):
    """初始列：仅权重 0 列含全部输入位。"""
    cols = [[] for _ in range(3)]
    cols[0] = ["din[%d]" % i for i in range(w)]
    return cols


def gen_wallace(w):
    """Wallace（FA+HA）归约。返回 (assigns, wires)。"""
    assigns, wires = [], []
    cols = build_cols(w)

    def add(name, expr, comment):
        wires.append(name)
        assigns.append("    assign %s = %s; // %s" % (name, expr, comment))

    stage = 0
    fa = ha = 0
    while max(len(c) for c in cols) > 2:
        stage += 1
        new = [[] for _ in range(len(cols) + 1)]
        for ci in range(len(cols)):
            items = list(cols[ci])
            k = 0
            while len(items) - k >= 3:
                a, b, c = items[k], items[k + 1], items[k + 2]
                k += 3
                s = "wf_s%d_%d" % (stage, fa)
                co = "wf_c%d_%d" % (stage, fa)
                fa += 1
                new[ci].append(s)
                new[ci + 1].append(co)
                add(s, "(%s ^ %s ^ %s)" % (a, b, c), "FA sum  w=%d" % ci)
                add(co, majority3(a, b, c), "FA carry w=%d" % (ci + 1))
            while len(items) - k >= 2:
                a, b = items[k], items[k + 1]
                k += 2
                s = "wh_s%d_%d" % (stage, ha)
                co = "wh_c%d_%d" % (stage, ha)
                ha += 1
                new[ci].append(s)
                new[ci + 1].append(co)
                add(s, "(%s ^ %s)" % (a, b), "HA sum  w=%d" % ci)
                add(co, "(%s & %s)" % (a, b), "HA carry w=%d" % (ci + 1))
            while k < len(items):
                new[ci].append(items[k])
                k += 1
        cols = new
    return assigns, wires, cols


def gen_compressor(w):
    """4:2 compressor（cin/cout 列间链）+FA/HA 归约。返回 (assigns, wires, cols)。"""
    assigns, wires = [], []
    cols = build_cols(w)

    def add(name, expr, comment):
        wires.append(name)
        assigns.append("    assign %s = %s; // %s" % (name, expr, comment))

    stage = 0
    nid = 0  # 命名计数（compressor/FA/HA 共用，保证唯一）
    while max(len(c) for c in cols) > 2:
        stage += 1
        new = [[] for _ in range(len(cols) + 1)]
        # 找出连续 len>=4 的列段（4:2 链）
        runs = []
        cur = []
        for ci in range(len(cols)):
            if len(cols[ci]) >= 4:
                cur.append(ci)
            else:
                if cur:
                    runs.append(cur)
                    cur = []
        if cur:
            runs.append(cur)

        used42 = set()
        for run in runs:
            run_cout = None
            for idx, ci in enumerate(run):
                items = list(cols[ci])
                a, b, c, d = items[0], items[1], items[2], items[3]
                used42.add(ci)
                cin = run_cout if idx > 0 else "1'b0"
                # 4:2 = FA(a,b,cin) → {s1, cout}；FA(s1,c,d) → {sum, carry}
                s1 = "cs_s1_%d_%d" % (stage, nid)
                co = "cs_co_%d_%d" % (stage, nid)
                sm = "cs_s_%d_%d" % (stage, nid)
                cy = "cs_c_%d_%d" % (stage, nid)
                nid += 1
                new[ci].append(sm)
                new[ci + 1].append(cy)
                add(s1, "(%s ^ %s ^ %s)" % (a, b, cin), "4:2 s1  w=%d" % ci)
                add(co, majority3(a, b, cin), "4:2 cout w=%d" % (ci + 1))
                add(sm, "(%s ^ %s ^ %s)" % (s1, c, d), "4:2 sum  w=%d" % ci)
                add(cy, majority3(s1, c, d), "4:2 carry w=%d" % (ci + 1))
                if idx == len(run) - 1:
                    # 链末 cout 作为普通进位进高列（复用已声明的 co，不再重复声明）
                    new[ci + 1].append(co)
                run_cout = co

        # 每列：先取 4:2 未消费的剩余项，再用 FA/HA/pass
        for ci in range(len(cols)):
            items = list(cols[ci])
            if ci in used42:
                rest = items[4:]
            else:
                rest = items
            k = 0
            while len(rest) - k >= 3:
                a, b, c = rest[k], rest[k + 1], rest[k + 2]
                k += 3
                s = "cf_s%d_%d" % (stage, nid)
                co2 = "cf_c%d_%d" % (stage, nid)
                nid += 1
                new[ci].append(s)
                new[ci + 1].append(co2)
                add(s, "(%s ^ %s ^ %s)" % (a, b, c), "FA sum  w=%d" % ci)
                add(co2, majority3(a, b, c), "FA carry w=%d" % (ci + 1))
            while len(rest) - k >= 2:
                a, b = rest[k], rest[k + 1]
                k += 2
                s = "ch_s%d_%d" % (stage, nid)
                co2 = "ch_c%d_%d" % (stage, nid)
                nid += 1
                new[ci].append(s)
                new[ci + 1].append(co2)
                add(s, "(%s ^ %s)" % (a, b), "HA sum  w=%d" % ci)
                add(co2, "(%s & %s)" % (a, b), "HA carry w=%d" % (ci + 1))
            while k < len(rest):
                new[ci].append(rest[k])
                k += 1
        cols = new
    return assigns, wires, cols


def emit_module(w, modname, kind):
    """生成单个模块文件文本。"""
    NBITS = clog2(w + 1)              # 结果 0..w 所需位数
    if kind == "wallace":
        assigns, wires, cols = gen_wallace(w)
        sname = lambda i: "wf_rs%d" % i
        cname = lambda i: "wf_rc%d" % i
        kind_cn = "Wallace tree（3:2 FA + 2:1 HA 归约）"
    else:
        assigns, wires, cols = gen_compressor(w)
        sname = lambda i: "cf_rs%d" % i
        cname = lambda i: "cf_rc%d" % i
        kind_cn = "4:2 compressor（cin/cout 列间链）+FA/HA 归约"

    # 收尾：NBITS 位 ripple-carry（每列 ≤2 bit + carry-in）
    RPT = len(cols)
    prev_c = "1'b0"
    fin = []
    for i in range(NBITS):
        a = cols[i][0] if i < RPT and len(cols[i]) > 0 else "1'b0"
        b = cols[i][1] if i < RPT and len(cols[i]) > 1 else "1'b0"
        s = sname(i)
        c = cname(i)
        fin.append("    assign %s = (%s ^ %s ^ %s); // final sum  bit%d" % (s, a, b, prev_c, i))
        fin.append("    assign %s = ((%s & %s) | (%s & (%s ^ %s))); // final carry bit%d" % (
            c, a, b, prev_c, a, b, i))
        prev_c = c

    hdr = []
    hdr.append("// ============================================================================")
    hdr.append("// %s — popcount %s (SEL-014)，由 tools/gen_popcount.py 生成" % (modname, kind_cn))
    hdr.append("// 输入: din[%d:0]，输出: popcnt[%d:0]（NBITS=clog2(%d+1)，结果 0..%d）" % (w - 1, NBITS - 1, w, w))
    hdr.append("// 结构: 权重 0 列含全部输入位 → 逐级归约（carry 抬入高权重列）→ 每列≤2")
    hdr.append("//       → %d 位 ripple-carry 收尾。门级扁平网表，PPA 结构可复现。" % NBITS)
    hdr.append("// 重新生成: python3 tools/gen_popcount.py --widths %d" % w)
    hdr.append("// ============================================================================")
    hdr.append("")
    hdr.append("module %s (" % modname)
    hdr.append("    input  logic [%d:0] din," % (w - 1))
    hdr.append("    output logic [%d:0] popcnt" % (NBITS - 1))
    hdr.append(");")
    hdr.append("")
    hdr.append("    // ---- 中间信号 ----------------")
    hdr.append(fmt_wire(wires))
    hdr.append("")
    hdr.append("    // ---- 归约 / 收尾 ----------------")
    hdr.append("")

    body = list(assigns)
    if fin:
        body.append("")
        body.extend(fin)
    body.append("")
    for i in range(NBITS):
        body.append("    assign popcnt[%d] = %s;" % (i, sname(i)))
    body.append("")
    body.append("endmodule")
    body.append("")
    return "\n".join(hdr + body)


def main():
    ap = argparse.ArgumentParser(description="popcount Wallace/4:2 compressor 电路生成器")
    ap.add_argument("--widths", nargs="+", type=int, default=[8, 16, 32, 64],
                    help="要生成的数据位宽（默认 8 16 32 64）")
    ap.add_argument("--out", default=DEFAULT_OUT, help="输出目录（默认 rtl/gen）")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    for w in args.widths:
        if w < 2 or w > 4096:
            print("skip width %d (out of [2,4096])" % w)
            continue
        for kind, mname in (("wallace", "popcount_wallace_d%d" % w),
                            ("compressor", "popcount_compressor_d%d" % w)):
            text = emit_module(w, mname, kind)
            path = os.path.join(args.out, "%s.sv" % mname)
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            print("WROTE %s (%d lines)" % (path, text.count("\n") + 1))
    print("GEN-DONE widths=%s out=%s" % (",".join(str(x) for x in args.widths), args.out))


if __name__ == "__main__":
    main()
