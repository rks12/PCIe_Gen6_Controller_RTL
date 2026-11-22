# PCIe Gen1–Gen6 Controller: Full Functional Verification Master Plan

**Baseline:** `PCIe_Gen6_Controller_RTL_v0.2.zip` (2026-11-22)
**Reference:** User-supplied *PCI Express Base Specification, Revision 6.0 (16 December 2021)*.
**Target:** Single-function PCIe Endpoint, maximum Gen6, widths x1/x2/x4/x8/x16, both legacy non-FLIT and negotiated FLIT modes.
**Status:** **VERIFICATION PLAN ONLY.** No UVM/cocotb HDL testbench has been implemented or run for this deliverable.

## 1. Goal and accurate starting point

Build a self-checking, reproducible verification environment that establishes, **for the explicitly implemented feature profile**, compliance with exercised mandatory PCIe protocol behavior at the Transaction Layer (TL), Data Link Layer (DLL), and Logical PHY, plus interface/CSR and reset/backpressure behavior. It is not evidence of electrical, PAM4 analog, SerDes, silicon timing, or PCI-SIG certification.

### What exists in RTL v0.2 and can be tested immediately

- `pcie_gen6_controller_top.sv`: preformatted single TLP (1–59 DWORDs) + externally supplied six DLP bytes -> full 256-byte FLIT; full-FLIT RX -> corrected TLP area + DLP; local engineering CSR; externally supplied L0/gen/width/FLIT mode.
- Connected: `pcie_link_guard`, `pcie_flit_tlp_packer`, `pcie_flit_tx_pipe`, `pcie_flit_rx_pipe`, `pcie_flit_encoder/decoder`, `pcie_crc64_gen`, `pcie_fec_encoder/decoder`, `pcie_register_bank`.
- Standalone **not top-connected**: `pcie_lcrc32_reference`, `pcie_credit_counter`, `pcie_flit_sequence_tracker`, `pcie_tlp_type_monitor`.
- There is **no full TLP parser, enumeration/standard config space, complete DLL/replay/FC, LTSSM, physical framing, PIPE or analog SerDes**. It is invalid to label Gen1–Gen6 protocol tests PASS before those modules exist.

### Requirements for a "fully functional testbench"

1. **Drivers + responder:** Can generate legal and illegal PCIe traffic in both directions with configurable timing, link widths/rates and flow control.
2. **Independent expected models:** Predict every transaction result/packet/state independently of DUT outputs; never use a DUT encoder as the only oracle for its decoder.
3. **Assertions and scoreboards:** Detect corruption, duplication, loss, misordering, wrong completion data/status, credit violations, incorrect retries, deadlocks and protocol-state violations.
4. **Coverage/traceability:** Each in-scope mandatory requirement has at least one directed test + monitor/assertion + coverage point + version-controlled evidence.
5. **Reproducibility:** Single-command jobs, deterministic seeds, logs, waveforms on failure, timeout/watchdog, CI gates and recorded tool versions.

## 2. Verification architecture

```text
                              TEST COORDINATOR / VIRTUAL SEQUENCER
                                            |
              +-----------------------------+----------------------------+
              |                             |                            |
      APPLICATION AGENT               CSR / CONFIG AGENT           LINK CONTROL AGENT
      TLP/TX and RX traffic           CSR now; PCIe config later   reset, L0, gen, width
              |                             |                            |
              +-----------------------------+----------------------------+
                                            |
                                      +-----------+
                                      |   DUT     |
                                      +-----------+
                                       |         |
                  (abstract full FLIT)|         | (later actual logical PHY/PIPE)
                                       |         |
                        FLIT PHY AGENT / ROOT-COMPLEX PEER BFM
                        TX monitor, RX driver, ACK/NAK, retry,
                        credits, LTSSM/ordered sets when available
                                       |
                       +---------------+----------------+
                       |               |                |
                    MONITORS       INDEPENDENT        ASSERTIONS
                    & EVENT BUS     GOLDEN MODELS      + COVERAGE
                       |               |                |
                       +-------- END-TO-END SCOREBOARD-+
                       |         / ERROR CLASSIFIER    |
                   REGRESSION / COVERAGE DATABASE / DEBUG REPORT
```

### Agent responsibilities

- **Application agent:** Generate requests (eventually memory read/write, completions, configuration, messages); apply random backpressure; check accepted handshakes and exact output timing.
- **Root Complex peer BFM:** Model a standards-aware opposite port (requester and completer), with true independent FC accounting, sequence and replay state. Do not assume loopback inherently proves correctness.
- **Abstract FLIT PHY agent (v0.2):** Accept/transmit 2048-bit FLIT transactions, inject bit/byte errors and stall ready/valid; assert external `phy_l0`, `phy_flit_enabled`, `phy_gen`, `phy_width`.
- **Logical PHY agent (future):** TS1/TS2/TS0, SKP/EIEOS/EIOS, framing and scrambling, lane striping/skew, equalization handshakes, speed and width change, recovery.
- **CSR/config agent:** For now test local engineering CSRs only; when added, test real PCIe Type-0 configuration requests, BAR decode, capability lists, reset properties and interrupts.
- **Scoreboards:** Separate `flit_integrity`, `dll_replay`, `tl_transaction`, `cfg`, `link_state` and `end_to_end` scoreboards to avoid masking an error in one layer by another.

## 3. Technical strategy and tooling

**Primary system regression:** SystemVerilog **UVM (IEEE 1800.2-compatible implementation)** with interfaces, sequence items, drivers, passive monitors, agents, subscribers, register model, scoreboard, functional coverage and SVA. Use a simulator version with the selected UVM implementation verified to work; a commercial simulator may be necessary.

**Open-source bootstrap:** Python 3 + `pytest` for independent golden vectors, and **cocotb + Verilator** for RTL component/top smoke tests. Cocotb tests supplement rather than substitute the full system verification and must be explicitly listed in the run manifest. Simulator/version compatibility must be pinned after tool selection. **Do not label `make check` as an HDL test.**

**Other analyses:** Verilator lint, synthesizability checks, optional SymbiYosys/formal for FIFO/sequence properties, CDC/lint, waveforms and coverage merger. Electrical compliance requires a separate real PHY/hardware validation program.

## 4. Project layout to implement in the next phase

```text
PCIe_Gen6_Controller_RTL/
├── rtl/                                # Existing DUT; not a testbench
├── scripts/rtl_sources.f               # Existing DUT compilation file list
├── tb/
│   ├── README.md                       # Setup, version pinning, run instructions
│   ├── configs/
│   │   ├── default.yaml                # Interface width, speed, timers, memory map
│   │   ├── link_modes.yaml             # All valid gen/width/FLIT combinations
│   │   └── regressions.yaml            # Smoke/nightly/full selection
│   ├── sv/
│   │   ├── interfaces/                 # app_if, flit_phy_if, csr_if, future pipe_if
│   │   ├── agents/                     # app, phy peer, link ctrl, cfg/CSR agents
│   │   ├── env/                        # pcie_env, virtual sequencer, config objects
│   │   ├── sequences/                  # directed, constrained random, error cases
│   │   ├── models/                     # independent transaction/link reference models
│   │   ├── scoreboards/                # TL/DLL/PHY/FLIT + end-to-end scoreboards
│   │   ├── assertions/                 # SVA protocol/interface property binders
│   │   ├── coverage/                   # covergroups, requirement bins, crosses
│   │   ├── tests/                      # UVM test classes
│   │   ├── pcie_tb_pkg.sv
│   │   └── tb_top.sv                    # clock/reset, DUT, UVM setup
│   ├── py/
│   │   ├── reference/                  # independent CRC/FEC/TLP/FC calculations
│   │   └── tests/                      # pytest/cocotb: v0.2 unit and top smoke
│   ├── vectors/                        # versioned specification-derived golden data
│   ├── requirements/                   # traceability: ReqID -> RTL -> test/assert
│   └── scripts/                        # run_tb.sh, regress.py, collect_coverage.py
├── docs/                               # Existing architecture/gap documentation
├── Makefile                            # Add tb-smoke/unit/nightly/full targets
└── build/tb/                           # Generated ONLY: never commit outputs
```

Each new source must begin with a multi-line header stating **purpose, connected interfaces, functions/tasks/classes, protocol assumptions, supported and excluded modes**. For each test: include unique test ID, reference, stimulus, oracle, expected behavior, pass/fail conditions and seed requirements.

## 5. Incremental execution plan / dependencies

| Gate | Stage | What becomes runnable | What is blocked | Exit requirement |
|---|---|---|---|---|
| **G0** | Infrastructure | Compile, lint, CI, clocks/reset, test discovery, logs | None except simulator installation | Clean elaboration and a single deterministic test result |
| **G1** | Current v0.2 connected datapath | Link guard, packer, CRC/FEC, top TX/RX, CSR, backpressure, reset | All true TL/DLL/LTSSM behavior | All v0.2 target tests pass with independent reference |
| **G2** | FLIT TL after RTL exists | Legal/illegal TLP decode, multi-TLP/spanning, ordering, completions, cfg | Missing TL implementation | Requirement mapping complete and TLP scoreboards pass |
| **G3** | FLIT DLL after RTL exists | DLP, FC initialization, sequence, Ack/Nak, standard/selective replay | Missing DLL implementation | Recovery after induced losses/corruption without data loss/duplication |
| **G4** | Legacy non-FLIT after RTL exists | Non-FLIT TLP/DLLP framing, CRC16/LCRC32, replay, FC | Missing NFM RTL | Gen1–Gen5 non-FLIT directed + random pass |
| **G5** | Logical PHY after RTL exists | LTSSM, speed/width, EQ, OS, scrambling, deskew, all logical rates | Missing PHY logic + PHY interface | Link reaches L0 and recovers for every supported mode |
| **G6** | Full system | Root Complex transactions, enumeration, BAR, MSI/MSI-X as included, reset | All G2–G5 implementations | End-to-end error-free traffic, recovery, deadlock tests pass |
| **G7** | Performance/interoperability | sustained stress, long randomized tests, performance and real peer | Real PIPE/PAM4 PHY and hardware | Defined throughput goals + external interoperability evidence |

**No false pass rule:** A test for an unimplemented block is `BLOCKED/NOT RUN`, not `PASS`, and never silently omitted from a declared profile.

## 6. Minimum directed functionality: current RTL (G1)

### 6.1 Arithmetic / data integrity

- CRC: zeroes, all-ones, alternating patterns, spec-derived Appendix-K reference matrices, one-hot input bits, seeded random 242B data; compare exact ordered 8-byte output with an **independent** model.
- FEC: group maps and parity positions, all 3 ECC groups, error correction at first/last byte, any payload/DLP/CRC/ECC position, 1-bit/1-byte errors, multiple errors in different groups, >1 symbol in a group, and invalid CRC after miscorrection. Do not assert that every double-byte error must be diagnosed by FEC alone; the final CRC is authoritative.
- FLIT codec: exact layout byte 0..255; random encode->independent reference->decode; injection before RX; decoder never presents invalid frames as good; required correction/drop pulses.

### 6.2 Interface/CSR/backpressure

- TX/RX full/empty and simultaneous dequeue+enqueue; ready/valid must be held until a handshake; data stays stable under stall; test stalls from 1 to thousands of cycles, reset while stalled and link-down while buffered.
- TLP length: counts 0,1,58,59,60,63; check accepted byte count and NOP padding; **count 59 is boundary**. This is only a packer test; a legal PCIe TLP header is supplied by a reference generator where needed.
- Link guard: all six gen indices, widths 1/2/4/8/16, invalid 0/3/5/17/31, L0 off, FLIT off at Gen6 and lower rates. Only the mode guard is being tested, NOT Gen1–Gen6 link implementation.
- CSR: signature/version/link status, scratch read/write, read-only semantics, flags, RX drop counter, reset behavior, adjacent read/write transactions.
- Counters: maximum 32-bit saturation; sustained bad frames; pulse width; corrected-but-CRC-invalid frame handling.

### 6.3 Key v0.2 integration issue to expose

**Link-down with a buffered FLIT may leave stale TX `phy_tx_flit_valid` or RX `rx_tlp_area_valid` asserted.** The top-level buffers currently have only `rst_n`, not a link-epoch flush. Tests must define whether link loss flushes buffered state, and fail until implemented consistently with PCIe link-down rules. Do not hide the failure by resetting the entire DUT in the test.

## 7. Full Transaction Layer coverage (future RTL, G2/G6)

- Memory Write/Read 32/64-bit addressing; zero/boundary/unaligned byte enables as permitted, MPS/MRRS edges, 4KB request boundaries, payload lengths, legal/illegal formats.
- Completion: tag/requester ID matching, multiple outstanding reads, split/compressed completions where applicable, byte count/lower address, completion status (SC/UR/CA), timeout, unexpected/duplicate completion, poisoned TLP, malformed handling.
- Ordering: posted/nonposted/completion interactions, Relaxed Ordering, No Snoop, ID-Based Ordering if implemented, traffic classes/VCs, fences and backpressure.
- Flow control: posted/nonposted/completion header/data credit classes, scaled FC and initialization/update, zero credit, credit replenishment, wrap vs saturation rules, no negative credits/deadlock.
- Configuration: Type 0 header, ID, class and capabilities, BAR probe/sizing, command/status, power/reset, MSI/MSI-X and AER only to the level declared implemented; legacy/local engineering CSRs are not host config space.
- FLIT TLP packing: NOP and 4-DW alignment, multiple TLPs, TLP crossing a FLIT, 236-byte usable TLP region and middle-of-FLIT discontinuities, OHC/prefix and FLIT status poisoning/nullification.

## 8. Full DLL verification (future RTL, G3/G4)

- **FLIT:** IDLE handshake, explicit/implicit sequence numbers, NOP FLIT vs Payload FLIT, modulo wrap, ACK, standard NAK, selective NAK, replay timer, retry buffer full/empty, acknowledgment loss, cumulative vs selective replay, credit release, reset while outstanding.
- **Important:** Replayed information must be linked to original TLP bytes; DLP payload in a replayed FLIT may be newly generated (the specification does not require replay of the old DLP bytes). Verify *packet semantics*, not byte-equality for every replayed FLIT.
- **Non-FLIT:** TLP sequence, LCRC32, DLLP CRC16, Ack/Nak DLLPs, replay timeout, duplicate TLP suppression, link-down cancellation, FC init and UpdateFC.
- Cross-layer: no delivering an uncorrected corrupted TLP; no duplicate completed request after replay; no credit leak; correct response on consecutive errors and replay exhaustion.

## 9. Full Logical PHY verification (future RTL, G5)

- Negotiation from reset through Detect/Polling/Configuration/Recovery to L0; transient disconnect, hot reset, disabled/loopback and modeled low-power states only if supported.
- Modes: Gen1/2 8b/10b, Gen3/4/5 128b/130b, Gen6 1b/1b/64 GT/s; FLIT negotiation on lower rates and mandatory at Gen6; successful fallback if partner lacks advertised support.
- Equalization phases, presets/coefficient acceptance, recovery speed changes, TX/RX polarity inversion, lane reversal if supported, lane striping/deskew, SKP and elastic-buffer operation, reference clock modes.
- Gen6 PAM4 logical Gray coding, precoding, 1b/1b scrambling and ordered-set interactions; use the PHY model for digital levels only, **not** analog signal eye, jitter, FBER, equalizer performance or electrical compliance.
- Every LTSSM transition must have explicit source-state/event/guard and a watchdog to reject illegal or stuck states.

## 10. End-to-end tests (future RTL, G6)

A root-complex responder enumerates the endpoint, reads PCI config registers, probes BARs, maps a BAR, issues MWr/MRd with various sizes, verifies data, runs multiple outstanding reads, triggers an implemented interrupt (MSI/MSI-X), and recovers from injected FLIT/TLP corruption and link retraining. Re-run with x1/x2/x4/x8/x16 and six speed generations where the RTL and chosen PHY truly support the combinations. For random runs, vary transaction mix, credits, backpressure, errors, order, link events and latency within legal constraints.

## 11. Independent reference model and assertions

- Maintain immutable specification-derived CRC64 and ECC vectors from Appendix K/J. Validate Python model against the vectors before using it as an oracle; cross-check an alternate matrix implementation if feasible.
- Build an RC golden memory model; transaction scoreboard keyed by requester ID/tag/completion context; compare byte enables and all completion fields, not merely payload contents.
- Keep predicted ACK/NAK/sequence/FC state in the **peer** and scoreboards, not by reading DUT internal state.
- Assertions: `valid && !ready |=> valid && $stable(data)` (qualified against reset/abort semantics); no output without accepted input or correctly modeled internal generation; no buffer overflow/underflow; only legal state transitions; no illegal FLIT/non-FLIT at Gen6; correctly bounded replay/timeout behavior; no application packet released with CRC invalid.
- Explicit reset/epoch semantics: cancel outstanding transactions and flush relevant buffers on link down as defined by the implementation's PCIe requirements.
- Add a global watchdog and a per-transaction timer so hung tests fail rather than pass by simulation termination.

## 12. Coverage and release criteria

**Per requirement:** `REQ_ID | spec section | mandatory/optional | declared support | RTL owner | test ID | assertion ID | coverpoint | result | waiver`.

**Coverage targets (project goals, not PCI-SIG certification thresholds):**

- 100% of **declared-in-scope mandatory requirements** linked to an executable test/assertion and observed at least once; all uncovered exclusions explicitly waived and documented.
- 100% of meaningful *protocol* bins: generation, width, negotiated packet mode, link states, ACK/NAK/replay types, sequence wrap, flow-control classes, TLP type/length boundaries, CRC/FEC correction outcome and resets.
- >=95% statement/branch/toggle coverage of in-scope RTL as an initial project goal, with reviewed unreachable code and justified exceptions. Coverage percentage alone never overrides an assertion/scoreboard failure.
- Zero open P0/P1 functional bugs for release, zero failing mandatory directed tests, zero unexplained SVA failures, zero expected-output mismatches, and zero seed-dependent crashes on full regression.
- Re-run failures with same seed; make seed, config hash, DUT commit, tool version, command, test IDs, logs and waveforms part of the archived report.

**Regression tiers:** PR/smoke (short directed + lint), nightly (all directed + medium constrained random), weekly/full (all valid mode combinations, long stress, fault campaigns and coverage closure), pre-release (full signoff + external peer/hardware where available).

## 13. Planned commands (NOT implemented in RTL v0.2)

From repository root after a compiler, UVM simulator and/or cocotb requirements are installed:

```bash
# EXISTING commands in v0.2
make check            # Python/source-reference checks, NOT RTL simulation
make lint             # HDL compiler lint: requires Verilator or Icarus

# PLANNED targets: add them with the future tb/ implementation
make tb-smoke SIM=verilator SEED=1
make tb-unit  SIM=verilator SEED=17
make tb-uvm   SIM=<supported-uvm-simulator> TEST=pcie_v0p2_smoke_test SEED=17
make tb-nightly SIM=<supported-uvm-simulator> SEED=17
make tb-full    SIM=<supported-uvm-simulator> SEED=17
make tb-coverage
```

Each target must return **non-zero** on compilation failure, assertion failure, scoreboard mismatch, uncovered mandatory requirement (for full), crash, or timeout. `PASS` must require one or more functional checks executed. Generated waveform and JUnit/JSON/coverage artifacts go under `build/tb/<run-id>/`.

## 14. Priority order and acceptance milestones

**First next delivery (TB-V1):** Real compile/elaboration and cocotb tests of the existing top, FIFO handshakes, exact FLIT layout/CRC/FEC, 1-TLP packer, link guard and local CSRs; reproduce at least one injected error and the link-down buffer hazard. Include a required failing/blocked list, not a fabricated full-pass report.

**Second delivery (TB-V2):** Independent FLIT RC-peer BFM with sequence/retry/FC as DLL RTL is added. **Third (TB-V3):** Full TL requester/completer + configuration/enumeration. **Fourth (TB-V4):** Non-FLIT + Logical PHY, all negotiated modes. **Fifth (TB-V5):** Regression closure, random stress, functional coverage, and real PHY/peer interoperation.

**Stop condition:** Do not call the project a *fully functional Gen1–Gen6 PCIe controller* until controller RTL itself passes G0–G6. A testbench cannot implement missing DUT functionality or establish Gen6 electrical capability.

## 15. Exact standards traceability anchors

- §1.5: TL/DLL/Physical layer division and services.
- §§2.2–2.6: FLIT/non-FLIT TLPs, routing, ordering and credits.
- §§3.2–3.6: Data Link states, FC initialization, DLLPs, non-FLIT reliability.
- §4.2/Table 4-1: mode combinations and negotiated FLIT mode.
- §§4.2.3.1–4.2.3.4: Gen6 encoding, FLIT format, sequence/replay, CRC and FEC.
- §§4.2.4–4.2.8: equalization, training, LTSSM, SKP handling.
- Chapters 5–7: PM, system/interrupt/error support and config space.
- Appendices J and K: reference RTL and matrices for FEC/CRC, respectively.

**Source ownership:** PCI-SIG specification is user-supplied and must not be redistributed with generated testbench files. Preserve references/section IDs only.
