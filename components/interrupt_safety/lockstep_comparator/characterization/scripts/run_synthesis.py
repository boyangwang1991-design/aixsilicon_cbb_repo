#!/usr/bin/env python3
"""按本机 pdk-scan 快照执行 DC 代表点综合，原始数据留在 build。"""
from pathlib import Path
import datetime,hashlib,json,shutil,subprocess,sys
import yaml
ROOT=Path(__file__).resolve().parents[2]
def main():
    snap=ROOT/'build/eda/pdk.local.yaml';d=yaml.safe_load(snap.read_text())
    corner='tt_nominal_max_1p00v_25c'
    libs=[lib for n in d['nodes'] for root in n['libraries'] for lib in root['libraries'] if lib['library']=='sc9_cmos28lp_base_hvt']
    db=libs[0]['corner_files']['db'][corner]
    out=ROOT/'build/eda/ppa'/('run-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f'));out.mkdir(parents=True)
    shutil.copy2(__file__,out/'run_synthesis.py');shutil.copy2(snap,out/'pdk.local.yaml')
    matrix=[{'WIDTH':32,'LOCKSTEP_DELAY':2,'LCL_REDUNDANCY_LEVEL':2,'CMP_PIPE_STAGES':0}]
    if '--probe' not in sys.argv:
        matrix += [{'WIDTH':w,'LOCKSTEP_DELAY':d,'LCL_REDUNDANCY_LEVEL':r,'CMP_PIPE_STAGES':p}
                   for w,d,r,p in [(8,0,0,0),(32,2,1,0),(128,2,2,0),(128,2,2,1),(32,0,2,0)]]
    if '--extra' in sys.argv:
        matrix=[dict(matrix[0],STATIC_COMPARE_MASK=0),dict(matrix[0],SUPPORT_FAULT_INJECTION=0)]
    for i,params in enumerate(matrix):
        dest=out/f'point_{i}';dest.mkdir()
        for source,name in [(ROOT/'rtl/lockstep_comparator_logic.sv','dut.sv'),(ROOT/'constraints/lockstep_comparator.sdc','constraints.sdc'),(Path(__file__).with_name('synth.tcl'),'synth.tcl'),(ROOT/'constraints/preserve_redundancy.tcl','preserve_redundancy.tcl')]:shutil.copy2(source,dest/name)
        (dest/'context.tcl').write_text(f'set TARGET_DB {{{db}}}\nset CORNER {corner}\nset PARAMETERS {{{",".join(f"{k}={v}" for k,v in params.items())}}}\n')
        (dest/'manifest.json').write_text(json.dumps({'parameters':params,'corner':corner,'period_ns':2.5,'inputs':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in dest.iterdir() if f.is_file()}},indent=2))
        with (dest/'dc.log').open('w') as f:
            try:rc=subprocess.run([shutil.which('dc_shell'),'-f','synth.tcl'],cwd=dest,stdout=f,stderr=subprocess.STDOUT,timeout=600).returncode
            except subprocess.TimeoutExpired:rc=124
        log=(dest/'dc.log').read_text(errors='replace')
        ok=rc==0 and 'LCL_SYNTH_PASS' in log and '\nError:' not in log and (dest/'mapped.v').exists()
        print(dest.name,'pass' if ok else 'fail',flush=True)
        if not ok:print(log[-5000:]);raise SystemExit(1)
    print('Evidence:',out,flush=True)
if __name__=='__main__':main()
