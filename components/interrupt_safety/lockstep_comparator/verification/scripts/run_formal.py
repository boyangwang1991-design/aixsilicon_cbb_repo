#!/usr/bin/env python3
"""Formality 比较 DC 输入 RTL 与映射网表；不将等价验证描述为功能属性证明。"""
from pathlib import Path
import argparse,datetime,json,re,shutil
from run_checks import ROOT,run,digest

def main():
    ap=argparse.ArgumentParser();ap.add_argument('synthesis_run',type=Path);ap.add_argument('--extra',action='store_true');args=ap.parse_args()
    synth=args.synthesis_run.resolve()
    out=ROOT/'build/eda/formal'/('run-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f'));out.mkdir(parents=True)
    shutil.copy2(__file__,out/'run_formal.py');shutil.copy2(Path(__file__).with_name('run_checks.py'),out/'run_checks.py')
    results=[]
    for point in sorted(synth.glob('point_*')):
        d=out/point.name;d.mkdir()
        manifest=json.loads((point/'manifest.json').read_text());source=(point/'dut.sv').read_text()
        source=re.sub(r'`ifndef SYNTHESIS.*?`endif','',source,flags=re.S)
        for k,v in manifest['parameters'].items():
            source,n=re.subn(r'(\b'+re.escape(k)+r'\s*=\s*)[^,\n]+',lambda m:m[1]+str(v),source,count=1)
            if n!=1:raise ValueError('Parameter specialization failed: '+k)
        (d/'reference.sv').write_text(source)
        for f in ['mapped.v','synthesis.svf','context.tcl']:shutil.copy2(point/f,d/f)
        tops=re.findall(r'^\s*module\s+(lockstep_comparator_logic(?:_WIDTH\w*)?)\s*\(', (d/'mapped.v').read_text(),re.M)
        if len(tops)!=1:raise ValueError('Mapped top ambiguous: '+repr(tops))
        script=f'''source context.tcl
set synopsys_auto_setup true
set_svf synthesis.svf
read_db $TARGET_DB
read_sverilog -r reference.sv
set_top r:/WORK/lockstep_comparator_logic
read_verilog -i mapped.v
set_top i:/WORK/{tops[0]}
match
if {{[verify]}} {{ puts "LCL_FORMAL_PASS" }} else {{ report_failing_points; report_unmatched_points; puts "LCL_FORMAL_FAIL" }}
exit
'''
        (d/'verify.tcl').write_text(script)
        (d/'inputs.json').write_text(json.dumps({f.name:digest(f) for f in d.iterdir() if f.is_file()},indent=2))
        rc,log=run([shutil.which('fm_shell'),'-f','verify.tcl'],d,'formal',timeout=600)
        ok=rc==0 and 'LCL_FORMAL_PASS\n' in log and 'Verification SUCCEEDED' in log and '\nError:' not in log
        results.append({'point':point.name,'parameters':manifest['parameters'],'status':'pass' if ok else 'fail','log_sha256':digest(d/'formal.log')})
        print(point.name,results[-1]['status'],flush=True)
        if not ok:print(log[-4000:])
    result={'run_id':out.name,'synthesis_run':synth.name,'scope':'RTL-to-mapped equivalence, not temporal safety property proof','status':'pass' if all(r['status']=='pass' for r in results) else 'fail','points':results}
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n');(ROOT/'reports'/('formal-extra-result.json' if args.extra else 'formal-result.json')).write_text(json.dumps(result,indent=2)+'\n')
    print('Evidence:',out,flush=True)
    if result['status']!='pass':raise SystemExit(1)
if __name__=='__main__':main()
