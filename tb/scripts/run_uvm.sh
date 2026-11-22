#!/usr/bin/env bash
# Run the full SystemVerilog UVM environment against the currently implemented
# abstract FLIT DUT ports. External UVM RTL/library is required (not bundled).
# SIM=questa: Questa/ModelSim with UVM installed or precompiled (recommended).
# SIM=verilator: Verilator >=5.052 with Accellera UVM 2020-3.2 and UVM_HOME.
# NO TEST is reported PASS merely for source audit; actual simulator must exit 0
# and print the UVM error/fatal summary (run -all for Questa).
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${SIM:=questa}"
: "${UVM_TESTNAME:=pcie_g6_smoke_test}"
: "${SEED:=17}"
: "${PYTHON:=python3}"
: "${UVM_HOME:=}"
mkdir -p build/uvm
"$PYTHON" tb/python/gen_vectors.py --seed "$SEED" --output build/tb/vectors

case "$SIM" in
  questa)
    command -v vlog >/dev/null || { echo 'ERROR: Questa vlog not in PATH' >&2; exit 127; }
    command -v vsim >/dev/null || { echo 'ERROR: Questa vsim not in PATH' >&2; exit 127; }
    vlib build/uvm/work 2>/dev/null || true
    vmap work build/uvm/work >/dev/null
    vlog -sv -work work +incdir+tb/uvm \
      -f scripts/rtl_sources.f -f tb/uvm/uvm_sources.f \
      > build/uvm/compile.log 2>&1 || {
        tail -n 100 build/uvm/compile.log >&2; exit 1;
      }
    vsim -c -lib work \
      -sv_seed "$SEED" pcie_g6_tb_top \
      +UVM_TESTNAME="$UVM_TESTNAME" +PCIE_VECTORS_DIR=build/tb/vectors \
      -do 'run -all; quit -f' | tee build/uvm/sim.log
    ;;
  verilator)
    command -v verilator >/dev/null || { echo 'ERROR: verilator not in PATH' >&2; exit 127; }
    if [ -z "$UVM_HOME" ] || [ ! -f "$UVM_HOME/src/uvm_pkg.sv" ]; then
      echo 'ERROR: Set UVM_HOME to the Accellera UVM 2020-3.2 tree (with src/uvm_pkg.sv)' >&2
      exit 127
    fi
    # Latest UVM support requires Verilator >=5.052. This route is optional;
    # vendor simulator is the reference and current Ubuntu apt Verilator 5.020
    # is not sufficient for complete UVM compilation.
    if [ "${UVM_SKIP_BUILD:-0}" != "1" ]; then
      dpi_opts=()
      if [ -f "$UVM_HOME/src/dpi/uvm_dpi.cc" ]; then
        dpi_opts=(--vpi "$UVM_HOME/src/dpi/uvm_dpi.cc")
      else
        echo 'WARNING: UVM DPI backend missing; compiling reduced UVM_NO_DPI mode' >&2
        dpi_opts=(+define+UVM_NO_DPI)
      fi
      verilator --binary --timing --assert -Wno-fatal \
        -j 2 --top-module pcie_g6_tb_top \
        --Mdir build/uvm/obj -o uvm_sim \
        "${dpi_opts[@]}" +incdir+"$UVM_HOME/src" +incdir+tb/uvm \
        "$UVM_HOME/src/uvm_pkg.sv" \
        -f scripts/rtl_sources.f -f tb/uvm/uvm_sources.f \
        > build/uvm/compile.log 2>&1 || {
          tail -n 130 build/uvm/compile.log >&2; exit 1;
        }
    fi
    build/uvm/obj/uvm_sim +UVM_TESTNAME="$UVM_TESTNAME" \
      +PCIE_VECTORS_DIR=build/tb/vectors +verilator+seed+"$SEED" \
      | tee build/uvm/sim.log
    ;;
  *) echo 'ERROR: SIM must be questa or verilator' >&2; exit 2 ;;
esac
if grep -Eq 'UVM_(ERROR|FATAL)\s*:\s*[1-9]' build/uvm/sim.log; then
  echo 'FAIL: UVM summary reports errors or fatals' >&2
  exit 1
fi
if ! grep -q 'G6_SCOREBOARD' build/uvm/sim.log; then
  echo 'FAIL: no scoreboard execution evidence' >&2
  exit 1
fi
printf 'PASS: UVM simulator ran %s (seed=%s) without reported errors\n' "$UVM_TESTNAME" "$SEED"
