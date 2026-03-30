.PHONY: unpack_libraries
unpack_libraries:
	tar -xzf libraryA.tar.gz

.PHONY: unpack_libraries
pack_libraries:
	tar -czf libraryA.tar.gz libraryA

.PHONY: test
test: unpack_libraries
	make -C add_source_exact_version test
	make -C add_install_exact_version test
	make -C add_install_better_patch_version test
	make -C add_install_compatible_version test