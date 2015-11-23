.PHONY: prepare_initrds
prepare_initrds:
	test -d workspace || git clone --single-branch https://github.com/scaleway/initrd workspace


.PHONY: build_initrds
build_initrds:
	cd workspace/Linux; make build TARGET=armv7l
	cd workspace/Linux; make build TARGET=x86_64


.PHONY: test_initrds
test_initrds:
	@echo "Error: Not yet implemented"


.PHONY: deploy_initrds
deploy_initrds: _s3cmd_login
	cd workspace/Linux; make publish_on_s3 TARGET=armv7l
	cd workspace/Linux; make publish_on_s3 TARGET=x86_64
	@cd workspace/Linux; make publish_on_store_sftp TARGET=armv7l
	@cd workspace/Linux; make publish_on_store_sftp TARGET=x86_64


.PHONY: clean_initrds
clean_initrds:
	-
