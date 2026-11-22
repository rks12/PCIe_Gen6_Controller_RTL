# PCIe 6.0 FLIT RTL datapath foundation build commands.
PYTHON ?= python3
.PHONY: check lint sources clean
check:
	$(PYTHON) scripts/source_audit.py
	$(PYTHON) scripts/protocol_reference.py
lint:
	bash scripts/lint.sh
sources:
	cat scripts/rtl_sources.f
clean:
	rm -rf build/ .pytest_cache/ __pycache__/

# G1 executable testbench. These targets are REAL HDL simulation when
# Verilator >=5 is installed; they fail if no simulator or test failure.
.PHONY: tb-model tb-vectors tb-smoke tb-primitives tb-unit tb-regression
TB_SEED ?= 17
tb-model:
	$(PYTHON) tb/python/test_reference.py
tb-vectors:
	$(PYTHON) tb/python/gen_vectors.py --seed $(TB_SEED)
tb-smoke:
	SEED=$(TB_SEED) MODE=top bash tb/scripts/run_g1.sh
tb-primitives:
	SEED=$(TB_SEED) MODE=primitives bash tb/scripts/run_g1.sh
tb-unit:
	SEED=$(TB_SEED) MODE=all bash tb/scripts/run_g1.sh
tb-regression:
	@set -e; for seed in 1 17 42 2026; do \
	  echo "RTL testbench seed=$$seed"; \
	  SEED=$$seed MODE=all bash tb/scripts/run_g1.sh; \
	done

# UVM environment: needs an IEEE 1800.2 UVM-capable HDL simulator.
.PHONY: tb-uvm tb-uvm-regression uvm-audit
uvm-audit:
	$(PYTHON) tb/uvm/structural_check.py
tb-uvm: uvm-audit
	SEED=$(TB_SEED) SIM=$${SIM:-questa} UVM_TESTNAME=$${UVM_TESTNAME:-pcie_g6_smoke_test} bash tb/scripts/run_uvm.sh
tb-uvm-regression: uvm-audit
	@set -e; for test in pcie_g6_smoke_test pcie_g6_random_test pcie_g6_negative_test pcie_g6_linkloss_test pcie_g6_width_test; do \
	  echo "UVM: $$test"; SEED=$(TB_SEED) SIM=$${SIM:-questa} UVM_TESTNAME=$$test bash tb/scripts/run_uvm.sh; \
	done
