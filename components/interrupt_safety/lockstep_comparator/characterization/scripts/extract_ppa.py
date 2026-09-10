#!/usr/bin/env python3
"""从不可变 DC 报告提取归一化摘要、检查结构并生成中文 Markdown/图。"""
from pathlib import Path
import hashlib,json,re,sys,os
ROOT=Path(__file__).resolve().parents[2]
NUM=r'([-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)'
def match(pattern,text):
    m=re.search(pattern,text)
    if not m:raise ValueError('报告缺少指标: '+pattern)
    return m

def main():
    rows=[]
    for root in map(Path,sys.argv[1:]):
        for p in sorted(root.glob('point_*')):
            meta=json.loads((p/'manifest.json').read_text());params=meta['parameters']
            reports={f.stem:f.read_text(errors='replace') for f in p.glob('*.rpt')}
            area=float(match(r'Total cell area:\s*'+NUM,reports['area'])[1])
            power=[]
            for label in ['Total Dynamic Power','Cell Leakage Power']:
                m=match(re.escape(label)+r'\s*=\s*'+NUM+r'\s*(mW|uW|nW|pW|W)',reports['power'])
                power.append(float(m[1])*{'W':1,'mW':1e-3,'uW':1e-6,'nW':1e-9,'pW':1e-12}[m[2]])
            def slack(text):
                vals=re.findall(r'slack \((MET|VIOLATED)\)\s*'+NUM,text)
                if not vals:raise ValueError('缺少 setup slack')
                return min(float(v) for _,v in vals),any(s=='VIOLATED' or float(v)<0 for s,v in vals)
            all_slack,bad=slack(reports['timing']);rr_slack,rr_bad=slack(reports['reg_reg'])
            registers=int(match(r'REGISTERS (\d+)',reports['registers'])[1])
            names=reports['registers'].splitlines()[1:]
            banks=[sum(f'g_path[{i}].u_path/' in n and 'data_q_reg' in n for n in names) for i in [0,1]]
            level=params['LCL_REDUNDANCY_LEVEL'];width=params['WIDTH'];delay=params['LOCKSTEP_DELAY']
            expected=[width*delay,width*delay if level==2 else 0]
            # 禁跨边界优化后，通道输出保持完整延迟路径，允许逐位核验独立存储。
            if banks!=expected:raise ValueError(f'延迟存储不符 {p}: {banks} vs {expected}')
            children=re.findall(r'^g_path\[([01])\]\.u_path\s+',reports['area'],re.M)
            if set(children)!=({'0'} if level==0 else {'0','1'}):raise ValueError('冗余层次缺失: '+str(p))
            codes=sorted(set(re.findall(r'\((LINT-\d+)\)',reports['check_design'])))
            unexpected=set(codes)-{'LINT-28','LINT-29','LINT-31','LINT-33'}
            if level==0 or params.get('STATIC_COMPARE_MASK')==0:
                unexpected.discard('LINT-52')  # 单比较器内部故障或全屏蔽结果为常量零。
            if params.get('STATIC_COMPARE_MASK')==0:
                unexpected.difference_update({'LINT-2','LINT-8'})  # 全屏蔽比较锥裁剪后留下未负载连接。
            if unexpected:raise ValueError('未解释 lint: '+repr(unexpected))
            rows.append({'run_id':root.name,'point':p.name,'parameters':params,'area_library_units':area,'registers':registers,
                         'delay_registers_a_b':banks,'all_setup_slack_ns':all_slack,'reg_reg_setup_slack_ns':rr_slack,
                         'dynamic_power_uW':power[0]*1e6,'leakage_power_nW':power[1]*1e9,'timing_status':'fail' if bad or rr_bad else 'pass',
                         'lint_codes':codes,'report_sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in p.glob('*.rpt')}})
    for row in rows:
        p=row['parameters'];row['label']=f"W{p['WIDTH']}/D{p['LOCKSTEP_DELAY']}/R{p['LCL_REDUNDANCY_LEVEL']}/P{p['CMP_PIPE_STAGES']}"+('/MASK0' if p.get('STATIC_COMPARE_MASK')==0 else '')+('/FI0' if p.get('SUPPORT_FAULT_INJECTION')==0 else '')
    result={'status':'pass' if all(r['timing_status']=='pass' for r in rows) else 'fail','evidence_level':'exploratory_fixed_library','corner':'tt_nominal_max_1p00v_25c','clock_period_ns':2.5,'tool':'DC V-2023.12-SP3','activity':'primary inputs p=0.5 toggle_rate=0.1; clock-derived sequential activity, no SAIF','rows':rows}
    comparable=[r for r in rows if r['parameters']['WIDTH']==128]
    def objectives(r):
        return (r['area_library_units'],r['dynamic_power_uW'],r['leakage_power_nW'],r['parameters']['CMP_PIPE_STAGES'],-r['reg_reg_setup_slack_ns'])
    result['wide_128_pareto']=[r['label'] for r in comparable if not any(
        all(a<=b for a,b in zip(objectives(other),objectives(r))) and any(a<b for a,b in zip(objectives(other),objectives(r)))
        for other in comparable if other is not r)]
    (ROOT/'reports/ppa-summary.json').write_text(json.dumps(result,indent=2)+'\n')
    os.environ.setdefault('MPLCONFIGDIR','/tmp/saf005-matplotlib')
    import matplotlib;matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.font_manager import FontProperties
    font=FontProperties(fname='/usr/share/fonts/google-noto-cjk/NotoSansCJK-DemiLight.ttc')
    fig,axes=plt.subplots(1,3,figsize=(17,5));x=list(range(len(rows)))
    for ax,key,title in zip(axes,['area_library_units','reg_reg_setup_slack_ns','dynamic_power_uW'],['面积（库面积单位）','寄存器间 setup 裕量（ns）','动态功耗估计（µW）']):
        ax.bar(x,[r[key] for r in rows],color='#237f9b');ax.set_title(title,fontproperties=font)
        ax.set_xticks(x,[r['label'] for r in rows],rotation=70,ha='right',fontsize=7);ax.grid(axis='y',alpha=.2)
    fig.suptitle('SAF-005 参数表征：固定库、400 MHz、概率活动率',fontproperties=font)
    fig.tight_layout();fig.savefig(ROOT/'reports/ppa-comparison.png',dpi=150);plt.close(fig)
    lines=['# SAF-005 PPA 表征报告','','本报告由 `characterization/scripts/extract_ppa.py` 从原始报告生成。',
      '', '## 条件与证据范围','','DC V-2023.12-SP3；GF CMOS28LP SC9 HVT，TT 1.00 V/25 °C；400 MHz。',
      '输入/输出延迟 0.25 ns，时钟不确定性 0.05 ns，输入 transition 0.05 ns，输出 load 0.01 pF。',
      '输入概率 0.5、toggle_rate 0.1；无 SAIF，时序单元活动由工具传播估计。功耗包括时钟相关单元内部功耗。',
      '数据来自固定库的探索性综合；当前工作树未锁定发布，不能作为物理签核或 qualified 结论。',
      '面积按 Liberty 库面积数值报告，不擅自转换为物理版图面积。层次保留、禁跨边界优化、无 retiming。',
      '', '## 测量结果','','| 配置 | 面积（库单位） | 寄存位 | 全路径裕量 ns | 寄存器间裕量 ns | 动态 µW | 漏电 nW |', '|---|---:|---:|---:|---:|---:|---:|']
    for r in rows:lines.append(f"| {r['label']} | {r['area_library_units']:.3f} | {r['registers']} | {r['all_setup_slack_ns']:.2f} | {r['reg_reg_setup_slack_ns']:.2f} | {r['dynamic_power_uW']:.3f} | {r['leakage_power_nW']:.3f} |")
    lines+=['','![参数化 PPA 对比](ppa-comparison.png)','','## 结构验收与选择边界','',
      '逐点检查 A/B 独立层次和延迟寄存位：Level 2 两套、Level 1 一套、Level 0 无 B；D=0 无延迟寄存器。',
      '所有检查基于映射后报告，寄存器数量不能替代布线/布局的物理独立性证明。',
      'LINT-28 为参数裁剪后的未用端口；LINT-29 为零延迟直通；LINT-31 为 fail-safe 公式优化后的同值输出；LINT-33 为多个未用端口接同一常量。详见 lint 说明。',
      '不同冗余级别和掩码配置具有不同安全覆盖，不能在单一 Pareto 集中互相替代。',
      'W128/R2/D2 的 P0/P1 可比较面积、功耗与时序，但 P1 额外增加一个周期检测延迟，选择需满足系统故障反应时间。',
      '该组以面积、动态/漏电功耗、检测延迟和寄存器间裕量形成多目标比较，P0/P1 均未被另一配置支配，均在本次两点 Pareto 前沿。',
      '默认安全配置保留 R2/D2/P0；R0 仅用于非安全调试。静态全 mask 用于证明裁剪，不可作为安全检测配置。',
      '', '## 可复现性','','运行目录 ID、每点参数与全部报告 SHA-256 见 [ppa-summary.json](ppa-summary.json)。原始库路径和商业工具日志仅保留在本地 build/eda。']
    (ROOT/'reports/ppa-report.md').write_text('\n'.join(lines)+'\n')
    print('PPA 摘要/中文报告/PNG 已生成；',len(rows),'点，状态',result['status'])
if __name__=='__main__':main()
