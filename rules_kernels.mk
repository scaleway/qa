.PHONY: prepare_kernels
prepare_kernels:
	test -d kernel-tools || git clone --single-branch https://github.com/scaleway/kernel-tools


.PHONY: build_kernels
build_kernels: _setenv
	cd kernel-tools; make KERNEL="$(KERNEL)" build


.PHONY: test_kernels
test_kernels:
	@echo "Error: Not yet implemented"


.PHONY: deploy_kernels
deploy_kernels:
	@echo "Error: Not yet implemented"


.PHONY: clean_kernels
clean_kernels:
	@echo "Error: Not yet implemented"
