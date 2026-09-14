"""Replay with the standalone component regression runner."""
import subprocess,sys
from pathlib import Path
if len(sys.argv)!=2: raise SystemExit("usage: verify.py COMPONENT_ROOT")
subprocess.run([sys.executable,str(Path(sys.argv[1])/"verification/run.py"),"--config",str(Path(__file__).with_name("config.yaml"))],check=True)
