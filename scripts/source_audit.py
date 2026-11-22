#!/usr/bin/env python3
"""Deterministic offline source packaging checks, not an HDL parser/linter.

Purpose: ensure RTL sources have standard module descriptions, no empty source
files, no obviously unmatched basic block delimiters, unique module names and
an updated source filelist. Use Verilator/Icarus for actual elaboration.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
rtl = ROOT / 'rtl'
files = sorted(rtl.rglob('*.sv'))
assert files, 'no RTL source files'
module_sources = {}
for path in files:
    text = path.read_text()
    assert text.lstrip().startswith('/*'), f'missing multiline header: {path}'
    assert path.stat().st_size > 250, f'unexpected short source: {path}'
    without_comments = re.sub(r'/\*.*?\*/|//[^\n]*', ' ', text, flags=re.S)
    tokens = re.findall(r'\b(?:module|endmodule|package|endpackage|function|endfunction)\b', without_comments)
    for a, b in [('module', 'endmodule'), ('package', 'endpackage'), ('function', 'endfunction')]:
        assert tokens.count(a) == tokens.count(b), f'{a}/{b} mismatch: {path}'
    for module in re.findall(r'\bmodule\s+([a-zA-Z_]\w*)', without_comments):
        assert module not in module_sources, f'duplicate module: {module}'
        module_sources[module] = path
assert 'pcie_gen6_controller_top' in module_sources
filelist = ROOT / 'scripts' / 'rtl_sources.f'
listed = [x.strip() for x in filelist.read_text().splitlines()
          if x.strip() and not x.strip().startswith('#')]
assert set(listed) == {str(f.relative_to(ROOT)) for f in files}, 'filelist and RTL tree diverge'
for f in listed:
    assert (ROOT / f).exists()
print(f'PASS: {len(files)} RTL files, {len(module_sources)} unique modules; source list/header/blocks checked')
print('NOTE: This is a structural check, not SystemVerilog syntax or elaboration')
