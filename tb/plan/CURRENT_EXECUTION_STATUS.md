# G1–G7 implementation / verification status

- **G0 (source/Python)**: available and run locally; HDL compile not run.
- **G1 (implemented codec and standalone utilities)**: SV tests authored
  (`tb_pcie_gen6_g1`, `tb_pcie_g1_primitives`); requires simulator to confirm.
- **G2 (transaction)**: BLOCKED — TLP parser, requester/completer, config absent.
- **G3 (FLIT replay and DLL)**: BLOCKED — ACK/NAK, seq and credit protocol absent.
- **G4 (non-FLIT)**: BLOCKED — full legacy DLL/PHY path absent.
- **G5 (LTSSM/PHY)**: BLOCKED — digital PCS and hardware PHY absent.
- **G6 (RC end-to-end)**: BLOCKED — actual transaction and configuration absent.
- **G7 (stress/hardware)**: BLOCKED — no physical Gen6 link.

The 76 rows of VERIFICATION_MATRIX.csv are requirement plans, not observed
PASS results. In particular, a model pass does not imply the HDL passed.
