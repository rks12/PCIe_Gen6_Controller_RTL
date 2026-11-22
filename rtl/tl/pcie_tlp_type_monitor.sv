/*
 * pcie_tlp_type_monitor.sv -- simple Gen6 FLIT-mode TLP-area observability.
 * PURPOSE: Expose the first TLP header Type and whether it is a NOP.
 * FUNCTION: Decode Type byte 0, located at the first byte of the header.
 * LIMITS: NOT a full FM packet parser; the type/length/OHC/TS/FC rules
 *         must be implemented before accepting arbitrary host TLPs.
 */
module pcie_tlp_type_monitor (
  input logic [1887:0] tlp_area,
  output logic [7:0] first_type,
  output logic first_is_nop
);
  assign first_type=tlp_area[7:0];
  assign first_is_nop=(first_type==8'h00);
endmodule
