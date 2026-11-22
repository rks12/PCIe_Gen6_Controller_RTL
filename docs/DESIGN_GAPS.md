# Design gaps / open implementation issues

## P0: blockers for calling this a functional PCIe controller

- **FM TLP specification:** Handle all mandatory Type encodings, header base sizes, OHC and TS, tag/requester/completer IDs, CRC/ECRC optional checks, malformed and unsupported requests, transaction ordering and NP completion timeout. Enforce TLP/FLIT packing across boundaries and NOP rules.
- **FM Data Link semantics:** 10-bit sequence numbers with IDLE/NOP/Payload and implicit/explicit logic; ACK/NAK, selective and standard replay, timeouts, retry TX/RX buffers and DLP credit updates. Today the RX path drops bad frames **without** generating a NAK.
- **NFM protocol:** Frame TLPs/DLLPs on link, sequence and LCRC, ACK/NAK and replay, FC init and credit distribution for Gen1..Gen5 and lower-rate non-FLIT mode.
- **Real logical PHY:** TS/OS parsing/creation; LTSSM including per-state timers; speed/width negotiation, equalization phases, polarity inversion, elastic buffer, lane deskew, framing, encoders/scramblers, link recovery and reset/power conditions.
- **Real physical interface:** Implement a vendor PHY/PIPE integration layer and clock/reset/CDC strategy; external analog PAM4 transceiver required for Gen6.
- **PCI function discoverability:** 4KB config space, capability structures, Type 0 endpoint headers, Device/Vendor ID, BAR decoding, MSI-X and required error/power controls. Local CSRs do NOT substitute for enumeration.

## P1: performance and robustness

- Replace single whole-frame 2048-bit ready/valid abstraction with banked/pipelined lane-parallel datapaths, buffered clock domains and a vendor-specific PHY bus.
- Pipeline CRC64 242-byte math and ECC syndrome search, validate equivalence, close Fmax in chosen node/FPGA. This version is logically unoptimized.
- Buffer sizing for credit windows/retries and deadlock analysis for backpressure.
- Verify poisoned/nullified TLP marker processing, ECRC, error reporting, deterministic reset and link-down transactions.

## P2: extra optional capabilities

Add needed optional capabilities only when baseline is correct: MSI-X, extended tags, SR-IOV, PASID/ATS/PRI, IDE, hot-plug, L1.1/L1.2, L0p, PTM, LTR, OBFF, various error extensions, alternate protocol and retimer handling.

## Open questions to lock before production

- Target FPGA/ASIC, synthesis tool and selected vendor PHY/SerDes, available PIPE interface width and clock frequencies.
- Endpoint single/multi-function or Root Port? This project assumes **Endpoint**, single function.
- Link width x1 / x4 / x8 / x16, target workload, MPS/MRRS, outstanding tags, BAR map, DMA/user protocol.
- Which optional PCIe capabilities must be exposed? Every declared capability implies more RTL and directed verification.

## Acceptance criteria for the eventual full implementation

1. Full HDL parser/elaboration clean, all warnings triaged, and synthesis reports reviewed.
2. Dedicated SystemVerilog/UVM TB verifies TL, DLL and PHY with golden packet models, including direct/indirect corner cases.
3. All mandatory spec rules traced to an RTL module and executable test/assertion.
4. Link trains and negotiates against a trusted RC/Endpoint PHY (including backward compatibility).
5. Enumeration, memory reads/writes, completions, interrupts and controlled errors verified through real host software/hardware.
6. Throughput, latency and PPA measured at target process, clock and xN width.
