/*
 * pcie_flit_decoder.sv -- receive-side FLIT integrity datapath.
 * PURPOSE: Correct ECC-protectable single-byte errors, then verify CRC.
 * FUNCTION: ECC decoder returns 250 corrected bytes. CRC generator
 *           recalculates check bytes from corrected TLP+DLP (242 bytes).
 *           A packet is accepted only when CRC matches and ECC reports
 *           no uncorrectable condition. An error must trigger recovery
 *           by the integrating link protocol (not implemented here).
 * IMPORTANT: Structural CRC/FEC equivalence is separately checked using
 *            Python reference vectors in scripts/protocol_reference.py.
 */
module pcie_flit_decoder (
  input  logic [2047:0] flit_in,
  output logic [1887:0] tlp_area,
  output logic [47:0] dlp,
  output logic fec_corrected,
  output logic fec_uncorrectable,
  output logic crc_error,
  output logic valid_flit
);
  logic [1999:0] corrected;
  logic [63:0] expected_crc;
  pcie_fec_decoder u_ecc(
    .flit_in(flit_in),.corrected_250(corrected),
    .corrected_any(fec_corrected),.uncorrectable(fec_uncorrectable)
  );
  pcie_crc64_gen u_crc(.data_242(corrected[1935:0]),.crc_bytes(expected_crc));
  assign crc_error=(expected_crc!=corrected[1999:1936]);
  assign valid_flit=~(crc_error | fec_uncorrectable);
  assign tlp_area=corrected[1887:0];
  assign dlp=corrected[1935:1888];
endmodule
