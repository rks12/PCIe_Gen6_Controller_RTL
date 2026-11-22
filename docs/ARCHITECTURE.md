# Architecture, byte order, and module boundaries

## Design intent

This snapshot is a **digital FLIT protection datapath** and integration foundation rather than a full PCIe Endpoint. It deliberately keeps external link-management responsibilities visible and unimplemented rather than inventing noncompliant placeholders.

## TX path

`tx_tlp_bytes` (little-endian byte packing: byte 0 at `[7:0]`) and `tx_tlp_dw_count` form a complete single FM TLP with declared 4-byte length. The packer copies the TLP to the 236-byte area and fills the unused area with zero-valued, 1-DW NOP TLPs. `tx_dlp` is supplied by the caller and occupies bytes 236..241. `pcie_crc64_gen` computes bytes 242..249 from the 242-byte input; `pcie_fec_encoder` computes bytes 250..255 from 250 bytes. `pcie_flit_tx_pipe` registers the whole frame and holds it under backpressure.

**Does not handle:** FM TLPs spanning frames, multiple non-NOP TLPs per FLIT, frame sequence/DLP creation, tag allocation, FC/P/NP/Cpl, legal TLP format validation or buffer availability. The caller must provide real FM packet bytes and valid DLP. The block does not assert that those bytes are protocol valid.

## RX path

`pcie_fec_decoder` computes three separate ECC group syndromes, attempts single-byte correction and returns corrected 250 bytes. `pcie_crc64_gen` recomputes the CRC from corrected bytes 0..241. `pcie_flit_decoder` rejects CRC mismatch or an uncorrectable ECC syndrome. On an accepted RX handshake, `pcie_flit_rx_pipe` registers the corrected 236+6 bytes; corrupt frames are dropped and counted.

**Does not handle:** NOP removal, FM Type/Length/OHC parsing, TLP segmentation across FLITs, message/completion routing, DLP handling, link-layer retransmission. Receiving a CRC-good frame is not sufficient to assert full PCIe protocol acceptance.

## GF256 differences

CRC field uses reduction **0x2B**, generator coefficients `D5 68 FE D5 33 41 4D 69`, initial eight-byte state all zero, message bytes 0..241, emits coefficient state in reverse byte order to CRC0..7.

ECC field uses reduction **0x1D** and `C = XOR(Bi*alpha^(84-i))`, `P = XOR(Bi)`. Three groups are selected by byte-index modulo 3, data bytes 0..249. ECC physical order is `C1 C2 C0 P1 P2 P0` (bytes 250..255).

**Performance note:** The pure combinational CRC expression is deep and the ECC lookup in this revision is algorithmic. It is correct as a mathematical reference model but not an optimized implementation for x16 at 64 GT/s. A production core should use parallel update matrices with staged pipelining, per-clock multi-byte groups, timing analysis, and independently checked latency equivalence.

## Link gate vs LTSSM

`pcie_link_guard` checks externally supplied flags for L0, FLIT enabled, Gen1..Gen6 and valid widths x1, x2, x4, x8 and x16. This does **not** train or negotiate a link. `phy_gen=6 && !phy_flit_enabled` is rejected, as required by PCIe 6.0. Lower Gen FLIT mode is allowed only when the external PHY reports negotiated FLIT operation. Non-FLIT is intentionally blocked because the complete data path is missing.

## Register bank vs PCI configuration

`pcie_register_bank` is a small local engineering/debug register file with read-only link/error capabilities and RW scratch. It must not be mapped as PCIe 4KB configuration space: this project does not yet enumerate as a function or implement BARs, IDs, MSI-X or extended PCIe capability chains.
