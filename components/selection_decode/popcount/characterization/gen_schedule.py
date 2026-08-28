#!/usr/bin/env python3
# ============================================================================
# gen_schedule.py — Wallace/Dadda 显式 FA 网表生成器（Change C2 定稿）
# ----------------------------------------------------------------------------
# 网表模型：FA 为显式实例（assign {cout,s} = a+b+c），SUM 留本列、CARRY 进右列；
# 收尾：终态各列剩余 dot（≤2/列，verify_schedule 保证）按列权静态移位后连加——
#       移位量为编译期常量，无任何运行时 % / 除法。
# 支持宽度：W=64 物化网表（其余宽度由脚本扩展参数即可再生成）。
# 正确性链：调度数学同源 verify_schedule.py(506/506) + G4 黄金模型仿真 +
#           fm_shell LEC vs impl_tree。
# 用法: uv run python gen_schedule.py     # 仅物化 W=64 wallace+dadda
# ============================================================================
import sys
from pathlib import Path

DTBL = [2, 3, 4, 6, 9, 13, 19, 28, 42, 63, 94, 141, 211, 316]


def seq_hi(w):
    for k, d in enumerate(DTBL):
        if d >= w:
            return k
    return len(DTBL) - 1


_sig_n = [0]


def _sig(pref):
    _sig_n[0] += 1
    return "%s_%d" % (pref, _sig_n[0])


def build_netlist(mode, W):
    """→ assigns[list of 'co,s,a,b,c'], finals[list of (sig,col)]"""
    hi = seq_hi(W)
    nrung = hi if mode == "dadda" else None
    cols = W.bit_length()
    cap = (nrung or cols) + cols + 4

    assigns = []
    col_bits = {0: ["data_i[%d]" % i for i in range(W)]}
    r = 0
    while r < cap:
        if max(len(v) for v in col_bits.values()) <= 2 and \
           (mode == "wallace" or r >= nrung):
            break
        tgt = DTBL[hi - 1 - r] if (mode == "dadda" and r < nrung) else None
        nxt = {}
        pend = []                       # 本轮左邻流入的 carry（进入当前列）
        for c in range(0, W.bit_length() + 2):
            pool = list(pend) + list(col_bits.get(c, []))
            pend = []
            n = len(pool)
            if mode == "wallace":
                f = n // 3
            else:
                f = 0 if (tgt is None or n <= tgt) else \
                    min((n - tgt + 1) // 2, n // 3)
                # 必须对“进位前总数”做可行性？不——FA 在含 carry 的池内即可
            rem = []
            for _ in range(f):
                a, b, cc = pool.pop(0), pool.pop(0), pool.pop(0)
                s, co = _sig("fa_s"), _sig("fa_c")
                assigns.append((co, s, a, b, cc))
                rem.append(s)
                pend.append(co)
            rem.extend(pool)
            if rem:
                nxt[c] = rem
        col_bits = dict(nxt)
        r += 1

    finals = [(nm, c) for c in sorted(col_bits) for nm in col_bits[c]]
    assert len(finals) <= 2 * (W.bit_length() + 1)
    return assigns, finals


def emit_module(mode, W=64):
    L = []
    A = L.append
    mod = "popcount_impl_" + mode
    A("// ---------------------------------------------------------------------------")
    A("// %s — 显式 FA 网表核（gen_schedule.py 物化 W=%d，勿手改）" % (mod, W))
    A("// 每个 assign = 一个真全加器；收尾为各列 dot 按常量移位后的连加。")
    A("// ---------------------------------------------------------------------------")
    A("module %s #(" % mod)
    A("    parameter int INPUT_WIDTH = %d," % W)
    A("    parameter int CNT_W       = $clog2(INPUT_WIDTH + 1)")
    A(") (")
    A("    input  logic [INPUT_WIDTH-1:0] data_i,")
    A("    output logic [CNT_W-1:0]       cnt_o")
    A(");")
    A("    generate")
    A("        if (INPUT_WIDTH != %d) begin : g_fixed_w" % W)
    A("            $error(\"%s: 生成版本仅物化 INPUT_WIDTH=%d\");" % (mod, W))
    A("        end")
    A("    endgenerate")

    cntw = W.bit_length()                    # CNT_W for W=64 → 7
    assigns, finals = build_netlist(mode, W)

    decls = sorted({s for co, s, _, _, _ in assigns} |
                   {co for co, _, _, _, _ in assigns})
    for d in decls:
        A("    logic %s;" % d)
    A("")
    for co, s, a, b, cc in assigns:
        A("    assign { %s, %s } = %s + %s + %s;" % (co, s, a, b, cc))
    A("")
    # ---- 终态：各列剩余 dot 按编译期常量移位(<<col)后连加（CNT_W 宽度封顶）----
    # 声明 wire [CNT_W-1:0] sh_i = {{c{1'b0}}, dot}; 零扩展+移位一次到位
    A("    // ---- 终态：各列剩余 dot 常量左移连加（权重 2^col；CNT_W 位宽无溢出）----")
    for i, (nm, c) in enumerate(finals):
        if c == 0:
            A("    wire [CNT_W-1:0] term_%d = %s;" % (i, nm))
        else:
            A("    wire [CNT_W-1:0] term_%d = %s << %d;" % (i, nm, c))
    exprs = ["term_%d" % i for i in range(len(finals))]
    A("    assign cnt_o = " + "\n                 + ".join(exprs) + ";")
    A("endmodule")
    return "\n".join(L)


def draw_arch(mode, W, out_png):
    """压缩树架构图 v2：bit=圆圈、逐层向下、层间均衡；
    左→右为位权列 2^0..；FA 组以 Σ 汇聚符号+箭头标注到下一层进位列。
    布局：每层高度 = 层内最大列高 × 行距；非满列垂直居中，视觉均衡。"""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D
    from matplotlib.patches import FancyArrowPatch

    tab = build_tab(mode, W)
    cols = W.bit_length()

    # 重放每轮绝对列高
    planes = []
    h = [0] * cols
    h[0] = W
    planes.append(list(h))
    for row in tab:
        pend, nh = 0, [0] * cols
        for c in range(cols):
            n = h[c] + pend
            f = row[c]
            nh[c] = n - 2 * f
            pend = f
        h = nh
        planes.append(list(h))

    rounds = len(tab)
    ROWH = 0.55                          # 相邻 bit 圈的 y 间距
    LAYH = 2.6                           # 层间距（取各层最大高 + 余量）
    maxh = max(max(p) for p in planes)

    fig, ax = plt.subplots(figsize=(9.5, (rounds + 1) * LAYH * 0.62 + 1.8))

    for r in range(rounds + 1):
        hs = planes[r]
        layer_top = -r * LAYH
        for c in range(cols):
            hh = hs[c]
            if hh == 0:
                continue
            shown = min(hh, 12)
            # 垂直居中该列的 dot 串
            y_start = layer_top - (maxh - shown) / 2.0
            face = "#4C8BF5" if r == 0 else "none"
            for k in range(shown):
                ax.scatter(c, y_start - k * ROWH, s=46 if r == 0 else 40,
                           marker="o", facecolors=face,
                           edgecolors="#1F3B60" if r == 0 else "#34495E",
                           linewidths=0.7, zorder=3)
            lbl_y = y_start - shown * ROWH - 0.25
            ax.text(c, lbl_y, str(hh), ha="center", fontsize=7,
                    color="#5D6D7E", zorder=4)
            if hh > shown:
                ax.text(c, lbl_y - 0.35, "(+%d)" % (hh - shown),
                        ha="center", fontsize=6, color="#7F8C8D")
        # 该轮发生的 FA 标注与 carry 箭头（引出至下一层的右侧列）
        if r < rounds:
            for c, f in enumerate(tab[r]):
                if not f:
                    continue
                xc, yc = c + 0.32, layer_top - maxh / 2.0
                ax.text(xc, yc, "Σ×%d" % f, fontsize=7.5, color="#B03A2E",
                        ha="left", va="center", zorder=4)
                arr = FancyArrowPatch((xc + 0.05, yc), (c + 1.02, yc + LAYH / 4),
                                      arrowstyle="-|>", mutation_scale=9,
                                      color="#E7A33A", lw=1.15,
                                      connectionstyle="arc3,rad=-0.18", zorder=2)
                ax.add_patch(arr)

    legend_items = [
        Line2D([], [], marker="o", ls="", mfc="#4C8BF5", mec="k",
               label="input bit (col0 · %d dots)" % W),
        Line2D([], [], marker="o", ls="", mfc="none", mec="#34495E",
               label="dot after round"),
        Line2D([], [], ls="", marker="$\\Sigma$", color="#B03A2E",
               markersize=10, label="full-adder group (3in→sum+carry)"),
        Line2D([], [], color="#E7A33A", lw=1.4,
               label="carry → next column (weight ×2)"),
    ]
    ax.legend(handles=legend_items, loc="upper right", fontsize=8)
    ax.set_xlim(-0.85, cols + 0.75)
    ax.set_ylim(-(rounds) * LAYH - maxh / 2 - 0.8, maxh / 2 + 1.0)
    ax.axis("off")
    ax.set_title("%s compression tree (W=%d): circle = one bit; "
                 "columns = weight 2^c; layers top-down"
                 % (mode.capitalize(), W), fontsize=10.5)
    fig.savefig(str(out_png), dpi=140, bbox_inches='tight')
    plt.close(fig)


def draw_arch_graphviz(mode, W, out_base):
    """v3 行交替结构：inputs 行 → [FA 行 → SUM/CARRY 输出行] ×R → final adder 行。
    同一行内节点 rank=same 强制；SUM 蓝边直下、CARRY 橙边斜向右列同层。"""
    """Graphviz 层级图：rankdir=TB；
    输入 bit=蓝圆、FA=Σ 盒、SUM 回列(同色层)、CARRY 红边进右列、
    收尾 dot 直接连加节点。dot 引擎渲染 PNG。"""
    import graphviz

    hi = seq_hi(W)
    nrung = hi if mode == "dadda" else None
    cols = W.bit_length()
    cap = (nrung or cols) + cols + 4

    g = graphviz.Digraph(name="popcount_%s_W%d" % (mode, W), format="png")
    g.attr(rankdir="TB", splines="true", nodesep="0.18", ranksep="0.55",
           label="%s compression tree (W=%d)" % (mode.capitalize(), W),
           labelloc="t", fontsize="14")
    g.attr("node", fontsize="9")

    # 行交替 rank 模型（用户指令）：inputs 行 → [FA 行 → dot 输出行]×R → final 行
    col_bits = {0: ["data_i[%d]" % i for i in range(min(W, 32))]}
    with g.subgraph() as rin:
        rin.attr(rank="same")
        for nm in col_bits[0]:
            g.node(nm, "", shape="circle", style="filled",
                   fillcolor="#4C8BF5", width="0.15", fixedsize="true")

    r = 0
    while r < cap:
        if max(len(v) for v in col_bits.values()) <= 2 and \
           (mode == "wallace" or r >= nrung):
            break
        tgt = DTBL[hi - 1 - r] if (mode == "dadda" and r < nrung) else None
        fa_row, out_row = [], {}
        nxt = {}
        pend = []
        for c in range(0, cols + 2):
            pool = list(pend) + list(col_bits.get(c, []))
            pend = []
            n = len(pool)
            if mode == "wallace":
                f = n // 3
            else:  # dadda
                f = 0 if (tgt is None or n <= tgt) else \
                    min((n - tgt + 1) // 2, n // 3)
            rem = []
            for _ in range(f):
                a, b, cc = pool.pop(0), pool.pop(0), pool.pop(0)
                s, co = _sig("fa_s"), _sig("fa_c")
                fan = "fa_%d_%s" % (r, co)
                g.node(fan, "FA", shape="box", style="filled",
                       fillcolor="#FDEBD0", color="#B03A2E", height="0.26",
                       width="0.5")
                fa_row.append(fan)
                for src in (a, b, cc):
                    g.edge(src, fan, color="#85929E")
                g.edge(fan, s, color="#2E86C1")     # SUM → 同列下一行
                g.edge(fan, co, color="#E7A33A")    # CARRY → 右列（斜）
                rem.append(s)
                pend.append(co)
                out_row[s] = out_row[co] = True
            rem.extend(pool)
            if rem:
                nxt[c] = rem
        with g.subgraph(name="cluster_r%d" % r) as sub:
            sub.attr(label="round %d" % r, fontsize="10", color="#BDC3C7")
            for fn in fa_row:
                sub.node(fn)
        # FA 同行；输出 dot 也同行（两个独立 rank 层 → 用户指令的行交替结构）
        if fa_row:
            with g.subgraph() as rk:
                rk.attr(rank="same")
                prev = None
                for fn in fa_row:
                    if prev: rk.edge(prev, fn, style="invis")
                    prev = fn
        if out_row:
            with g.subgraph() as ro:
                ro.attr(rank="same")
                olist = sorted(out_row)
                prev = None
                for od in olist:
                    if prev: ro.edge(prev, od, style="invis")
                    prev = od
        col_bits = dict(nxt)
        r += 1

    # 收尾加法器节点
    terms = [(nm, c) for c in sorted(col_bits) for nm in col_bits[c]]
    with g.subgraph(name="cluster_fin") as sub:
        sub.attr(label="final weighted adder", fontsize="10", color="#A9DFBF")
        for i, (nm, c) in enumerate(terms):
            sub.node("term_%d" % i,
                     "%s<<%d" % ("{...}" if nm.startswith("data_i") else nm, c),
                     shape="note", fontsize="8")
            g.edge(nm, "term_%d" % i)
    base = str(out_base)
    try:
        g.render(base, cleanup=True)
        print("[gen]", base + ".png")
    except Exception as e:                              # graphviz 二进制缺失
        print("[warn] graphviz render failed:", e)


def main():
    root = Path(__file__).resolve().parent.parent
    rtl = root / "rtl"
    out = rtl / "popcount_compressed.sv"

    head = ("// ===========================================================================\n"
            "// popcount_compressed.sv — Wallace/Dadda 显式 FA 网表（gen_schedule.py 产物）\n"
            "// ===========================================================================\n"
            "`ifndef POPCOUNT_COMPRESSED_SVH\n"
            "`define POPCOUNT_COMPRESSED_SVH\n\n")
    body = emit_module("wallace")  # Change C3: dadda 网表移除（调度策略与 wallace 在单列退化场景无差）
    tail = "`endif\n"
    out.write_text(head + body + tail, encoding="utf-8")
    print("[gen]", out)

    want = [int(x) for x in sys.argv[1:]] or [64]
    for w in want:
        for mode in ("wallace", "dadda"):
            png = root.parent / "build" / ("arch_%s_W%d.png" % (mode, w)); png.parent.mkdir(parents=True, exist_ok=True)
            try:
                draw_arch(mode, w, str(png))            # matplotlib 圈图
                print("[gen]", png.name)
            except Exception as e:
                print("[warn] mpl arch:", e)
            base = root.parent / "build" / ("gvarch_%s_W%d" % (mode, w)); base.parent.mkdir(parents=True, exist_ok=True)
            try:
                draw_arch_graphviz(mode, w, str(base))   # graphviz DAG 图
            except ImportError:
                print("[warn] py-graphviz missing — skip gvarch")


if __name__ == "__main__":
    main()
