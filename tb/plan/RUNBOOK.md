# Testbench Runbook — Planned Commands and Signoff

This is a **future CLI contract**, not an assertion that these TB targets already exist in RTL v0.2.

## Current executable commands

```bash
cd PCIe_Gen6_Controller_RTL
make check   # Only existing source/Python reference checks
make lint    # Requires an installed Verilator or Icarus; otherwise fails
```

## Proposed tool dependencies

- `python3`, `pytest`, `cocotb` and `verilator` for the open-source component/top-level test lane. Pin actual versions in future `tb/requirements.txt` and `tb/tool_versions.lock` after a compatible combination is validated.
- SystemVerilog simulator with verified UVM support for complete environment; pin the UVM version/library and vendor command line in `tb/scripts/run_tb.sh`.
- Optional Questa/Verdi/other coverage tools, assertion engines, formal tool, Waveform viewers. Commercial tools are **not bundled**.

## Proposed make targets

| Target | Behavior | Required exit condition |
|---|---|---|
| `make tb-smoke SIM=verilator SEED=1` | Compile actual RTL, run deterministic connected v0.2 top smoke | No compile/monitor/scoreboard failure |
| `make tb-unit SIM=verilator SEED=17` | CRC/FEC/packer/buffer/CSR/guard standalone | All reference/handshake comparisons match |
| `make tb-uvm SIM=<sim> TEST=<uvm-test> SEED=17` | Compile named UVM test and run | UVM fatal/error 0, checked transactions >0 |
| `make tb-nightly SIM=<sim> SEED=17` | Every directed case + bounded random runs | No unexpected failure + coverage data saved |
| `make tb-full SIM=<sim> SEED=17` | Declared protocol-profile signoff | All in-scope mandatory requirements verified |
| `make tb-coverage` | Merge/explain coverage, list gaps/waivers | Thresholds in master plan satisfied |

## Artifact format

Each job writes `build/tb/<run-id>/manifest.json`, `result.json`, `junit.xml`, simulation log, failing waveforms, test seeds/config, coverage (if available) and requirement-delta summary. Output values should include `PASS`, `FAIL`, `BLOCKED`, `NOT_RUN`, `EXPECTED_FAIL`; only actual passing assertions/scoreboards permit `PASS`.

## Suggested signoff sequence

1. Elaboration succeeds; stop on errors (and triage warnings).
2. Run current RTL G1 tests with independent CRC/FEC reference vectors.
3. Record and resolve link-loss buffer semantics and any other G1 defects.
4. Add RTL G2–G5 modules, and corresponding agent/scoreboard/coverage before marking supported.
5. Run G6 end-to-end, G7 PHY/hardware checks, then final coverage closure.
