/*
 * pcie_lcrc32_reference.sv -- legacy/non-FLIT LCRC reference primitive.
 * PURPOSE: Calculate the CRC part of the older packet protection scheme;
 *          this is NOT a complete Gen1..Gen5 Data Link implementation.
 * FUNCTION: Consume byte0..byteN in stream order, bit0..bit7 within each
 *           byte; seed FFFFFFFF, polynomial 04C11DB7, final complement.
 *           Output bit mapping follows PCIe 6.0 Table 3-7 (bytewise reversal).
 * CAUTION: The upstream caller must prepend the two PCIe sequence bytes,
 *          then the complete TLP. STP/END/EDB/framing and ACK/NAK are out
 *          of scope; do not connect to a real legacy link without them.
 */
module pcie_lcrc32_reference (
  input logic clk,rst_n,
  input logic start,
  input logic in_valid,
  input logic [7:0] in_byte,
  output logic [31:0] crc_field
);
  logic [31:0] state;
  logic [31:0] next_crc;
  logic [31:0] complement_crc;
  function automatic logic [31:0] step_crc(input logic [31:0] state_in,
                                            input logic [7:0] data_in);
    logic [31:0] c;
    c=state_in;
    for(int bit_index=0;bit_index<8;bit_index++)
      c=(c[0]^data_in[bit_index]) ? ((c>>1)^32'hedb88320) : (c>>1);
    return c;
  endfunction
  function automatic logic [7:0] reverse_bits(input logic [7:0] a);
    logic [7:0] b;
    for(int i=0;i<8;i++) b[i]=a[7-i];
    return b;
  endfunction
  assign next_crc=step_crc(start ? 32'hffff_ffff : state,in_byte);
  assign complement_crc=~state;
  always_comb begin
    for(int j=0;j<4;j++)
      crc_field[8*j +: 8]=reverse_bits(complement_crc[8*j +: 8]);
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) state<=32'hffff_ffff;
    else if(in_valid) state<=next_crc;
    else if(start) state<=32'hffff_ffff;
  end
endmodule
