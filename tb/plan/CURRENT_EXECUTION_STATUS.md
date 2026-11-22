# G1–G7 implementation / verification status

- **G0 (source/Python)**: available and run locally; HDL G1 compile + simulation passed via GitHub Actions.
- **G1 (implemented codec and standalone utilities)**: SV tests authored
  (`tb_pcie_gen6_g1`, `tb_pcie_g1_primitives`); both top and primitive suites passed under Verilator on GitHub Actions.
- **G2 (transaction)**: BLOCKED — TLP parser, requester/completer, config absent.
- **G3 (FLIT replay and DLL)**: BLOCKED — ACK/NAK, seq and credit protocol absent.
- **G4 (non-FLIT)**: BLOCKED — full legacy DLL/PHY path absent.
- **G5 (LTSSM/PHY)**: BLOCKED — digital PCS and hardware PHY absent.
- **G6 (RC end-to-end)**: BLOCKED — actual transaction and configuration absent.
- **G7 (stress/hardware)**: BLOCKED — no physical Gen6 link.

The 76 rows of VERIFICATION_MATRIX.csv are requirement plans, not observed
PASS results. In particular, a model pass does not imply the HDL passed.

- **Prototype IEEE 1800.2 UVM**: agents, sequences, scoreboard, SVA and
  six test scenarios exist under `tb/uvm/`. The UVM smoke/random tests
  passed on GitHub Actions together with negative, link-loss and width tests;
  newly added backpressure case awaits latest CI.
