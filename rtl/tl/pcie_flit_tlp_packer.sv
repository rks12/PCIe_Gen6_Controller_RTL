/*
 * pcie_flit_tlp_packer.sv -- single-TLP placement into a Gen6 TLP region.
 * PURPOSE: Form a legal-width 236-byte TLP area for single-TLP frames.
 * FUNCTION: Copy tlp_dw_count*4 bytes from input bus into the low end
 *           of the FLIT TLP region, pad all remaining 4-byte words with
 *           zero = FLIT NOP TLP Type 00 (Table 2-5).
 * RESTRICTIONS: Only a whole, single, <=236 byte FLIT-formatted TLP.
 *               Caller must provide a valid FM header and matching length;
 *               no handling of multi-FLIT TLPs, ECRC or >1 TLP/FLIT.
 */
module pcie_flit_tlp_packer (
  input logic [1887:0] tlp_bytes,
  input logic [5:0] tlp_dw_count,
  output logic [1887:0] packed_tlp,
  output logic invalid_length
);
  always_comb begin
    packed_tlp='0;
    invalid_length=(tlp_dw_count==0 || tlp_dw_count>59);
    for (int i=0;i<236;i++) begin
      if ((i < (int'(tlp_dw_count)*4)) && !invalid_length)
        packed_tlp[i*8 +: 8]=tlp_bytes[i*8 +: 8];
    end
  end
endmodule
