#!/usr/bin/env python3
"""Structural source-inventory check; deliberately NOT a UVM compiler or sim.

Validates that the specified interface, UVM classes, build scripts and tests
are present. Actual elaboration requires a UVM-capable simulator and library.
"""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
UVM = ROOT / "tb" / "uvm"
required = {
 "pcie_g6_if.sv": ["interface pcie_g6_if", "phy_rx_flit_ready"],
 "pcie_g6_types.svh": ["class pcie_tx_item", "class pcie_rx_item", "class pcie_g6_vectors"],
 "pcie_g6_agents.svh": ["class pcie_tx_agent", "class pcie_rx_agent", "class pcie_link_agent", "class pcie_csr_agent", "class pcie_bus_monitor"],
 "pcie_g6_scoreboard.svh": ["class pcie_g6_scoreboard", "covergroup traffic_cg", "write_tx_expected", "write_rx_expected"],
 "pcie_g6_sequences.svh": ["class pcie_g6_virtual_seq", "class pcie_g6_virtual_sequencer"],
 "pcie_g6_env.svh": ["class pcie_g6_env", "accepted_ap.connect", "observed_ap.connect"],
 "pcie_g6_tests.svh": ["class pcie_g6_smoke_test", "class pcie_g6_random_test", "class pcie_g6_negative_test", "class pcie_g6_linkloss_test", "class pcie_g6_width_test", "class pcie_g6_backpressure_test"],
 "pcie_g6_pkg.sv": ["import uvm_pkg::*", '`include "uvm_macros.svh"'],
 "pcie_g6_sva.sv": ["assert property", "module pcie_g6_sva"],
 "pcie_g6_tb_top.sv": ["pcie_gen6_controller_top dut", "run_test"],
}
for rel, needles in required.items():
    s=(UVM/rel).read_text()
    for needle in needles:
        assert needle in s, f"{rel}: missing {needle}"
for rel in ("tb/scripts/run_uvm.sh", "tb/uvm/uvm_sources.f", "tb/uvm/README.md"):
    assert (ROOT/rel).is_file(), f"missing {rel}"
print("PASS: UVM class/agent/test hierarchy and required files present")
print("NOTE: this check is NOT a SystemVerilog compilation or UVM simulation")
