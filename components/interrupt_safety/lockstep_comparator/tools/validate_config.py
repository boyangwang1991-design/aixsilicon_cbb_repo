#!/usr/bin/env python3
"""本 CBB 的宿主配置边界：在 SV unsigned/位向量转换前拒绝非法值。"""
from pathlib import Path
import argparse,json
import yaml
ROOT=Path(__file__).resolve().parents[1]
def validate(parameters):
    model=yaml.safe_load((ROOT/'cbb.yaml').read_text())['parameters']
    if set(parameters)!=set(model):raise ValueError('LCL_CONFIG_KEYS: 缺失或未知参数')
    for name,spec in model.items():
        v=parameters[name]
        if spec['type']=='bool':
            if type(v) is not bool:raise ValueError('LCL_CONFIG_TYPE: '+name)
        elif type(v) is not int:raise ValueError('LCL_CONFIG_TYPE: '+name)
        legal=spec.get('legal',{})
        if 'min' in legal and v<legal['min']:raise ValueError('LCL_CONFIG_RANGE: '+name)
        if 'max' in legal and v>legal['max']:raise ValueError('LCL_CONFIG_RANGE: '+name)
    mask=parameters['STATIC_COMPARE_MASK']
    if mask!=-1 and mask.bit_length()>parameters['WIDTH']:raise ValueError('LCL_CONFIG_MASK: STATIC_COMPARE_MASK')
    return parameters
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('file',type=Path);a=ap.parse_args()
    d=yaml.safe_load(a.file.read_text());validate(d.get('parameters',d));print(json.dumps({'status':'pass'}))
