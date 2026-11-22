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
