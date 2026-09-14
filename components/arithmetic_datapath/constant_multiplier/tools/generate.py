#!/usr/bin/env python3
"""Deterministic constant multiplier DAG compiler (Apache-2.0)."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import yaml

VERSION = "1.0.0"
ROOT = Path(__file__).resolve().parents[1]
DEFAULTS = dict(
    INPUT_WIDTH=16,
    INPUT_SIGNED=True,
    COEFF="3",
    OUTPUT_MODE="FULL",
    SHIFT_RIGHT=0,
    ROUND_MODE="FLOOR",
    OVERFLOW_MODE="WRAP",
    LATENCY=0,
    IMPL="NATIVE",
    OPERAND_ISOLATION=False,
)
ENUMS = dict(
    OUTPUT_MODE=["FULL", "QUANTIZED"],
    ROUND_MODE=["FLOOR", "TOWARD_ZERO", "NEAREST_EVEN"],
    OVERFLOW_MODE=["WRAP", "SATURATE"],
    IMPL=["NATIVE", "BINARY", "CSD", "ADDER_GRAPH", "AUTO"],
)


def width(lo, hi, signed):
    b = 1
    while (lo < -(1 << (b - 1)) or hi >= (1 << (b - 1))) if signed else (hi >= (1 << b)):
        b += 1
    return b


def normalize(raw):
    if not isinstance(raw, dict):
        raise ValueError("configuration must be a mapping")
    unknown = set(raw) - set(DEFAULTS) - {"COEFF_WIDTH", "OUTPUT_WIDTH", "OUTPUT_SIGNED"}
    if unknown:
        raise ValueError(f"unknown parameters: {sorted(unknown)}")
    c = DEFAULTS | raw
    for n, values in ENUMS.items():
        if type(c[n]) is int and 0 <= c[n] < len(values):
            c[n] = values[c[n]]
    v = c["COEFF"]
    if type(v) not in (int, str) or not re.fullmatch(r"-?(0|[1-9][0-9]*)", str(v)):
        raise ValueError("COEFF must be an exact decimal integer, never float/bool")
    k = int(v)
    c["COEFF"] = str(k)
    c.setdefault("COEFF_WIDTH", width(k, k, True))
    for n, lo, hi in [
        ("INPUT_WIDTH", 1, 128),
        ("COEFF_WIDTH", 1, 128),
        ("LATENCY", 0, 8),
        ("SHIFT_RIGHT", 0, 256),
    ]:
        if type(c[n]) is not int or not lo <= c[n] <= hi:
            raise ValueError(f"{n} out of range [{lo},{hi}]")
    if not -(1 << (c["COEFF_WIDTH"] - 1)) <= k < (1 << (c["COEFF_WIDTH"] - 1)):
        raise ValueError("COEFF does not fit COEFF_WIDTH")
    for n in ["INPUT_SIGNED", "OPERAND_ISOLATION"]:
        if type(c[n]) is not bool:
            raise ValueError(n + " must be bool")
    for n, values in ENUMS.items():
        if c[n] not in values:
            raise ValueError(n + " invalid enumeration")
    if "OUTPUT_WIDTH" in raw and (
        type(raw["OUTPUT_WIDTH"]) is not int or not 1 <= raw["OUTPUT_WIDTH"] <= 256
    ):
        raise ValueError("OUTPUT_WIDTH out of range [1,256]")
    if "OUTPUT_SIGNED" in raw and type(raw["OUTPUT_SIGNED"]) is not bool:
        raise ValueError("OUTPUT_SIGNED must be bool")
    w, s = c["INPUT_WIDTH"], c["INPUT_SIGNED"]
    xmin, xmax = (-(1 << (w - 1)), (1 << (w - 1)) - 1) if s else (0, (1 << w) - 1)
    a, b = sorted([xmin * k, xmax * k])
    if c["OUTPUT_MODE"] == "FULL":
        if c["SHIFT_RIGHT"] or c["ROUND_MODE"] != "FLOOR" or c["OVERFLOW_MODE"] != "WRAP":
            raise ValueError("FULL requires SHIFT_RIGHT=0, FLOOR, WRAP")
        # FULL output declarations are derived; explicit overrides cannot change semantics.
        c["OUTPUT_SIGNED"] = s or k < 0
        c["OUTPUT_WIDTH"] = width(a, b, c["OUTPUT_SIGNED"])
    else:
        if type(c.get("OUTPUT_SIGNED")) is not bool:
            raise ValueError("QUANTIZED requires OUTPUT_SIGNED bool")
        if type(c.get("OUTPUT_WIDTH")) is not int or not 1 <= c["OUTPUT_WIDTH"] <= 256:
            raise ValueError("QUANTIZED requires OUTPUT_WIDTH in [1,256]")
    return c


class Graph:
    def __init__(self, c):
        self.c = c
        self.nodes = []
        self.shared = {}
        self.input = self.add("input", [], 1)

    def add(self, op, args, k, shift=0, stage=0):
        key = (op, tuple(args), k, shift, stage)
        if key in self.shared:
            return self.shared[key]
        w, s = self.c["INPUT_WIDTH"], self.c["INPUT_SIGNED"]
        lo, hi = (-(1 << (w - 1)), (1 << (w - 1)) - 1) if s else (0, (1 << w) - 1)
        lo, hi = sorted([lo * k, hi * k])
        # Internal nodes are signed even for unsigned inputs.
        n = {
            "id": f"n{len(self.nodes)}",
            "op": op,
            "inputs": args,
            "coefficient": str(k),
            "width": width(lo, hi, True),
            "signed": True,
            "stage": stage,
            "shift": shift,
        }
        self.nodes.append(n)
        self.shared[key] = n["id"]
        return n["id"]

    def node(self, id):
        return self.nodes[int(id[1:])]

    def coeff(self, id):
        return int(self.node(id)["coefficient"])

    def shift(self, a, n):
        return a if n == 0 else self.add("shift", [a], self.coeff(a) << n, shift=n)

    def combine(self, a, b, subtract=False):
        return self.add(
            "sub" if subtract else "add",
            [a, b],
            self.coeff(a) + (-1 if subtract else 1) * self.coeff(b),
        )

    def expand(self, k, impl, base=None):
        base = self.input if base is None else base
        if k == 0:
            return self.add("constant", [], 0)
        sign = -1 if k < 0 else 1
        k = abs(k)
        terms = []
        bit = 0
        while k:
            digit = 0
            if impl == "BINARY":
                digit = k & 1
            elif k & 1:
                digit = 2 - (k % 4) if k > 1 else 1
            if digit:
                terms.append((self.shift(base, bit), digit * sign))
            k = (k - digit) // 2
            bit += 1
        while len(terms) > 1:
            nxt = []
            for i in range(0, len(terms), 2):
                if i + 1 == len(terms):
                    nxt.append(terms[i])
                    continue
                (a, sa), (b, sb) = terms[i : i + 2]
                if sa == sb:
                    nxt.append((self.combine(a, b), sa))
                elif sa > 0:
                    nxt.append((self.combine(a, b, True), 1))
                else:
                    nxt.append((self.combine(b, a, True), 1))
            terms = nxt
        root, sign = terms[0]
        return root if sign > 0 else self.combine(self.add("constant", [], 0), root, True)

    def reachable(self, root):
        live = set()

        def visit(n):
            if n in live:
                return
            live.add(n)
            for a in self.node(n)["inputs"]:
                visit(a)

        visit(root)
        return [n for n in self.nodes if n["id"] in live]

    def cost(self, root):
        ns = self.reachable(root)
        depth = {}
        fan = {n["id"]: 0 for n in ns}
        for n in ns:
            depth[n["id"]] = max([depth[a] for a in n["inputs"]] or [0]) + int(
                n["op"] in ("add", "sub", "multiply")
            )
            for a in n["inputs"]:
                fan[a] += 1
        adders = sum(n["width"] for n in ns if n["op"] in ("add", "sub"))
        registers = sum(n["width"] for n in ns if n["op"] == "register")
        if self.c["LATENCY"] > 1:
            # Static upper estimate of live values crossing stage boundaries.
            stages = max(1, depth[root])
            registers += sum(
                n["width"]
                * max(0, (depth[root] - depth[n["id"]]) * (self.c["LATENCY"] - 1) // stages)
                for n in ns
            )
        return adders + 4 * depth[root] + sum(max(0, v - 1) for v in fan.values()) + registers


def build(c, budget=64, seed=914):
    if type(budget) is not int or not 0 <= budget <= 4096:
        raise ValueError("search budget must be in [0,4096]")
    g = Graph(c)
    k = int(c["COEFF"])
    impl = c["IMPL"]
    meta = {
        "algorithm": VERSION,
        "budget": budget,
        "seed": seed,
        "attempts": 0,
        "quality": "estimated",
    }
    if impl == "AUTO":
        impl = "NATIVE"
        meta["fallback"] = "no trusted technology-bound PPA cache; NATIVE baseline"
    if impl == "NATIVE":
        root = g.add("multiply", [g.input], k)
    else:
        root = g.expand(k, "BINARY" if impl == "BINARY" else "CSD")
        if impl == "ADDER_GRAPH":
            best = g.cost(root)
            for sh in range(1, 128):
                for delta in [-1, 1]:
                    if meta["attempts"] >= budget:
                        break
                    meta["attempts"] += 1
                    factor = (1 << sh) + delta
                    if factor <= 1 or abs(k) <= factor or k % factor:
                        continue
                    t = g.expand(k // factor, "CSD")
                    candidate = g.combine(g.shift(t, sh), t, delta < 0)
                    cost = g.cost(candidate)
                    if cost < best:
                        root, best = candidate, cost
                if meta["attempts"] >= budget:
                    break
            if budget == 0:
                meta["fallback"] = "search budget exhausted; validated deterministic CSD candidate"
    # Rebuild live DAG and assign arithmetic stages, inserting explicit balancing registers.
    h = Graph(c)
    mapped = {g.input: h.input}
    depth = {}
    live = g.reachable(root)
    for n in live:
        depth[n["id"]] = max([depth[a] for a in n["inputs"]] or [0]) + int(
            n["op"] in ("add", "sub", "multiply")
        )
    maxdepth = max(1, depth[root])
    last = max(0, c["LATENCY"] - 1)
    if impl == "NATIVE":
        last = 0
    for n in live:
        if n["op"] == "input":
            continue
        stage = depth[n["id"]] * last // maxdepth
        args = []
        for a in n["inputs"]:
            v = mapped[a]
            while h.node(v)["stage"] < stage:
                v = h.add("register", [v], h.coeff(v), stage=h.node(v)["stage"] + 1)
            args.append(v)
        mapped[n["id"]] = h.add(n["op"], args, int(n["coefficient"]), n["shift"], stage)
    r = mapped[root]
    while h.node(r)["stage"] < max(0, c["LATENCY"] - 1):
        r = h.add("register", [r], h.coeff(r), stage=h.node(r)["stage"] + 1)
    q = h.add("quantize", [r], k, stage=h.node(r)["stage"])
    h.node(q)["width"] = c["OUTPUT_WIDTH"]
    h.node(q)["signed"] = c["OUTPUT_SIGNED"]
    output = q
    if c["LATENCY"]:
        output = h.add("register", [q], k, stage=c["LATENCY"])
        h.node(output).update(width=c["OUTPUT_WIDTH"], signed=c["OUTPUT_SIGNED"], quantized=True)
    meta["selected"] = impl
    graph = {
        "nodes": h.nodes,
        "product": r,
        "output": output,
        "search": meta,
        "latency": c["LATENCY"],
    }
    validate_graph(graph, c)
    return graph


def validate_graph(graph, c):
    seen = {}
    for n in graph["nodes"]:
        id = n["id"]
        args = n["inputs"]
        op = n["op"]
        if id in seen or any(a not in seen for a in args):
            raise ValueError("DAG duplicate, cycle, or forward edge")
        arity = {
            "input": 0,
            "constant": 0,
            "shift": 1,
            "add": 2,
            "sub": 2,
            "multiply": 1,
            "register": 1,
            "quantize": 1,
        }
        if op not in arity or len(args) != arity[op]:
            raise ValueError("DAG opcode/arity")
        ks = [int(seen[a]["coefficient"]) for a in args]
        k = int(n["coefficient"])
        expected = {
            "input": lambda: 1,
            "constant": lambda: 0,
            "shift": lambda: ks[0] << n["shift"],
            "add": lambda: ks[0] + ks[1],
            "sub": lambda: ks[0] - ks[1],
            "multiply": lambda: ks[0] * int(c["COEFF"]),
            "register": lambda: ks[0],
            "quantize": lambda: ks[0],
        }[op]()
        if expected != k:
            raise ValueError("DAG coefficient mismatch")
        if n["stage"] < 0 or n["stage"] > (
            c["LATENCY"] if n.get("quantized") else max(0, c["LATENCY"] - 1)
        ):
            raise ValueError("DAG stage range")
        for a in args:
            if n["stage"] != seen[a]["stage"] + int(op == "register"):
                raise ValueError("DAG branch alignment")
        if op != "quantize" and not n.get("quantized"):
            w = c["INPUT_WIDTH"]
            lo = -(1 << (w - 1)) if c["INPUT_SIGNED"] else 0
            hi = (1 << (w - int(c["INPUT_SIGNED"]))) - 1
            a, b = sorted([lo * k, hi * k])
            if not n["signed"] or n["width"] < width(a, b, True):
                raise ValueError("DAG insufficient exact precision")
        elif n["width"] != c["OUTPUT_WIDTH"] or n["signed"] != c["OUTPUT_SIGNED"]:
            raise ValueError("DAG output type")
        seen[id] = n
    if int(seen[graph["product"]]["coefficient"]) != int(c["COEFF"]):
        raise ValueError("DAG wrong product")
    if seen[graph["product"]]["stage"] != max(0, c["LATENCY"] - 1):
        raise ValueError("DAG wrong output stage")
    output = seen[graph["output"]]
    if c["LATENCY"]:
        if (
            output["op"] != "register"
            or not output.get("quantized")
            or output["stage"] != c["LATENCY"]
        ):
            raise ValueError("DAG output register")
        output = seen[output["inputs"][0]]
    if output["op"] != "quantize" or output["inputs"] != [graph["product"]]:
        raise ValueError("DAG output edge")


def literal(k, w):
    return f"{w}'sh{(k % (1 << w)):x}"


def emit(c, graph, module="constant_multiplier_generated"):
    if not re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*", module):
        raise ValueError("invalid module name")
    source = (ROOT / "rtl/constant_multiplier.sv").read_text()
    start = source.index("module constant_multiplier #(")
    ports = source.index(")(\n", start)
    endports = source.index("\n);", ports) + 3
    header = f"module {module}" + source[ports + 1 : endports] + "\n"
    values = dict(c)
    values["COEFF"] = literal(int(c["COEFF"]), 129)
    for n, vs in ENUMS.items():
        values[n] = vs.index(c[n])
    values["IMPL"] = 0
    decl = []
    for n, v in values.items():
        typ = "logic signed [128:0]" if n == "COEFF" else ("bit" if type(v) is bool else "integer")
        decl.append(f"  localparam {typ} {n} = {int(v) if type(v) is bool else v};")
    decl.append(f"  localparam integer DATA_W = {c['OUTPUT_WIDTH']};")
    # ANSI port widths must be literals in the fixed generated instance.
    header = header.replace("DATA_W-1", str(c["OUTPUT_WIDTH"] - 1)).replace(
        "((INPUT_WIDTH > 0) ? INPUT_WIDTH : 1)-1", str(c["INPUT_WIDTH"] - 1)
    )
    source = (
        "// Generated by tools/generate.py "
        + VERSION
        + "; DO NOT EDIT.\n"
        + header
        + "\n".join(decl)
        + source[endports:]
    )
    lines = []
    for n in graph["nodes"]:
        if n["op"] == "quantize" or n.get("quantized"):
            continue
        id, w, op = n["id"], n["width"], n["op"]
        args = n["inputs"]
        lines.append(f"  logic signed [{w - 1}:0] {id};")
        a = [f"{w}'($signed({x}))" for x in args]
        if op == "register":
            lines.append(f"  always_ff @(posedge clk_i) if (ce_i) {id} <= {a[0]};")
            continue
        expr = {
            "input": lambda: f"{w}'(x_ext)",
            "constant": lambda: "'0",
            "shift": lambda: f"({a[0]} <<< {n['shift']})",
            "add": lambda: f"({a[0]} + {a[1]})",
            "sub": lambda: f"({a[0]} - {a[1]})",
            "multiply": lambda: f"({a[0]} * {literal(int(c['COEFF']), w)})",
        }[op]()
        lines.append(f"  assign {id} = {expr};")
    lines.append(f"  assign product = PW'($signed({graph['product']}));")
    source = re.sub(
        r"  // ARITHMETIC_BEGIN.*?  // ARITHMETIC_END", "\n".join(lines), source, flags=re.S
    )
    if c["LATENCY"] > 0:
        pipe = """  logic [LATENCY-1:0] valid_q;
  always_ff @(posedge clk_i) begin
    if (!rst_ni) valid_q <= '0;
    else if (ce_i) begin
      valid_q[0] <= valid_i;
      for (integer j=1;j<LATENCY;j=j+1) valid_q[j] <= valid_q[j-1];
    end
    if (ce_i) begin data_o <= data_comb; overflow_o <= overflow_comb; end
  end
  assign valid_o=valid_q[LATENCY-1];"""
        source = re.sub(r"  // PIPELINE_BEGIN.*?  // PIPELINE_END", pipe, source, flags=re.S)
    return source


def generate(raw, out, module="constant_multiplier_generated", budget=64, seed=914):
    c = normalize(raw)
    g = build(c, budget, seed)
    sv = emit(c, g, module)
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for name, value in [("config.yaml", c), ("graph.yaml", g)]:
        (out / name).write_text(yaml.safe_dump(value, sort_keys=False))
    (out / (module + ".sv")).write_text(sv)
    manifest = {
        "generator": VERSION,
        "module": module,
        "configuration_sha256": hashlib.sha256(json.dumps(c, sort_keys=True).encode()).hexdigest(),
        "rtl_sha256": hashlib.sha256(sv.encode()).hexdigest(),
        "output_width": c["OUTPUT_WIDTH"],
        "output_signed": c["OUTPUT_SIGNED"],
        "latency": c["LATENCY"],
        "ii": 1,
        "structure": g["search"],
        "verification": "not_run",
        "ppa_index": "ppa.json",
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (out / "ppa.json").write_text(
        json.dumps({"status": "not_run", "area": None, "delay": None, "power": None}) + "\n"
    )
    core = {
        "name": f"aixsilicon:cbb:{module}:0.1.0",
        "filesets": {"rtl": {"files": [module + ".sv"], "file_type": "systemVerilogSource"}},
        "targets": {"default": {"filesets": ["rtl"], "toplevel": module}},
    }
    (out / (module + ".core")).write_text("CAPI=2:\n" + yaml.safe_dump(core, sort_keys=False))
    (out / "verify.py").write_text(
        '"""Replay with the standalone component regression runner."""\nimport subprocess,sys\nfrom pathlib import Path\nif len(sys.argv)!=2: raise SystemExit("usage: verify.py COMPONENT_ROOT")\nsubprocess.run([sys.executable,str(Path(sys.argv[1])/"verification/run.py"),"--config",str(Path(__file__).with_name("config.yaml"))],check=True)\n'
    )
    return c, g


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("config")
    ap.add_argument("--out", required=True)
    ap.add_argument("--module", default="constant_multiplier_generated")
    ap.add_argument("--budget", type=int, default=64)
    ap.add_argument("--seed", type=int, default=914)
    a = ap.parse_args()
    try:
        generate(yaml.safe_load(Path(a.config).read_text()), a.out, a.module, a.budget, a.seed)
    except (ValueError, KeyError, TypeError) as e:
        ap.exit(2, "CM-CONFIG: " + str(e) + "\n")


if __name__ == "__main__":
    main()
