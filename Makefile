all: travis


ACTIONS = prepare build test deploy clean


.PHONY: _scw_login
_scw_login: $(HOME)/.scwrc
$(HOME)/.scwrc:
	@echo "Writing ~/.scwrc"
	@if [ "$(TRAVIS_SCALEWAY_TOKEN)" -a "$(TRAVIS_SCALEWAY_ORGANIZATION)" ]; then \
	  scw login --organization="$(TRAVIS_SCALEWAY_ORGANIZATION)" --token="$(TRAVIS_SCALEWAY_TOKEN)" -s; \
	else \
	  echo "Cannot login to 'scw', credentials are missing"; \
	  exit 1; \
	fi


.PHONY: _s3cmd_login
_s3cmd_login: $(HOME)/.s3cfg
$(HOME)/.s3cfg:
	@echo "Writing ~/.s3cfg"
	wget https://raw.githubusercontent.com/scaleway/image-tools/master/image-builder/s3cfg_template -O $@
	@if [ "$(TRAVIS_SCALEWAY_TOKEN)" -a "$(TRAVIS_SCALEWAY_ORGANIZATION)" ]; then \
	  echo access_key=$(TRAVIS_SCALEWAY_ORGANIZATION) >> $@; \
	  echo secret_key=$(TRAVIS_SCALEWAY_TOKEN) >> $@; \
	else \
	  echo "Cannot login to 's3cmd', credentials are missing"; \
	  exit 1; \
	fi

.PHONY: _netrc_login
_netrc_login: $(HOME)/.netrc
$(HOME)/.netrc:
	@echo "Writing ~/.netrc"
	@if [ "$(STORE_HOSTNAME)" -a "$(STORE_USERNAME)" -a "$(STORE_PASSWORD)" ]; then \
	  echo machine "$(STORE_HOSTNAME)" > $@; \
	  echo login "$(STORE_USERNAME)" >> $@; \
	  echo password "$(STORE_PASSWORD)" >> $@; \
	else \
	  echo "Cannot login to 'netrc', credentials are missing"; \
	  exit 1; \
	fi
	chmod 600 $@


.PHONY: _docker_login
_docker_login: $(HOME)/.dockercfg


.PHONY: $(HOME)/.dockercfg
$(HOME)/.dockercfg:
	@echo "Writing ~/.dockercfg"
	@if [ ! -s $@ ]; then \
	  echo "Generating ~/.dockercfg file"; \
	  test -n "$(TRAVIS_DOCKER_EMAIL)" && docker login -e="$(TRAVIS_DOCKER_EMAIL)" -u="$(TRAVIS_DOCKER_USERNAME)" -p="$(TRAVIS_DOCKER_PASSWORD)"; \
	  touch $@; \
	  mkdir -p $(HOME)/.docker; \
	  touch $(HOME)/.docker/config.json; \
	fi


.PHONY: _sshkey
_sshkey: $(HOME)/.ssh/id_rsa
$(HOME)/.ssh/id_rsa:
	@echo "Writing ~/.ssh/id_rsa"
	@if [ -z "$(TRAVIS_SSH_PRIV_KEY)" ]; then \
	  echo "[+] Generating an ssh key if needed..."; \
	  test -f $@ || ssh-keygen -t rsa -f $@ -N ""; \
	else \
	  echo "[+] Writing ssh key from environment..."; \
	  echo $(TRAVIS_SSH_PRIV_KEY) | tr "@" "\n" | tr "_" " " > $@; \
	  chmod 600 $@; \
	fi


.PHONY: _setenv
_setenv:
	@mkdir -p .tmp
	@#echo travis_pull_request='$(TRAVIS_PULL_REQUEST)' travis_commit='$(TRAVIS_COMMIT)' travis_tag='$(TRAVIS_TAG)' travis_branch='$(TRAVIS_BRANCH)'
	@test `git diff --name-status master...HEAD | grep '/.build' | awk 'END{print NR}'` -eq 1 || (echo "Error: You need to have one and only one '.build' file at a time. Exiting..."; exit 1); \

	$(eval CHANGES := $(shell git diff --name-status master...HEAD | grep '/.build' | awk '{ print $$2 }'))
	$(eval TYPE := $(shell echo $(CHANGES) | cut -d/ -f1))
	$(eval URI := $(shell echo $(CHANGES) | sed 's@^[^/]*/@@;s@/[0-9]*/\.build$$@@'))
	$(eval REVISION := $(shell echo $(CHANGES) | sed 's@^.*/\([0-9]*\)/\.build$$@\1@'))
	$(eval REPONAME := $(shell echo $(URI) | cut -d/ -f3))
	$(eval REPOURL := $(shell echo $(URI) | cut -d/ -f1-3))
	$(eval SUBDIR := $(shell echo $(URI) | cut -d/ -f4-))

	@# Images specific
	$(eval SERVER := $(shell test -f .tmp/server && cat .tmp/server || echo ""))
	$(eval IMAGE_SUBDIR := $(shell echo $(SUBDIR) | sed 's@^\(.*\)/[^/]*$$@\1@'))
	$(eval IMAGE_ARCH := $(shell echo $(SUBDIR) | sed 's@^.*/\([^/]*\)$$@\1@'))

	@# Kernerls specific
	$(eval KERNEL := $(shell echo "$(URI)" | sed 's@github.com/scaleway/kernel-tools/@@'))


.PHONY: info
info: _setenv
	@echo changes='$(CHANGES)'
	@echo travis='$(TRAVIS)'
	@echo travis_pull_request='$(TRAVIS_PULL_REQUEST)'
	@echo travis_commit='$(TRAVIS_COMMIT)'
	@echo travis_branch='$(TRAVIS_BRANCH)'
	@echo travis_tag='$(TRAVIS_TAG)'
	@echo type='$(TYPE)'
	@echo uri='$(URI)'
	@echo revision='$(REVISION)'
	@echo reponame='$(REPONAME)'
	@echo repourl='$(REPOURL)'
	@echo subdir='$(SUBDIR)'
	@echo image_subdir='$(IMAGE_SUBDIR)'
	@echo image_arch='$(IMAGE_ARCH)'
	@echo server='$(SERVER)'
	@echo kernel='$(KERNEL)'


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
