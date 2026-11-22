/*
 * pcie_fec_decoder.sv -- byte-error correction for all three ECC groups.
 * PURPOSE: Correct one corrupted byte per ECC group (including CRC bytes).
 * FUNCTION:
 *   1. Recompute each group's check/parity syndromes.
 *   2. A check-only syndrome identifies its check byte; a parity-only
 *      syndrome identifies its parity byte.
 *   3. If both syndromes are nonzero, compare C/P with every legal
 *      alpha^(84-pos) weighting to locate a single erroneous data byte.
 *   4. Flag an unlocatable syndrome; always require the downstream
 *      eight-byte CRC to PASS before accepting a FLIT.
 * CAUTION: Multi-byte errors can mimic correctable syndromes. CRC is mandatory.
 */
module pcie_fec_decoder (
  input  logic [2047:0] flit_in,
  output logic [1999:0] corrected_250,
  output logic          corrected_any,
  output logic          uncorrectable
);
  import pcie_gen6_pkg::*;
  logic [7:0] p[0:2], c[0:2];
  logic [7:0] sp, sc, b;
  logic [7:0] rxp, rxc;
  logic found;
  int location;
  always_comb begin
    corrected_250=flit_in[1999:0];
    corrected_any=1'b0;
    uncorrectable=1'b0;
    for (int g=0;g<3;g++) begin
      p[g]=0;
      c[g]=0;
    end
    for (int i=0;i<250;i++) begin
      b=flit_in[i*8 +: 8];
      p[i%3]=p[i%3]^b;
      c[i%3]=c[i%3]^gf_mul(b,gf_pow_alpha(84-(i/3)),8'h1d);
    end
    /* Group index to wire ECC location: 0->252/255,
     * 1->250/253, 2->251/254. */
    sp=0; sc=0; rxp=0; rxc=0; found=0; location=0;
    for (int g=0;g<3;g++) begin
      rxc=flit_in[8*(g==0?252:(g==1?250:251)) +: 8];
      rxp=flit_in[8*(g==0?255:(g==1?253:254)) +: 8];
      sp=p[g]^rxp;
      sc=c[g]^rxc;
      found=1'b0;
      location=0;
      if (sp==0 && sc==0) begin
        /* no error in this ECC group */
      end else if (sp==0 || sc==0) begin
        /* Single check/parity byte error: data bytes already intact.
         * A downstream CRC check will still guard payload acceptance. */
        corrected_any=1'b1;
      end else begin
        for (int k=0;k<84;k++) begin
          if (((3*k+g)<250) &&
              (gf_mul(sp,gf_pow_alpha(84-k),8'h1d)==sc)) begin
            found=1'b1;
            location=3*k+g;
          end
        end
        if (found) begin
          corrected_250[8*location +: 8] =
            corrected_250[8*location +: 8]^sp;
          corrected_any=1'b1;
        end else begin
          uncorrectable=1'b1;
        end
      end
    end
  end
endmodule
