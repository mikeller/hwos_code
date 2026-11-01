.PHONY: build install clean

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
install:
	DEVICE='$(DEVICE)' \
	FIRMWARE_INSTALLER='$(FIRMWARE_INSTALLER)' DC_VENDOR='$(DC_VENDOR)' DC_PRODUCT='$(DC_PRODUCT)' \
	./tools/install_hwos.sh

clean:
	rm -rf build
