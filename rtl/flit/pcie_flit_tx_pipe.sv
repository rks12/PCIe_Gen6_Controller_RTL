/*
 * pcie_flit_tx_pipe.sv -- one-entry registered full-FLIT transmitter.
 * PURPOSE: Decouple the FLIT codec from external PHY-facing transfer.
 * FUNCTION: Ready/valid holding register. A clock edge takes the input
 *           only on in_valid & in_ready; out_flit remains stable while
 *           out_valid & !out_ready. No frames are silently discarded.
 * TIMING: Combinational CRC/FEC is a reference model, not Gen6 Fmax closure.
 */
module pcie_flit_tx_pipe (
  input logic clk, rst_n,
  input logic in_valid,
  output logic in_ready,
  input logic [1887:0] in_tlp,
  input logic [47:0] in_dlp,
  output logic out_valid,
  input logic out_ready,
  output logic [2047:0] out_flit
);
  logic [2047:0] encoded;
  pcie_flit_encoder u_enc(.tlp_area(in_tlp),.dlp(in_dlp),.flit_out(encoded));
  assign in_ready=~out_valid || out_ready;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_valid<=1'b0;
      out_flit<='0;
    end else if (in_ready) begin
      out_valid<=in_valid;
      if (in_valid) out_flit<=encoded;
    end
  end
endmodule
