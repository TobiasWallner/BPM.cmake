cmake_minimum_required(VERSION 3.20)

# ==============================================================================
# BPMInstallPackage
# ==============================================================================
#
# Description:
# -------------
#   Deterministically fetches, builds, installs, and exposes a CMake-based
#   dependency from a Git repository using a content-addressed install layout.
#
#   The function implements a lightweight, CMake-native package manager with:
#
#     - Git mirror-based source caching
#     - Submodule support
#     - Toolchain and compiler fingerprinting
#     - Content-addressed binary installs (SHA256-based)
#     - Deterministic and isolated find_package resolution
#     - Transitive toolchains  
#
#   Each dependency is installed into a directory derived from a manifest hash
#   that includes:
#
#     - Compiler identity and binary hash
#     - Compiler version
#     - System information
#     - CMake version
#     - Toolchain file hash (if provided)
#     - Dependency name
#     - Git repository URL
#     - Git tag / commit
#     - Build type
#     - Additional CMake arguments (ARGS)
#
#   If an identical configuration has already been built, the existing
#   installation is reused. Otherwise, a new isolated build is performed.
#
#
# Workflow:
# ---------
#   1. A manifest string is generated and hashed (SHA256, shortened).
#   2. The install prefix is derived from that hash.
#   3. The requested packages are searched exclusively inside that prefix
#      using:
#
#         find_package(CONFIG NO_DEFAULT_PATH PATHS <install>)
#
#      Cached <Package>_DIR entries are cleared to avoid cross-root reuse.
#
#   4. If not found:
#        - A Git mirror is created or updated.
#        - The requested tag/commit is verified.
#        - A working copy is cloned from the mirror.
#        - Submodules are initialized recursively.
#        - The project is configured, built, and installed.
#        - The temporary source and build directories are removed.
#
#   5. The installed packages are made available via find_package().
#
#
# Caching Behavior:
# -----------------
#   Two cache modes are supported:
#
#   • Local (default)
#       Uses:
#         <build>/_deps/<NAME>/
#
#   • External cache (via -DBPM_CACHE=<path> or environment variable)
#       Installs into:
#         <BPM_CACHE>/<NAME>/install/<HASH>/
#       Mirrors stored in:
#         <BPM_CACHE>/<NAME>/mirror/
#
#   Install directories are immutable and content-addressed.
#
#
# Required Arguments:
# -------------------
#   NAME <string>
#       Logical name of the dependency.
#
#   PACKAGES <list>
#       One or more CMake package names provided by the dependency.
#
#   GIT_REPOSITORY <url>
#       Git repository URL.
#
#
# Optional Arguments:
# -------------------
#   GIT_TAG <tag-or-commit>
#       Git tag, branch, or commit hash to check out.
#       If omitted, defaults to repository HEAD.
#
#   BUILD_TYPE <string>
#       Build configuration (e.g. Release, Debug).
#       Default: Release
#
#   ARGS <list>
#       Additional -D arguments forwarded to the dependency’s
#       CMake configure step.
#
#   TRANSITIVE_COMPILER_FLAGS <list>
#       Optional flags forwarded to transitive builds.
#
#
# Determinism Guarantees:
# -----------------------
#   - Binary reuse occurs only when the full manifest hash matches.
#   - find_package() is restricted to the computed install directory.
#   - Cached <Package>_DIR entries are cleared to avoid unintended reuse.
#   - Git mirrors avoid redundant network access.
#
#
# Notes:
# ------
#   - Intended for CMake projects exporting proper Config.cmake files.
#   - Does not rely on system-wide installations.
#   - Designed as a lightweight, project-scoped, source-based package manager.
#
#
# Example:
# --------
#   BPMInstallPackage(
#       NAME paho.mqtt.cpp
#       PACKAGES PahoMqttCpp
#       GIT_REPOSITORY https://github.com/eclipse-paho/paho.mqtt.cpp
#       GIT_TAG v1.6.0
#       BUILD_TYPE Release
#       ARGS
#           -DPAHO_WITH_MQTT_C=ON
#           -DPAHO_BUILD_SHARED=FALSE
#           -DPAHO_BUILD_STATIC=TRUE
#           -DPAHO_WITH_SSL=TRUE
#   )
#
# ==============================================================================

function(bpm_resolve_var RESULT_VAR)

    # If user did not pass -D
    if(NOT DEFINED ${RESULT_VAR})

        set(_value "")

        # Check environment variable
        if(DEFINED ENV{${RESULT_VAR}} AND NOT "$ENV{${RESULT_VAR}}" STREQUAL "")
            set(_value "$ENV{${RESULT_VAR}}")
            message(STATUS "BPM [${BPM_NAME}]: resolve ${RESULT_VAR} - from environment variable: ${_value}")
        else()
            message(STATUS "BPM [${BPM_NAME}]: resolve ${RESULT_VAR} - no chache: use local <build-dir>/_deps")
        endif()

        set(${RESULT_VAR} "${_value}" CACHE PATH "" FORCE)

    else()
        message(STATUS "BPM [${BPM_NAME}]: resolve ${RESULT_VAR} - from CMAKE_ARG: ${${RESULT_VAR}}")
    endif()

endfunction()

function(bpm_manifest_append INPUT VAR OUTPUT)

    set(_manifest "${${INPUT}}")

    if(DEFINED ${VAR})
        string(APPEND _manifest "${VAR}=${${VAR}}\n")
    else()
        string(APPEND _manifest "${VAR}=<UNDEFINED>\n")
    endif()

    set(${OUTPUT} "${_manifest}" PARENT_SCOPE)

endfunction()

function(bpm_create_manifest RESULT_VAR)
    SET(manifest "")

    # Toolchain identity:
    file(SHA256 "${CMAKE_C_COMPILER}" C_COMPILER_HASH)
    bpm_manifest_append(manifest CMAKE_C_COMPILER_ID manifest)
    bpm_manifest_append(manifest C_COMPILER_HASH manifest)
    bpm_manifest_append(manifest CMAKE_C_COMPILER_VERSION manifest)
    
    bpm_manifest_append(manifest CMAKE_CXX_COMPILER_ID manifest)
    file(SHA256 "${CMAKE_CXX_COMPILER}" CXX_COMPILER_HASH)
    bpm_manifest_append(manifest CXX_COMPILER_HASH manifest)
    bpm_manifest_append(manifest CMAKE_CXX_COMPILER_VERSION manifest)

    bpm_manifest_append(manifest CMAKE_SYSTEM_NAME manifest)
    bpm_manifest_append(manifest CMAKE_SYSTEM_PROCESSOR manifest)
    bpm_manifest_append(manifest CMAKE_VERSION manifest)

    # Toolchain
    if(CMAKE_TOOLCHAIN_FILE AND EXISTS "${CMAKE_TOOLCHAIN_FILE}")
        file(SHA256 "${CMAKE_TOOLCHAIN_FILE}" TOOLCHAIN_HASH)
    endif()
    bpm_manifest_append(manifest TOOLCHAIN_HASH manifest)

    set(${RESULT_VAR} "${manifest}" PARENT_SCOPE)

endfunction()


 function(BPMInstallPackage)
    
    # -------------------------------
    # Parse Arguments
    # -------------------------------
    set(options)
        set(oneValueArgs
        NAME
        GIT_REPOSITORY
        GIT_TAG
        BUILD_TYPE
    )
    
    set(multiValueArgs
        PACKAGES
        ARGS
        TRANSITIVE_COMPILER_FLAGS
    )
    
    cmake_parse_arguments(BPM
    "${options}"
    "${oneValueArgs}"
    "${multiValueArgs}"
    ${ARGN}
    )
    
    # -------------------------------
    # Validate Required Arguments
    # -------------------------------
    if(NOT BPM_NAME)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: NAME is required")
    endif()
    
    if(NOT BPM_PACKAGES)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: PACKAGES is required")
    endif()
    
    if(NOT BPM_GIT_REPOSITORY)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: GIT_REPOSITORY is required")
    endif()
    
    if(NOT BPM_GIT_TAG)
        message(STATUS "BPM [${BPM_NAME}]: GIT_TAG not provided --> defaulting to main/master HEAD")
    endif()
    
    if(NOT BPM_BUILD_TYPE)
        message(STATUS "BPM [${BPM_NAME}]: BUILD_TYPE not provided --> defaulting to Release")
        set(BPM_BUILD_TYPE Release)
    endif()


    # -------------------------------
    # Define Directories
    # -------------------------------

    bpm_create_manifest(manifest)
    bpm_manifest_append(manifest BPM_NAME manifest)
    bpm_manifest_append(manifest BPM_GIT_REPOSITORY manifest)
    bpm_manifest_append(manifest BPM_GIT_TAG manifest)
    bpm_manifest_append(manifest BPM_BUILD_TYPE manifest)
    
    # sort arguments before appending
    set(_sorted_args "${BPM_ARGS}")
    list(SORT _sorted_args)
    string(JOIN ";" _sorted_args_string ${_sorted_args})
    set(BPM_ARGS_SORTED "${_sorted_args_string}")
    bpm_manifest_append(manifest BPM_ARGS_SORTED manifest)
    
    string(SHA256 MANIFEST_HASH "${manifest}")
    string(SUBSTRING "${MANIFEST_HASH}" 0 16 SHORT_HASH)

    set(DEFAULT_CACHE ${CMAKE_BINARY_DIR}/_deps)
    bpm_resolve_var(BPM_CACHE)

    if(NOT BPM_CACHE)
        # local build
        set(library_mirror_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}/mirror")
        set(library_src_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}/src/${SHORT_HASH}")
        set(library_build_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}/build/${SHORT_HASH}")
        set(library_install_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}/install/${SHORT_HASH}")
        set(manifest_file_path "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}/install/${SHORT_HASH}.manifest")
    else()
        # cached build
        set(library_mirror_dir "${BPM_CACHE}/${BPM_NAME}/mirror")
        set(library_src_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}/src/${SHORT_HASH}")
        set(library_build_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}/build/${SHORT_HASH}")
        set(library_install_dir "${BPM_CACHE}/${BPM_NAME}/install/${SHORT_HASH}")
        set(manifest_file_path "${BPM_CACHE}/${BPM_NAME}/install/${SHORT_HASH}.manifest")
    endif()
    
    if(NOT EXISTS ${manifest_file_path})
        file(WRITE "${manifest_file_path}" "${manifest}")
    endif()
    
    set(all_packages_found TRUE)
    foreach(package IN LISTS BPM_PACKAGES)
        message(STATUS "BPM [${BPM_NAME}]: Find package : ${BPM_NAME}: ${package} in ${library_install_dir}")
        # unset for deterministic find without sideeffects
        unset(${package}_DIR CACHE)
        unset(${package}_DIR)
        find_package(${package} QUIET CONFIG NO_DEFAULT_PATH PATHS "${library_install_dir}")
        if(${package}_FOUND)
            message(STATUS "BPM [${BPM_NAME}]: package ${package} - found")
        else()
            message(WARNING "BPM [${BPM_NAME}]: package ${package} - missing --> attempt install")
            set(all_packages_found FALSE)
        endif()
    endforeach()

    # -------------------------------
    # Install Repository (if needed)
    # -------------------------------
    
    if(NOT ${all_packages_found})
        message(STATUS "BPM [${BPM_NAME}]: Did not find installed library: ${BPM_NAME}")
        
        # -------------------------------
        # Clone Repository (if needed)
        # -------------------------------
        
        message(STATUS "BPM [${BPM_NAME}]: Cloning git repository: ${BPM_GIT_REPOSITORY}")
        if(EXISTS "${library_mirror_dir}/HEAD")
            message(STATUS "BPM [${BPM_NAME}]: Git mirror found at: ${library_mirror_dir}")
            message(STATUS "BPM [${BPM_NAME}]: Cloning git repository: ${BPM_GIT_REPOSITORY} - skipped")
        else()
            
            execute_process(
                COMMAND git clone --mirror ${BPM_GIT_REPOSITORY} ${library_mirror_dir} --recursive -c advice.detachedHead=false
                RESULT_VARIABLE res
            )
        
            if(res EQUAL 0)
                message(STATUS "BPM [${BPM_NAME}]: Cloning git repository: ${BPM_GIT_REPOSITORY} - success")
            else() 
                message(FATAL_ERROR "BPM [${BPM_NAME}]: Cloning git repository: ${BPM_GIT_REPOSITORY} - failed")
            endif()
        endif()

        # -------------------------------
        # checkout tag
        # -------------------------------

        message(STATUS "BPM [${BPM_NAME}]: Update mirror for tag ${BPM_GIT_TAG}")

        # check if tag exists
        execute_process(
            COMMAND git --git-dir=${library_mirror_dir}
                    rev-parse --verify ${BPM_GIT_TAG}^{commit}
            RESULT_VARIABLE tag_exists
            OUTPUT_QUIET
            ERROR_QUIET
        )

        # fetch if tag does not exist in the mirror
        if(tag_exists EQUAL 0)
            message(STATUS "BPM [${BPM_NAME}]: tag ${BPM_GIT_TAG} is part of the mirror")
            message(STATUS "BPM [${BPM_NAME}]: Update mirror for tag ${BPM_GIT_TAG} - skipped")
        else()
            message(STATUS "BPM [${BPM_NAME}]: tag ${BPM_GIT_TAG} is not part of the mirror --> attempt to update/fetch mirror")

            execute_process(
                COMMAND git --git-dir=${library_mirror_dir}
                        fetch --all --tags
                RESULT_VARIABLE res
            )

            if(NOT res EQUAL 0)
                message(STATUS "BPM [${BPM_NAME}]: Failed to fetch mirror")
                message(FATAL_ERROR "BPM [${BPM_NAME}]: Update mirror for tag ${BPM_GIT_TAG} - failed")
            endif()

            message(STATUS "BPM [${BPM_NAME}]: Re-check if git tag ${BPM_GIT_TAG} exists after fetch")
            execute_process(
                COMMAND git --git-dir=${library_mirror_dir}
                        rev-parse --verify ${BPM_GIT_TAG}^{commit}
                RESULT_VARIABLE tag_exists
                OUTPUT_QUIET
                ERROR_QUIET
            )

            if(tag_exists EQUAL 0)
                message(STATUS "BPM [${BPM_NAME}]: Re-check if git tag ${BPM_GIT_TAG} exists after fetch - success")
            else()
                message(FATAL_ERROR "BPM [${BPM_NAME}]: Re-check if git tag ${BPM_GIT_TAG} exists after fetch - failed")
            endif()
        endif()
        message(STATUS "BPM [${BPM_NAME}]: Update mirror for tag ${BPM_GIT_TAG} - success")

        # clone mirror into woring source dir
        message(STATUS "BPM [${BPM_NAME}]: Cloning mirror into source dir")
        if(NOT EXISTS ${library_src_dir}/.git)
            execute_process(
                COMMAND git clone --reference ${library_mirror_dir} --branch ${BPM_GIT_TAG} ${library_mirror_dir} ${library_src_dir} -c advice.detachedHead=false
                RESULT_VARIABLE res
            )
            if(res EQUAL 0)
                message(STATUS "BPM [${BPM_NAME}]: Cloning mirror into source dir - success")
            else()
                message(FATAL_ERROR "BPM [${BPM_NAME}]: Cloning mirror into source dir - failed")
            endif()
        else()
            message(STATUS "BPM [${BPM_NAME}]: Cloning mirror into source dir - skipped")
        endif()
        

        message(STATUS "BPM [${BPM_NAME}]: Updating git-submodules")
        execute_process(
            COMMAND git -C ${library_src_dir} submodule update --init --recursive
            RESULT_VARIABLE res
        )
        if(res EQUAL 0)
            message(STATUS "Updating git-submodules - success")
        else()
            message(FATAL_ERROR "Updating git-submodules - failed")
        endif()

        # -------------------------------
        # Configure
        # -------------------------------
    
        set(toolchain_args "")
        
        if(CMAKE_TOOLCHAIN_FILE)
            list(APPEND toolchain_args "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
        else()
            list(APPEND toolchain_args
                "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
                "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
            )
        endif()

        execute_process(
            COMMAND ${CMAKE_COMMAND}
            -S ${library_src_dir}
            -B ${library_build_dir}
            
            -DCMAKE_BUILD_TYPE=${BPM_BUILD_TYPE}
            -DCMAKE_INSTALL_PREFIX=${library_install_dir}
            -DCMAKE_POSITION_INDEPENDENT_CODE=${CMAKE_POSITION_INDEPENDENT_CODE}
            -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
            
            ${BPM_ARGS}
            ${toolchain_args}

            # try disable testing
            -DBUILD_TESTING=OFF 
            -DBUILD_TESTS=OFF
            -DENABLE_TESTING=OFF
			-DENABLE_TESTS=OFF
			
			# try disable building examples
			-DBUILD_EXAMPLES=OFF
			-DBUILD_EXAMPLE=OFF
			-DENABLE_EXAMPLES=OFF
			-DENABLE_EXAMPLE=OFF

            OUTPUT_QUIET
            RESULT_VARIABLE res
        )

        if(res EQUAL 0)
            message(STATUS "BPM [${BPM_NAME}]: Configuring ${BPM_NAME} - done")
        else() 
            message(STATUS "BPM [${BPM_NAME}]: Configuring ${BPM_NAME} - failed")
        endif()
    
        # -------------------------------
        # Build
        # -------------------------------
    
        message(STATUS "BPM [${BPM_NAME}]: Building ${BPM_NAME}")
        execute_process(
            COMMAND ${CMAKE_COMMAND}
            --build ${library_build_dir}
            --config ${BPM_BUILD_TYPE}
            OUTPUT_QUIET
            RESULT_VARIABLE res
        )
        if(res EQUAL 0)
            message(STATUS "BPM [${BPM_NAME}]: Building ${BPM_NAME} - done")
        else() 
            message(STATUS "BPM [${BPM_NAME}]: Building ${BPM_NAME} - failed")
        endif()
    
        # -------------------------------
        # Install
        # -------------------------------
    
        message(STATUS "BPM [${BPM_NAME}]: Installing ${BPM_NAME}")
        execute_process(
            COMMAND ${CMAKE_COMMAND}
            --install ${library_build_dir}
            --prefix ${library_install_dir}
            --config ${BPM_BUILD_TYPE}
            OUTPUT_QUIET
            RESULT_VARIABLE res
        )
        if(res EQUAL 0)
            message(STATUS "BPM [${BPM_NAME}]: Installing ${BPM_NAME} - done")
        else() 
            message(STATUS "BPM [${BPM_NAME}]: Installing ${BPM_NAME} - failed")
        endif()
    
        # -------------------------------
        # Provide installed package names
        # -------------------------------
        
        file(GLOB config_files
        "${library_install_dir}/lib/cmake/*/*Config.cmake")
    
        if(config_files)
        
            set(package_names "")
            
            foreach(config_file ${config_files})
            
                # Get directory containing the Config.cmake
                get_filename_component(config_dir "${config_file}" DIRECTORY)
                
                # Extract the folder name (usually the package name)
                get_filename_component(package_name "${config_dir}" NAME)
                
                list(APPEND package_names "${package_name}")
            
            endforeach()
            
            # Remove duplicates (in case of Config + ConfigVersion files etc.)
            list(REMOVE_DUPLICATES package_names)
            
            message(STATUS "")
            message(STATUS "BPM [${BPM_NAME}]: Installed CMake package(s) for ${BPM_NAME}:")
            foreach(BPM ${package_names})
                message(STATUS " - ${BPM}")
            endforeach()
            message(STATUS "")
        
        else()
            message(WARNING "BPM [${BPM_NAME}]: Installed, but no CMake package config files found.")
        endif()
    
        # -------------------------------
        # Make Available
        # -------------------------------
        
        foreach(package IN LISTS BPM_PACKAGES)
            message(STATUS "BPM [${BPM_NAME}]: make available : ${BPM_NAME}: ${package}")
            find_package(${package} QUIET HINTS "${library_install_dir}")
            if(${package}_FOUND)
                message(STATUS "BPM [${BPM_NAME}]: make available : ${BPM_NAME}: ${package} - success")
            else()
                message(STATUS "BPM [${BPM_NAME}]: make available : ${BPM_NAME}: ${package} - failed")
                set(all_packages_found FALSE)
            endif()
        endforeach()

        # -------------------------------
        # Cleaning step
        # -------------------------------
        message(STATUS "BPM [${BPM_NAME}]: Clean working source dir")
        file(REMOVE_RECURSE "${library_src_dir}")
        message(STATUS "BPM [${BPM_NAME}]: Clean working source dir - done")

        message(STATUS "BPM [${BPM_NAME}]: Clean temporary build")
        file(REMOVE_RECURSE "${library_build_dir}")
        message(STATUS "BPM [${BPM_NAME}]: Clean temporary build - done")

    endif()
endfunction()