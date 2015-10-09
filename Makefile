all: travis


.PHONY: scw_login
scw_login: $(HOME)/.scwrc


$(HOME)/.scwrc:
	@if [ "$(TRAVIS_SCALEWAY_TOKEN)" -a "$(TRAVIS_SCALEWAY_ORGANIZATION)" ]; then \
	  echo '{"api_endpoint":"https://api.scaleway.com/","account_endpoint":"https://account.scaleway.com/","organization":"$(TRAVIS_SCALEWAY_ORGANIZATION)","token":"$(TRAVIS_SCALEWAY_TOKEN)"}' > ~/.scwrc && \
	  chmod 600 ~/.scwrc; \
	else \
	  echo "Cannot login, credentials are missing"; \
	  exit 1; \
	fi


.PHONY: travis
travis:
	@echo travis_pull_request='$(TRAVIS_PULL_REQUEST)' travis_commit='$(TRAVIS_COMMIT)' travis_tag='$(TRAVIS_TAG)' travis_branch='$(TRAVIS_BRANCH)'

	@test `git diff --name-status master...HEAD | grep '/.build' | awk 'END{print NR}'` -eq 1 || (echo "Error: You need to have one and only one '.build' file at a time. Exiting..."; exit 1)

	$(eval TYPE := $(shell find . -name ".build" | cut -d/ -f2))
	$(eval URI := $(shell find . -name ".build" | sed 's@^./[^/]*/@@;s@/[0-9]*/\\.build$$@@'))
	$(eval REVISION := $(shell find . -name ".build" | sed 's@.*/\([0-9]*\)/\\.build$$@\1@'))

	@# run outside of travis
	test -n "$(TRAVIS)" || URI="$(URI)" REVISION="$(REVISION)" $(MAKE) "travis_$(TYPE)"
	@# run on travis only for pull-requests
	test -z "$(TRAVIS)" -o "$(TRAVIS_PULL_REQUEST)" = false || URI="$(URI)" REVISION="$(REVISION)" $(MAKE) "travis_$(TYPE)"

	@# run on travis for non pull-requests
	test -n "$(TRAVIS)" -a "$(TRAVIS_PULL_REQUEST)" = false && echo "Not on a PR, nothing to do" || true


.PHONY: travis_kernels
travis_kernels:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building kernel..."

	$(eval KERNEL := $(shell echo "$(URI)" | sed 's@github.com/scaleway/kernel-tools/@@'))
	test -d kernel-tools || git clone --single-branch https://github.com/scaleway/kernel-tools
	cd kernel-tools; make KERNEL="$(KERNEL)" build


.PHONY: travis_images
travis_images: scw_login
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)

	$(eval REPONAME := $(shell echo $(URI) | cut -d/ -f3))
	$(eval REPOURL := $(shell echo $(URI) | cut -d/ -f1-3))
	$(eval SUBDIR := $(shell echo $(URI) | cut -d/ -f4-))

	@echo "[+] Flushing cache..."
	test -f ~/.scw-cache.db && scw _flush-cache || true

	@echo "[+] Cleaning old builder(s) if any..."
	(for server in `scw ps -f name=qa-image-builder -q`; do scw stop -t $$server & scw rm -f $$server & done; wait `jobs -p` || true) 2>/dev/null

	@echo "[+] Flushing cache after cleanup..."
	test -f ~/.scw-cache.db && scw _flush-cache || true

	@echo "[+] Generating an ssh key if needed..."
	test -f $(HOME)/.ssh/id_rsa || ssh-keygen -t rsa -f $(HOME)/.ssh/id_rsa -N ""

	@echo "[+] Spawning a new builder..."
	scw -D run --detach --tmp-ssh-key --name=qa-image-builder image-builder 2>&1 | anonuuid

	@echo "[+] Waiting for server to be available..."
	echo | scw exec -w -T=300 image-builder uptime

	@echo "[+] Getting information about the server..."
	scw inspect server:image-builder | anonuuid

	@echo "[+] Logging in to Docker hub..."
	@test -z "$(TRAVIS_DOCKER_EMAIL)" || (scw exec image-builder docker login -e="$(TRAVIS_DOCKER_EMAIL)" -u="$(TRAVIS_DOCKER_USERNAME)" -p="$(TRAVIS_DOCKER_PASSWORD)")
	scw exec image-builder docker version
	scw exec image-builder docker info

	@echo "[+] Logging in to scw..."
	@scw exec image-builder scw login --organization=$(shell cat ~/.scwrc | jq .organization) --token=$(shell cat ~/.scwrc | jq .token) -s

	@echo "[+] Fetching the image sources..."
	scw exec image-builder git clone --single-branch https://$(REPOURL)

	@echo "[+] Building the image..."
	scw exec image-builder 'cd $(REPONAME); make build'

	@echo "[+] Releasing image on docker hub..."
	scw exec image-builder 'cd $(REPONAME); make release'

	# FIXME: push on store

	@echo "[+] Creating a scaleway image..."
	scw exec image-builder 'cd $(REPONAME); make image_on_local'

	# Test image

	@echo "[+] Cleaning up..."
	(scw stop -t qa-image-builder & scw rm -f qa-image-builder & wait `jobs -p` || true) 2>/dev/null

.PHONY: travis_initrds
travis_initrd:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building initrd..."

	@echo "Error: Not yet implemented"; exit 1
