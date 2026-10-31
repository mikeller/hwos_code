.PHONY: build install clean

FIRMWARE_INSTALLER ?= subsurface-downloader
DC_VENDOR ?= Heinrichs Weikamp
DC_PRODUCT ?= OSTC 3

# Builds the checked-out, pushed commit on the configured Windows C18 builder.
# Copy tools/build_hwos.remote.conf.example to the ignored .conf file first.
build:
	./tools/build_hwos.sh

# No device is selected by default. `make install` requires both DEVICE and an
# explicit acknowledgement of the UNVALIDATED firmware state; see doc/building.md.
install:
	DEVICE='$(DEVICE)' CONFIRM_UNVALIDATED_OSTC3='$(CONFIRM_UNVALIDATED_OSTC3)' \
	FIRMWARE_INSTALLER='$(FIRMWARE_INSTALLER)' DC_VENDOR='$(DC_VENDOR)' DC_PRODUCT='$(DC_PRODUCT)' \
	./tools/install_hwos.sh

clean:
	rm -rf build
