#############################################################################
# Makefile for building: TrueNAS SCALE
#############################################################################
PYTHON?=/usr/bin/python3
COMMIT_HASH=$(shell git rev-parse --short HEAD)
PACKAGES?=""
ISO_DIR?=""
ISO_PATH?=""
UPDATE_FILE_PATH?=""
REPO_CHANGED=$(shell if [ -d "./venv-$(COMMIT_HASH)" ]; then git status --porcelain | grep -c "scale_build/"; else echo "1"; fi)
# Check if --break-system-packages flag is supported by pip
BREAK_SYS_PKGS_FLAG=$(shell ${PYTHON} -m pip help install | grep -q -- '--break-system-packages' && echo "--break-system-packages" || echo "")

.DEFAULT_GOAL := all
DEST_DIR="./pip-packages"

check:
ifneq ($(REPO_CHANGED),0)
	@echo "Setting up new virtual environment"
	@rm -rf venv-*
	@${PYTHON} -m pip install $(BREAK_SYS_PKGS_FLAG) -U virtualenv >/dev/null || { echo "Failed to install/upgrade virtualenv package"; exit 1; }
	@${PYTHON} -m venv venv-${COMMIT_HASH} || { echo "Failed to create virutal environment"; exit 1; }
endif

all: checkout packages update iso

pipinstall:
	@{ . ./venv-${COMMIT_HASH}/bin/activate && \
		python3 -m pip install --find-links=$(DEST_DIR) -r requirements.txt >/dev/null 2>&1 && \
		python3 -m pip install . >/dev/null 2>&1; } || { echo "Failed to install scale-build"; exit 1; }

pipcache:
	@{ . ./venv-${COMMIT_HASH}/bin/activate && \
		if [ ! -d "$(DEST_DIR)" ]; then \
			mkdir -p "$(DEST_DIR)"; \
			python3 -m pip download -r requirements.txt -d "$(DEST_DIR)"; \
		fi; }
clean: check
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build clean
checkout: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build checkout
check_upstream_package_updates: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build check_upstream_package_updates
iso: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build iso
packages: check pipcache pipinstall
ifeq ($(PACKAGES),"")
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build packages
else
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build packages --packages ${PACKAGES}
endif
update: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build update
validate_manifest: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build validate --no-validate-system_state
validate: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build validate

branchout: checkout pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build branchout $(args)
del:
	sudo rm -rf logs/
	sudo rm -rf tmp/tmpfs/chroot/
	sudo rm -rf venv-*
	sudo rm -rf "$(DEST_DIR)"
test: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && pytest scale_build/tests/unit/test_package_rebuild_logic.py -vs
testb: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && pytest scale_build/tests/unit/test_binary_packages.py -vs
packiso: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build packiso --packiso ${ISO_DIR}
unpackiso: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build unpackiso --unpackiso ${ISO_PATH}
updateinstall: check pipcache pipinstall
	. ./venv-${COMMIT_HASH}/bin/activate && scale_build updateinstall --updateinstall ${UPDATE_FILE_PATH}