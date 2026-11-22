# Feature support and validation matrix — revision 0.4

Legend: **Implemented** = RTL code exists and path is connected; some paths have directed/limited UVM simulation but not complete protocol signoff. **Utility only** = reusable isolated block exists, not connected. **Not implemented** = cannot be used in a compliant PCIe link.

| Layer | Feature | Status | Precise boundary |
|---|---|---|---|
| FLIT | 256B fixed layout (236+6+8+6) | Implemented | Full-frame bus |
| FLIT | 8B CRC algorithm | Implemented | Six Appendix-K basis vectors match in Python |
| FLIT | 3-way ECC encoder | Implemented | Python parity/check model run |
| FLIT | Single-byte ECC correction + CRC-after-FEC | Implemented | Python single-byte fault model run |
| FLIT | TX/RX ready/valid holding buffers | Implemented | RTL present, needs HDL simulation |
| TL | One complete FM TLP, padding with NOP TLPs | Implemented (restricted) | 1..59 DW and no spanning |
| TL | First-byte TLP type observability | Utility only | Type probe, not parser |
| TL | Full FM TLP header/parser/OHC/TS | Not implemented | Mandatory to complete |
| TL | Non-FLIT TLP header/parser | Not implemented | Mandatory for non-FLIT |
| TL | Requester/completer, MRd/MWr, Cpl and errors | Not implemented | Mandatory to complete |
| TL | PCI config space, BARs, enumeration | Not implemented | Mandatory to complete |
| TL | Ordering/TC/VC and PCIe credit accounting | Not implemented | Generic counter utility only |
| DLL | Legacy LCRC32 primitive | Utility only | Not connected to framing or replay |
| DLL | Basic expected FLIT sequence tracker | Utility only | Not full Gen6 retry rules |
| DLL | DLP payload generation/extraction | Not implemented | DLP supplied by caller |
| DLL | FC init, updates, data link control/management | Not implemented | Mandatory to complete |
| DLL | FM ACK/NAK, implicit/explicit seq, retry, reorder | Not implemented | Mandatory to complete |
| DLL | NFM DLLP/sequence/LCRC/replay integration | Not implemented | Mandatory to complete |
| PHY | External link-status validation | Implemented | Consumes external reported PHY status |
| PHY | Real Detect/Polling/Config/Recovery LTSSM | Not implemented | Mandatory to complete |
| PHY | Training sets and ordered sets | Not implemented | Mandatory to complete |
| PHY | Gen1/2 8b/10b + scrambler | Not implemented | Mandatory to complete |
| PHY | Gen3/4/5 128b/130b + scrambler | Not implemented | Mandatory to complete |
| PHY | Gen6 1b/1b + PAM4 mapping/Gray/precoding | Not implemented | Mandatory to complete |
| PHY | Lane striping, deskew, SKP, speed/width negotiation | Not implemented | Mandatory to complete |
| PHY | Clocking, PIPE, analog SerDes, EQ, CDR | Not implemented | External IP/hardware required |
| System | Local engineering CSR read/write | Implemented | NOT standard PCI config space |
| System | MSI/MSI-X/PM/AER/FLR/IDE/SR-IOV | Not implemented | Required/optional according to selected profile |
| Validation | Python CRC/FEC algorithm checks | Implemented and run | Passes provided Python vectors |
| Validation | Structural source audit | Implemented and run | Passes local static checks |
| Validation | Real HDL compile/elaboration | **G1 CI PASS** | GitHub Actions Verilator lint and binary run; UVM compiles on separate simulator lane |
| Validation | RTL-directed simulation / UVM | **G1 CI PASS; UVM testbench present** | G1 top+primitive and Five UVM scenarios verified; sixth backpressure test awaits latest CI |
| Validation | Synthesis, Fmax/PPA, real hardware interoperability | **Not run** | Necessary for a usable controller |

**This repository has no validated PCIe generation interoperability.** “Gen6” denotes the format/math targeted by the codec, not a completed Gen6 link.


### v0.3 verification status
Executable G1 HDL testbenches are added under `tb/` and a link-epoch flush
fix is included. Python golden tests passed; **RTL simulation has not yet
been run** in the author environment. No feature outside the existing v0.2
foundation is implied by the presence of the 76-case verification plan.

### v0.4 verification update
IEEE 1800.2 UVM structure in `tb/uvm/` has active TX/RX/link/CSR agents,
scoreboard, coverage and SVA for the currently implemented abstract-FLIT
interface. The G1 directed simulation passed on GitHub CI; UVM smoke/random
and three directed UVM scenarios passed on the pinned modern UVM simulator. The 76 future G2–G7 scenarios
remain BLOCKED unless matching RTL is implemented and independently checked.
