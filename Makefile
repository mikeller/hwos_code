.PHONY: build clean

# Override C18_BIN or individual tool variables for a non-default C18 install.
# Example: make build C18_BIN=/opt/microchip/mplabc18/v3.47/bin
build:
	./tools/build_hwos.sh

clean:
	rm -rf build
