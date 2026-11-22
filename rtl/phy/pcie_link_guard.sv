/*
 * pcie_link_guard.sv -- validated interface to an EXTERNAL PCIe PHY/LTSSM.
 * PURPOSE: Prevent transfer when physical link training is incomplete,
 *          negotiation failed, or the current mode is unsupported by RTL.
 * FUNCTION: Check externally reported L0, speed, width and FLIT-mode
 *           negotiation. Gen6 (64 GT/s) can never use non-FLIT mode.
 * LIMIT: The actual PCIe LTSSM, ordered sets, equalization, scrambling,
 *        lane deskew, power states and analog PHY are NOT supplied here.
 */
module pcie_link_guard (
  input logic phy_l0,
  input logic phy_flit_enabled,
  input logic [2:0] phy_gen,       /* 1..6 */
  input logic [4:0] phy_width,     /* 1,2,4,8,16 */
  output logic flit_link_ready,
  output logic unsupported_nonflit,
  output logic invalid_negotiation
);
  logic speed_ok, width_ok;
  assign speed_ok=(phy_gen>=3'd1 && phy_gen<=3'd6);
  assign width_ok=(phy_width==5'd1 || phy_width==5'd2 ||
                   phy_width==5'd4 || phy_width==5'd8 ||
                   phy_width==5'd16);
  assign invalid_negotiation=phy_l0 &&
     (!speed_ok || !width_ok || (phy_gen==3'd6 && !phy_flit_enabled));
  assign unsupported_nonflit=phy_l0 && speed_ok && width_ok &&
     !phy_flit_enabled && (phy_gen!=3'd6);
  assign flit_link_ready=phy_l0 && phy_flit_enabled && speed_ok && width_ok;
endmodule
