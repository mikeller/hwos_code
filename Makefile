.PHONY: build clean

# Builds the checked-out, pushed commit on the configured Windows C18 builder.
# Copy tools/build_hwos.remote.conf.example to the ignored .conf file first.
build:
	./tools/build_hwos.sh

clean:
	rm -rf build
