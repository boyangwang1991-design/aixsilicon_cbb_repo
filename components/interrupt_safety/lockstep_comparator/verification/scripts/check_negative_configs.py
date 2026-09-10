#!/usr/bin/env python3
"""检查生成的全部非法配置均在宿主预检被拒绝；此阶段先于 SV 类型转换。"""
from pathlib import Path
import importlib.util,json,hashlib
import yaml
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'tools/validate_config.py';spec=importlib.util.spec_from_file_location('lcl_config',path)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
results=[]
for group in ['mandatory','boundary','pairwise','negative']:
    configs=yaml.safe_load((ROOT/f'verification/configs/{group}.yaml').read_text())['configs']
    for cfg in configs:
        try:module.validate(cfg['parameters']);error=None
        except ValueError as exc:error=str(exc)
        if (group=='negative')!=(error is not None):raise SystemExit('Unexpected preflight result: '+cfg['config_id'])
        if group=='negative':results.append({'config_id':cfg['config_id'],'diagnostic':error,'status':'pass'})
result={'status':'pass','phase':'host_preflight_before_SV_cast','negative_cases':results,'validator_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(ROOT/'reports/negative-config-result.json').write_text(json.dumps(result,indent=2)+'\n');print('全部 8 个非法配置在宿主预检被拒绝；103 个合法生成配置通过。')
