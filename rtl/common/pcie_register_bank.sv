/*
 * pcie_register_bank.sv -- local engineering/status CSR bank.
 * PURPOSE: Provide visibility into the controller from a simple local
 *          register access port (NOT the host PCIe Configuration Space).
 * FUNCTION: Word-aligned 32-bit addresses, synchronous read data, software
 *           scratch register, read-only link/error features, capability bits.
 * READ ADDRESS MAP:
 *   0x00: 0x50434936 signature ('PCI6')
 *   0x04: version (major=0, minor=2, patch=0)
 *   0x08: link {ready, PHY L0, FLIT negotiated, speed, width}
 *   0x0C: RX FLIT CRC/FEC drop count
 *   0x10: scratch RW
 *   0x14: flags {unsupported_nonflit,invalid_negotiation}
 *   0x18: implemented features: bit0 CRC64, bit1 ECC correction,
 *         bit2 single-TLP packer, bit3 error-drop, bit4 status CSR.
 * IMPORTANT: Do not expose these registers as standard PCIe config space.
 */
module pcie_register_bank (
  input logic clk,rst_n,
  input logic csr_rd_en,csr_wr_en,
  input logic [7:0] csr_addr,
  input logic [31:0] csr_wdata,
  output logic [31:0] csr_rdata,
  output logic csr_rvalid,
  input logic link_ready,phy_l0,flit_enabled,
  input logic [2:0] phy_gen,
  input logic [4:0] phy_width,
  input logic [31:0] drop_count,
  input logic unsupported_nonflit,invalid_negotiation
);
  logic [31:0] scratch;
  logic [31:0] read_mux;
  always_comb begin
    read_mux=32'h0;
    case (csr_addr)
      8'h00:read_mux=32'h5043_4936;
      8'h04:read_mux=32'h0000_0200;
      8'h08:read_mux={20'h0,phy_width,phy_gen,flit_enabled,phy_l0,link_ready,1'b0};
      8'h0c:read_mux=drop_count;
      8'h10:read_mux=scratch;
      8'h14:read_mux={30'h0,invalid_negotiation,unsupported_nonflit};
      8'h18:read_mux=32'h0000_001f;
      default:read_mux=32'h0;
    endcase
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      scratch<='0;
      csr_rdata<='0;
      csr_rvalid<=0;
    end else begin
      csr_rvalid<=csr_rd_en;
      if(csr_rd_en) csr_rdata<=read_mux;
      if(csr_wr_en && csr_addr==8'h10) scratch<=csr_wdata;
    end
  end
endmodule
