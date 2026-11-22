/*
 * pcie_g6_pkg.sv -- ordered aggregation of all testbench UVM components.
 * Build order: transaction types, agents, scoreboard and coverage,
 * reusable sequences, environment/virtual sequencer, and tests.
 * Supported Accellera IEEE 1800.2 UVM libraries are provided by simulator.
 */
`timescale 1ns/1ps
package pcie_g6_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "pcie_g6_types.svh"
  `include "pcie_g6_agents.svh"
  `include "pcie_g6_scoreboard.svh"
  `include "pcie_g6_sequences.svh"
  `include "pcie_g6_env.svh"
  `include "pcie_g6_tests.svh"
endpackage
