# Testbench to build separately later (not included in this archive)

**Testbench is intentionally deferred**, as requested. Do NOT interpret Python algorithm checks as the future HDL testbench.

## Stage 0 — prepare compiler and waveforms

- Install Verilator (or commercial simulator), Python3, cocotb or SV UVM as appropriate.
- Run `make lint` and resolve all HDL errors/warnings before writing tests.
- Fix the target PHY/lane width, clocks and protocol stack profile.

## Stage 1 — CRC/FEC block verification

- RTL CRC64 matches Appendix K generator-matrix vectors for every single-bit basis, plus random payloads.
- ECC encode/decode has directed tests for all 256 byte locations and bit positions; random independent errors in separate groups; double errors within a group rejected by CRC.
- CRC errors and ECC status signal checks; reset and X-propagation checks.
- RTL ready/valid latency, stalled TX/RX and full one-entry buffers.

## Stage 2 — TL/DLL verification (after implementation)

- FLIT NOPs, multiple TLPs, spanning TLPs, OHC, different lengths, credits and markers.
- Transaction requests/completions, 3DW/4DW, config/BAR, ordering, tags, split completion, timeout.
- FM implicit/explicit sequence and IDLE handshake, FC init, NAK selective and standard, all TX/RX retry corner cases.
- NFM STP/END/EDB, DLLPs, LCRC32 and retry behavior.

## Stage 3 — PHY and system integration (after implementation)

- LTSSM detect/poll/config/recovery/L0 and illegal transitions.
- Gen1..Gen6 encoding/scrambling, speed/mode/link width x1/x2/x4/x8/x16.
- Electrical idle, ordered sets, SKP insertion/removal, deskew, equalization, reset and retraining.
- Packet corruption, loss, duplication, lane skew and rate drops.
- Eventually formal protocol assertions, bus functional model and hardware interoperability.

## Coverage and signoff

Every PCIe MUST/SHALL assertion included in selected implementation profile should map to: (1) source section, (2) RTL owner, (3) test case and (4) coverage assertion. Track supported/unsupported features precisely and do not promote the project to Gen6 capability without verified link training and a real PHY.


### v0.3 update
G1 smoke and utility HDL test sources now exist under `tb/sv/`; see
`tb/README.md`. Full UVM / G2–G7 verification remains future work.
