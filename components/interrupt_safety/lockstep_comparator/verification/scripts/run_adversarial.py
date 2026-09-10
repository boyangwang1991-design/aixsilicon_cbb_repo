#!/usr/bin/env python3
"""非法参数、X/Z 与检查器变异；区分预期失败和工具/许可证失败。"""
from pathlib import Path
import datetime,json,shutil,re
from run_checks import ROOT,run,digest

def main():
    out=ROOT/'build/eda/adversarial'/('run-'+datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%d-%H%M%S-%f'))
    out.mkdir(parents=True);shutil.copy2(__file__,out/'run_adversarial.py');shutil.copy2(Path(__file__).with_name('run_checks.py'),out/'run_checks.py')
    rtl=(ROOT/'rtl/lockstep_comparator_logic.sv').read_text();results=[]
    def case(name,source,tb,phase,token):
        d=out/name;d.mkdir();(d/'dut.sv').write_text(source);(d/'top.sv').write_text(tb)
        cmd=[shutil.which('vcs'),'-full64','-sverilog','-timescale=1ns/1ps','-assert','svaext','dut.sv','top.sv','-top','test_top','-o','simv']
        (d/'command.json').write_text(json.dumps(cmd))
        rc,log=run(cmd,d,'compile');ok=False
        if phase=='compile':ok=rc!=0 and token in log and ('Error-' in log or 'Fatal' in log) and 'Failed to obtain license' not in log
        elif rc==0 and not re.search(r'Error-|Fatal:',log):
            rc,log=run([str(d/'simv')],d,'simulation')
            # VCS 的 $fatal 可返回 0；必须同时匹配指定诊断与终止块，且不能到达正常结束标记。
            ok=(rc in (0,1) and token in log and 'Fatal:' in log and '$finish called' in log and 'TEST_PASS' not in log) if phase=='fail' else (rc==0 and token in log and not re.search(r'Fatal:|Error:',log))
        result={'test':name,'status':'pass' if ok else 'fail','expected_phase':phase,'expected_token':token,
                'inputs':{x:digest(d/x) for x in ['dut.sv','top.sv','command.json']},'logs':{f.name:digest(f) for f in d.glob('*.log')}}
        results.append(result)
        print(name,result['status'],flush=True)
        if not ok:print(log[-3000:])
    # tc_negative: generate $error 必须在编译/展开阶段报出特定违规原因。
    for name,param,value,token in [('width','WIDTH',0,'LCL_PARAM_WIDTH'),('pipe','CMP_PIPE_STAGES',2,'LCL_PARAM_PIPE'),('level','LCL_REDUNDANCY_LEVEL',3,'LCL_PARAM_LEVEL'),('pipe_signed','CMP_PIPE_STAGES',-1,'LCL_PARAM_PIPE'),('level_signed','LCL_REDUNDANCY_LEVEL',-1,'LCL_PARAM_LEVEL')]:
        case('tc_negative_'+name,rtl,f'module test_top;lockstep_comparator_logic #(.{param}({value})) dut();endmodule','compile',token)
    base='''module test_top;
      logic clk=0,rst=0;always #5 clk=~clk;
      logic [7:0] a=0,b=0,mask='1;
      lockstep_comparator_logic #(.WIDTH(8),.LOCKSTEP_DELAY(0)) dut(
       .clk_i(clk),.rst_ni(rst),.main_i(a),.shadow_i(b),.compare_enable_i(1'b1),
       .main_active_i(1'b1),.shadow_active_i(1'b1),.runtime_mask_i(mask),.valid_mask_i(8'hff),
       .error_clear_i(1'b0),.fi_enable_i(1'b0),.fi_target_i(2'b00),.fi_mask_i(8'b0));
      initial begin #2;rst=0;#10;rst=1;#10;STIM;#20;$display("TEST_PASS");$finish;end
      endmodule'''
    # tc_unknown: identical unknowns must fail; statically/dynamically masked unknowns are irrelevant.
    for value in ["8'hxx","8'hzz"]:
        case('tc_unknown_'+('x' if 'xx' in value else 'z'),rtl,base.replace('STIM',f'a={value};b={value}'),'fail','PROP-LCL_KNOWN-003')
    case('tc_unknown_masked',rtl,base.replace('STIM',"mask=0;a='x;b='z"),'pass','TEST_PASS')
    # tc_mutation: 独立刺激检出安全汇总 OR→AND 错误；反转断言检出断言行为变化。
    mutated=rtl.replace('assign safety_fault_o = main_shadow_mismatch_o | lcl_internal_fault_o;',
                         'assign safety_fault_o = main_shadow_mismatch_o & lcl_internal_fault_o;')
    assert mutated!=rtl
    case('tc_mutation_or',mutated,base.replace('STIM',"b='1"),'fail','PROP-LCL_SAFE-001')
    mutated=rtl.replace('safety_fault_o == (main_shadow_mismatch_o | lcl_internal_fault_o)',
                        'safety_fault_o != (main_shadow_mismatch_o | lcl_internal_fault_o)')
    case('tc_mutation_assertion',mutated,base.replace('STIM',"b='1"),'fail','PROP-LCL_SAFE-001')
    summary={'run_id':out.name,'status':'pass' if all(r['status']=='pass' for r in results) else 'fail','results':results}
    (out/'result.json').write_text(json.dumps(summary,indent=2)+'\n')
    (ROOT/'reports/adversarial-result.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('Evidence:',out,flush=True)
    if summary['status']!='pass':raise SystemExit(1)
if __name__=='__main__':main()
