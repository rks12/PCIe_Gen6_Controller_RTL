# Local validation evidence (2026-11-22)

| Command / check | Observation | Evidence limitation |
|---|---|---|
| `make check` | PASS: structural source audit, six CRC basis vectors, 1,024 single-byte recoveries, four 2-byte fault examples | Python only; no RTL execution |
| `python3 tb/python/test_reference.py` | PASS: basis cases, byte-order checks, corrected data/CRC/ECC positions | Golden model only |
| `python3 tb/python/gen_vectors.py --seed 17` | PASS: 8 sets of 256B FLIT / raw TLP / 6B DLP / length vectors | Vector generation, not compiled RTL |
| `bash -n tb/scripts/run_g1.sh` | PASS: shell syntax | Does not compile SV |
| `make tb-smoke`, `make tb-primitives` | NOT RUN: Verilator >=5 unavailable in local container | Needs actual HDL simulator |
| Gen1–Gen6 PCIe end-to-end/UVM/certification | BLOCKED: missing protocol RTL & PHY | No compliance claim |

**Status:** G1 testbench sources authored; SystemVerilog functional pass is
**unverified** until an HDL compiler/simulator runs them. Compilation errors,
RTL failure or CI errors discovered later require diagnosis; never declare
PASS based only on Python vectors.
