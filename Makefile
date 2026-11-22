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
