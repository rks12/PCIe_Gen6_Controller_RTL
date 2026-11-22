/*
 * pcie_g6_tests.svh -- UVM test matrix for present G1 RTL functionality.
 * Tests: smoke (codec/CSR), constrained-index random stress, negative guard,
 * bad-length filtering, reset/link-down buffer flushing and boundary widths.
 * Coverage closure for a complete PCIe protocol is explicitly NOT implied.
 */
`ifndef PCIE_G6_TESTS_SVH
`define PCIE_G6_TESTS_SVH
class pcie_g6_base_test extends uvm_test;
  `uvm_component_utils(pcie_g6_base_test)
  pcie_g6_env env;
  pcie_g6_vectors vectors;
  virtual pcie_g6_if vif;
  string vector_dir="build/tb/vectors";
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual pcie_g6_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","No DUT interface configured")
    void'($value$plusargs("PCIE_VECTORS_DIR=%s",vector_dir));
    vectors=pcie_g6_vectors::type_id::create("vectors");
    vectors.load(vector_dir);
    uvm_config_db#(pcie_g6_vectors)::set(this,"env.scoreboard","vectors",vectors);
    env=pcie_g6_env::type_id::create("env",this);
  endfunction
  task wait_reset();
    wait(vif.rst_n === 1'b1);
    repeat(2) @(posedge vif.clk);
  endtask
  task guard_check(bit expected_ready,string description);
    #1;
    if(vif.flit_link_ready!==expected_ready)
      `uvm_error("GUARD",$sformatf("%s expected=%b actual=%b",description,expected_ready,vif.flit_link_ready))
  endtask
endclass

class pcie_g6_smoke_test extends pcie_g6_base_test;
  `uvm_component_utils(pcie_g6_smoke_test)
  function new(string n,uvm_component p); super.new(n,p); endfunction
  task run_phase(uvm_phase phase);
    pcie_g6_virtual_seq s;
    phase.raise_objection(this);
    wait_reset();
    s=pcie_g6_virtual_seq::type_id::create("smoke_vseq");
    s.vectors=vectors;s.rounds=16;
    s.start(env.virtual_sqr);
    guard_check(1,"Gen6 x4 FLIT L0");
    phase.drop_objection(this);
  endtask
endclass

class pcie_g6_random_test extends pcie_g6_base_test;
  `uvm_component_utils(pcie_g6_random_test)
  function new(string n,uvm_component p); super.new(n,p); endfunction
  task run_phase(uvm_phase phase);
    pcie_g6_virtual_seq s;
    phase.raise_objection(this);
    wait_reset();
    s=pcie_g6_virtual_seq::type_id::create("random_vseq");
    s.vectors=vectors;s.rounds=96;s.random_mode=1;
    s.start(env.virtual_sqr);
    phase.drop_objection(this);
  endtask
endclass

class pcie_g6_negative_test extends pcie_g6_base_test;
  `uvm_component_utils(pcie_g6_negative_test)
  function new(string n,uvm_component p); super.new(n,p); endfunction
  task run_phase(uvm_phase phase);
    pcie_g6_virtual_seq s;
    phase.raise_objection(this);
    wait_reset();
    s=pcie_g6_virtual_seq::type_id::create("negative_vseq");
    s.vectors=vectors;
    s.set_link(1,1,6,4); guard_check(1,"valid link");
    s.tx_one(0,1,0);
    s.tx_one(0,1,60);
    s.tx_one(0,1,63);
    s.set_link(1,0,6,4);guard_check(0,"Gen6 must be FLIT");
    s.set_link(1,1,6,3);guard_check(0,"invalid width 3");
    s.set_link(1,1,0,4);guard_check(0,"invalid Gen0");
    s.set_link(1,1,7,4);guard_check(0,"invalid Gen7");
    s.set_link(1,0,5,4);guard_check(0,"non-FLIT currently unsupported");
    s.set_link(1,1,6,4);guard_check(1,"recovery after invalid settings");
    #50ns;
    phase.drop_objection(this);
  endtask
endclass

class pcie_g6_linkloss_test extends pcie_g6_base_test;
  `uvm_component_utils(pcie_g6_linkloss_test)
  function new(string n,uvm_component p); super.new(n,p); endfunction
  task run_phase(uvm_phase phase);
    pcie_g6_virtual_seq s;
    phase.raise_objection(this);
    wait_reset();
    s=pcie_g6_virtual_seq::type_id::create("linkloss_vseq");s.vectors=vectors;
    // Stall both consumer ports, then enqueue exactly one frame each.
    s.set_link(1,1,6,4,0,0);
    s.tx_one(1);
    s.rx_one(2,0);
    s.set_link(0,1,6,4,0,0,3);guard_check(0,"link disabled");
    s.set_link(1,1,6,4,1,1,4);guard_check(1,"link reenabled");
    if(vif.phy_tx_flit_valid || vif.rx_tlp_area_valid)
      `uvm_error("STALE","Buffered data survived link-down epoch")
    // Reuse link after a flush to ensure new packets still work.
    s.tx_one(2);s.rx_one(2,1);
    #100ns;
    phase.drop_objection(this);
  endtask
endclass

class pcie_g6_width_test extends pcie_g6_base_test;
  `uvm_component_utils(pcie_g6_width_test)
  function new(string n,uvm_component p); super.new(n,p); endfunction
  task run_phase(uvm_phase phase);
    pcie_g6_virtual_seq s;
    bit [4:0] widths[5]='{1,2,4,8,16};
    phase.raise_objection(this);
    wait_reset();
    s=pcie_g6_virtual_seq::type_id::create("width_vseq");s.vectors=vectors;
    for(int gen=1;gen<=6;gen++) begin
      foreach(widths[i]) begin
        s.set_link(1,1,3'(gen),widths[i]);
        guard_check(1,$sformatf("gen=%0d width=%0d",gen,widths[i]));
        s.tx_one((gen+i)%8);
        s.rx_one((gen+i)%8,0);
      end
    end
    #50ns;
    phase.drop_objection(this);
  endtask
endclass
`endif
