/*
 * pcie_crc64_gen.sv -- combinational CRC generator over 242 FLIT bytes.
 * PURPOSE: Protect the first 236 TLP-area and 6 DLP bytes of a Gen6 FLIT.
 * FUNCTION: Iterate the exact GF(2^8) update specified by PCIe 6.0;
 *           emit CRC byte 0 at crc_bytes[7:0] (corresponds to state[7:0]).
 * NOTES: No initial/final XOR, no Ethernet CRC-64 substitution.
 *        This reference combinational realization has a very long path.
 *        For real Gen6 timing, retime/pipeline without changing its vectors.
 */
module pcie_crc64_gen (
  input  logic [1935:0] data_242,
  output logic [63:0] crc_bytes
);
  import pcie_gen6_pkg::*;
  logic [63:0] s;
  always_comb begin
    s=64'h0;
    for (int i=0; i<242; i++) begin
      s=crc64_advance(s,data_242[8*i +: 8]);
    end
    /* CRC0 is lowest output byte; CRC7 is highest output byte. */
    for (int j=0; j<8; j++) begin
      crc_bytes[8*j +: 8]=s[8*j +: 8];
    end
  end
endmodule
