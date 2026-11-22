#!/usr/bin/env bash
# Run HDL syntax/elaboration checks with a real compiler (no TB required).
# Prefer Verilator; fall back to Icarus Verilog for basic elaboration.
set -euo pipefail
cd "$(dirname "$0")/.."
if command -v verilator >/dev/null 2>&1; then
  echo '[lint] Verilator found'
  verilator --lint-only -Wall -Wno-fatal --top-module pcie_gen6_controller_top \
    -f scripts/rtl_sources.f
  echo '[lint] Verilator top-level elaboration completed'
elif command -v iverilog >/dev/null 2>&1; then
  echo '[lint] Icarus Verilog found'
  iverilog -g2012 -s pcie_gen6_controller_top \
    -o /tmp/pcie_gen6_controller_elab.vvp -f scripts/rtl_sources.f
  rm -f /tmp/pcie_gen6_controller_elab.vvp
  echo '[lint] Icarus top-level elaboration completed'
else
  echo 'ERROR: Verilator and Icarus Verilog are both unavailable.' >&2
  echo 'Install on Ubuntu/Debian: sudo apt-get install verilator' >&2
  echo 'No HDL compile has been performed; make check runs only algorithm/static checks.' >&2
  exit 2
fi
