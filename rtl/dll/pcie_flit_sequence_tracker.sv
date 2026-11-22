/*
 * pcie_flit_sequence_tracker.sv -- initial FLIT sequencing observability.
 * PURPOSE: Maintain expected sequential payload FLIT number on accepted
 *          explicit sequence numbers to help construct a future retry FSM.
 * FUNCTION: Counter begins at 10'h001; zero is skipped on wrap.
 *           unexpected_sequence pulses when an arriving number differs.
 * LIMITS: NOT the complete PCIe 6.0 IDLE/explicit/implicit handshake,
 *         ACK/NAK, selective replay or TX/RX retry-buffer management.
 */
module pcie_flit_sequence_tracker (
  input logic clk, rst_n, clear,
  input logic accepted_payload,
  input logic [9:0] rx_sequence,
  output logic [9:0] expected_sequence,
  output logic unexpected_sequence
);
  assign unexpected_sequence=accepted_payload &&
                              (rx_sequence!=expected_sequence);
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) expected_sequence<=10'h001;
    else if (clear) expected_sequence<=10'h001;
    else if (accepted_payload && !unexpected_sequence)
      expected_sequence <= expected_sequence==10'h3ff ? 10'h001 :
                           expected_sequence+1'b1;
  end
endmodule
