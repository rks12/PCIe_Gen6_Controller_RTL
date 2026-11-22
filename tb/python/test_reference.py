#!/usr/bin/env python3
"""Testbench-side independent-vector verification, runnable without HDL tools.

This exercises the golden-vector generator and samples ECC/CRC failure cases.
It does NOT establish that compiled RTL passes; that requires tb-smoke.
"""
from __future__ import annotations
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'scripts'))
from protocol_reference import encode_flit, decode_flit, run_checks
from gen_vectors import main as gen_main, pack_hex, LENGTHS


def verify() -> None:
    """Prove intended vectors are ordered correctly and detect corruption."""
    run_checks()
    frame = encode_flit(bytes(range(236)), bytes(range(6)))
    assert len(frame) == 256
    assert bytes.fromhex(pack_hex(frame))[::-1] == frame
    # Nontrivial RX path checks spanning payload, DLP, CRC and ECC positions.
    for pos in [0, 23, 235, 236, 241, 242, 249, 250, 253, 255]:
        damaged = bytearray(frame)
        damaged[pos] ^= 0xA5
        corrected, good, fixed = decode_flit(bytes(damaged))
        assert good and fixed and corrected == frame[:250], pos
    # Two distinct damaged bytes in the same ECC group are not correctable.
    damaged = bytearray(frame)
    damaged[0] ^= 0x53
    damaged[3] ^= 0xC1
    assert not decode_flit(bytes(damaged))[1]
    print('PASS: G1 independent reference-model integrity and vector ordering')

if __name__ == '__main__':
    verify()
