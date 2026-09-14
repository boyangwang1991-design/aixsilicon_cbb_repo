"""tc_contract: executable contract suite, generated TB plus independent integer oracle."""

from pathlib import Path
import runpy

if __name__ == "__main__":
    runpy.run_path(str(Path(__file__).resolve().parents[1] / "run.py"), run_name="__main__")
