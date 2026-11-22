/*
 * pcie_flit_encoder.sv -- construct a complete 256-byte Gen6 FLIT.
 * PURPOSE:
 *   Assemble a pre-formatted 236-byte FM TLP region and six DLP bytes,
 *   calculate the PCIe 6.0 eight-byte CRC, then add six ECC bytes.
 * FUNCTION: flit_out bytes 0..235=TLP; 236..241=DLP; 242..249=CRC;
 *           250..255=FEC. All packed vectors have byte 0 in bits 7:0.
 * LIMITS: Caller is responsible for legal TLP length, TLP packing,
 *         credit accounting, DLP encoding, sequence and retry semantics.
 */
module pcie_flit_encoder (
  input  logic [1887:0] tlp_area,
  input  logic [47:0]   dlp,
  output logic [2047:0] flit_out
);
  logic [1935:0] data_242;
  logic [1999:0] data_250;
  logic [63:0]   crc;
  logic [47:0]   ecc;
  assign data_242={dlp,tlp_area};
  pcie_crc64_gen u_crc(.data_242(data_242),.crc_bytes(crc));
  assign data_250={crc,data_242};
  pcie_fec_encoder u_ecc(.data_250(data_250),.ecc_6(ecc));
  assign flit_out={ecc,data_250};
endmodule
