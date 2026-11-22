/*
 * pcie_g6_types.svh -- UVM sequence items and immutable golden-vector bank.
 * PURPOSE: carry independent model expectations through sequencer, driver,
 * monitor and scoreboard. No UVM integer field macro is used on >64-bit busses.
 * Golden vectors are created by Python (separate algorithm) and read with
 * $readmemh; this avoids testing the DUT solely against its own decoder.
 */
`ifndef PCIE_G6_TYPES_SVH
`define PCIE_G6_TYPES_SVH

class pcie_g6_vectors extends uvm_object;
  `uvm_object_utils(pcie_g6_vectors)
  localparam int N = 8;
  bit [2047:0] golden[0:N-1];
  bit [1887:0] raw[0:N-1];
  bit [47:0] dlp[0:N-1];
  bit [5:0] dw[0:N-1];
  function new(string name="pcie_g6_vectors"); super.new(name); endfunction
  function void load(string dir="build/tb/vectors");
    $readmemh({dir,"/golden_flits.hex"}, golden);
    $readmemh({dir,"/raw_tlps.hex"}, raw);
    $readmemh({dir,"/dlp.hex"}, dlp);
    $readmemh({dir,"/lengths.hex"}, dw);
    if(dw[0]==0 || dw[5]!=59)
      `uvm_fatal("VECTORS", {"Golden vectors absent/invalid in ",dir})
  endfunction
endclass

class pcie_tx_item extends uvm_sequence_item;
  `uvm_object_utils(pcie_tx_item)
  int unsigned index;
  bit [1887:0] data;
  bit [5:0] dw;
  bit [47:0] dlp;
  bit illegal;
  function new(string name="pcie_tx_item"); super.new(name); endfunction
endclass

class pcie_rx_item extends uvm_sequence_item;
  `uvm_object_utils(pcie_rx_item)
  int unsigned index;
  bit [2047:0] flit;
  // 0: clean; 1: one-byte correctable corruption; 2: uncorrectable 2-byte
  int unsigned corruption;
  function new(string name="pcie_rx_item"); super.new(name); endfunction
endclass

class pcie_link_item extends uvm_sequence_item;
  `uvm_object_utils(pcie_link_item)
  bit l0=1, flit_mode=1;
  bit [2:0] gen=6;
  bit [4:0] width=4;
  bit tx_ready=1, rx_ready=1;
  int unsigned hold_cycles=2;
  function new(string name="pcie_link_item"); super.new(name); endfunction
endclass

class pcie_csr_item extends uvm_sequence_item;
  `uvm_object_utils(pcie_csr_item)
  bit write_en;
  bit [7:0] addr;
  bit [31:0] data;
  bit [31:0] expected;
  bit check_read=1;
  function new(string name="pcie_csr_item"); super.new(name); endfunction
endclass

typedef enum int { TX_PHY_EMIT, RX_TL_DELIVER, RX_DROP, RX_CORRECT, LINK_DOWN } pcie_obs_kind_e;
class pcie_obs extends uvm_sequence_item;
  `uvm_object_utils(pcie_obs)
  pcie_obs_kind_e kind;
  bit [2047:0] flit;
  bit [1887:0] tlp;
  bit [47:0] dlp;
  function new(string name="pcie_obs"); super.new(name); endfunction
endclass
`endif
