all: travis


.PHONY: travis
travis:
	@test `find . -name .todo | awk 'END{print NR}'` -eq 1 || (echo "Error: You need to only have 1 .todo file at a time. Exiting..."; exit 1)

	$(eval TYPE := $(shell find . -name .todo | cut -d/ -f2))
	$(eval URI := $(shell find . -name .todo | sed 's@^./kernels/@@;s@/[0-9]*/.todo$$@@'))
	$(eval REVISION := $(shell find . -name .todo | sed 's@.*/\([0-9]*\)/.todo$$@\1@'))
	URI="$(URI)" REVISION="$(REVISION)" $(MAKE) "travis_$(TYPE)"


.PHONY: travis_kernels
travis_kernels:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building kernel..."

	@echo "Error: Not yet implemented"; exit 1


.PHONY: travis_images
travis_images:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building image..."

	@echo "Error: Not yet implemented"; exit 1


.PHONY: travis_initrds
travis_images:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building image..."

	@echo "Error: Not yet implemented"; exit 1
