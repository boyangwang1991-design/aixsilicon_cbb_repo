#!/usr/bin/env python3
"""核验真实映射报告中的延迟存储、层次和静态掩码裁剪；不依据目录存在判定。"""
from pathlib import Path
import hashlib,json,re
ROOT=Path(__file__).resolve().parents[2]
def tc_synthesis_structure():
    summary=json.loads((ROOT/'reports/ppa-summary.json').read_text());results=[]
    current=hashlib.sha256((ROOT/'rtl/lockstep_comparator_logic.sv').read_bytes()).hexdigest()
    for point in summary['rows']:
        raw=ROOT/'build/eda/ppa'/point['run_id']/point['point'];params=point['parameters']
        assert hashlib.sha256((raw/'dut.sv').read_bytes()).hexdigest()==current,'综合不是当前 RTL'
        for name,expected in point['report_sha256'].items():
            assert hashlib.sha256((raw/name).read_bytes()).hexdigest()==expected,'报告内容变化: '+name
        text=(raw/'registers.rpt').read_text();delay=params['LOCKSTEP_DELAY'];width=params['WIDTH'];level=params['LCL_REDUNDANCY_LEVEL']
        counts=[sum(f'g_path[{i}].u_path/' in n and 'data_q_reg' in n for n in text.splitlines()) for i in [0,1]]
        assert counts==[width*delay,width*delay if level==2 else 0],(counts,params)
        if params.get('STATIC_COMPARE_MASK')==0:
            # DC 可将常量映射为 tie cell 和别名，使用 check_design 解析后的连接事实。
            diagnostics=(raw/'check_design.rpt').read_text()
            assert diagnostics.count("output port 'mismatch_o' is connected directly to 'logic 0'")==2,'全屏蔽比较器未裁剪为零'
        results.append({'run_id':point['run_id'],'point':point['point'],'status':'pass','delay_registers_a_b':counts})
    out={'status':'pass','rtl_sha256':current,'points':results}
    (ROOT/'reports/structure-result.json').write_text(json.dumps(out,indent=2)+'\n')
    print('tc_synthesis_structure:',len(results),'点通过')
if __name__=='__main__':tc_synthesis_structure()
