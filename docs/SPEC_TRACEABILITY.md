# PCIe Base Specification Revision 6.0 traceability

The original user-provided PCI-SIG document (16 December 2021, 1,923 pages) remains the authoritative rules source. This file lists sections used in this snapshot without reproducing specification text. The project does not distribute that document.

| Area | Spec sections/pages | Current code | Completeness |
|---|---|---|---|
| PCIe TL/DLL/PHY layering | §1.5, pp.109–113 | RTL module organization | Architectural only |
| FM TLP header/type and NOP | §2.2.1.2, pp.122–141 | `tl/pcie_flit_tlp_packer.sv` | NOP padding only |
| TL FC, ordering | §2.4–2.6, pp.222–252 | generic credit primitive | Not implemented |
| DL states/FC/DLLP | §3.2–3.5, pp.264–286 | none | Not implemented |
| Non-FLIT LCRC and replay | §3.6, pp.287–306 | `common/pcie_lcrc32_reference.sv` | Utility only |
| Mode negotiation/table | §4.2/Table 4-1, pp.307–308 | `phy/pcie_link_guard.sv` | Consumes external state only |
| Gen6 1b/1b PAM4 | §4.2.3.1, pp.340–348 | none | Not implemented |
| FLIT layout and TLP bytes | §4.2.3.3–4.2.3.4.1, pp.351–358 | `flit/pcie_flit_encoder.sv` | Data layout only |
| DLP encoding/replay controls | §4.2.3.4.2, pp.359–384 | standalone tracker | Not implemented |
| Eight-byte CRC generator | §4.2.3.4.3, pp.384–385; Appendix K | `pcie_gen6_pkg.sv`, `pcie_crc64_gen.sv` | Algorithm implemented |
| Three-way ECC | §4.2.3.4.4, pp.385–391; Appendix J | `pcie_fec_encoder/decoder.sv` | Algorithm implemented |
| LTSSM / link EQ | §4.2.4–4.2.7, pp.392–530 | none | Not implemented |
| Power management | Ch.5 | none | Not implemented |
| Interrupts / errors | Ch.6 | local error counter only | Not implemented |
| PCI config space | Ch.7 | local status CSR only | Not implemented |
| Electrical/analog | Ch.8 and relevant PHY requirements | none | External IP required |

**Conformance warning:** Mathematical CRC/FEC vector agreement only validates the specific encoding algorithms. It does not establish any full-transaction or link-level conformance.
