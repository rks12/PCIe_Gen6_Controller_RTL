/*
 * pcie_credit_counter.sv -- reusable local outstanding credit accounting.
 * PURPOSE: Track occupancy of one abstract PCIe flow-control credit pool.
 * FUNCTION: Grant deposits credits, consume subtracts one when available.
 *           Full-width saturating arithmetic avoids wrap on grant.
 * LIMITS: Not the spec FC update/initialization protocol; connect to
 *         per-VC P/NP/Cpl header/data accounting in a subsequent stage.
 */
module pcie_credit_counter #(
  parameter int CW=16
)(
  input logic clk, rst_n,
  input logic grant_valid,
  input logic [CW-1:0] grant_amount,
  input logic consume_valid,
  output logic consume_ready,
  output logic [CW-1:0] available
);
  logic [CW:0] next_available;
  always_comb begin
    consume_ready=(available!=0);
    next_available={1'b0,available};
    if (consume_valid && consume_ready) next_available=next_available-1'b1;
    if (grant_valid) next_available=next_available+{1'b0,grant_amount};
    if (next_available[CW]) next_available={1'b0,{CW{1'b1}}};
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) available<='0;
    else available<=next_available[CW-1:0];
  end
endmodule
