GOCMD?=go
GOFLAGS?=-mod=vendor
PACK_VERSION?=dev-$(shell date +%Y-%m-%d-%H:%M:%S)
PACK_BIN?=pack
PACKAGE_BASE=github.com/buildpacks/pack
SRC:=$(shell find . -type f -name '*.go' -not -path "*/vendor/*")
ARCHIVE_NAME=pack-$(PACK_VERSION)
TEST_TIMEOUT?=900s
UNIT_TIMEOUT?=$(TEST_TIMEOUT)
ACCEPTANCE_TIMEOUT?=$(TEST_TIMEOUT)

export GOFLAGS:=$(GOFLAGS)
export CGO_ENABLED=0

all: clean verify test build

mod-tidy:
	$(GOCMD) mod tidy
	cd tools; $(GOCMD) mod tidy
	
mod-vendor:
	$(GOCMD) mod vendor
	cd tools; $(GOCMD) mod vendor
	
tidy: mod-tidy mod-vendor format

build:
	@echo "> Building..."
	mkdir out
	$(GOCMD) build -ldflags "-s -w -X 'github.com/buildpacks/pack/cmd.Version=${PACK_VERSION}'" -o ./out/$(PACK_BIN) -a ./cmd/pack

package:
	tar czf ./out/$(ARCHIVE_NAME).tgz -C out/ pack

install-mockgen:
	@echo "> Installing mockgen..."
	cd tools; $(GOCMD) install github.com/golang/mock/mockgen

install-goimports:
	@echo "> Installing goimports..."
	cd tools; $(GOCMD) install golang.org/x/tools/cmd/goimports

format: install-goimports
	@echo "> Formating code..."
	@goimports -l -w -local ${PACKAGE_BASE} ${SRC}

install-golangci-lint:
	@echo "> Installing golangci-lint..."
	cd tools; $(GOCMD) install github.com/golangci/golangci-lint/cmd/golangci-lint

lint: install-golangci-lint
	@echo "> Linting code..."
	@golangci-lint run -c golangci.yaml

test: unit acceptance

unit:
	@echo "> Running unit/integration tests..."
	$(GOCMD) test -v -count=1 -parallel=1 -timeout=$(UNIT_TIMEOUT) ./...

acceptance:
	@echo "> Running acceptance tests..."
	$(GOCMD) test -v -count=1 -parallel=1 -timeout=$(ACCEPTANCE_TIMEOUT) -tags=acceptance ./acceptance

acceptance-all:
	@echo "> Running acceptance tests..."
	ACCEPTANCE_SUITE_CONFIG=$$(cat ./acceptance/testconfig/all.json) $(GOCMD) test -v -count=1 -parallel=1 -timeout=$(ACCEPTANCE_TIMEOUT) -tags=acceptance ./acceptance

clean:
	@echo "> Cleaning workspace..."
	rm -rf ./out

verify: verify-format lint

generate: install-mockgen
	@echo "> Generating mocks..."
	$(GOCMD) generate ./...

verify-format: install-goimports
	@echo "> Verifying format..."
	@test -z "$(shell goimports -l -local ${PACKAGE_BASE} ${SRC})"; _err=$$?;\
	[ $$_err -ne 0 ] &&\
	echo "ERROR: Format verification failed!\n" &&\
	goimports -d -local ${PACKAGE_BASE} ${SRC} &&\
	exit $$_err;\
	exit 0;

prepare-for-pr: tidy verify test
	@git diff-index --quiet HEAD --; _err=$$?;\
	[ $$_err -ne 0 ] &&\
	echo "-----------------" &&\
	echo "NOTICE: There are some files that have not been committed." &&\
	echo "-----------------\n" &&\
	git status &&\
	echo "\n-----------------" &&\
	echo "NOTICE: There are some files that have not been committed." &&\
	echo "-----------------\n"  &&\
	exit 0;

.PHONY: clean build format imports lint test unit acceptance verify verify-format
