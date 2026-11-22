/*
 * pcie_g6_env.svh -- reusable PCIe G6 prototype UVM verification environment.
 * Four active stimulus agents (host TX, external FLIT RX, link config and CSR),
 * one independent pin monitor, scoreboard, coverage and virtual sequencer.
 * The model reference is supplied by the test, not copied from the DUT.
 */
`ifndef PCIE_G6_ENV_SVH
`define PCIE_G6_ENV_SVH
class pcie_g6_env extends uvm_env;
  `uvm_component_utils(pcie_g6_env)
  pcie_tx_agent tx_agent;
  pcie_rx_agent rx_agent;
  pcie_link_agent link_agent;
  pcie_csr_agent csr_agent;
  pcie_bus_monitor bus_monitor;
  pcie_g6_scoreboard scoreboard;
  pcie_g6_virtual_sequencer virtual_sqr;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_agent=pcie_tx_agent::type_id::create("tx_agent",this);
    rx_agent=pcie_rx_agent::type_id::create("rx_agent",this);
    link_agent=pcie_link_agent::type_id::create("link_agent",this);
    csr_agent=pcie_csr_agent::type_id::create("csr_agent",this);
    bus_monitor=pcie_bus_monitor::type_id::create("bus_monitor",this);
    scoreboard=pcie_g6_scoreboard::type_id::create("scoreboard",this);
    virtual_sqr=pcie_g6_virtual_sequencer::type_id::create("virtual_sqr",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    tx_agent.drv.accepted_ap.connect(scoreboard.tx_exp_imp);
    rx_agent.drv.accepted_ap.connect(scoreboard.rx_exp_imp);
    bus_monitor.observed_ap.connect(scoreboard.obs_imp);
    virtual_sqr.tx_sqr=tx_agent.sqr;
    virtual_sqr.rx_sqr=rx_agent.sqr;
    virtual_sqr.link_sqr=link_agent.sqr;
    virtual_sqr.csr_sqr=csr_agent.sqr;
  endfunction
endclass
`endif
