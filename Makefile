# chronos2-go-base — formatting, analysis, builds, and checks on the embedded
# weights and on the module's size.
#
# `make help` lists every public target alphabetically with its one-line
# description. The listing is generated from the `## target: description`
# comments below, so a new target documents itself by carrying one.
#
# Every target is phony; the Go toolchain already does its own staleness
# tracking. Every tool a target runs comes from PATH. The repository's mise.toml
# pins each one, together with the Go toolchain, and `mise install` provisions
# them all.


###############################################################################
# MODULE SETTINGS

APP := chronos2-go-base


###############################################################################
# COMMON SETTINGS

# The directory holding config.json and manifest.json.
WEIGHTS_DIR := weights

# The ceiling Go places on a module, in bytes, applied twice: to the zip that
# `git archive` produces for the module's repository, and to the module zip's
# total uncompressed size. Both limits are 500 MiB.
MODULE_SIZE_LIMIT := 524288000

# Every hand-written Go file Git does not ignore, including new files not yet
# added.
GO_FILES = git ls-files --cached --others --exclude-standard '*.go'

.DEFAULT_GOAL := help
.PHONY: build check check-size format help lint security security-gosec security-govulncheck verify-weights


###############################################################################
# TARGETS

## build: compile the package, which embeds the config and imports the four parts
build:
	go build ./...

## check: verify the config against the manifest, then the module's size against Go's limits
check: verify-weights check-size

## check-size: check the working tree, as it would be committed, against Go's module size limits
#
# Go downloads a module at a repository root with `git archive`, so both the
# archive of the whole tree and the sum of its file sizes must stay within
# MODULE_SIZE_LIMIT. The tree is built in a temporary index seeded from the
# real one, so tracked files stay tracked and ignored files stay out; the real
# index, HEAD, and every ref are left untouched. `git add` does write the new
# blobs to the object database, where a later commit reuses them.
check-size:
	@set -e; \
	scratch=$$(mktemp -d); trap 'rm -rf "$$scratch"' EXIT; \
	index=$$(git rev-parse --git-path index); \
	if [ -f "$$index" ]; then cp "$$index" "$$scratch/index"; fi; \
	export GIT_INDEX_FILE="$$scratch/index"; \
	git add -A; \
	tree=$$(git write-tree); \
	archive=$$(git archive --format=zip "$$tree" | wc -c | tr -d ' '); \
	files=$$(git ls-tree -r -l "$$tree" | awk '$$2 == "blob" { total += $$4 } END { printf "%d", total }'); \
	status=0; \
	for measure in "archive zip:$$archive" "uncompressed files:$$files"; do \
		label=$${measure%%:*}; bytes=$${measure##*:}; \
		headroom=$$(( $(MODULE_SIZE_LIMIT) - bytes )); \
		awk -v label="$$label" -v bytes="$$bytes" -v headroom="$$headroom" 'BEGIN { \
			printf "%-20s %11d bytes (%6.1f MiB), headroom %11d bytes (%6.1f MiB)\n", \
				label, bytes, bytes / 1048576, headroom, headroom / 1048576 }'; \
		if [ "$$bytes" -gt $(MODULE_SIZE_LIMIT) ]; then \
			echo "$$label exceeds the limit of $(MODULE_SIZE_LIMIT) bytes"; status=1; \
		fi; \
	done; \
	exit $$status

## format: rewrite the hand-written Go files with goimports, then gofumpt
format:
	@files=$$($(GO_FILES)); \
	if [ -n "$$files" ]; then goimports -w $$files && gofumpt -w $$files; fi

## help: list the available targets
help:
	@echo "$(APP) — available targets:"
	@echo
	@grep -hE '^## [a-z0-9-]+:' $(MAKEFILE_LIST) \
		| sed -e 's/^## //' \
		| awk -F': ' '{ printf "%s\t%s\n", $$1, $$2 }' \
		| sort \
		| awk -F'\t' '{ printf "  %-22s %s\n", $$1, $$2 }'

## lint: check formatting, run the analyzers, then check spelling
#
# The formatters run in check mode, so lint never mutates the tree. errcheck's
# -blank is deliberately not set, because a justified discard is written
# `_ = f()`.
lint:
	@files=$$($(GO_FILES)); \
	for formatter in goimports gofumpt; do \
		echo "==> $$formatter"; \
		offenders=$$([ -z "$$files" ] || $$formatter -l $$files); \
		if [ -n "$$offenders" ]; then \
			echo "not $$formatter-formatted:"; echo "$$offenders"; \
			echo "run: make format"; exit 1; \
		fi; \
	done
	@echo "==> go vet"
	@go vet ./...
	@echo "==> staticcheck"
	@staticcheck ./...
	@echo "==> errcheck"
	@errcheck -asserts ./...
	@echo "==> ineffassign"
	@ineffassign ./...
	@echo "==> misspell"
	@files=$$($(GO_FILES)); [ -z "$$files" ] || misspell -locale US -source=go -error $$files
	@echo "==> typos"
	@typos --locale en-us

## security: run every security scanner — gosec, then govulncheck
security: security-gosec security-govulncheck

## security-gosec: scan the module for insecure code patterns
security-gosec:
	@echo "==> gosec"
	@gosec -quiet -exclude-generated ./...

## security-govulncheck: check the module's dependencies against the Go vulnerability database
#
# Not hermetic: it needs network access and consults a database that changes
# independently of this repository.
security-govulncheck:
	@echo "==> govulncheck"
	@govulncheck ./...

## verify-weights: check config.json against weights/manifest.json
#
# The shards live in the four part modules, whose own verify-weights targets
# check them.
verify-weights:
	@cd $(WEIGHTS_DIR); \
	expected=$$(jq -er '.config_sha256' manifest.json); \
	actual=$$(shasum -a 256 config.json | cut -d ' ' -f 1); \
	if [ "$$actual" = "$$expected" ]; then echo "ok    config.json"; \
	else echo "FAIL  config.json: sha256 $$actual, manifest $$expected"; exit 1; fi
