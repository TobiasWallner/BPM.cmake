.PHONY: test
test:
ifeq ($(OS),Windows_NT)
	@echo ""
	@for %%I in (.) do @echo Running: %%~nxI
	cmake -S . -B build "-DBPM_LOCATION=../../BPM.cmake" && (for %%I in (.) do @echo PASSED: %%~nxI & exit /b 0) || (for %%I in (.) do @echo FAILED: %%~nxI & exit /b 1)
	@echo ""
else
	@echo ""
	@echo "Running: $(notdir $(CURDIR))"
	cmake -S . -B build "-DBPM_LOCATION=../../BPM.cmake" && echo "PASSED: $(notdir $(CURDIR))" || (echo "FAILED: $(notdir $(CURDIR))"; exit 1)
	@echo ""
endif