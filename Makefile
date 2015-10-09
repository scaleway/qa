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

	@if [ -z "$(TRAVIS)" -o "$(TRAVIS_PULL_REQUEST)" != false ]; then \
	  test `git diff --name-status master...HEAD | grep '/.build' | awk 'END{print NR}'` -eq 1 || (echo "Error: You need to have one and only one '.build' file at a time. Exiting..."; exit 1); \
	fi

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
	$(eval SUBDIR := $(shell echo $(URI) | cut -d/ -f4))

	@echo "[+] Flushing cache..."
	test -f ~/.scw-cache.db && scw _flush-cache || true

	@echo "[+] Cleaning old builder(s) if any..."
	(for server in `scw ps -f "tags=image=$(REPONAME) name=qa-image-builder" -q`; do scw stop -t $$server & scw rm -f $$server & done; wait `jobs -p` || true)

	@echo "[+] Flushing cache after cleanup..."
	test -f ~/.scw-cache.db && scw _flush-cache || true

	@echo "[+] Generating an ssh key if needed..."
	test -f $(HOME)/.ssh/id_rsa || ssh-keygen -t rsa -f $(HOME)/.ssh/id_rsa -N ""

	@echo "[+] Spawning a new builder..."
	$(eval SERVER := $(shell scw -D run -d --tmp-ssh-key --name=qa-image-builder --env="image=$(REPONAME)" image-builder))

	@echo "[+] Waiting for server to be available..."
	scw exec -w -T=300 $(SERVER) uptime

	@echo "[+] Getting information about the server..."
	scw inspect server:$(SERVER) | anonuuid

	@echo "[+] Logging in to Docker hub..."
	@test -z "$(TRAVIS_DOCKER_EMAIL)" || (scw exec $(SERVER) docker login -e="$(TRAVIS_DOCKER_EMAIL)" -u="$(TRAVIS_DOCKER_USERNAME)" -p="$(TRAVIS_DOCKER_PASSWORD)")
	scw exec $(SERVER) docker version
	scw exec $(SERVER) docker info

	@echo "[+] Logging in to scw..."
	@scw exec $(SERVER) scw login --organization=$(shell cat ~/.scwrc | jq .organization) --token=$(shell cat ~/.scwrc | jq .token) -s

	@echo "[+] Fetching the image sources..."
	scw exec $(SERVER) git clone --single-branch https://$(REPOURL)

	@echo "[+] Building the image..."
	scw exec $(SERVER) 'cd $(REPONAME)/$(SUBDIR); make build'

	@echo "[+] Releasing image on docker hub..."
	scw exec $(SERVER) 'cd $(REPONAME)/$(SUBDIR); make release'

	# FIXME: push on store

	@echo "[+] Creating a scaleway image..."
	scw exec $(SERVER) 'cd $(REPONAME)/$(SUBDIR); make image_on_local'

	# Test image

	@echo "[+] Cleaning up..."
	(for server in `scw ps -f "tags=image=$(REPONAME) name=qa-image-builder" -q`; do scw stop -t $$server & scw rm -f $$server & done; wait `jobs -p` || true)

.PHONY: travis_initrds
travis_initrd:
	@test -n "$(URI)" || (echo "Error: URI is missing"; exit 1)
	@test -n "$(REVISION)" || (echo "Error: REVISION is missing"; exit 1)
	@echo "Building initrd..."

	@echo "Error: Not yet implemented"; exit 1
