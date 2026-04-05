.PHONY: unpack_libraries
unpack_libraries:
	tar -xzf libraryA.tar.gz
	tar -xzf libraryB.tar.gz
	tar -xzf libraryBoption.tar.gz

.PHONY: unpack_libraries
pack_libraries:
	tar -czf libraryA.tar.gz libraryA
	tar -czf libraryB.tar.gz libraryB
	tar -czf libraryBoption.tar.gz libraryBoption

.PHONY: test
test: unpack_libraries
	make -C add_install_better_patch_version test
	make -C add_install_compatible_version test
	make -C add_install_exact_version test
	make -C add_nested_libraries_with_different_options_fails test
	make -C add_nested_libraries_with_different_options_inherit test
	make -C add_nested_libraries_with_same_options_succeeds test
	make -C add_source_exact_version test
	make -C add_two_libraries_with_different_option_truth_values_succeeds test
	make -C add_two_libraries_with_different_options_fails test