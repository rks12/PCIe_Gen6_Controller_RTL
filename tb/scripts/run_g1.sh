#!/usr/bin/env bash
# Compile and execute G1 SystemVerilog testbenches using real RTL elaboration.
# MODE=top: top FLIT/CSR/guard; MODE=primitives: standalone utilities;
# MODE=all: both. No output is marked PASS without a simulator pass marker.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${PYTHON:=python3}"
: "${SEED:=17}"
: "${VERILATOR:=verilator}"
: "${TB_JOBS:=2}"
: "${MODE:=all}"
if ! command -v "$VERILATOR" >/dev/null 2>&1; then
  echo 'ERROR: Verilator is not installed. Install Verilator >=5, then run make tb-smoke.' >&2
  exit 127
fi
mkdir -p build/tb
"$PYTHON" tb/python/gen_vectors.py --seed "$SEED" --output build/tb/vectors
case "$MODE" in
  top) suites="tb_pcie_gen6_g1" ;;
  primitives) suites="tb_pcie_g1_primitives" ;;
  all) suites="tb_pcie_gen6_g1 tb_pcie_g1_primitives" ;;
  *) echo "Unsupported MODE=$MODE (top|primitives|all)" >&2; exit 2 ;;
esac
for top in $suites; do
  outdir="build/tb/${top}"
  mkdir -p "$outdir"
  "$VERILATOR" --binary --timing --assert -Wno-fatal --trace --top-module "$top" \
    -j "$TB_JOBS" --Mdir "$outdir/obj" -o tb_sim \
    -f scripts/rtl_sources.f "tb/sv/${top}.sv" > "$outdir/compile.log" 2>&1 || {
      tail -n 100 "$outdir/compile.log" >&2; exit 1;
    }
  set +e
  "$outdir/obj/tb_sim" +SEED="$SEED" > "$outdir/sim.log" 2>&1
  rc=$?
  set -e
  cat "$outdir/sim.log"
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: $top HDL simulation failed (exit $rc); see $outdir/sim.log" >&2
    exit "$rc"
  fi
  if ! grep -Eq 'ALL G1( PRIMITIVE)? HDL CHECKS PASSED' "$outdir/sim.log"; then
    echo "FAIL: $top exited without functional pass marker" >&2
    exit 1
  fi
  echo "PASS: compiled HDL $top self-checking simulation"
done
