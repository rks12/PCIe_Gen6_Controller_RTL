/*
 * pcie_gen6_controller_top.sv -- working GEN6 FLIT DATAPATH FOUNDATION.
 *
 * PORT CONTRACT:
 *   External PHY/LTSSM provides L0, negotiated FLIT mode, gen and width.
 *   Input TLP bus carries ONE COMPLETE 4-byte-aligned, already encoded
 *   PCIe FLIT-mode TLP of 1..59 DWs. This module pads the rest with NOPs.
 *   The six DLP bytes MUST be supplied as valid protocol bytes by caller.
 *   Output to PHY is a full 256-byte encoded FLIT on ready/valid interface.
 *   Input from PHY is one full FLIT. Valid RX outputs are corrected 236-byte
 *   TLP region + 6 DLP bytes. RX drops corrupt FLITs and counts them.
 *
 * PURPOSE:
 *   Compose the verified mathematical CRC/FEC building blocks with
 *   transfer-safe holding registers, link guard, and engineering CSRs.
 *
 * IMPORTANT LIMITATION:
 *   This module is NOT a full PCIe Gen1..Gen6 Endpoint IP. It has no
 *   physical ordered sets, LTSSM, PCIe FC initialization, full FM TLP
 *   parsing, FLIT sequence/ACK-NAK handshake/retry, config space, DMA,
 *   power management, MSI-X, legacy link or actual PHY. The PHY interface
 *   is an abstract full-FLIT bus, NOT PIPE or a SerDes pin-level protocol.
 *   See README.md and docs/FEATURE_MATRIX.md before integration.
 */
module pcie_gen6_controller_top (
  input logic clk,rst_n,
  /* External PHY and link-training status. */
  input logic phy_l0,
  input logic phy_flit_enabled,
  input logic [2:0] phy_gen,
  input logic [4:0] phy_width,
  output logic flit_link_ready,
  output logic unsupported_nonflit,
  output logic invalid_negotiation,
  /* Local engineering CSR port. */
  input logic csr_rd_en,csr_wr_en,
  input logic [7:0] csr_addr,
  input logic [31:0] csr_wdata,
  output logic [31:0] csr_rdata,
  output logic csr_rvalid,
  /* One complete, preformatted FM TLP (1..59 DW), packed from byte 0. */
  input logic tx_tlp_valid,
  output logic tx_tlp_ready,
  input logic [1887:0] tx_tlp_bytes,
  input logic [5:0] tx_tlp_dw_count,
  input logic [47:0] tx_dlp,
  output logic tx_length_error,
  /* Abstract PHY TX full FLIT. */
  output logic phy_tx_flit_valid,
  input logic phy_tx_flit_ready,
  output logic [2047:0] phy_tx_flit,
  /* Abstract PHY RX full FLIT. */
  input logic phy_rx_flit_valid,
  output logic phy_rx_flit_ready,
  input logic [2047:0] phy_rx_flit,
  /* Corrected RX region; TLP parsing is a separate missing stage. */
  output logic rx_tlp_area_valid,
  input logic rx_tlp_area_ready,
  output logic [1887:0] rx_tlp_area,
  output logic [47:0] rx_dlp,
  output logic rx_drop_pulse,
  output logic rx_fec_corrected_pulse,
  output logic [31:0] rx_crc_error_count
);
  logic [1887:0] padded_tlp;
  logic bad_len;
  logic tx_pipe_ready;
  logic rx_pipe_ready;
  logic phy_tx_flit_valid_raw, rx_tlp_area_valid_raw;

  pcie_link_guard u_link_guard (
    .phy_l0(phy_l0),.phy_flit_enabled(phy_flit_enabled),
    .phy_gen(phy_gen),.phy_width(phy_width),
    .flit_link_ready(flit_link_ready),
    .unsupported_nonflit(unsupported_nonflit),
    .invalid_negotiation(invalid_negotiation)
  );

  pcie_flit_tlp_packer u_packer (
    .tlp_bytes(tx_tlp_bytes),.tlp_dw_count(tx_tlp_dw_count),
    .packed_tlp(padded_tlp),.invalid_length(bad_len)
  );
  assign tx_length_error=tx_tlp_valid && bad_len;
  assign tx_tlp_ready=flit_link_ready && !bad_len && tx_pipe_ready;
  pcie_flit_tx_pipe u_tx (
    .clk(clk),.rst_n(rst_n),.flush(!flit_link_ready),
    .in_valid(tx_tlp_valid && tx_tlp_ready),.in_ready(tx_pipe_ready),
    .in_tlp(padded_tlp),.in_dlp(tx_dlp),
    .out_valid(phy_tx_flit_valid_raw),.out_ready(phy_tx_flit_ready && flit_link_ready),
    .out_flit(phy_tx_flit)
  );

  /* The PHY must never see a buffered frame after link-down.
   * The synchronous pipe flush invalidates it on the next clk edge. */
  assign phy_tx_flit_valid=phy_tx_flit_valid_raw && flit_link_ready;
  assign rx_tlp_area_valid=rx_tlp_area_valid_raw && flit_link_ready;
  /* RX side must not advertise acceptance before link and RX buffer ready. */
  assign phy_rx_flit_ready=flit_link_ready && rx_pipe_ready;
  pcie_flit_rx_pipe u_rx (
    .clk(clk),.rst_n(rst_n),.flush(!flit_link_ready),
    .in_valid(phy_rx_flit_valid && phy_rx_flit_ready),
    .in_ready(rx_pipe_ready),.in_flit(phy_rx_flit),
    .out_valid(rx_tlp_area_valid_raw),.out_ready(rx_tlp_area_ready && flit_link_ready),
    .out_tlp(rx_tlp_area),.out_dlp(rx_dlp),
    .drop_pulse(rx_drop_pulse),
    .fec_corrected_pulse(rx_fec_corrected_pulse),
    .crc_error_count(rx_crc_error_count)
  );
  pcie_register_bank u_registers (
    .clk(clk),.rst_n(rst_n),
    .csr_rd_en(csr_rd_en),.csr_wr_en(csr_wr_en),
    .csr_addr(csr_addr),.csr_wdata(csr_wdata),
    .csr_rdata(csr_rdata),.csr_rvalid(csr_rvalid),
    .link_ready(flit_link_ready),.phy_l0(phy_l0),
    .flit_enabled(phy_flit_enabled),.phy_gen(phy_gen),
    .phy_width(phy_width),.drop_count(rx_crc_error_count),
    .unsupported_nonflit(unsupported_nonflit),
    .invalid_negotiation(invalid_negotiation)
  );
endmodule
