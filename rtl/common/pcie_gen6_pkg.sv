/*
 * pcie_gen6_pkg.sv -- mathematical and protocol constants used by the digital
 * Gen6 FLIT datapath.
 *
 * PURPOSE:
 *   Provide a single reviewed definition of the GF(2^8) operations for the
 *   PCIe 6.0 eight-byte CRC and three-way interleaved ECC. The CRC GF uses
 *   primitive polynomial x^8+x^5+x^3+x+1 (8'h2b remainder). The ECC GF uses
 *   x^8+x^4+x^3+x^2+1 (8'h1d remainder). THEY ARE NOT INTERCHANGEABLE.
 *
 * FUNCTIONS:
 *   gf_mul(a,b,reduction): finite-field multiplication (8 iterations).
 *   gf_pow_alpha(n): ECC alpha^n, 0 <= n <= 84 (bounded exponent).
 *   crc64_advance(state,data): append one message byte, MSB coefficient first.
 *   get_byte/set_byte are intentionally NOT provided: packed buses use
 *   explicit byte slices [8*idx +: 8] to fix byte ordering.
 *
 * REFERENCE:
 *   PCIe Base Specification 6.0, Sections 4.2.3.4.3, 4.2.3.4.4,
 *   Appendix J and Appendix K. This is an independent implementation.
 */
package pcie_gen6_pkg;
  parameter int FLIT_BYTES  = 256;
  parameter int TLP_BYTES   = 236;
  parameter int DLP_BYTES   = 6;
  parameter int CRC_BYTES   = 8;
  parameter int ECC_BYTES   = 6;

  function automatic logic [7:0] gf_mul(
      input logic [7:0] aa,
      input logic [7:0] bb,
      input logic [7:0] reduction
  );
    logic [7:0] a, b, p;
    a=aa; b=bb; p=8'h00;
    for (int k=0; k<8; k++) begin
      if (b[0]) p=p^a;
      a=a[7] ? ((a << 1) ^ reduction) : (a << 1);
      b=b >> 1;
    end
    return p;
  endfunction

  /* ECC field alpha=x, with primitive reduction 8'h1d. */
  function automatic logic [7:0] gf_pow_alpha(input int unsigned exponent);
    logic [7:0] x;
    x=8'h01;
    for (int k=0; k<85; k++) begin
      if (k < exponent) x=gf_mul(x,8'h02,8'h1d);
    end
    return x;
  endfunction

  /*
   * Byte-oriented remainder for g(x)=x^8+a^172*x^7+a^116*x^6+
   * a^186*x^5+a^172*x^4+a^195*x^3+a^134*x^2+a^199*x+a^36
   * over GF(2^8) with primitive reduction 8'h2b.
   * State holds eight polynomial coefficients, highest in bits [63:56].
   * START AT ZERO and process input bytes 0..241 in increasing order.
   * On completion, CRC bytes 242..249 are state bytes 7..0 (reversed).
   */
  function automatic logic [63:0] crc64_advance(
      input logic [63:0] s, input logic [7:0] d
  );
    logic [7:0] f;
    f=s[63:56]^d;
    return {
      (s[55:48]^gf_mul(f,8'hd5,8'h2b)),
      (s[47:40]^gf_mul(f,8'h68,8'h2b)),
      (s[39:32]^gf_mul(f,8'hfe,8'h2b)),
      (s[31:24]^gf_mul(f,8'hd5,8'h2b)),
      (s[23:16]^gf_mul(f,8'h33,8'h2b)),
      (s[15: 8]^gf_mul(f,8'h41,8'h2b)),
      (s[ 7: 0]^gf_mul(f,8'h4d,8'h2b)),
      (         gf_mul(f,8'h69,8'h2b))
    };
  endfunction
endpackage
