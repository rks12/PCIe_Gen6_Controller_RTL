#!/usr/bin/env python3
"""Generate fully independent Python reference vectors for the G1 RTL testbench.

PURPOSE: Confirm RTL against a separate implementation of the PCIe 6.0
CRC/FEC equations, not merely by loopback through the RTL encoder/decoder.
FILES: golden_flits.hex (2048 bits), raw_tlps.hex (1888 bits), dlp.hex
(48 bits), lengths.hex (6 bits), manifest.json. Byte zero occupies bits 7:0.
These are generated artifacts; never add build/tb/ to source control.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import random
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from protocol_reference import encode_flit, decode_flit

LENGTHS = [1, 4, 17, 32, 58, 59, 6, 41]


def pack_hex(data: bytes) -> str:
    """Represent packed SV logic as an integer, reversing wire byte order."""
    return data[::-1].hex()


def main() -> None:
    """Build repeatable independent vectors and verify their own integrity."""
    ap = argparse.ArgumentParser()
    ap.add_argument('--seed', type=int, default=17)
    ap.add_argument('--output', type=Path, default=ROOT/'build'/'tb'/'vectors')
    a = ap.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    rng = random.Random(a.seed)
    out = {'golden_flits.hex': [], 'raw_tlps.hex': [], 'dlp.hex': [], 'lengths.hex': []}
    for n in LENGTHS:
        raw = bytes(rng.randrange(256) for _ in range(236))
        dlp = bytes(rng.randrange(256) for _ in range(6))
        padded = raw[:n*4] + bytes(236-n*4)
        flit = encode_flit(padded, dlp)
        decoded, valid, corrected = decode_flit(flit)
        assert valid and not corrected and decoded == flit[:250]
        out['raw_tlps.hex'].append(pack_hex(raw))
        out['dlp.hex'].append(pack_hex(dlp))
        out['golden_flits.hex'].append(pack_hex(flit))
        out['lengths.hex'].append(f'{n:02x}')
    for name, lines in out.items():
        (a.output/name).write_text('\n'.join(lines)+'\n')
    (a.output/'manifest.json').write_text(json.dumps({
        'generator': 'tb/python/gen_vectors.py', 'seed': a.seed,
        'case_count': len(LENGTHS), 'tlp_dw_lengths': LENGTHS,
        'basis': 'scripts/protocol_reference.py (PCIe 6.0 FLIT CRC/FEC)',
        'byte_order': 'wire byte 0 is least-significant packed byte'
    }, indent=2)+'\n')
    print(f'PASS: {len(LENGTHS)} independent RTL expected vectors generated (seed={a.seed})')

if __name__ == '__main__':
    main()
