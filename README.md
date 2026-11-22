# PCIe Gen1–Gen6 Endpoint Controller — RTL Research Foundation (v0.3)

> **STATUS — NOT A COMPLETE PCIe CONTROLLER.** This repository implements the core **PCIe 6.0 FLIT CRC/FEC digital codec**, one-frame ready/valid datapaths, limited single-TLP FLIT-area packing, link-status gating, basic local CSRs, and standalone initial utilities. It does **not** implement a PCI-SIG-compliant PCIe Gen1–Gen6 Endpoint. **Do not advertise this RTL as Gen6-capable on hardware or connect it directly to a commercial PCIe link.** See the detailed [feature matrix](docs/FEATURE_MATRIX.md) and remaining work.

The scope is explicit to prevent a dangerous *compiles = protocol works* assumption. The user-provided **PCI Express Base Specification Revision 6.0, 16 December 2021** is the design reference. The copyrighted specification itself is **not redistributed** in this ZIP.

## 1. What works in the repository now

- Correct Gen6 **256-byte FLIT layout**: TLP area 236 B, DLP area 6 B, CRC 8 B, FEC 6 B.
- Independently coded 8-byte CRC over GF(256) using the **correct polynomial**, validated against six Appendix-K generator-matrix basis vectors.
- Three-way interleaved ECC encoding and receiver single-byte correction (up to one byte in each ECC group), with a **post-correction CRC accept criterion**.
- Single, preformatted, 4-byte-aligned FLIT-mode TLP (1–59 DW) put at the front of a FLIT, with zero-valued NOP TLP padding. Other valid packing schemes are **not** supported.
- One-entry ready/valid holding registers for 2048-bit FLIT TX and RX. Bad RX FLITs are dropped/counted but **no NAK/retry is generated**.
- Abstract PHY link-status/negotiation gate, local diagnostic CSR bank, standalone legacy LCRC computation and generic credit counter.
- Automated **Python algorithm checks** and source structural audit. No full HDL simulation, timing closure or real link validation has been performed.

## 2. What does NOT work yet (essential before a real PCIe link)

1. **Complete Transaction Layer:** FM/NFM TLP formatting/parsing for all mandatory request/completion types; Memory/Configuration TLP processing, 4KB config space and capabilities, BARs, IDs/tags, completions, ordering, virtual channels and complete credit bookkeeping; receiver must not expose raw 236 B TLP areas as already parsed transactions.
2. **Complete Data Link Layer:** DLL state protocol, credit initialization and updates, DLP encoding, ACK/NAK and sequence numbers, correct FLIT IDLE handshake, implicit and explicit numbering, NOP/Payload handling, selective/standard retransmission, RX reorder/retry buffer and replay timeouts. The standalone sequence tracker is intentionally **not connected**.
3. **Complete Logical PHY:** real LTSSM states and timers, Detect/Polling/Configuration/Recovery, ordered sets, width and rate negotiation, scramblers, 8b/10b, 128b/130b, Gen6 1b/1b, Gray coding, precoding, electrical idle, SKP/deskew, lane mapping and equalization. The **external** PHY/LTSSM signals in the top are *assumptions*, not training RTL.
4. **Actual PHY interface:** PIPE-compatible or vendor-specific PCS/PMA interface, transceivers, clocks/CDC, reset sequencing, and Gen6 PAM4 analog SerDes. Full 2048-bit one-cycle FLIT buses in this repository are *not* electrical PCIe interfaces.
5. **Production timing/PPA:** The reference CRC/FEC codec is a deep combinational implementation. It has not been pipelined for Gen6 clock rates, area/power, SRAM replay buffers, or x16 throughput.
6. **System services:** Standard configuration-space registers, enumeration, DMA, MSI/MSI-X, AER error semantics, PM/ASPM/L1 substates, hot reset/FLR, integrity IDE, retimers, and optional virtualization/other capabilities.
7. **Legacy Gen1–Gen5 non-FLIT link operation:** The LCRC reference utility exists, but no complete legacy TX/RX framing and retry path is integrated. FLIT mode at Gen1–Gen5 rates is also **only a codec**, not a PHY.
8. **Verification:** A G1 standalone HDL testbench is now in `tb/` (v0.3); complete UVM remains deferred. See [testbench plan](docs/TESTBENCH_NEXT_PHASE.md).

## 3. RTL block diagram (as implemented)

```text
  Local TLP bytes + size (FLIT-format already complete)
                        |
                 [TLP / NOP packer]                 [Local CSRs]
                        |                                  |
                   236-byte area                     status read
                        |                                  |
  caller's 6-byte DLP -> [FLIT encoder]                  |
                         | CRC64 over 242 bytes            |
                         | ECC  over 250 bytes             |
                         v                                 |
                     [TX 1-entry] -------------------------+
                         |
          abstract 2048-bit external PHY TX
              (no PHY/PCS supplied here)
                         |
          abstract 2048-bit external PHY RX
                         |
                     [RX 1-entry]
                         | ECC correct -> CRC verify
                         | corrupt packet drop/count
                         v
                  raw TLP region + DLP
               (NOT parsed PCIe transactions)

          EXTERNAL physical link/LTSSM -> link guard
          Blocks TX/RX unless trained FLIT mode is reported.
```

[Initial conceptual architecture image](docs/architecture_overview.png) illustrates the **eventual** target controller; many blocks in that image are NOT present in this revision.

## 4. Directory and file structure (v0.3)

```text
PCIe_Gen6_Controller_RTL/
├── README.md                         # Master setup, limits, module tree
├── Makefile                          # check / lint / sources / clean targets
├── rtl/
│   ├── pcie_gen6_controller_top.sv    # Integrates RX, TX, link guard, CSR
│   ├── common/
│   │   ├── pcie_gen6_pkg.sv           # GF256 and CRC polynomials/functions
│   │   ├── pcie_lcrc32_reference.sv   # Standalone legacy LCRC utility
│   │   └── pcie_register_bank.sv      # Local engineering/status CSRs
│   ├── tl/
│   │   ├── pcie_flit_tlp_packer.sv    # One complete TLP and NOP padding
│   │   └── pcie_tlp_type_monitor.sv   # First TLP Type byte probe
│   ├── dll/
│   │   ├── pcie_credit_counter.sv     # Simple credit accounting primitive
│   │   └── pcie_flit_sequence_tracker.sv # Basic expected seq monitor
│   ├── flit/
│   │   ├── pcie_crc64_gen.sv          # Gen6 eight-byte CRC generator
│   │   ├── pcie_fec_encoder.sv        # 3-way ECC encoder
│   │   ├── pcie_fec_decoder.sv        # 3-way ECC correction decoder
│   │   ├── pcie_flit_encoder.sv       # Compose TLP+DLP+CRC+ECC
│   │   ├── pcie_flit_decoder.sv       # ECC before CRC; error flags
│   │   ├── pcie_flit_tx_pipe.sv       # One-entry full FLIT TX
│   │   └── pcie_flit_rx_pipe.sv       # One-entry full FLIT RX, drop/count
│   └── phy/
│       └── pcie_link_guard.sv         # External training status validation
├── scripts/
│   ├── rtl_sources.f                 # Compile-order HDL filelist
│   ├── lint.sh                       # Verilator/Icarus syntax/elaboration
│   ├── protocol_reference.py         # Independent CRC/FEC golden model
│   └── source_audit.py               # Structural source completeness audit
├── checks/
│   └── check_results.txt             # Original Python/source check evidence
├── tb/                               # v0.3 executable G1 verification
│   ├── README.md                     # Actual HDL test commands and limitations
│   ├── sv/                           # Self-checking top and primitive SV tests
│   ├── python/                       # Independent generated vectors + model checks
│   ├── scripts/run_g1.sh             # Compiles and simulates real RTL
│   ├── plan/                         # Original 76-test full-protocol future plan
│   └── results/                      # Truthful validation status
├── .github/workflows/verify.yml      # Automated G1 verification on push/PR
├── CHANGELOG.md                      # v0.3 details and link-loss fix
└── docs/
    ├── architecture_overview.png     # Conceptual future target (not as-built)
    ├── ARCHITECTURE.md               # Interfaces, byte order and path limits
    ├── FEATURE_MATRIX.md             # Implemented / missing / validation
    ├── DESIGN_GAPS.md               # Missing work before PCIe link compliance
    ├── SPEC_TRACEABILITY.md          # PCIe 6.0 chapter cross reference
    └── TESTBENCH_NEXT_PHASE.md       # Future TB / scoreboard strategy
```

Every `.sv` file starts with a multiline comment describing its scope, functions, behavior, and restrictions. The comments in `pcie_gen6_pkg.sv` also describe the two distinct GF(256) fields and byte ordering.

## 5. How to run

### On Ubuntu / Debian (recommended for EDA tools)

```bash
sudo apt-get update
sudo apt-get install -y make python3 verilator
unzip PCIe_Gen6_Controller_RTL_with_TB_v0.3.zip
cd PCIe_Gen6_Controller_RTL
make check       # Python reference algorithm and structural audit
make lint        # real SystemVerilog lint/elaboration: Verilator
make sources     # show compile-order RTL source list
```

### On macOS

```bash
brew install python verilator make
unzip PCIe_Gen6_Controller_RTL_with_TB_v0.3.zip
cd PCIe_Gen6_Controller_RTL
make check
make lint
```

If Verilator is unavailable, `make lint` tries `iverilog -g2012`. `make check` uses only Python standard library and **does not compile RTL**. A nonzero exit from `make lint` must be treated as an HDL compilation failure, not ignored. You can run Verilator explicitly with:

```bash
verilator --lint-only -Wall -Wno-fatal --top-module pcie_gen6_controller_top \
  -f scripts/rtl_sources.f
```

**IMPORTANT:** In **v0.3**, executable G1 self-checking SystemVerilog tests are now included
under [`tb/`](tb/README.md). They cover only the already implemented RTL
foundation. The UVM/complete protocol suite remains unimplemented. Run
`make tb-unit` after installing Verilator >=5.

## 6. Top-level interface summary

| Interface | Width | Notes |
|---|---:|---|
| `clk, rst_n` | 1 each | Single-clock functional prototype; active-low asynchronous reset |
| `phy_l0, phy_flit_enabled` | 1 each | Status supplied by EXTERNAL PHY/LTSSM |
| `phy_gen, phy_width` | 3, 5 | Encoded gen=1..6, width=1/2/4/8/16 |
| `tx_tlp_bytes` | 1888 | Up to 236 bytes of **fully preformatted** FM TLP |
| `tx_tlp_dw_count` | 6 | 1..59 DW, nonzero; packet length supplied by caller |
| `tx_tlp_valid/ready` | 1 each | Ready/valid event on rising edge |
| `tx_dlp` | 48 | Full 6 bytes supplied by caller, **not automatically encoded** |
| `phy_tx_flit` | 2048 | One 256-byte encoded, protected FLIT |
| `phy_rx_flit` | 2048 | One 256-byte frame from abstract PHY |
| `rx_tlp_area, rx_dlp` | 1888, 48 | Receive raw area only if ECC/CRC valid |
| `rx_drop_pulse, rx_crc_error_count` | 1, 32 | Integrity failures discarded and counted |
| `csr_addr / csr_wdata / csr_rdata` | 8/32/32 | Local debug CSRs only, not PCI config registers |

The output `phy_tx_flit_valid` remains asserted until `phy_tx_flit_ready`, and the data is held stable during backpressure. The receiver similarly holds valid output until consumed. A transmitting caller **must hold its input stable** while `tx_tlp_valid=1` and `tx_tlp_ready=0` and must not assume `tx_tlp_valid` means the FLIT was sent without a handshake.

## 7. Test evidence and limitations

`make check` exercises:
- Six 8-byte CRC basis vectors against the PCIe 6.0 Appendix K generator matrix.
- Four random valid 256-byte FLIT encode/decode loops.
- 1,024 single-byte corruption cases, including data, CRC and ECC locations.
- Four two-byte error examples that must fail the final CRC check.
- Source/header/filelist structure consistency.

These are **Python golden-model checks**, not direct RTL execution. The creation environment did not provide Verilator, Icarus Verilog or Yosys and had no package-network access; hence **the RTL has not passed real HDL lint, elaboration, synthesis or simulation here**. Run `make lint` on your development machine and fix any issues reported before further development. The separate TB phase must include golden-vector RTL comparison, randomized link and reset corner cases, retry/FC verification, formal properties and interoperability tests.

## 8. Development sequence (before complete controller claim)

1. **Transaction Layer:** full FM packet builder/parser, requester/completer, config space, BAR, tag/credit/order engines.
2. **Data Link:** FM sequence handshake, DLP credit updates, ACK/NAK, retry/reorder; complete NFM link path.
3. **Logical PHY:** LTSSM, TS1/TS2, speed/mode and lane negotiation, scramblers, coders, SKP/deskew/equalization; PIPE/vendor PHY shim.
4. **PPA and robustness:** throughput-matched multi-lane datapaths, retiming, CDC, clocks/resets, replay memories.
5. **Testbench separately:** block-level directed TB and integrated protocol/UVM suite with spec traceability.

### Licensing and provenance

The RTL and scripts here were authored for this deliverable. The supplied PCIe specification is a copyrighted external document, **not included**; this project does not imply certification, licensing, PCI-SIG membership or permission to distribute that specification. The `docs/architecture_overview.png` is an illustrative concept, not a compliance artifact.

## v0.3 — Testbench, CI and link-down correction

New additions are documented in [`tb/README.md`](tb/README.md) and
[`CHANGELOG.md`](CHANGELOG.md). Read **both** before running.

```bash
make tb-model      # Python golden-model checks only
make tb-smoke      # real HDL top test (Verilator >=5)
make tb-primitives # real HDL standalone utility tests
make tb-unit       # both real HDL tests
make tb-regression # repeat with multiple deterministic seeds
```

Historical G1–G7 verification planning documents and the 76-case matrix are
under [`tb/plan/`](tb/plan/). The presence of those plans does **not** mean
that unsupported protocol features have been implemented or tested. The
original conceptual diagram is not an as-built protocol diagram.

**Validation status:** Python vector and structural checks passed locally;
RTL compilation/simulation had not been run in the creation environment
because no compatible simulator was installed. See
[`tb/results/LOCAL_VALIDATION.md`](tb/results/LOCAL_VALIDATION.md).
