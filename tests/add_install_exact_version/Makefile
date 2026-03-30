.PHONY: test
test: 
	cmake -S . -B build "-DBPM_LOCATION=../../BPM.cmake"
	cmake --build build
	ctest --test-dir build --output-on-failure
