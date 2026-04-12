.PHONY: test
test: 
ifeq ($(OS),Windows_NT)
	@echo ""
	@for %%I in (.) do @echo Running: %%~nxI
	cmake -S . -B build -DBPM_ROOT="$(CURDIR)/../.."
	cmake --build build
	ctest --test-dir build --output-on-failure
	@echo "PASSED"
	@echo ""
else
	@echo ""
	@echo "Running: $(notdir $(CURDIR))"
	cmake -S . -B build -DBPM_ROOT="$(CURDIR)/../.."
	cmake --build build
	ctest --test-dir build --output-on-failure
	@echo "PASSED"
	@echo ""
endif