"""Check INV-001 settling and its ability to detect a stable wrong output."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time


def main():
    root = Path(__file__).resolve().parents[2]
    sources = [root / 'rtl/parity_gen_check.sv', root / 'verification/simulation/parity_assertion_tb.sv',
               Path(__file__).resolve()]
    identity = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    batch = root / 'build/assertion' / str(time.time_ns())
    batch.mkdir(parents=True)
    def execute(args, name):
        with (batch / name).open('w') as log:
            result = subprocess.run(args, cwd=batch, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=600, check=False)
        return result.returncode
    command = ['vcs', '-full64', '-sverilog', '-timescale=1ns/1ps', '-top', 'parity_assertion_tb',
               *map(str, sources[:2]), '-o', str(batch / 'simv')]
    compile_exit = execute(command, 'compile.log')
    outcome = {'inputs': identity, 'compile_command': command, 'compile_exit': compile_exit}
    passed = compile_exit == 0
    if passed:
        code = execute([str(batch / 'simv')], 'positive.log')
        positive = (batch / 'positive.log').read_text()
        passed = code == 0 and 'PARITY_ASSERTION_TB PASS' in positive and not re.search(r'(?m)^Error:|^Fatal:|failed at', positive)
        outcome['positive_exit'] = code
        code = execute([str(batch / 'simv'), '+INJECT_ERROR'], 'mutation.log')
        mutation = (batch / 'mutation.log').read_text()
        detected = 'INV-001 even violation' in mutation and 'MUTATION_EXECUTED' in mutation
        passed &= detected
        outcome.update(mutation_exit=code, mutation_detected=detected)
    passed &= identity == {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    outcome['status'] = 'pass' if passed else 'fail'
    outcome['logs'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in batch.glob('*.log')}
    (batch / 'execution.json').write_text(json.dumps(outcome, indent=2) + '\n')
    print(batch / 'execution.json')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
