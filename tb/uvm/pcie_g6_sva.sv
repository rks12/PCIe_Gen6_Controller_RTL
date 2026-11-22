/*
 * pcie_g6_sva.sv -- concurrent link/handshake safety assertions.
 * PURPOSE: detect output instability while stalled, invalid Gen6 non-FLIT
 * readiness, invalid input length acceptance, and RX output after link-down.
 * Assertions do not model PCIe 6.0 link training, replay or TLP semantics.
 * The assertions bind to top-level abstract handshake pins in the harness.
 */
`timescale 1ns/1ps
module pcie_g6_sva(pcie_g6_if pif);
  property p_tx_stable;
    @(posedge pif.clk) disable iff (!pif.rst_n)
    (pif.phy_tx_flit_valid && !pif.phy_tx_flit_ready && pif.flit_link_ready)
       |=> (!pif.flit_link_ready || (pif.phy_tx_flit_valid && $stable(pif.phy_tx_flit)));
  endproperty
  property p_rx_stable;
    @(posedge pif.clk) disable iff (!pif.rst_n)
    (pif.rx_tlp_area_valid && !pif.rx_tlp_area_ready && pif.flit_link_ready)
       |=> (!pif.flit_link_ready || (pif.rx_tlp_area_valid &&
                $stable(pif.rx_tlp_area) && $stable(pif.rx_dlp)));
  endproperty
  property p_invalid_length;
    @(posedge pif.clk) disable iff (!pif.rst_n)
    (pif.tx_tlp_valid && (pif.tx_tlp_dw_count==0 || pif.tx_tlp_dw_count>59))
       |-> (pif.tx_length_error && !pif.tx_tlp_ready);
  endproperty
  property p_no_gen6_nonflit;
    @(posedge pif.clk) disable iff (!pif.rst_n)
    (pif.phy_gen==6 && !pif.phy_flit_enabled) |-> !pif.flit_link_ready;
  endproperty
  property p_no_outside_l0;
    @(posedge pif.clk) disable iff (!pif.rst_n)
    (!pif.flit_link_ready) |-> (!pif.phy_tx_flit_valid && !pif.rx_tlp_area_valid);
  endproperty
  a_tx_stable: assert property(p_tx_stable) else $error("TX output not stable under backpressure");
  a_rx_stable: assert property(p_rx_stable) else $error("RX output not stable under backpressure");
  a_invalid_length: assert property(p_invalid_length) else $error("Invalid TLP length accepted");
  a_no_gen6_nonflit: assert property(p_no_gen6_nonflit) else $error("Gen6 non-FLIT active");
  a_no_outside_l0: assert property(p_no_outside_l0) else $error("Output valid while link inactive");
endmodule
