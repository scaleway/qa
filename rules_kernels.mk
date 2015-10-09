.PHONY: travis_kernels
travis_kernels: _setenv
	@echo "Building kernel..."

	$(eval KERNEL := $(shell echo "$(URI)" | sed 's@github.com/scaleway/kernel-tools/@@'))
	test -d kernel-tools || git clone --single-branch https://github.com/scaleway/kernel-tools
	cd kernel-tools; make KERNEL="$(KERNEL)" build
