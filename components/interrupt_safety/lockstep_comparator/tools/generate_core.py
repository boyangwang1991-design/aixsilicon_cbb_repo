#!/usr/bin/env python3
"""从 SSOT 和随包模板生成 FuseSoC Core，不依赖私有 skill。"""
from pathlib import Path
import yaml
p=Path(__file__).resolve().parents[1];d=yaml.safe_load((p/'cbb.yaml').read_text())
s=(p/'tools/template.core.tmpl').read_text()
s=s.replace('<CBB_NAME>',d['cbb']['name']).replace('<VERSION>',d['cbb']['version']).replace('<TB_TOP>','lcl_smoke_top')
start=s.index('  <PARAMETER>:');end=s.index('targets:',start)
param_defs={k:{'datatype':'int','paramtype':'vlogparam','default':int(v['default'])} for k,v in d['parameters'].items()}
s=s[:start]+''.join('  '+line+'\n' for line in yaml.safe_dump(param_defs,sort_keys=False).splitlines())+s[end:]
s=s.replace('[<PARAMETER>]','['+', '.join(param_defs)+']')
s=s.replace('rtl/lockstep_comparator.sv','rtl/lockstep_comparator_logic.sv').replace('toplevel: lockstep_comparator\n','toplevel: lockstep_comparator_logic\n')
s=s.replace('files: [verification/simulation/lcl_smoke_top.sv]','files: [verification/simulation/lcl_tester.sv, verification/simulation/lcl_smoke_top.sv]')
s=s.replace("vcs_options: [-full64, '-timescale=1ns/1ps']","vcs_options: [-full64, '-timescale=1ns/1ps', '-assert', svaext, '+lint=all']")
(p/'aixsilicon_cbb_lockstep_comparator.core').write_text(s)
print('Core generated from cbb.yaml and package template')
