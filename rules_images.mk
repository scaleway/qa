.PHONY: prepare_images
prepare_images: _prepare_images_setup_server


.PHONY: _prepare_images_setup_server
_prepare_images_setup_server: _setenv _docker_login _scw_login _prepare_images_spawn_server _netrc_login
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
	scw exec $(SERVER) "cd "$(REPONAME)"; git log HEAD^..HEAD"


.PHONY: _prepare_images_spawn_server
_prepare_images_spawn_server: _scw_login _sshkey
	@$(MAKE) clean_images

	@echo "[+] Picking a builder..."
	scw ps --filter=tags=permanent-builder -q | shuf | head -n1 > .tmp/server
	@#scw run -d --tmp-ssh-key --name=qa-image-builder --env="image=$(REPONAME)" image-builder | tee .tmp/server


.PHONY: build_images
build_images: _setenv
	@echo "[+] Building the image..."
	scw exec $(SERVER) 'cd "$(REPONAME)/$(SUBDIR)"; make build'


.PHONY: test_images
test_images: _setenv
	@echo "WARNING: NOT YET IMPLEMENTED"


.PHONY: deploy_images
deploy_images: _setenv
	@echo "[+] Releasing image on docker hub..."
	scw exec $(SERVER) 'cd "$(REPONAME)/$(SUBDIR)"; make release'

	@echo "[+] Publishing on store..."
	scw exec $(SERVER) 'cd "$(REPONAME)/$(SUBDIR)"; make publish_on_store_sftp STORE_USERNAME=$(STORE_USERNAME) STORE_HOSTNAME=$(STORE_HOSTNAME)'

	@echo "[+] Creating a scaleway image..."
	scw exec $(SERVER) 'cd "$(REPONAME)/$(SUBDIR)"; make image_on_local'


.PHONY: clean_images
clean_images: _setenv
	@echo "[+] Cleaning up..."
	@test -f ~/.scw-cache.db && scw _flush-cache >/dev/null || true
	(for server in `scw ps -f "tags=image=$(REPONAME) name=qa-image-builder" -q`; do scw stop -t "$$server" & scw rm -f "$$server" & done; wait `jobs -p` || true) 2>/dev/null
	@test -f ~/.scw-cache.db && scw _flush-cache >/dev/null || true
	rm -f .tmp/server
