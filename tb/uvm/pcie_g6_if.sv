/*
 * pcie_g6_if.sv -- testbench-side pin-level bundle for the existing prototype.
 * PURPOSE: unify the DUT's FLIT, CSR, link-status and ready/valid signals.
 * The PHY signals here are abstract 256-byte transfers, not PCIe PIPE/PAM4.
 * Drivers place stimulus on falling clock edges, monitors sample handshakes
 * on rising edges. This intentionally does not pretend to be a Root Port BFM.
 */
`timescale 1ns/1ps
interface pcie_g6_if(input logic clk);
  logic rst_n;
  logic phy_l0, phy_flit_enabled;
  logic [2:0] phy_gen;
  logic [4:0] phy_width;
  logic flit_link_ready, unsupported_nonflit, invalid_negotiation;
  logic csr_rd_en, csr_wr_en;
  logic [7:0] csr_addr;
  logic [31:0] csr_wdata, csr_rdata;
  logic csr_rvalid;
  logic tx_tlp_valid, tx_tlp_ready;
  logic [1887:0] tx_tlp_bytes;
  logic [5:0] tx_tlp_dw_count;
  logic [47:0] tx_dlp;
  logic tx_length_error;
  logic phy_tx_flit_valid, phy_tx_flit_ready;
  logic [2047:0] phy_tx_flit;
  logic phy_rx_flit_valid, phy_rx_flit_ready;
  logic [2047:0] phy_rx_flit;
  logic rx_tlp_area_valid, rx_tlp_area_ready;
  logic [1887:0] rx_tlp_area;
  logic [47:0] rx_dlp;
  logic rx_drop_pulse, rx_fec_corrected_pulse;
  logic [31:0] rx_crc_error_count;
endinterface
