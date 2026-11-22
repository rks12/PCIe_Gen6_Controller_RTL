/*
 * pcie_fec_encoder.sv -- PCIe Gen6 three-way interleaved FEC encoding.
 * PURPOSE: Add six parity/check bytes to 250 content+CRC bytes.
 * FUNCTION: For each ECC group k=(physical_byte_index % 3), calculate:
 *             P = XOR(data byte at each group position)
 *             C = XOR(data[pos] * alpha^(84-pos)) over GF(2^8).
 *           Map group check bytes to physical positions 250,251,252,
 *           and group parity bytes to positions 253,254,255.
 *           Group 0 contains 84 data bytes; groups 1 and 2 contain 83.
 *           Their missing group position 83 is implicitly zero.
 * REFERENCE: PCIe 6.0 Section 4.2.3.4.4.
 */
module pcie_fec_encoder (
  input  logic [1999:0] data_250,
  output logic [47:0]  ecc_6
);
  import pcie_gen6_pkg::*;
  logic [7:0] p[0:2];
  logic [7:0] c[0:2];
  logic [7:0] b;
  always_comb begin
    for (int g=0;g<3;g++) begin p[g]=0; c[g]=0; end
    for (int i=0;i<250;i++) begin
      b=data_250[i*8 +: 8];
      p[i%3]=p[i%3]^b;
      c[i%3]=c[i%3]^gf_mul(b,gf_pow_alpha(84-(i/3)),8'h1d);
    end
    ecc_6={p[0],p[2],p[1],c[0],c[2],c[1]};
    /* [7:0]=check group1, [15:8]=check group2, [23:16]=check
     * group0, [31:24]=parity group1, [39:32]=parity group2,
     * [47:40]=parity group0. */
  end
endmodule
