#!/usr/bin/env python3
"""Independent PCIe 6.0 FLIT CRC/FEC reference and deterministic self-checks.

This is NOT a cocotb/HDL testbench. It checks the finite-field and placement
algorithms used in the RTL, including six vectors from spec Appendix K, and
single-byte corruption of the FLIT body. HDL compilation remains separate.

All data is in wire-byte order: byte 0 first. IEEE/ECMA CRC-64 implementations
are not interchangeable with this PCIe 6.0 GF(256) CRC.
"""
from __future__ import annotations
import argparse
import random

CRC_COEFF = (0xD5, 0x68, 0xFE, 0xD5, 0x33, 0x41, 0x4D, 0x69)


def gf_mul(a: int, b: int, reduction: int) -> int:
    """Multiply two GF(256) elements with the specified 8-bit reduction."""
    result = 0
    for _ in range(8):
        if b & 1:
            result ^= a
        a = ((a << 1) ^ (reduction if a & 0x80 else 0)) & 0xFF
        b >>= 1
    return result


def gf_alpha_power(exponent: int) -> int:
    """ECC alpha^n, using PCIe ECC primitive x^8+x^4+x^3+x^2+1."""
    value = 1
    for _ in range(exponent):
        value = gf_mul(value, 2, 0x1D)
    return value


def crc8_bytes(data: bytes) -> bytes:
    """PCIe 6.0 FLIT eight-byte CRC over exactly 242 data bytes."""
    if len(data) != 242:
        raise ValueError('CRC requires exactly 242 FLIT bytes')
    s = [0] * 8
    for b in data:
        f = s[0] ^ b
        s = [s[i + 1] ^ gf_mul(f, CRC_COEFF[i], 0x2B) for i in range(7)] + [
            gf_mul(f, CRC_COEFF[7], 0x2B)
        ]
    return bytes(reversed(s))


def fec6(data: bytes) -> bytes:
    """Generate six PCIe 6.0 ECC bytes from 250 content+CRC bytes."""
    if len(data) != 250:
        raise ValueError('FEC requires exactly 250 FLIT bytes')
    p = [0] * 3
    c = [0] * 3
    for i, b in enumerate(data):
        g = i % 3
        p[g] ^= b
        c[g] ^= gf_mul(b, gf_alpha_power(84 - i // 3), 0x1D)
    return bytes([c[1], c[2], c[0], p[1], p[2], p[0]])


def encode_flit(tlp: bytes, dlp: bytes) -> bytes:
    """Pack the PCIe six-field FLIT: 236 TLP, 6 DLP, 8 CRC, 6 ECC."""
    if len(tlp) != 236 or len(dlp) != 6:
        raise ValueError('requires 236 bytes TLP and 6 bytes DLP')
    content = tlp + dlp
    data250 = content + crc8_bytes(content)
    return data250 + fec6(data250)


def decode_flit(flit: bytes) -> tuple[bytes, bool, bool]:
    """Correct one byte per FEC group, then verify CRC; return data250/status.

    A multi-byte error may have the same ECC syndrome as a single-byte error;
    the terminal CRC check prevents such a frame from being consumed.
    """
    if len(flit) != 256:
        raise ValueError('requires 256 bytes')
    buf = bytearray(flit)
    any_fix = False
    unc = False
    for g in range(3):
        p = 0
        c = 0
        for pos in range(84):
            i = 3 * pos + g
            if i >= 250:
                continue
            p ^= buf[i]
            c ^= gf_mul(buf[i], gf_alpha_power(84 - pos), 0x1D)
        check_idx = (252, 250, 251)[g]
        parity_idx = (255, 253, 254)[g]
        sp = p ^ buf[parity_idx]
        sc = c ^ buf[check_idx]
        if sp == 0 and sc == 0:
            continue
        if sp == 0 or sc == 0:
            any_fix = True  # only ECC parity/check byte is corrupted
            continue
        matches = [3 * pos + g for pos in range(84)
                   if 3 * pos + g < 250 and
                   gf_mul(sp, gf_alpha_power(84 - pos), 0x1D) == sc]
        if len(matches) == 1:
            buf[matches[0]] ^= sp
            any_fix = True
        else:
            unc = True
    correct = (crc8_bytes(buf[:242]) == buf[242:250]) and not unc
    return bytes(buf[:250]), correct, any_fix


def run_checks() -> None:
    """Check Appendix K basis samples, random frames, all single-byte faults."""
    assert gf_alpha_power(8) == 0x1D
    reference = [
        # Input byte-index, bit-index, expected [CRC byte 7..byte 0].
        # These limited basis vectors were independently checked against
        # the uploaded PCIe Base Spec 6.0 Appendix K matrix.
        (0, 0, '61 b9 a7 e9 1a c3 3b 0b'),
        (0, 7, '81 5c fe c8 f4 a9 92 07'),
        (1, 2, '8f 27 11 01 51 7c a4 87'),
        (50, 4, '30 5d b7 b7 be ed 9b bf'),
        (100, 6, '2e 1d 8b 0e 02 9f 5b 0a'),
        (241, 7, 'a7 ad 46 a7 3e 67 9d 2d'),
    ]
    for byte, bit, expected_state in reference:
        data = bytearray(242)
        data[byte] = 1 << bit
        # Reference shown in state high-to-low order; CRC bytes are reversed.
        got_state = crc8_bytes(bytes(data))[::-1]
        assert got_state == bytes.fromhex(expected_state), (
            f'CRC mismatch at byte {byte} bit {bit}: {got_state.hex()}')
    print(f'PASS: {len(reference)} Appendix K CRC basis vectors')
    rng = random.Random(0x6E6)
    for case in range(4):
        tlp = bytes(rng.randrange(256) for _ in range(236))
        dlp = bytes(rng.randrange(256) for _ in range(6))
        frame = encode_flit(tlp, dlp)
        assert len(frame) == 256
        corrected, ok, changed = decode_flit(frame)
        assert ok and not changed and corrected == frame[:250]
        for i in range(256):
            corrupt = bytearray(frame)
            corrupt[i] ^= 0xA5
            decoded, ok, changed = decode_flit(bytes(corrupt))
            assert ok and changed and decoded == frame[:250], (case, i)
    print('PASS: 4 random FLITs, 1,024 single-byte corruption recoveries')
    frame = encode_flit(bytes(range(236)), bytes(range(6)))
    for i, j in [(0, 3), (1, 4), (7, 10), (242, 245)]:
        corrupt = bytearray(frame)
        corrupt[i] ^= 0x53
        corrupt[j] ^= 0xC1
        _, ok, _ = decode_flit(bytes(corrupt))
        assert not ok, (i, j)
    print('PASS: 4 representative two-byte uncorrectable error cases')
    print('ALL PYTHON ALGORITHM CHECKS PASSED (NOT RTL SIMULATION)')


if __name__ == '__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    run_checks()
