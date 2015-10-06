all: travis


.PHONY: travis
travis:
	@test `find . -name .todo | awk 'END{print NR}'` -eq 1 || (echo "Error: You need to only have 1 .todo file at a time. Exiting..."; exit 1)

	$(eval TYPE := $(shell find . -name .todo | cut -d/ -f2))
	$(eval URI := $(shell find . -name .todo | sed 's@^./[^/]*/@@;s@/[0-9]*/.todo$$@@'))
	$(eval REVISION := $(shell find . -name .todo | sed 's@.*/\([0-9]*\)/.todo$$@\1@'))
	URI="$(URI)" REVISION="$(REVISION)" $(MAKE) "travis_$(TYPE)"


.PHONY: travis_kernels
travis_kernels:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building kernel..."

	$(eval KERNEL := $(shell echo "$(URI)" | sed 's@github.com/scaleway/kernel-tools/@@'))
	test -d kernel-tools || git clone --single-branch https://github.com/scaleway/kernel-tools
	cd kernel-tools; make KERNEL="$(KERNEL)" build


.PHONY: travis_images
travis_images:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building image..."

	$(eval REPONAME := $(shell echo $(URI) | cut -d/ -f3))
	$(eval REPOURL := $(shell echo $(URI) | cut -d/ -f1-3))
	$(eval SUBDIR := $(shell echo $(URI) | cut -d/ -f4-))

	test -d tmp/$(REPONAME) || (mkdir -p tmp; cd tmp; git clone --single-branch https://$(REPOURL))
	cd tmp/$(REPONAME); make build

.PHONY: travis_initrds
travis_initrd:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building initrd..."

	@echo "Error: Not yet implemented"; exit 1
