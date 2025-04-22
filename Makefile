.PHONY: all build test clean en fr business academic release dev dev-academic-en dev-academic-fr dev-business-en dev-business-fr ci-test

all: build

build: business academic

business:
	uv run python build.py --types business

academic:
	uv run python build.py --types academic

en:
	uv run python build.py --languages en

fr:
	uv run python build.py --languages fr

test: build
	uv run python -m pytest -v tests/

test-offline: build
	CI=true uv run python -m pytest -v tests/

clean:
	rm -f output/*.pdf
	rm -f temp_*.typ

dev:
	uv run python build.py --dev

dev-academic-en:
	uv run python build.py --types academic --languages en --dev

dev-academic-fr:
	uv run python build.py --types academic --languages fr --dev

dev-business-en:
	uv run python build.py --types business --languages en --dev

dev-business-fr:
	uv run python build.py --types business --languages fr --dev

ci-test:
	@echo "Running CI simulation..."
	@echo "Step 1: Clean environment"
	$(MAKE) clean
	@echo "Step 2: Build all resume formats"
	$(MAKE) build
	@echo "Step 3: Run tests (offline mode)"
	$(MAKE) test-offline
	@echo "CI simulation completed successfully!"

release: clean all test
	@echo "Release build completed and tested successfully!"