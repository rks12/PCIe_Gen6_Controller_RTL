# Changelog

## v0.4 — SystemVerilog UVM environment and regression

- Added IEEE 1800.2 UVM agents (TX, RX, link, CSR), passive monitor,
  virtual sequencer, deterministic and random sequences, independent
  Python-FLIT scoreboard, transaction functional coverage, and SVA.
- Added six runnable UVM tests for current RTL: smoke, random stress,
  negative/invalid guard, link-down flush, all link widths/generations, and TX/RX backpressure
  in negotiated FLIT mode.
- Added a separate GitHub Actions UVM simulation workflow using a pinned
  Verilator 5.054 binary and bundled Accellera UVM 2020-3.2 library.
- Fixed the reproducible G1 primitive monitor directed-test failure by
  driving the complete TLP-area bus; latest G1 CI passed.
- **NOT** a full PCIe verification IP suite because most TL/DLL/LTSSM/PHY
  modules remain missing. Full protocol cases remain BLOCKED.

## v0.3 — G1 executable testbench and link-epoch flush

- Added deterministic Python-generated, independent golden FLIT inputs.
- Added self-checking SystemVerilog top-level and primitive suites, run script,
  Make targets, verification documentation, original 76-case future plan,
  and GitHub Actions CI definition.
- Fixed a known issue in the one-frame TX/RX pipes: data queued before
  link-down must not reappear after link-up. The top masks `valid` immediately
  when link guard deasserts; pipe `flush` drops pending entries on the next clk.
- **Does not add** full TL/DLL/LTSSM/PHY or commercial UVM suite.
- Python model and source audit have passed in creation environment; actual
  HDL compilation/simulation **not run** there due to missing Verilator.
  CI will compile and run HDL once the files are committed to GitHub.

## v0.2 — initial RTL research foundation

- CRC/FEC datapath, FLIT holding registers, simple packer, engineering CSR,
  protocol reference Python and link-state input guard.
