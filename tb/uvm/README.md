# SystemVerilog UVM testbench for PCIe Gen6 FLIT RTL prototype

> **Status: five UVM tests compiled and passed on GitHub CI with Verilator
> 5.054 and UVM 2020-3.2. A sixth backpressure test has been added and is
> awaiting its final CI result.** The existing
> `G1` Verilator directed testbench runs separately. **This UVM environment is
> not a complete PCIe 6.0 Root Complex VIP**, because the DUT itself lacks
> PCIe Transaction Layer, full DLL, LTSSM and real PHY/PIPE integration.

## What was implemented

| Area | UVM implementation | Checks |
|---|---|---|
| Host transmit interface | `pcie_tx_agent`, sequencer, driver | ready/valid, bytewise 256-byte encoded FLIT vs Python oracle |
| External PHY receive | `pcie_rx_agent`, driver | good/one-byte corrected/two-byte drop, recovered payload, retry-not-implemented |
| Link state control | `pcie_link_agent` | L0 gating, Gen1–Gen6 FLIT negotiation inputs, width validity, link-down flush |
| Engineering CSR access | `pcie_csr_agent` | signature, version, scratch, feature registers |
| Passive observation | `pcie_bus_monitor` | output deliveries, drop and correction pulses, link epochs |
| Scoreboard | `pcie_g6_scoreboard` | independent Python vectors; accepted/transmitted transaction ordering; drain checks |
| Functional coverage | `pcie_g6_coverage` | TX/RX, packet length bins, corruption kind/cross |
| Assertions | `pcie_g6_sva` | valid stability, malformed length, link-down, Gen6 FLIT rules |
| Virtual sequences | `pcie_g6_virtual_seq` | multi-agent orchestrated smoke/random/negative/flush/width |

## Tests

- `pcie_g6_smoke_test`: 16 TX and 16 RX packets, CRC/FEC, CSR checks
- `pcie_g6_random_test`: 96 independent vector index/error-mode selections
- `pcie_g6_negative_test`: malformed lengths (0/60/63), illegal Gen/width/mode
- `pcie_g6_linkloss_test`: buffered TX/RX invalidated by lost link, then recovery
- `pcie_g6_width_test`: all 5 supported link widths at 6 generation codes
- `pcie_g6_backpressure_test`: stalled TX/RX stability and recovery

## Run

External UVM is NOT copied into this repository; install it from
[Accellera's UVM repository](https://github.com/accellera-official/uvm-core).
A commercial simulator with IEEE 1800.2 UVM precompiled is recommended.

```bash
make check
make tb-unit
SIM=questa UVM_TESTNAME=pcie_g6_smoke_test make tb-uvm
SIM=questa UVM_TESTNAME=pcie_g6_random_test SEED=42 make tb-uvm
SIM=questa make tb-uvm-regression
```

Optional: Verilator >=5.052 + UVM 2020-3.2 may be usable via
`SIM=verilator UVM_HOME=/path/to/uvm make tb-uvm`, depending on how that
UVM library was built. Ubuntu 24.04 apt Verilator 5.020 does **not** run
this UVM testbench. Do not treat the structural UVM check as simulation.

### Source hierarchy

```text
tb/uvm/
  pcie_g6_if.sv           DUT signal bundle
  pcie_g6_pkg.sv          includes UVM components in order
  pcie_g6_types.svh       transactions and external goldens
  pcie_g6_agents.svh      TX/RX/Link/CSR agents, passive monitor
  pcie_g6_scoreboard.svh  reference comparisons + coverage
  pcie_g6_sequences.svh   reusable child + virtual sequences
  pcie_g6_env.svh         monitor/scoreboard/agents connections
  pcie_g6_tests.svh       5 runnable UVM test classes
  pcie_g6_sva.sv          concurrent safety assertions
  pcie_g6_tb_top.sv       named DUT connections, clock/reset
  uvm_sources.f           UVM source file order

tb/scripts/run_uvm.sh     compile/sim commands
```

## Known limitations / blocked tests

- No TLP header semantic checking beyond the prototype's accepted length.
- The 8 independent vectors contain arbitrary bytes; they are **codec
  stimulus**, not necessarily legal PCIe TLPs.
- No standard PCIe configuration space; CSR above is a local engineering port.
- No LTSSM, ordered sets, electrical PAM4, lane training/equalization or PIPE.
- No non-FLIT mode: Gen1–Gen5 cases exercise a diagnostic link guard only.
- No actual ACK/NAK replay, flow-control initialization, requester/completer,
  MSI/MSI-X, multi-VC, AER, SR-IOV, real Root Complex peer, stress throughput
  or actual PCI-SIG protocol compliance.

The verification matrix in `tb/plan/VERIFICATION_MATRIX.csv` includes future
scenarios, not assertions that those features already exist. Advance a test
from BLOCKED only when its corresponding RTL has been implemented and
verified against an independent oracle.
