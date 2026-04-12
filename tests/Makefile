.PHONY: unpack_libraries
unpack:
	tar -xzf libraryA.tar.gz
	tar -xzf libraryB.tar.gz
	tar -xzf libraryBoption.tar.gz
	tar -xzf libraryC.tar.gz
	tar -xzf libraryDepC.tar.gz

.PHONY: unpack_libraries
pack:
	tar -czf libraryA.tar.gz libraryA
	tar -czf libraryB.tar.gz libraryB
	tar -czf libraryBoption.tar.gz libraryBoption
	tar -czf libraryC.tar.gz libraryC
	tar -czf libraryDepC.tar.gz libraryDepC

.PHONY: test
test: unpack
	make -C add_install_better_patch_version test
	make -C add_install_compatible_version test
	make -C add_install_exact_version test
	make -C add_nested_libraries_with_different_options_fails test
	make -C add_nested_libraries_with_different_options_inherit test
	make -C add_nested_libraries_with_same_options_succeeds test
	make -C add_source_exact_version test
	make -C add_two_libraries_with_different_option_truth_values_succeeds test
	make -C add_two_libraries_with_different_options_fails test
	make -C depend_on_B_and_DepC test