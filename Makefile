all: travis


ACTIONS = prepare build test deploy clean


.PHONY: _scw_login
_scw_login: $(HOME)/.scwrc
$(HOME)/.scwrc:
	@if [ "$(TRAVIS_SCALEWAY_TOKEN)" -a "$(TRAVIS_SCALEWAY_ORGANIZATION)" ]; then \
	  echo '{"api_endpoint":"https://api.scaleway.com/","account_endpoint":"https://account.scaleway.com/","organization":"$(TRAVIS_SCALEWAY_ORGANIZATION)","token":"$(TRAVIS_SCALEWAY_TOKEN)"}' > ~/.scwrc && \
	  chmod 600 ~/.scwrc; \
	else \
	  echo "Cannot login, credentials are missing"; \
	  exit 1; \
	fi


.PHONY: _docker_login
_docker_login: $(HOME)/.dockercfg
$(HOME)/.dockercfg:
	@test -n "$(TRAVIS_DOCKER_EMAIL)" && docker login -e="$(TRAVIS_DOCKER_EMAIL)" -u="$(TRAVIS_DOCKER_USERNAME)" -p="$(TRAVIS_DOCKER_PASSWORD)"


.PHONY: _sshkey
_sshkey: $(HOME)/.ssh/id_rsa
$(HOME)/.ssh/id_rsa:
	@echo "[+] Generating an ssh key if needed..."
	test -f $(HOME)/.ssh/id_rsa || ssh-keygen -t rsa -f $(HOME)/.ssh/id_rsa -N ""


.PHONY: _setenv
_setenv:
	@mkdir -p .tmp
	@#echo travis_pull_request='$(TRAVIS_PULL_REQUEST)' travis_commit='$(TRAVIS_COMMIT)' travis_tag='$(TRAVIS_TAG)' travis_branch='$(TRAVIS_BRANCH)'
	@test `git diff --name-status master...HEAD | grep '/.build' | awk 'END{print NR}'` -eq 1 || (echo "Error: You need to have one and only one '.build' file at a time. Exiting..."; exit 1); \

	$(eval TYPE := $(shell find . -name ".build" | cut -d/ -f2))
	$(eval URI := $(shell find . -name ".build" | sed 's@^./[^/]*/@@;s@/[0-9]*/\\.build$$@@'))
	$(eval REVISION := $(shell find . -name ".build" | sed 's@.*/\([0-9]*\)/\\.build$$@\1@'))
	$(eval REPONAME := $(shell echo $(URI) | cut -d/ -f3))
	$(eval REPOURL := $(shell echo $(URI) | cut -d/ -f1-3))
	$(eval SUBDIR := $(shell echo $(URI) | cut -d/ -f4))
	$(eval SERVER := $(shell test -f .tmp/server && cat .tmp/server || echo ""))


.PHONY: travis
travis: _setenv
	@test -z "$(TRAVIS)" || (echo "'make travis' is made for testing travis-like build outside of travis"; exit 1)

	$(MAKE) prepare_$(TYPE)
	$(MAKE) build_$(TYPE)
	$(MAKE) test_$(TYPE)
	$(MAKE) deploy_$(TYPE)
	$(MAKE) clean_$(TYPE)


.PHONY: $(ACTIONS)
$(ACTIONS): _setenv
	$(MAKE) $@_$(TYPE)


-include ./rules_images.mk
-include ./rules_kernels.mk
-include ./rules_initrds.mk
