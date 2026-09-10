#!/usr/bin/env python3
"""SAF-005 可重放 VCS 回归：配置来自 config-gen；原始证据保留在 build。"""
from pathlib import Path
import argparse, datetime, hashlib, itertools, json, re, shutil, subprocess
import yaml
ROOT=Path(__file__).resolve().parents[2]
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd, cwd, name, timeout=600):
    with (cwd/(name+'.log')).open('w') as out:
        try: rc=subprocess.run(cmd,cwd=cwd,stdout=out,stderr=subprocess.STDOUT,timeout=timeout).returncode
        except subprocess.TimeoutExpired: rc=124
    return rc,(cwd/(name+'.log')).read_text(errors='replace')
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--smoke',action='store_true');args=ap.parse_args()
    vcs=shutil.which('vcs')
    if not vcs: raise SystemExit('VCS_UNAVAILABLE')
    rid='run-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f')
    out=ROOT/'build/eda/verification'/rid;out.mkdir(parents=True)
    sources=[ROOT/'rtl/lockstep_comparator_logic.sv',ROOT/'verification/simulation/lcl_tester.sv',Path(__file__).resolve()]
    for f in sources:shutil.copy2(f,out/f.name)
    configs=[]
    for name in (['mandatory'] if args.smoke else ['mandatory','boundary','pairwise']):
        f=ROOT/f'verification/configs/{name}.yaml';shutil.copy2(f,out/f.name)
        configs+=yaml.safe_load(f.read_text())['configs']
    cfgs={c['config_id']:c for c in configs};configs=list(cfgs.values())
    # 补充风险集由生成器缺口和已明确的三元风险驱动，保留 config-gen 原始 SSOT。
    coverage = None
    if not args.smoke:
        coverage_path=ROOT/'verification/configs/pairwise-coverage.yaml'
        shutil.copy2(coverage_path,out/coverage_path.name)
        coverage=yaml.safe_load(coverage_path.read_text())
        defaults=configs[0]['parameters']
        candidates=[dict(defaults,**missing) for pair in coverage['pairs'] for missing in pair['missing_pairs']]
        for level,delay,pipe,features in itertools.product([0,1,2],[0,2],[0,1],[False,True]):
            candidates.append(dict(defaults,LCL_REDUNDANCY_LEVEL=level,LOCKSTEP_DELAY=delay,CMP_PIPE_STAGES=pipe,
                STARTUP_GUARD_CYCLES=1,SUPPORT_FAULT_INJECTION=features,SUPPORT_RUNTIME_MASK=features,SUPPORT_VALID_MASK=features))
        known={tuple(c['parameters'].items()) for c in configs}
        for candidate in candidates:
            key=tuple(candidate.items())
            if key not in known:
                known.add(key)
                configs.append({'config_id':f'risk_{len(configs):03d}','parameters':candidate})
        missing=[]
        for pair in coverage['pairs']:
            a,b=pair['parameters'];seen={(c['parameters'][a],c['parameters'][b]) for c in configs}
            for va,vb in itertools.product(coverage['domains'][a],coverage['domains'][b]):
                if (va,vb) not in seen:missing.append({a:va,b:vb})
        if missing:raise ValueError('风险补充后仍存在采样域值对缺口: '+repr(missing))
    top=['module regression_top;','timeunit 1ns; timeprecision 1ps;',f'wire [{len(configs)-1}:0] done;']
    for i,c in enumerate(configs):
        pars=','.join(f'.{k}({int(v)})' for k,v in c['parameters'].items())
        top.append(f'lcl_tester #({pars},.CASE_ID({i})) u_{i}(.done(done[{i}]));')
    top+=['initial begin wait(&done); $display("LCL_REGRESSION_PASS"); $finish; end',
          'initial begin #1000000; $fatal(1,"LCL_TIMEOUT"); end','endmodule']
    (out/'regression_top.sv').write_text('\n'.join(top)+'\n')
    command=[vcs,'-full64','-sverilog','-timescale=1ns/1ps','-assert','svaext','+lint=all',
             'lockstep_comparator_logic.sv','lcl_tester.sv','regression_top.sv','-top','regression_top','-o','simv']
    manifest={'run_id':rid,'seed':5005,'command':command,'inputs':{f.name:digest(out/f.name) for f in sources},'configs':configs}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    rc,log=run(command,out,'compile')
    if rc or re.search(r'Error-|Fatal:',log):raise SystemExit(f'COMPILE_FAIL {out} rc={rc}\n'+log[-4000:])
    rc,log=run([str(out/'simv')],out,'simulation')
    passes=re.findall(r'LCL_CASE_PASS id=(\d+)',log)
    ok=rc==0 and 'LCL_REGRESSION_PASS' in log and len(set(passes))==len(configs) and not re.search(r'Fatal:|Error:',log)
    result={'run_id':rid,'status':'pass' if ok else 'fail','cases':len(configs),'passed':len(set(passes)),
            'checks':sum(int(x) for x in re.findall(r'checks=(\d+)',log)),
            'sampled_pairwise_missing':0 if coverage else None,
            'input_sha256':manifest['inputs'],'logs':{n:digest(out/(n+'.log')) for n in ['compile','simulation']}}
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    reports=ROOT/'reports';reports.mkdir(exist_ok=True)
    (reports/('smoke-result.json' if args.smoke else 'verification-result.json')).write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result));print('Evidence:',out,flush=True)
    if not ok:raise SystemExit(log[-4000:])
if __name__=='__main__':main()
