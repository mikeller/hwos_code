.PHONY: build install clean check host-check

FIRMWARE_INSTALLER ?= subsurface-downloader
DC_VENDOR ?= Heinrichs Weikamp
DC_PRODUCT ?= OSTC 3
DEVICE ?=

# Optional developer-specific installation settings. A local.mk may set DEVICE
# to an exact Bluetooth address. A command-line DEVICE= value always overrides
# this local default.
-include local.mk

# Builds the checked-out, pushed commit on the configured Windows C18 builder.
# Copy tools/build_hwos.remote.conf.example to the ignored .conf file first.
build:
	./tools/build_hwos.sh

# No device is selected unless local.mk or an explicit DEVICE= value supplies one.
install: export DEVICE := $(value DEVICE)
install: export FIRMWARE_INSTALLER := $(value FIRMWARE_INSTALLER)
install: export DC_VENDOR := $(value DC_VENDOR)
install: export DC_PRODUCT := $(value DC_PRODUCT)
install:
	./tools/install_hwos.sh

clean:
	rm -rf build

# --- Host-only sanity build, no licence required -------------------------
#
# src/p2_deco.c, src/compass.c and src/compass_calib.c already have a
# cross-compile path for Visual C/host GCC: src/p2_definitions.h (lines
# 47-56) defines CROSS_COMPILE/__18CXX and neutralises the C18-only `ram`,
# `rom`, `overlay` and `PARAMETER` keywords when UNIX or WIN32 is defined,
# and all three files guard their `#pragma udata`/`#pragma romdata` blocks
# with `#ifndef UNIX`. `check` exercises that path with the host GCC. It is
# a compile-only syntax/definition sanity check: it never links, never runs
# the resulting objects, and writes only into the ignored build/host-check
# directory. It is not a firmware build and proves nothing about the C18
# link or device behaviour; see doc/building.md.
#
# -Wall -Wextra is intentionally non-blocking: this is 2010s embedded C
# with a substantial pre-existing warning backlog (see doc/building.md,
# "Cloud CI assessment"). Only an actual compile error fails this target;
# warnings are counted and reported, not gated, and must not be silenced
# wholesale.
HOST_CHECK_DIR := build/host-check
HOST_CHECK_SOURCES := src/p2_deco.c src/compass.c src/compass_calib.c
HOST_CHECK_CFLAGS := -DUNIX -Wall -Wextra

check: host-check

host-check:
	@mkdir -p $(HOST_CHECK_DIR)
	@status=0; \
	for src in $(HOST_CHECK_SOURCES); do \
		base=$$(basename "$${src%.c}"); \
		obj="$(HOST_CHECK_DIR)/$$base.o"; \
		log="$(HOST_CHECK_DIR)/$$base.log"; \
		echo "host-check: compiling $$src"; \
		if ! gcc $(HOST_CHECK_CFLAGS) -c "$$src" -o "$$obj" 2>"$$log"; then \
			status=1; \
		fi; \
		cat "$$log" >&2; \
		count=$$(grep -c 'warning:' "$$log"); \
		echo "host-check: $$src: $$count warning(s)"; \
	done; \
	exit $$status
