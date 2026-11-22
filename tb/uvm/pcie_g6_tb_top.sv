/*
 * pcie_g6_tb_top.sv -- runnable UVM harness for the existing controller_top.
 * Clock/reset generation, typed interface, complete named-port DUT hookup,
 * config_db injection and run_test are confined to this integration module.
 * Test classes cannot directly drive RTL internals; they use UVM agents.
 * IMPORTANT: PHY status is supplied by the test; no LTSSM/PIPE model exists.
 */
`timescale 1ns/1ps
module pcie_g6_tb_top;
  import uvm_pkg::*;
  import pcie_g6_pkg::*;
  bit clk=0;
  always #5 clk=~clk;
  pcie_g6_if pif(clk);

  pcie_gen6_controller_top dut (
    .clk(pif.clk),.rst_n(pif.rst_n),
    .phy_l0(pif.phy_l0),.phy_flit_enabled(pif.phy_flit_enabled),
    .phy_gen(pif.phy_gen),.phy_width(pif.phy_width),
    .flit_link_ready(pif.flit_link_ready),
    .unsupported_nonflit(pif.unsupported_nonflit),
    .invalid_negotiation(pif.invalid_negotiation),
    .csr_rd_en(pif.csr_rd_en),.csr_wr_en(pif.csr_wr_en),
    .csr_addr(pif.csr_addr),.csr_wdata(pif.csr_wdata),
    .csr_rdata(pif.csr_rdata),.csr_rvalid(pif.csr_rvalid),
    .tx_tlp_valid(pif.tx_tlp_valid),.tx_tlp_ready(pif.tx_tlp_ready),
    .tx_tlp_bytes(pif.tx_tlp_bytes),.tx_tlp_dw_count(pif.tx_tlp_dw_count),
    .tx_dlp(pif.tx_dlp),.tx_length_error(pif.tx_length_error),
    .phy_tx_flit_valid(pif.phy_tx_flit_valid),
    .phy_tx_flit_ready(pif.phy_tx_flit_ready),
    .phy_tx_flit(pif.phy_tx_flit),
    .phy_rx_flit_valid(pif.phy_rx_flit_valid),
    .phy_rx_flit_ready(pif.phy_rx_flit_ready),
    .phy_rx_flit(pif.phy_rx_flit),
    .rx_tlp_area_valid(pif.rx_tlp_area_valid),
    .rx_tlp_area_ready(pif.rx_tlp_area_ready),
    .rx_tlp_area(pif.rx_tlp_area),.rx_dlp(pif.rx_dlp),
    .rx_drop_pulse(pif.rx_drop_pulse),
    .rx_fec_corrected_pulse(pif.rx_fec_corrected_pulse),
    .rx_crc_error_count(pif.rx_crc_error_count)
  );

  pcie_g6_sva assertions (pif);

  initial begin
    pif.rst_n=0;
    pif.phy_l0=0;pif.phy_flit_enabled=0;
    pif.phy_gen=6;pif.phy_width=4;
    pif.csr_rd_en=0;pif.csr_wr_en=0;pif.csr_addr=0;pif.csr_wdata=0;
    pif.tx_tlp_valid=0;pif.tx_tlp_bytes='0;pif.tx_tlp_dw_count=0;pif.tx_dlp='0;
    pif.phy_tx_flit_ready=0;pif.phy_rx_flit_valid=0;
    pif.phy_rx_flit='0;pif.rx_tlp_area_ready=0;
    repeat(5) @(negedge clk);
    pif.rst_n=1;
  end
  initial begin
    uvm_config_db#(virtual pcie_g6_if)::set(null,"*","vif",pif);
    begin
      string test_name="pcie_g6_smoke_test";
      void'($value$plusargs("UVM_TESTNAME=%s",test_name));
      run_test(test_name);
    end
  end
  initial begin
    #1000000ns;
    $fatal(1,"UVM harness watchdog timeout");
  end
endmodule
