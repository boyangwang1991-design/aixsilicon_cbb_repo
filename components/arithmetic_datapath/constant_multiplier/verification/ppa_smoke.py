"""Run the existing independent RTL checker on every measured PPA configuration group."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "verification"))
import run


def main():
    data = json.loads((ROOT / "build/eda/ppa/results.json").read_text())
    groups = {}
    for point in data["points"]:
        config = dict(point["configuration"])
        config.pop("IMPL")
        groups[json.dumps(config, sort_keys=True)] = config
    # Only supply the configuration source; oracle, DUT, cycle checks and
    # mutations remain the same independently validated regression harness.
    run.cases = lambda: [run.normalize(config) for config in groups.values()]
    sys.argv = [sys.argv[0], "--out", str(ROOT / "build/eda/ppa_functional")]
    run.main()


if __name__ == "__main__":
    main()
