SRC_DIR := src test scripts
SOURCES := $(foreach dir,$(SRC_DIR),$(wildcard $(dir)/*.sol))

.PHONY: all build generate test test-env

all: build generate

build:
	forge build

generate: build
	node export-abis.cjs

test:
	forge test

test-env:
	forge script scripts/TestEnv.s.sol:Setup --fork-url http://127.0.0.1:8545 --broadcast --legacy --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

lint: $(SOURCES)
	forge fmt --check $^

format: $(SOURCES)
	forge fmt $^
