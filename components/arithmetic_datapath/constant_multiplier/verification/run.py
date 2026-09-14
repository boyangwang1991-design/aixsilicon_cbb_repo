#!/usr/bin/env python3
"""Standalone deterministic actual-RTL regression. Requires PyYAML and VCS."""

import argparse, copy, hashlib, json, random, shutil, subprocess, sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / "tools"), str(ROOT / "model")]
from generate import normalize, generate, build, validate_graph, emit, literal, ENUMS
from reference import evaluate


def cases():
    configs = []

    def add(**kw):
        configs.append(normalize(kw))

    for w in [1, 2, 8]:
        for signed in [False, True]:
            for k in [0, 1, -1, 3, -3, 16, -16, 31, 45, 85]:
                add(INPUT_WIDTH=w, INPUT_SIGNED=signed, COEFF=str(k))
    for w in [16, 32, 64, 128]:
        for k in [0, -1, 341, (1 << 127) - 1, -(1 << 127)]:
            add(INPUT_WIDTH=w, INPUT_SIGNED=bool(w % 3), COEFF=str(k), LATENCY=w % 9)
    for mode in ENUMS["ROUND_MODE"]:
        for overflow in ENUMS["OVERFLOW_MODE"]:
            for signed in [False, True]:
                for shift in [0, 1, 3, 256]:
                    add(
                        INPUT_WIDTH=8,
                        COEFF="-7",
                        OUTPUT_MODE="QUANTIZED",
                        OUTPUT_WIDTH=4,
                        OUTPUT_SIGNED=signed,
                        ROUND_MODE=mode,
                        OVERFLOW_MODE=overflow,
                        SHIFT_RIGHT=shift,
                        LATENCY=2,
                    )
    for latency in range(9):
        for k in [0, 1, -1, 45]:
            add(INPUT_WIDTH=8, COEFF=str(k), LATENCY=latency, OPERAND_ISOLATION=True)
    return list({json.dumps(c, sort_keys=True): c for c in configs}.values())


def host_checks():
    count = 0
    invalid = [
        {"INPUT_WIDTH": 0},
        {"INPUT_WIDTH": 129},
        {"COEFF": 1.5},
        {"COEFF": True},
        {"COEFF": "1e4"},
        {"COEFF": str(1 << 127)},
        {"COEFF": str(-(1 << 127) - 1)},
        {"COEFF": "1", "COEFF_WIDTH": 1},
        {"COEFF_WIDTH": 0},
        {"COEFF_WIDTH": 129},
        {"LATENCY": 9},
        {"LATENCY": -1},
        {"SHIFT_RIGHT": 257},
        {"SHIFT_RIGHT": 1},
        {"ROUND_MODE": "NEAREST_EVEN"},
        {"OVERFLOW_MODE": "SATURATE"},
        {"OUTPUT_MODE": "QUANTIZED"},
        {"INPUT_SIGNED": 1},
        {"IMPL": "UNKNOWN"},
        {"typo": 1},
        {"OUTPUT_MODE": "QUANTIZED", "OUTPUT_WIDTH": 257, "OUTPUT_SIGNED": False},
    ]
    for c in invalid:
        try:
            normalize(c)
        except ValueError:
            count += 1
        else:
            raise AssertionError(f"accepted illegal configuration {c}")
    c = normalize({"COEFF": "45", "LATENCY": 4, "IMPL": "ADDER_GRAPH"})
    g = build(c)
    assert emit(c, g) == emit(c, build(c))
    assert build(c, 0)["search"]["fallback"]
    assert build(normalize({"IMPL": "AUTO"}))["search"]["selected"] == "NATIVE"
    for kind in ["width", "coefficient", "stage", "cycle", "output"]:
        bad = copy.deepcopy(g)
        n = next(n for n in bad["nodes"] if n["op"] in ("add", "sub"))
        if kind == "width":
            n["width"] = 1
        elif kind == "coefficient":
            n["coefficient"] = "999"
        elif kind == "stage":
            n["stage"] = 7
        elif kind == "cycle":
            n["inputs"][0] = n["id"]
        else:
            bad["output"] = bad["product"]
        try:
            validate_graph(bad, c)
        except ValueError:
            count += 1
        else:
            raise AssertionError("undetected graph mutation " + kind)
    for p, shift, mode, expected in [
        (-7, 1, "FLOOR", -4),
        (-7, 1, "TOWARD_ZERO", -3),
        (-7, 1, "NEAREST_EVEN", -4),
        (-5, 1, "NEAREST_EVEN", -2),
        (5, 1, "NEAREST_EVEN", 2),
        (7, 1, "NEAREST_EVEN", 4),
    ]:
        cfg = normalize(
            dict(
                INPUT_WIDTH=8,
                COEFF="1",
                OUTPUT_MODE="QUANTIZED",
                OUTPUT_WIDTH=8,
                OUTPUT_SIGNED=True,
                SHIFT_RIGHT=shift,
                ROUND_MODE=mode,
            )
        )
        assert evaluate(p & 255, cfg) == (expected & 255, 0)
    return count


def vectors(c, seed):
    rng = random.Random(seed)
    w = c["INPUT_WIDTH"]
    mask = (1 << w) - 1
    data = (
        list(range(1 << w))
        if w <= 8
        else [0, 1, 2, mask, mask - 1, 1 << (w - 1), (1 << (w - 1)) - 1]
        + [rng.getrandbits(w) for _ in range(80)]
    )
    data += [rng.getrandbits(w) for _ in range(100)]
    queue = [None] * c["LATENCY"]
    result = []
    # Directed startup/reset-while-disabled; continuous exhaustive region, then pause/bubbles/reset.
    seq = [(0, 0, 0, 0), (0, 1, 1, mask), (1, 0, 1, mask)]
    for i, x in enumerate(data):
        random_phase = i >= len(data) - 100
        seq.append(
            (
                0 if random_phase and i % 31 == 0 else 1,
                int(not random_phase or rng.random() > 0.3),
                int(not random_phase or rng.random() > 0.25),
                x,
            )
        )
    seq += [(1, 1, 0, 0)] * (c["LATENCY"] + 2)
    for rst, ce, valid, x in seq:
        incoming = evaluate(x, c) if valid else None
        if c["LATENCY"] == 0:
            out = incoming
        else:
            if not rst:
                queue = [None] * c["LATENCY"]
            elif ce:
                queue = [incoming] + queue[:-1]
            out = queue[-1]
        result.append((rst, ce, valid, x, int(out is not None), *(out or (0, 0))))
    return result


def run_command(cmd, cwd, log, timeout=300):
    with log.open("w") as f:
        r = subprocess.run(cmd, cwd=cwd, stdout=f, stderr=subprocess.STDOUT, timeout=timeout)
    return r.returncode, log.read_text(errors="replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--host-only", action="store_true")
    ap.add_argument("--matrix", action="store_true")
    ap.add_argument("--out", default=str(ROOT / "build/eda/regression"))
    a = ap.parse_args()
    count = host_checks()
    print(f"host negative/mutation checks: {count}", flush=True)
    if a.host_only:
        return
    if not shutil.which("vcs"):
        raise SystemExit("OPTIONAL_UNAVAILABLE: vcs")
    configs = [normalize(yaml.safe_load(Path(a.config).read_text()))] if a.config else cases()
    if a.matrix:
        configs = []
        for file in sorted((ROOT / "verification/configs").glob("*.yaml")):
            doc = yaml.safe_load(file.read_text())
            for row in doc.get("configs", []):
                if file.stem == "negative":
                    try:
                        normalize(row["parameters"])
                    except (ValueError, TypeError):
                        pass
                    else:
                        raise AssertionError("matrix negative accepted " + row["config_id"])
                else:
                    configs.append(normalize(row["parameters"]))
    if a.quick:
        configs = [
            normalize(dict(INPUT_WIDTH=8, COEFF="45", LATENCY=3)),
            normalize(dict(INPUT_WIDTH=8, COEFF="-1")),
            normalize(dict(INPUT_WIDTH=128, COEFF=str(-(1 << 127)), LATENCY=8)),
            normalize(
                dict(
                    INPUT_WIDTH=8,
                    COEFF="-7",
                    OUTPUT_MODE="QUANTIZED",
                    OUTPUT_WIDTH=4,
                    OUTPUT_SIGNED=True,
                    ROUND_MODE="NEAREST_EVEN",
                    OVERFLOW_MODE="SATURATE",
                    SHIFT_RIGHT=1,
                    LATENCY=2,
                )
            ),
        ]
    out = Path(a.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    modules = []
    sources = [ROOT / "rtl/constant_multiplier.sv"]
    records = []
    tests = []
    # All implementations share exactly the same stimulus for each numerical configuration.
    for i, base in enumerate(configs):
        variants = ENUMS["IMPL"] if not a.config and not a.matrix else [base["IMPL"]]
        for impl in variants:
            c = dict(base, IMPL=impl)
            j = len(records)
            name = f"cm_{j}"
            directory = out / name
            generate(c, directory, name)
            sources.append(directory / (name + ".sv"))
            vec = vectors(c, 914 + i)
            vf = directory / "vectors.txt"
            vf.write_text("".join(" ".join(format(v, "x") for v in row) + "\n" for row in vec))
            w, ow = c["INPUT_WIDTH"], c["OUTPUT_WIDTH"]
            tbname = f"case_{j}"
            # Also compare the parameterized NATIVE baseline on every generated configuration.
            ps = []
            for key, val in c.items():
                if key == "COEFF":
                    v = literal(int(val), 129)
                elif key == "IMPL":
                    v = "0"
                elif key in ENUMS:
                    v = str(ENUMS[key].index(val))
                else:
                    v = str(int(val))
                ps.append(f".{key}({v})")
            tests.append(f'''module {tbname}(output logic done);
logic clk_i=0,rst_ni,ce_i,valid_i;
logic [{w - 1}:0] data_i;
wire valid_o,overflow_o,ref_valid,ref_overflow;
wire [{ow - 1}:0] data_o,ref_data;
{name} dut(.*);
constant_multiplier #({",".join(ps)}) baseline(.clk_i(clk_i),.rst_ni(rst_ni),.ce_i(ce_i),.valid_i(valid_i),.data_i(data_i),.valid_o(ref_valid),.data_o(ref_data),.overflow_o(ref_overflow));
always #5 clk_i=~clk_i;
integer fd,rc,line; logic ev,eo;logic [{ow - 1}:0] ed;
initial begin
 done=0;line=0;fd=$fopen("{vf}","r");if(!fd)$fatal(1,"vector file");
 if ({j}==0 && $test$plusargs("MUTATE")) force dut.data_o='1;
 if ({j}==0 && $test$plusargs("DROP")) force dut.valid_o=1'b0;
 while (!$feof(fd)) begin
  @(negedge clk_i);
  rc=$fscanf(fd,"%h %h %h %h %h %h %h\\n",rst_ni,ce_i,valid_i,data_i,ev,ed,eo);
  if(rc!=7)$fatal(1,"bad vector");
  @(posedge clk_i); #1;
  if(valid_o!==ev || (ev && (data_o!==ed || overflow_o!==eo))) $fatal(1,"CM-MISMATCH case {j} line %0d got %h/%b/%b expected %h/%b/%b",line,data_o,valid_o,overflow_o,ed,ev,eo);
  if(ref_valid!==ev || (ev && (ref_data!==ed || ref_overflow!==eo))) $fatal(1,"CM-BASELINE case {j} line %0d",line);
  line=line+1;
 end
 $fclose(fd);done=1;
end
endmodule
''')
            modules.append(f"{tbname} c{j}(done[{j}]);")
            records.append(
                {
                    "config": c,
                    "vectors": len(vec),
                    "module": name,
                    "rtl_sha256": hashlib.sha256(
                        (directory / (name + ".sv")).read_bytes()
                    ).hexdigest(),
                }
            )
    tb = out / "tb.sv"
    tb.write_text(
        "\n".join(tests)
        + f"\nmodule tb;wire [{len(records) - 1}:0] done;"
        + "".join(modules)
        + '\ninitial begin wait (&done);$display("CM-PASS");$finish;end\ninitial begin #1000000;$fatal(1,"timeout");end\nendmodule\n'
    )
    cmd = [
        "vcs",
        "-full64",
        "-sverilog",
        "-timescale=1ns/1ps",
        "+define+CM_ASSERTIONS",
        "-assert",
        "svaext",
        *[str(s) for s in sources],
        str(tb),
        "-top",
        "tb",
        "-o",
        str(out / "simv"),
    ]
    print(f"compiling {len(records)} configurations", flush=True)
    rc, log = run_command(cmd, out, out / "compile.txt", 600)
    if rc or "Error-" in log:
        raise SystemExit("compile failed: " + str(out / "compile.txt"))
    rc, log = run_command([str(out / "simv")], out, out / "simulation.txt")
    if rc or "CM-PASS" not in log or "Error:" in log or "Fatal:" in log:
        raise SystemExit("simulation failed: " + str(out / "simulation.txt"))
    mutation = {}
    for kind in ["MUTATE", "DROP"]:
        rc, log = run_command([str(out / "simv"), "+" + kind], out, out / (kind + ".txt"))
        mutation[kind] = "CM-MISMATCH" in log and "CM-PASS" not in log
        if not mutation[kind]:
            raise SystemExit("mutation escaped: " + kind)
    summary = {
        "status": "pass",
        "seed": 914,
        "host_negative_graph_mutations": count,
        "configurations": len(records),
        "vectors": sum(r["vectors"] for r in records),
        "mutation": mutation,
        "cases": records,
        "formal": "not_run",
        "compile_command": cmd,
        "log_hashes": {
            f: hashlib.sha256((out / f).read_bytes()).hexdigest()
            for f in ["compile.txt", "simulation.txt", "MUTATE.txt", "DROP.txt"]
        },
    }
    (out / "result.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(
        f"PASS: {summary['configurations']} configurations, {summary['vectors']} cycles", flush=True
    )


if __name__ == "__main__":
    main()
