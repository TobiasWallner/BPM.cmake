cmake_minimum_required(VERSION 3.20)

# ==============================================================================
# BPMCreateInstallPackage
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
# Optional Flags:
# --------------
# QUIET
#       If provided: Hides outputs of sub commands like `find_package`, `cmake -S . -B build ...`, `cmake --build build`, `cmake --install ...`
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
#   OPTIONS <list>
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
#   BPMCreateInstallPackage(
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

    set(_value "")

    if(DEFINED ${RESULT_VAR} AND NOT "${${RESULT_VAR}}" STREQUAL "")
        message(STATUS "BPM: resolve ${RESULT_VAR} - from CMAKE_ARG: ${${RESULT_VAR}}")
        return()
    endif()

    if(DEFINED ENV{${RESULT_VAR}} AND NOT "$ENV{${RESULT_VAR}}" STREQUAL "")
        set(_value "$ENV{${RESULT_VAR}}")
        message(STATUS "BPM: resolve ${RESULT_VAR} - from environment variable: ${_value}")
    else()
        file(RELATIVE_PATH rel_build_dir "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}")
        message(STATUS "BPM: resolve ${RESULT_VAR} - no cache provided: use local: ./${rel_build_dir}/_deps")
    endif()

    set(${RESULT_VAR} "${_value}" CACHE PATH "" FORCE)

endfunction()

function(bpm_create_manifest OUT_MANIFEST OUT_HASH)

    set(_manifest "")

    foreach(var IN LISTS ARGN)

        if(DEFINED ${var})
            set(_value "${${var}}")
        else()
            set(_value "<UNDEFINED>")
        endif()

        string(APPEND _manifest "${var}=${_value}\n")

    endforeach()

    string(SHA256 _hash "${_manifest}")
    string(SUBSTRING "${_hash}" 0 16 _short_hash)

    set(${OUT_MANIFEST} "${_manifest}" PARENT_SCOPE)
    set(${OUT_HASH} "${_short_hash}" PARENT_SCOPE)

endfunction()
#
# @brief Finds all options that contain `test` or `example` (case insensitive) in a file
#
function(bpm_find_test_example_options cmake_file result_var)
    file(READ "${cmake_file}" content)

    set(test_regex "[Tt][Ee][Ss][Tt]")
    set(example_regex "[Ee][Xx][Aa][Mm][Pp][Ll][Ee]")
    set(test_or_example_regex "(${test_regex}|${example_regex})")

    set(regex_str "option[ \t\r\n]*\\([ \t\r\n]*([A-Za-z0-9_]*${test_or_example_regex}[A-Za-z0-9_]*)")

    # Find all option(...) occurrences
    string(REGEX MATCHALL
        "${regex_str}"
        matches
        "${content}"
    )

    set(found_options "")

    foreach(m ${matches})
        string(REGEX REPLACE
            "${regex_str}"
            "\\1"
            opt
            "${m}"
        )
        list(APPEND found_options "${opt}")
    endforeach()

    set(${result_var} "${found_options}" PARENT_SCOPE)
endfunction()

#
# @brief Finds all options recursively in the provided folder that contain `test` or `example` (case insensitive) in a file
#
function(bpm_find_test_example_options_r search_folder result_var)
    file(GLOB_RECURSE cmake_files "${search_folder}/CMakeLists.txt" "${search_folder}/*.cmake")

    set(all_flags "")

    foreach(file_ ${cmake_files})
        bpm_find_test_example_options(${file_} flags_)
        list(APPEND all_flags ${flags_})
    endforeach()

    list(REMOVE_DUPLICATES all_flags)
    set(${result_var} "${all_flags}" PARENT_SCOPE)
endfunction()

#
# @brief clones a repository if it does not already exist
#
function(bpm_clone_repository_if_needed lib_name git_repo mirror_dir execute_process_flags)
    if(NOT EXISTS "${mirror_dir}/HEAD")
        message(STATUS "BPM [${lib_name}]: Cloning git repository: ${git_repo}")
        
        execute_process(
            COMMAND git clone --mirror "${git_repo}" "${mirror_dir}" --recursive -c advice.detachedHead=false
            RESULT_VARIABLE res
            ${execute_process_flags}
        )
    
        if(res EQUAL 0)
            message(STATUS "BPM [${lib_name}]: Cloning git repository: ${git_repo} - success")
        else() 
            message(FATAL_ERROR "BPM [${lib_name}]: Cloning git repository: ${git_repo} - failed")
        endif()
    endif()
endfunction()

#
# @brief checs out a git tag 
#
# optionally fetches from the origin repo if the mirror does not have the tag
#
function(bpm_verify_git_tag lib_name git_tag lib_mirror_dir execute_process_quiet OUT_COMMIT)
    # check if tag exists
    execute_process(
        COMMAND git "--git-dir=${lib_mirror_dir}"
                rev-parse --verify "${git_tag}^{commit}"
        RESULT_VARIABLE tag_exists
        OUTPUT_VARIABLE BPM_GIT_COMMIT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    # fetch if tag does not exist in the mirror
    if(NOT tag_exists EQUAL 0)
        message(STATUS "BPM [${lib_name}]: Fetch mirror for tag ${git_tag}")

        execute_process(
            COMMAND git "--git-dir=${lib_mirror_dir}"
                    fetch --all --tags
            RESULT_VARIABLE res
            ${execute_process_quiet}
        )

        if(NOT res EQUAL 0)
            message(FATAL_ERROR "BPM [${lib_name}]: Fetch mirror for tag ${git_tag} - failed")
        endif()

        execute_process(
            COMMAND git "--git-dir=${lib_mirror_dir}"
                    rev-parse --verify "${git_tag}^{commit}"
            RESULT_VARIABLE tag_exists
            OUTPUT_VARIABLE BPM_GIT_COMMIT
            OUTPUT_STRIP_TRAILING_WHITESPACE
        )

        if(tag_exists EQUAL 0)
            message(STATUS "BPM [${lib_name}]: Fetch mirror for tag ${git_tag} - success")
        else()
            message(FATAL_ERROR "BPM [${lib_name}]: Fetch mirror for tag ${git_tag} - failed (tag not found after fetch)")
        endif()
    endif()

    set(${OUT_COMMIT} ${BPM_GIT_COMMIT} PARENT_SCOPE)

endfunction()

function(bpm_try_find_packages lib_name packages library_install_dir find_package_quiet OUT_FOUND_ALL)
    set(all_packages_found TRUE)
    file(RELATIVE_PATH rel_install_dir "${CMAKE_SOURCE_DIR}" "${library_install_dir}")
    foreach(package IN LISTS packages)
        # unset for deterministic find without sideeffects
        unset(${package}_DIR CACHE)
        find_package(${package} ${find_package_quiet} CONFIG NO_DEFAULT_PATH PATHS "${library_install_dir}")
        unset(${package}_DIR)
        if(${package}_FOUND)
            message(STATUS "BPM [${lib_name}]: Find package : ${package} - found: in ./${rel_install_dir}")
        else()
            message(STATUS "BPM [${lib_name}]: WARNING: Find package : ${package} - missing")
            set(all_packages_found FALSE)
        endif()
    endforeach()

    set(${OUT_FOUND_ALL} ${all_packages_found} PARENT_SCOPE)
endfunction()

function(bpm_clone_from_mirror lib_name library_mirror_dir library_src_dir git_tag execute_process_quiet)

    message(STATUS "BPM [${lib_name}]: Cloning mirror into source dir")
    if(NOT EXISTS ${library_src_dir}/.git)
        execute_process(
            COMMAND git clone --reference "${library_mirror_dir}" --branch "${git_tag}" "${library_mirror_dir}" "${library_src_dir}" -c advice.detachedHead=false
            RESULT_VARIABLE res
            ${execute_process_quiet}
        )
        if(res EQUAL 0)
            message(STATUS "BPM [${lib_name}]: Cloning mirror into source dir - success")
        else()
            message(FATAL_ERROR "BPM [${lib_name}]: Cloning mirror into source dir - failed")
        endif()
    else()
        message(STATUS "BPM [${lib_name}]: Cloning mirror into source dir - skipped")
    endif()
    

    message(STATUS "BPM [${lib_name}]: Updating git-submodules")
    execute_process(
        COMMAND git -C "${library_src_dir}" submodule update --init --recursive
        RESULT_VARIABLE res
        ${execute_process_quiet}
    )
    if(res EQUAL 0)
        message(STATUS "Updating git-submodules - success")
    else()
        message(FATAL_ERROR "Updating git-submodules - failed")
    endif()

endfunction()

function(bpm_configure_library lib_name library_src_dir library_build_dir cmake_build_args execute_process_quiet)

    # parse the libraries cmake lists for flags that enable tests and disable them
    bpm_find_test_example_options_r(${library_src_dir} test_example_options)
    set(cmake_disable_test_example_flags "")

    foreach(flag ${test_example_options})
        list(APPEND cmake_disable_test_example_flags "-D${flag}=OFF")
    endforeach()

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
        -S "${library_src_dir}"
        -B "${library_build_dir}"
        -G "${CMAKE_GENERATOR}"
        
        -DCMAKE_BUILD_TYPE=${BPM_BUILD_TYPE}
        -DCMAKE_INSTALL_PREFIX=${library_install_dir}
        -DCMAKE_POSITION_INDEPENDENT_CODE=${CMAKE_POSITION_INDEPENDENT_CODE}
        -DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}
        
        ${cmake_build_args}
        ${toolchain_args}
        ${cmake_disable_test_example_flags}

        "-DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
        "-DCMAKE_GENERATOR=${CMAKE_GENERATOR}"

        RESULT_VARIABLE res
        ${execute_process_quiet}
    )

    if(res EQUAL 0)
        message(STATUS "BPM [${lib_name}]: Configuring - done")
    else() 
        message(STATUS "BPM [${lib_name}]: Configuring - failed")
    endif()

endfunction()

function(bpm_build_library lib_name library_build_dir build_type execute_process_quiet)

    message(STATUS "BPM [${lib_name}]: Building")
    execute_process(
        COMMAND ${CMAKE_COMMAND}
        --build ${library_build_dir}
        --config ${build_type}
        RESULT_VARIABLE res
        ${execute_process_quiet}
    )
    if(res EQUAL 0)
        message(STATUS "BPM [${lib_name}]: Building - done")
    else() 
        message(STATUS "BPM [${lib_name}]: Building - failed")
    endif()

endfunction()

#
# @brief For installing packages
#
# - Downloads git repositories
# - Stores mirrors of the repositories
# - Creates configuration and environment dependent manifest files and hashes
# - Configures, builds and installs each library in its own folder, seperated by the config hashes
# - Uses find package to make the packages of the libraries available
#
function(BPMCreateInstallPackage)
    
    # -------------------------------
    # Parse Arguments
    # -------------------------------
    set(options QUIET)

    set(oneValueArgs
        NAME
        GIT_REPOSITORY
        GIT_TAG
        BUILD_TYPE
    )
    
    set(multiValueArgs
        PACKAGES
        OPTIONS
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
    if(BPM_QUIET)
        set(find_package_quiet "QUIET")
        set(execute_process_quiet "OUTPUT_QUIET")
    else()
        set(find_package_quiet "")
        set(execute_process_quiet "")
    endif()

    if(NOT BPM_NAME)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: NAME is required")
    endif()
    
    if(NOT BPM_PACKAGES)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: PACKAGES is required")
    endif()
    
    if(NOT BPM_GIT_REPOSITORY)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: GIT_REPOSITORY is required")
    endif()
    
    if(NOT BPM_BUILD_TYPE)
        set(BPM_BUILD_TYPE Release)
    endif()

    if(BPM_${BPM_NAME}_ADDED)
        return()
    endif()

    set(BPM_ARGS "")
    if(BPM_OPTIONS)
        foreach(opt IN LISTS BPM_OPTIONS)
            list(APPEND BPM_ARGS "-D${opt}")
        endforeach()
    endif()

    # -------------------------------
    # Define Cache Location
    # -------------------------------

    # guard around `BPM_CACHE` so that `bpm_resolve_var` runs the first time and every time when `BPM_CACHE` changes
    if(NOT BPM_CACHE_RESOLVED)
        set(BPM_CACHE_RESOLVED TRUE PARENT_SCOPE)
        bpm_resolve_var(BPM_CACHE)
    endif()

    if(NOT BPM_CACHE)
        set(bpm_cache_base_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}")
    else()
        set(bpm_cache_base_dir "${BPM_CACHE}/${BPM_NAME}")
    endif()

    # -------------------------------
    # Define Mirror Dir
    # -------------------------------

    set(library_mirror_dir "${bpm_cache_base_dir}/mirror")
    
    # -------------------------------
    # Clone/fetch repository
    # -------------------------------

    bpm_clone_repository_if_needed("${BPM_NAME}" "${BPM_GIT_REPOSITORY}" "${library_mirror_dir}" "${execute_process_quiet}")
    bpm_verify_git_tag("${BPM_NAME}" "${BPM_GIT_TAG}" "${library_mirror_dir}" "${execute_process_quiet}" BPM_GIT_COMMIT)

    string(SUBSTRING "${BPM_GIT_COMMIT}" 0 16 BPM_GIT_COMMIT_SHORT)
    set(library_src_dir "${bpm_cache_base_dir}/src/${BPM_GIT_COMMIT_SHORT}/")

    # -------------------------------
    # create manifest
    # -------------------------------

    # sort arguments before appending
    set(_sorted_options "${BPM_OPTIONS}")
    list(SORT _sorted_options)
    string(JOIN ";" _sorted_options_string ${_sorted_options})
    set(BPM_OPTIONS_SORTED "${_sorted_options_string}")

    file(SHA256 "${CMAKE_C_COMPILER}" C_COMPILER_HASH)
    file(SHA256 "${CMAKE_CXX_COMPILER}" CXX_COMPILER_HASH)

    bpm_create_manifest(manifest MANIFEST_HASH 
        CMAKE_C_COMPILER_ID
        C_COMPILER_HASH
        CMAKE_C_COMPILER_VERSION
        CMAKE_CXX_COMPILER_ID
        CXX_COMPILER_HASH
        CMAKE_CXX_COMPILER_VERSION
        CMAKE_SYSTEM_NAME
        CMAKE_SYSTEM_PROCESSOR
        CMAKE_VERSION
        TOOLCHAIN_HASH
        BPM_GIT_COMMIT
        BPM_NAME
        BPM_GIT_REPOSITORY
        BPM_GIT_TAG
        BPM_BUILD_TYPE
        BPM_OPTIONS
    ) 

    string(SUBSTRING "${MANIFEST_HASH}" 0 16 SHORT_HASH)

    # -------------------------------
    # Define hashed directories
    # -------------------------------

    set(library_build_dir "${bpm_cache_base_dir}/build/${SHORT_HASH}")
    set(library_install_dir "${bpm_cache_base_dir}/install/${SHORT_HASH}")
    set(manifest_dir "${bpm_cache_base_dir}/manifest")
    set(manifest_file_path "${bpm_cache_base_dir}/manifest/${SHORT_HASH}.manifest")

    if(NOT EXISTS ${manifest_dir})
        file(MAKE_DIRECTORY "${manifest_dir}")
    endif()

    if(NOT EXISTS ${manifest_file_path})
        file(WRITE "${manifest_file_path}" "${manifest}")
    endif()
    
    bpm_try_find_packages("${BPM_NAME}" "${BPM_PACKAGES}" "${library_install_dir}" "${find_package_quiet}" all_packages_found)
    if(NOT all_packages_found)
        message(STATUS "BPM [${BPM_NAME}]: Find package - failed: attempt install")
    endif()

    # -------------------------------
    # Install Repository (if needed)
    # -------------------------------
    
    if(NOT all_packages_found)

        # clone mirror into source dir

        bpm_clone_from_mirror("${BPM_NAME}" "${library_mirror_dir}" "${library_src_dir}" "${BPM_GIT_TAG}" "${execute_process_quiet}")

        # -------------------------------
        # Configure
        # -------------------------------
        
        bpm_configure_library("${BPM_NAME}" "${library_src_dir}" "${library_build_dir}" "${BPM_ARGS}" "${execute_process_quiet}")
    
        # -------------------------------
        # Build
        # -------------------------------
    
        bpm_build_library("${BPM_NAME}" "${library_build_dir}" "${BPM_BUILD_TYPE}" "${execute_process_quiet}")

        # -------------------------------
        # Install
        # -------------------------------
    
        message(STATUS "BPM [${BPM_NAME}]: Installing ${BPM_NAME}")
        execute_process(
            COMMAND ${CMAKE_COMMAND}
            --install ${library_build_dir}
            --prefix ${library_install_dir}
            --config ${BPM_BUILD_TYPE}
            RESULT_VARIABLE res
            ${execute_process_quiet}
        )
        if(res EQUAL 0)
            message(STATUS "BPM [${BPM_NAME}]: Installing ${BPM_NAME} - done")
        else() 
            # clean install on error
            file(REMOVE_RECURSE "${library_install_dir}")
            message(STATUS "BPM [${BPM_NAME}]: Installing ${BPM_NAME} - failed")
        endif()
    
        # -------------------------------
        # Provide installed package names
        # -------------------------------
        
        file(GLOB_RECURSE config_files "${library_install_dir}/*Config.cmake" "${library_install_dir}/*config.cmake")
    
        if(config_files)
        
            set(package_names "")
            
            foreach(config_file IN LISTS config_files)
            
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
            foreach(BPM IN LISTS package_names)
                message(STATUS " - ${BPM}")
            endforeach()
            message(STATUS "")
        
        else()
            message(FATAL_ERROR "BPM [${BPM_NAME}]: Installed, but no CMake package config files found.")
        endif()
    
        # -------------------------------
        # Make Available
        # -------------------------------
        
        bpm_try_find_packages("${BPM_NAME}" "${BPM_PACKAGES}" "${library_install_dir}" "${find_package_quiet}" all_packages_found)
        if(NOT all_packages_found)
            message(FATAL_ERROR "BPM [${BPM_NAME}]: Find package - failed after (re-)install")
        endif()

        # -------------------------------
        # Cleaning step
        # -------------------------------

        # clean source directory, we don't really need it and it is ofthen 10 times larger than the mirror, build or install directory

        # message(STATUS "BPM [${BPM_NAME}]: Clean working source dir")
        # file(REMOVE_RECURSE "${library_src_dir}")
        # message(STATUS "BPM [${BPM_NAME}]: Clean working source dir - done")

    endif()

    set(BPM_${BPM_NAME}_ADDED ON PARENT_SCOPE)
endfunction()



function(BPMAddPackage)
    
    # -------------------------------
    # Parse Arguments
    # -------------------------------
    set(options QUIET)

    set(oneValueArgs
        NAME
        GIT_REPOSITORY
        GIT_TAG
        BUILD_TYPE
    )
    
    set(multiValueArgs
        OPTIONS
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
    if(BPM_QUIET)
        set(find_package_quiet "QUIET")
        set(execute_process_quiet "OUTPUT_QUIET")
    else()
        set(find_package_quiet "")
        set(execute_process_quiet "")
    endif()

    if(NOT BPM_NAME)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: NAME is required")
    endif()
    
    if(NOT BPM_GIT_REPOSITORY)
        message(FATAL_ERROR "BPM [${BPM_NAME}]: GIT_REPOSITORY is required")
    endif()
    
    if(NOT BPM_BUILD_TYPE)
        set(BPM_BUILD_TYPE Release)
    endif()

    if(BPM_${BPM_NAME}_ADDED)
        return()
    endif()

    # -------------------------------
    # Define Cache Location
    # -------------------------------

    # guard around `BPM_CACHE` so that `bpm_resolve_var` runs the first time and every time when `BPM_CACHE` changes
    if(NOT BPM_CACHE_RESOLVED)
        set(BPM_CACHE_RESOLVED TRUE PARENT_SCOPE)
        bpm_resolve_var(BPM_CACHE)
    endif()

    if(NOT BPM_CACHE)
        set(bpm_cache_base_dir "${CMAKE_BINARY_DIR}/_deps/${BPM_NAME}")
    else()
        set(bpm_cache_base_dir "${BPM_CACHE}/${BPM_NAME}")
    endif()

    # -------------------------------
    # Define Mirror Dir
    # -------------------------------

    set(library_mirror_dir "${bpm_cache_base_dir}/mirror")
    
    # -------------------------------
    # Clone/fetch repository
    # -------------------------------

    bpm_clone_repository_if_needed("${BPM_NAME}" "${BPM_GIT_REPOSITORY}" "${library_mirror_dir}" "${execute_process_quiet}")
    bpm_verify_git_tag("${BPM_NAME}" "${BPM_GIT_TAG}" "${library_mirror_dir}" "${execute_process_quiet}" BPM_GIT_COMMIT)

    string(SUBSTRING "${BPM_GIT_COMMIT}" 0 16 BPM_GIT_COMMIT_SHORT)
    set(library_src_dir "${bpm_cache_base_dir}/src/${BPM_GIT_COMMIT_SHORT}/")

    # -------------------------------
    # create manifest
    # -------------------------------

    # sort arguments before appending
    set(_sorted_options "${BPM_OPTIONS}")
    list(SORT _sorted_options)
    string(JOIN ";" _sorted_options_string ${_sorted_options})
    set(BPM_OPTIONS_SORTED "${_sorted_options_string}")

    file(SHA256 "${CMAKE_C_COMPILER}" C_COMPILER_HASH)
    file(SHA256 "${CMAKE_CXX_COMPILER}" CXX_COMPILER_HASH)

    bpm_create_manifest(manifest MANIFEST_HASH 
        CMAKE_C_COMPILER_ID
        C_COMPILER_HASH
        CMAKE_C_COMPILER_VERSION
        CMAKE_CXX_COMPILER_ID
        CXX_COMPILER_HASH
        CMAKE_CXX_COMPILER_VERSION
        CMAKE_SYSTEM_NAME
        CMAKE_SYSTEM_PROCESSOR
        CMAKE_VERSION
        TOOLCHAIN_HASH
        BPM_GIT_COMMIT
        BPM_NAME
        BPM_GIT_REPOSITORY
        BPM_GIT_TAG
        BPM_BUILD_TYPE
        BPM_OPTIONS_SORTED
    ) 

    string(SUBSTRING "${MANIFEST_HASH}" 0 16 SHORT_HASH)

    # -------------------------------
    # Define hashed directories
    # -------------------------------

    set(library_build_dir "${bpm_cache_base_dir}/build/${SHORT_HASH}")
    set(manifest_dir "${bpm_cache_base_dir}/manifest")
    set(manifest_file_path "${bpm_cache_base_dir}/manifest/${SHORT_HASH}.manifest")

    if(NOT EXISTS ${manifest_dir})
        file(MAKE_DIRECTORY "${manifest_dir}")
    endif()

    if(NOT EXISTS ${manifest_file_path})
        file(WRITE "${manifest_file_path}" "${manifest}")
    endif()

    # -------------------------------
    # Install Repository (if needed)
    # -------------------------------
    
    if(NOT EXISTS "${library_src_dir}/.git")
        # clone mirror into source dir
        bpm_clone_from_mirror("${BPM_NAME}" "${library_mirror_dir}" "${library_src_dir}" "${BPM_GIT_TAG}" "${execute_process_quiet}")
    endif()

    foreach(opt IN LISTS BPM_OPTIONS)

        # split "NAME=VALUE" → NAME;VALUE
        string(REPLACE "=" ";" opt_parts "${opt}")

        list(GET opt_parts 0 opt_name)
        list(GET opt_parts 1 opt_value)

        # force set cache variable
        set(${opt_name} "${opt_value}" CACHE STRING "" FORCE)

    endforeach()
    add_subdirectory("${library_src_dir}" "${library_build_dir}")

    set(BPM_${BPM_NAME}_ADDED ON PARENT_SCOPE)
endfunction()