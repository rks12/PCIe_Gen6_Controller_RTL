/*
 * pcie_flit_rx_pipe.sv -- one-entry registered full-FLIT receiver.
 * PURPOSE: Enforce ECC-then-CRC integrity checking before release upstream.
 * FUNCTION: On an accepted input, latch corrected TLP+DLP, flags and
 *           valid output. A corrupted frame generates drop_pulse and
 *           increments the error counter, but is never delivered to TL.
 *           The downstream protocol must generate suitable NAK/replay;
 *           that control engine is not yet implemented.
 * LINK EPOCH: flush clears pending RX TLP and pulses, but preserves the
 *             diagnostic drop count until reset.
 */
module pcie_flit_rx_pipe (
  input logic clk, rst_n,
  input logic flush, /* clear buffered output on loss of link */
  input logic in_valid,
  output logic in_ready,
  input logic [2047:0] in_flit,
  output logic out_valid,
  input logic out_ready,
  output logic [1887:0] out_tlp,
  output logic [47:0] out_dlp,
  output logic drop_pulse,
  output logic fec_corrected_pulse,
  output logic [31:0] crc_error_count
);
  logic [1887:0] decoded_tlp;
  logic [47:0] decoded_dlp;
  logic fec_corr, fec_unc, crc_bad, decoded_valid;
  pcie_flit_decoder u_dec(
    .flit_in(in_flit),.tlp_area(decoded_tlp),.dlp(decoded_dlp),
    .fec_corrected(fec_corr),.fec_uncorrectable(fec_unc),
    .crc_error(crc_bad),.valid_flit(decoded_valid)
  );
  assign in_ready=~out_valid || out_ready;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_valid<=0;
      out_tlp<='0;
      out_dlp<='0;
      drop_pulse<=0;
      fec_corrected_pulse<=0;
      crc_error_count<='0;
    end else if (flush) begin
      out_valid<=1'b0;
      drop_pulse<=1'b0;
      fec_corrected_pulse<=1'b0;
    end else begin
      drop_pulse<=0;
      fec_corrected_pulse<=0;
      if (in_ready) begin
        out_valid<=in_valid && decoded_valid;
        if (in_valid) begin
          fec_corrected_pulse<=fec_corr;
          if (decoded_valid) begin
            out_tlp<=decoded_tlp;
            out_dlp<=decoded_dlp;
          end else begin
            drop_pulse<=1'b1;
            if (crc_error_count!=32'hffff_ffff)
              crc_error_count<=crc_error_count+1'b1;
          end
        end
      end
    end
  end
endmodule
