# Third-party dependencies and redistribution notes

This repository's [MIT License](LICENSE) applies to repository-owned material
that the copyright holder is entitled to license. It does not change the
licences of external dependencies or grant rights in external specifications.

## External dependencies (not vendored in this source tree)

| Item | Use | Redistributed with this repository? | Licensing action |
| --- | --- | --- | --- |
| [Verilator](https://github.com/verilator/verilator) | RTL linting, simulation and UVM test execution | No; installed separately or downloaded by CI | Review upstream licence and notices before redistributing a binary |
| [Accellera UVM Core](https://github.com/accellera-official/uvm-core) (UVM 2020-3.2) | External SystemVerilog UVM library for the testbench | No; obtained through the simulator/tool distribution | Preserve applicable upstream copyright and licence notices if redistributed |
| [EDAPack Verilator binary](https://github.com/EDAPack/verilator-bin) (CI references v5.054) | CI simulator distribution | No; downloaded at CI runtime | Check binary distribution terms and included component notices |
| Icarus Verilog, Python, make and system packages | Optional local build/test utilities | No | Follow the terms of the versions actually installed |
| `actions/checkout@v4` and `actions/upload-artifact@v4` | GitHub Actions CI workflows | No; referenced by CI configuration | Use subject to upstream terms |

## External specifications and standards

- **PCI Express Base Specification Revision 6.0** is used as an external
  protocol reference. It is copyrighted material and is **not** bundled or
  relicensed by this repository. No permission to redistribute that
  specification is implied.
- The repository does **not** contain a third-party PDK, standard-cell library,
  proprietary PCIe verification IP, or an actual analog PHY implementation.

## If using this repository as a Mercor task starting point

1. Link a fixed Git commit and explicitly identify the task's selected files.
2. Include this repository's MIT `LICENSE` in the task bundle when distributing
   its covered source, and preserve any existing attribution.
3. Declare any separately supplied third-party IP, libraries, datasets, EDA
   tool bundles or PDKs as required by the task intake form, with their **actual
   pinned versions and applicable licences**. Do not assume that this MIT
   licence applies to those external components.
4. Do not copy the copyrighted PCIe specification into the task materials.
5. Recheck provenance and rights before using any file contributed by a
   third party in the future.

**Important:** The root licence documents permissions for eligible repository
material. It does not itself prove ownership, provenance, benchmark eligibility,
or compliance with Mercor's separate seed-authorship policy.
