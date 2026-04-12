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
test:
	@(cd add_install_better_patch_version && "$(MAKE)" test)
	@(cd add_install_compatible_version && "$(MAKE)" test)
	@(cd add_install_exact_version && "$(MAKE)" test)
	@(cd add_nested_libraries_with_different_options_fails && "$(MAKE)" test)
	@(cd add_nested_libraries_with_different_options_inherit && "$(MAKE)" test)
	@(cd add_nested_libraries_with_same_options_succeeds && "$(MAKE)" test)
	@(cd add_source_exact_version && "$(MAKE)" test)
	@(cd add_two_libraries_with_different_option_truth_values_succeeds && "$(MAKE)" test)
	@(cd add_two_libraries_with_different_options_fails && "$(MAKE)" test)
	@(cd depend_on_B_and_DepC && "$(MAKE)" test)