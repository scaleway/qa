.PHONY: prepare_images
prepare_images: _prepare_images_setup_server


.PHONY: _prepare_images_setup_server
_prepare_images_setup_server: _setenv
	if [ "${IMAGE_ARCH}" = "armv7l" ]; then        \
	  $(MAKE) _prepare_images_setup_server_scw;    \
	else                                           \
	  $(MAKE) _prepare_images_setup_server_local;  \
	fi


.PHONY: _prepare_images_setup_server_scw
_prepare_images_setup_server_scw: _setenv _docker_login _scw_login _netrc_login _sshkey _prepare_build_server
	$(eval SERVER := $(shell test -f .tmp/server && cat .tmp/server || echo ""))
	@echo "[+] Waiting for server to be available..."
	scw exec -w -T=300 $(SERVER) uptime

	@echo "[+] Getting information about the server..."
	scw inspect server:$(SERVER) | anonuuid

	@echo "[+] Writing up builder:~/.dockercfg"
	@scw exec $(SERVER) "echo -n `openssl enc -base64 -A -in ~/.dockercfg` | openssl base64 -d -A > ~/.dockercfg"
	@echo "[+] Writing up builder:~/.netrc"
	@scw exec $(SERVER) "echo -n `openssl enc -base64 -A -in ~/.netrc` | openssl base64 -d -A > ~/.netrc"
	@echo "[+] Writing up builder:~/.docker/config.json"
	@scw exec $(SERVER) "mkdir -p .docker; echo -n `openssl enc -base64 -A -in ~/.docker/config.json` | openssl base64 -d -A > ~/.docker/config.json"
	scw exec $(SERVER) docker version
	scw exec $(SERVER) docker info

	@echo "[+] Writing up builder:~/.scwrc"
	@scw exec $(SERVER) scw login --organization="$(shell cat ~/.scwrc | jq .organization)" --token="$(shell cat ~/.scwrc | jq .token)" -s

	@echo "[+] Fetching the image sources..."
	scw exec $(SERVER) rm -rf "./$(REPONAME)"
	scw exec $(SERVER) git clone --single-branch "https://$(REPOURL)"
	scw exec $(SERVER) "cd "$(REPONAME)"; git show --summary | cat"


.PHONY: _prepare_images_setup_server_local
_prepare_images_setup_server_local: _setenv _docker_login _netrc_login _scw_login _sshkey
	docker version
	docker info

	@echo "[+] Fetching the image sources..."
	rm -rf "./$(REPONAME)"
	git clone --single-branch "https://$(REPOURL)"
	cd "$(REPONAME)"; git show --summary | cat


.PHONY: build_images
build_images: _setenv
	@echo "[+] Building the image..."
	if [ "${IMAGE_ARCH}" = "armv7l" ]; then \
	  scw exec $(SERVER) 'cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make build ARCH="$(IMAGE_ARCH)" BUILD_OPTS="--pull"'; \
	else \
	  cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make build ARCH="$(IMAGE_ARCH)" BUILD_OPTS="--pull"; \
	fi


.PHONY: test_images
test_images: _setenv
	@echo "WARNING: NOT YET IMPLEMENTED"


.PHONY: deploy_images
deploy_images: _setenv
	if [ "${IMAGE_ARCH}" = "armv7l" ]; then       \
	  $(MAKE) deploy_images_scw;                  \
	else                                          \
	  $(MAKE) deploy_images_local;                \
	fi


.PHONY: deploy_images_scw
deploy_images_scw: _setenv
	@echo "[+] Releasing image on docker hub..."
	scw exec $(SERVER) 'cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make ARCH="$(IMAGE_ARCH)" release'

	@echo "[+] Publishing on store..."
	scw exec $(SERVER) 'cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make ARCH="$(IMAGE_ARCH)" publish_on_store_sftp STORE_USERNAME=$(STORE_USERNAME) STORE_HOSTNAME=$(STORE_HOSTNAME)'

	@echo "[+] Creating a scaleway image..."
	scw exec $(SERVER) 'cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make ARCH="$(IMAGE_ARCH)" image_on_local'


.PHONY: deploy_images_local
deploy_images_local: _setenv
	@echo "[+] Releasing image on docker hub..."
	cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make ARCH="$(IMAGE_ARCH)" release

	@echo "[+] Publishing on store..."
	cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make ARCH="$(IMAGE_ARCH)" publish_on_store_sftp STORE_USERNAME=$(STORE_USERNAME) STORE_HOSTNAME=$(STORE_HOSTNAME)

	@echo "[+] Creating a scaleway image..."
	cd "$(REPONAME)/$(IMAGE_SUBDIR)"; make ARCH="$(IMAGE_ARCH)" image_on_store STORE_HOSTNAME=$(STORE_HOSTNAME) STORE_PATH=$(STORE_USERNAME)/images


.PHONY: clean_images
clean_images: _setenv
	@echo "[+] Cleaning up..."
	@test -f ~/.scw-cache.db && scw _flush-cache >/dev/null || true
	(for server in `scw ps -f "tags=image=$(REPONAME) name=qa-image-builder" -q`; do scw stop -t "$$server" & scw rm -f "$$server" & done; wait `jobs -p` || true) 2>/dev/null
	@test -f ~/.scw-cache.db && scw _flush-cache >/dev/null || true
	rm -f .tmp/server
