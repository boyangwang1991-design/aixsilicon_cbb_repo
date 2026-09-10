#!/usr/bin/env python3
"""将 Core 依赖闭包导出到独立目录，完成真实 setup/build/run。"""
import datetime,json,shutil
from run_checks import ROOT,run,digest

def main():
    out=ROOT/'build/eda/core'/('run-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f'));out.mkdir(parents=True)
    package=out/'package';package.mkdir()
    paths=['aixsilicon_cbb_lockstep_comparator.core','rtl/lockstep_comparator_logic.sv','verification/simulation/lcl_tester.sv','verification/simulation/lcl_smoke_top.sv']
    for relative in paths:
        dest=package/relative;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/relative,dest)
    shutil.copy2(__file__,out/'run_core.py')
    cmd=[shutil.which('fusesoc'),'--cores-root',str(package),'run','--target=sim','--build-root',str(out/'work'),'aixsilicon:cbb:lockstep_comparator:1.0.0']
    (out/'manifest.json').write_text(json.dumps({'command':cmd,'inputs':{f:digest(package/f) for f in paths}},indent=2))
    rc,log=run(cmd,out,'fusesoc',timeout=600)
    ok=rc==0 and 'LCL_CORE_PASS' in log and 'LCL_CASE_PASS' in log and 'Fatal:' not in log
    summary={'run_id':out.name,'status':'pass' if ok else 'fail','standalone_export':True,'log_sha256':digest(out/'fusesoc.log')}
    (ROOT/'reports/core-result.json').write_text(json.dumps(summary,indent=2)+'\n');print(summary,flush=True)
    if not ok:raise SystemExit(log[-5000:])
if __name__=='__main__':main()
