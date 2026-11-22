/*
 * pcie_g6_agents.svh -- actively driven TX, RX, link and CSR UVM agents.
 * Each active agent contains a sequencer and driver; the independent passive
 * protocol monitor observes only the DUT pins and publishes transactions.
 * Handshake contracts: present data on negedge; accept only at posedge when
 * valid and ready. Watchdogs prevent deadlocked tests silently succeeding.
 * NOTE: This is for the current abstract-FLIT RTL, not full PCIe link VIP.
 */
`ifndef PCIE_G6_AGENTS_SVH
`define PCIE_G6_AGENTS_SVH
class pcie_tx_sequencer extends uvm_sequencer #(pcie_tx_item);
  `uvm_component_utils(pcie_tx_sequencer)
  function new(string n,uvm_component p); super.new(n,p); endfunction
endclass
class pcie_rx_sequencer extends uvm_sequencer #(pcie_rx_item);
  `uvm_component_utils(pcie_rx_sequencer)
  function new(string n,uvm_component p); super.new(n,p); endfunction
endclass
class pcie_link_sequencer extends uvm_sequencer #(pcie_link_item);
  `uvm_component_utils(pcie_link_sequencer)
  function new(string n,uvm_component p); super.new(n,p); endfunction
endclass
class pcie_csr_sequencer extends uvm_sequencer #(pcie_csr_item);
  `uvm_component_utils(pcie_csr_sequencer)
  function new(string n,uvm_component p); super.new(n,p); endfunction
endclass

class pcie_tx_driver extends uvm_driver #(pcie_tx_item);
  `uvm_component_utils(pcie_tx_driver)
  virtual pcie_g6_if vif;
  uvm_analysis_port #(pcie_tx_item) accepted_ap;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual pcie_g6_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","TX vif missing")
    accepted_ap=new("accepted_ap",this);
  endfunction
  task run_phase(uvm_phase phase);
    pcie_tx_item req;
    int n;
    vif.tx_tlp_valid=0;
    forever begin
      seq_item_port.get_next_item(req);
      @(negedge vif.clk);
      vif.tx_tlp_bytes=req.data;
      vif.tx_tlp_dw_count=req.dw;
      vif.tx_dlp=req.dlp;
      vif.tx_tlp_valid=1;
      n=0;
      if(req.illegal) begin
        #1;
        if(!vif.tx_length_error || vif.tx_tlp_ready)
          `uvm_error("ILLEGAL","Malformed length unexpectedly accepted")
        @(negedge vif.clk); vif.tx_tlp_valid=0;
      end else begin
        do begin
          @(posedge vif.clk);
          n++;
          if(n>250) `uvm_fatal("TXWD","TX handshake timeout")
        end while(!vif.tx_tlp_ready);
        // Driver expectation is independent of observed PHY output.
        accepted_ap.write(req);
        @(negedge vif.clk); vif.tx_tlp_valid=0;
      end
      seq_item_port.item_done();
    end
  endtask
endclass

class pcie_rx_driver extends uvm_driver #(pcie_rx_item);
  `uvm_component_utils(pcie_rx_driver)
  virtual pcie_g6_if vif;
  uvm_analysis_port #(pcie_rx_item) accepted_ap;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual pcie_g6_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","RX vif missing")
    accepted_ap=new("accepted_ap",this);
  endfunction
  task run_phase(uvm_phase phase);
    pcie_rx_item req;
    int n;
    vif.phy_rx_flit_valid=0;
    forever begin
      seq_item_port.get_next_item(req);
      @(negedge vif.clk);
      vif.phy_rx_flit=req.flit;
      vif.phy_rx_flit_valid=1;
      n=0;
      do begin
        @(posedge vif.clk);
        n++;
        if(n>250) `uvm_fatal("RXWD","RX handshake timeout")
      end while(!vif.phy_rx_flit_ready);
      accepted_ap.write(req);
      @(negedge vif.clk); vif.phy_rx_flit_valid=0;
      seq_item_port.item_done();
    end
  endtask
endclass

class pcie_link_driver extends uvm_driver #(pcie_link_item);
  `uvm_component_utils(pcie_link_driver)
  virtual pcie_g6_if vif;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual pcie_g6_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","link vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    pcie_link_item req;
    forever begin
      seq_item_port.get_next_item(req);
      @(negedge vif.clk);
      vif.phy_l0=req.l0;
      vif.phy_flit_enabled=req.flit_mode;
      vif.phy_gen=req.gen;
      vif.phy_width=req.width;
      vif.phy_tx_flit_ready=req.tx_ready;
      vif.rx_tlp_area_ready=req.rx_ready;
      repeat(req.hold_cycles) @(posedge vif.clk);
      seq_item_port.item_done();
    end
  endtask
endclass

class pcie_csr_driver extends uvm_driver #(pcie_csr_item);
  `uvm_component_utils(pcie_csr_driver)
  virtual pcie_g6_if vif;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual pcie_g6_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","CSR vif missing")
  endfunction
  task run_phase(uvm_phase phase);
    pcie_csr_item req;
    vif.csr_rd_en=0; vif.csr_wr_en=0;
    forever begin
      seq_item_port.get_next_item(req);
      @(negedge vif.clk);
      vif.csr_addr=req.addr;
      vif.csr_wdata=req.data;
      vif.csr_wr_en=req.write_en;
      vif.csr_rd_en=!req.write_en;
      @(posedge vif.clk); #1;
      if(!req.write_en && req.check_read &&
         (!vif.csr_rvalid || vif.csr_rdata !== req.expected))
        `uvm_error("CSR",$sformatf("Read %02h: got %08h expected %08h",req.addr,vif.csr_rdata,req.expected))
      @(negedge vif.clk);
      vif.csr_rd_en=0; vif.csr_wr_en=0;
      seq_item_port.item_done();
    end
  endtask
endclass

class pcie_tx_agent extends uvm_agent;
  `uvm_component_utils(pcie_tx_agent)
  pcie_tx_sequencer sqr;
  pcie_tx_driver drv;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr=pcie_tx_sequencer::type_id::create("sqr",this);
    drv=pcie_tx_driver::type_id::create("drv",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
class pcie_rx_agent extends uvm_agent;
  `uvm_component_utils(pcie_rx_agent)
  pcie_rx_sequencer sqr;
  pcie_rx_driver drv;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr=pcie_rx_sequencer::type_id::create("sqr",this);
    drv=pcie_rx_driver::type_id::create("drv",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
class pcie_link_agent extends uvm_agent;
  `uvm_component_utils(pcie_link_agent)
  pcie_link_sequencer sqr;
  pcie_link_driver drv;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr=pcie_link_sequencer::type_id::create("sqr",this);
    drv=pcie_link_driver::type_id::create("drv",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass
class pcie_csr_agent extends uvm_agent;
  `uvm_component_utils(pcie_csr_agent)
  pcie_csr_sequencer sqr;
  pcie_csr_driver drv;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr=pcie_csr_sequencer::type_id::create("sqr",this);
    drv=pcie_csr_driver::type_id::create("drv",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass

class pcie_bus_monitor extends uvm_monitor;
  `uvm_component_utils(pcie_bus_monitor)
  virtual pcie_g6_if vif;
  uvm_analysis_port #(pcie_obs) observed_ap;
  bit was_link_ready=0;
  function new(string n,uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual pcie_g6_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","monitor vif missing")
    observed_ap=new("observed_ap",this);
  endfunction
  function void publish(pcie_obs_kind_e k,bit [2047:0] flit='0,
                        bit [1887:0] tlp='0,bit [47:0] dlp='0);
    pcie_obs t=pcie_obs::type_id::create("event");
    t.kind=k; t.flit=flit; t.tlp=tlp; t.dlp=dlp;
    observed_ap.write(t);
  endfunction
  task run_phase(uvm_phase phase);
    fork
      forever begin
        @(posedge vif.clk);
        if(vif.rst_n) begin
          if(vif.phy_tx_flit_valid && vif.phy_tx_flit_ready)
            publish(TX_PHY_EMIT,vif.phy_tx_flit);
          if(vif.rx_tlp_area_valid && vif.rx_tlp_area_ready)
            publish(RX_TL_DELIVER,'0,vif.rx_tlp_area,vif.rx_dlp);
        end
      end
      forever begin
        @(negedge vif.clk);
        if(vif.rst_n) begin
          if(was_link_ready && !vif.flit_link_ready) publish(LINK_DOWN);
          was_link_ready=vif.flit_link_ready;
          if(vif.rx_fec_corrected_pulse) publish(RX_CORRECT);
          if(vif.rx_drop_pulse) publish(RX_DROP);
        end else was_link_ready=0;
      end
    join
  endtask
endclass
`endif
