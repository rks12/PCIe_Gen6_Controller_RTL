/*
 * pcie_g6_sequences.svh -- re-usable UVM traffic, corruption and CSR sequences.
 * Traffic is deterministic given Python vector seed; the random regression
 * selects among externally computed goldens rather than predicting its own
 * results using DUT functions. Each sequence sends exactly one transaction.
 * The virtual sequencer ties the four active agents together, permitting
 * high-level scenario scripts without driving the DUT from test classes.
 */
`ifndef PCIE_G6_SEQUENCES_SVH
`define PCIE_G6_SEQUENCES_SVH
class pcie_tx_vector_seq extends uvm_sequence #(pcie_tx_item);
  `uvm_object_utils(pcie_tx_vector_seq)
  pcie_g6_vectors vectors;
  int unsigned index=0;
  bit illegal=0;
  bit [5:0] illegal_dw=0;
  function new(string n="pcie_tx_vector_seq"); super.new(n); endfunction
  task body();
    pcie_tx_item req=pcie_tx_item::type_id::create("tx_req");
    if(index>=8) `uvm_fatal("BADINDEX","TX vector index out of bounds")
    start_item(req);
    req.index=index; req.data=vectors.raw[index];
    req.dw=illegal?illegal_dw:vectors.dw[index];
    req.dlp=vectors.dlp[index]; req.illegal=illegal;
    finish_item(req);
  endtask
endclass

class pcie_rx_vector_seq extends uvm_sequence #(pcie_rx_item);
  `uvm_object_utils(pcie_rx_vector_seq)
  pcie_g6_vectors vectors;
  int unsigned index=0;
  int unsigned corruption=0;
  function new(string n="pcie_rx_vector_seq"); super.new(n); endfunction
  task body();
    pcie_rx_item req=pcie_rx_item::type_id::create("rx_req");
    if(index>=8 || corruption>2) `uvm_fatal("BADINDEX","RX vector corruption/index out of bounds")
    start_item(req);
    req.index=index; req.corruption=corruption;
    req.flit=vectors.golden[index];
    if(corruption==1) req.flit[8*235 +:8]^=8'hA5;
    if(corruption==2) begin
      req.flit[8*0 +:8]^=8'h53;
      req.flit[8*3 +:8]^=8'hC1;
    end
    finish_item(req);
  endtask
endclass

class pcie_link_set_seq extends uvm_sequence #(pcie_link_item);
  `uvm_object_utils(pcie_link_set_seq)
  bit l0=1, flit_mode=1, tx_ready=1, rx_ready=1;
  bit [2:0] gen=6;
  bit [4:0] width=4;
  int unsigned cycles=2;
  function new(string n="pcie_link_set_seq"); super.new(n); endfunction
  task body();
    pcie_link_item req=pcie_link_item::type_id::create("link_req");
    start_item(req);
    req.l0=l0; req.flit_mode=flit_mode;
    req.gen=gen;req.width=width;
    req.tx_ready=tx_ready;req.rx_ready=rx_ready;
    req.hold_cycles=cycles;
    finish_item(req);
  endtask
endclass

class pcie_csr_op_seq extends uvm_sequence #(pcie_csr_item);
  `uvm_object_utils(pcie_csr_op_seq)
  bit wr=0;
  bit [7:0] addr=0;
  bit [31:0] data=0, expected=0;
  bit check_read=1;
  function new(string n="pcie_csr_op_seq"); super.new(n); endfunction
  task body();
    pcie_csr_item req=pcie_csr_item::type_id::create("csr_req");
    start_item(req);
    req.write_en=wr;req.addr=addr;req.data=data;
    req.expected=expected;req.check_read=check_read;
    finish_item(req);
  endtask
endclass

class pcie_g6_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(pcie_g6_virtual_sequencer)
  pcie_tx_sequencer tx_sqr;
  pcie_rx_sequencer rx_sqr;
  pcie_link_sequencer link_sqr;
  pcie_csr_sequencer csr_sqr;
  function new(string n,uvm_component p); super.new(n,p); endfunction
endclass

class pcie_g6_virtual_seq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(pcie_g6_virtual_seq)
  `uvm_declare_p_sequencer(pcie_g6_virtual_sequencer)
  pcie_g6_vectors vectors;
  int unsigned rounds=8;
  bit random_mode=0;
  function new(string n="pcie_g6_virtual_seq"); super.new(n); endfunction
  task set_link(bit l0=1, bit flit_mode=1, bit [2:0] gen=6,
                bit [4:0] width=4,bit tx_ready=1,bit rx_ready=1,int cycles=2);
    pcie_link_set_seq s=pcie_link_set_seq::type_id::create("link_seq");
    s.l0=l0;s.flit_mode=flit_mode;s.gen=gen;s.width=width;
    s.tx_ready=tx_ready;s.rx_ready=rx_ready;s.cycles=cycles;
    s.start(p_sequencer.link_sqr);
  endtask
  task tx_one(int unsigned index,bit illegal=0,bit [5:0] bad_dw=0);
    pcie_tx_vector_seq s=pcie_tx_vector_seq::type_id::create("tx_seq");
    s.vectors=vectors;s.index=index;s.illegal=illegal;s.illegal_dw=bad_dw;
    s.start(p_sequencer.tx_sqr);
  endtask
  task rx_one(int unsigned index,int unsigned corruption=0);
    pcie_rx_vector_seq s=pcie_rx_vector_seq::type_id::create("rx_seq");
    s.vectors=vectors;s.index=index;s.corruption=corruption;
    s.start(p_sequencer.rx_sqr);
  endtask
  task csr_op(bit wr,bit [7:0] addr,bit [31:0] data=0,
              bit [31:0] expected=0);
    pcie_csr_op_seq s=pcie_csr_op_seq::type_id::create("csr_seq");
    s.wr=wr;s.addr=addr;s.data=data;s.expected=expected;
    s.start(p_sequencer.csr_sqr);
  endtask

  task body();
    int idx, mode;
    set_link();
    csr_op(0,8'h00,0,32'h5043_4936);
    csr_op(0,8'h04,0,32'h0000_0200);
    csr_op(0,8'h18,0,32'h0000_001f);
    csr_op(1,8'h10,32'hA5C3_7E29);
    csr_op(0,8'h10,0,32'hA5C3_7E29);
    for(int i=0;i<int'(rounds);i++) begin
      idx=random_mode?$urandom_range(0,7):i%8;
      tx_one(idx);
      idx=random_mode?$urandom_range(0,7):i%8;
      mode=random_mode?$urandom_range(0,2):i%3;
      rx_one(idx,mode);
    end
    // Drain the one-deep TX and RX holding buffers before phase finishes.
    #100ns;
  endtask
endclass
`endif
