cmake_minimum_required(VERSION 3.20)

# @parses a constraint + version string into a list of elements.
# 
# input: >=1.2.3 --> output: LIST >=;1;2;3
# input: >=
function(bpm_parse_version_string INPUT out_version)
    string(REPLACE ";" "\\;" SAFE_INPUT "${INPUT}")

    set(VERSION_QUALIFIER "")
    set(VERSION_MAJOR "")
    set(VERSION_MINOR "")
    set(VERSION_PATCH "")

    # --------------------------------------------------------
    # Split qualifier from remainder
    # --------------------------------------------------------
    string(REGEX MATCH "^(>=|\\^|~|=)?(.+)$" _ "${SAFE_INPUT}")
    if(CMAKE_MATCH_1)
        set(VERSION_QUALIFIER "${CMAKE_MATCH_1}")
    else()
        set(VERSION_QUALIFIER "=")
    endif()
    set(VALUE     "${CMAKE_MATCH_2}")

    # --------------------------------------------------------
    # Try semantic version (optional leading 'v')
    # --------------------------------------------------------
    string(REGEX MATCH "^v?([0-9]+)\\.([0-9]+)\\.([0-9]+)$" _ "${VALUE}")

    if(CMAKE_MATCH_0)
        # Valid semver
        set(${out_version} "${VERSION_QUALIFIER}" "${CMAKE_MATCH_1}" "${CMAKE_MATCH_2}" "${CMAKE_MATCH_3}" PARENT_SCOPE)
    else()
        # ----------------------------------------------------
        # Not semver → treat as tag or commit hash
        # ----------------------------------------------------

        # Disallow ^ and ~ for non-semver
        if(VERSION_QUALIFIER STREQUAL "^" OR VERSION_QUALIFIER STREQUAL "~")
            message(FATAL_ERROR "BPM [${NAME}]: Invalid constraint '${VERSION_QUALIFIER}' for non-semver reference '${VALUE}'")
        endif()

        # Only allow empty, '=' or '>='
        if(VERSION_QUALIFIER AND
            NOT VERSION_QUALIFIER STREQUAL "=" AND
            NOT VERSION_QUALIFIER STREQUAL ">=")
            message(FATAL_ERROR "BPM [${NAME}]: Invalid qualifier '${VERSION_QUALIFIER}' for tag/hash '${VALUE}'")
        endif()

        set(${out_version} "${VERSION_QUALIFIER}" "${VALUE}" PARENT_SCOPE)
    endif()
endfunction()

# @brief parses a path or url followed by a tag, commit or version with optional constraints
# 
# examples:
# ---------
# - path: `https://github.com/org/repo`
#
# - with version: https://github.com/org/repo@1.2.3
# - with v-version: https://github.com/org/repo@v1.2.3
# 
# - with constrained version: https://github.com/org/repo@>=1.2.3
# - with constrained version: https://github.com/org/repo@^1.2.3
# - with constrained version: https://github.com/org/repo@~1.2.3
# - with constrained version: https://github.com/org/repo@=1.2.3
#
# - with constrained v-version: https://github.com/org/repo@>=v1.2.3
# - with constrained v-version: https://github.com/org/repo@^v1.2.3
# - with constrained v-version: https://github.com/org/repo@~v1.2.3
# - with constrained v-version: https://github.com/org/repo@=v1.2.3
# 
# - with named tag: https://github.com/org/repo@git-tag
# - with constrained named tag: https://github.com/org/repo@>=git-tag
# - with constrained named tag: https://github.com/org/repo@=git-tag
# - Not allowed: https://github.com/org/repo@^git-tag
# - Not allowed: https://github.com/org/repo@~git-tag
#
# - with commit hash: https://github.com/org/repo@a5486b
# - with constrained commit hash: https://github.com/org/repo@>=a5486b
# - Not allowed: https://github.com/org/repo@^a5486b
# - Not allowed: https://github.com/org/repo@~a5486b
# ```
#
# Outputs:
# - PARSE_FULL_PATH
# - PARSE_NAME
# - PARSE_VERSION_QUALIFIER
# - PARSE_VERSION_MAJOR
# - PARSE_VERSION_MINOR
# - PARSE_VERSION_PATCH
# - PARSE_GIT_TAG_OR_HASH
# 

function(bpm_parse_short_dependency INPUT out_git_repo out_name out_tag)

    # ------------------------------------------------------------
    # Split into FULL_PATH and optional VERSION_PART using '@'
    # ------------------------------------------------------------
    string(REGEX MATCH "^([^@]+)(@(.+))?$" _ "${INPUT}")

    set(FULL_PATH "${CMAKE_MATCH_1}")
    set(VERSION_PART "${CMAKE_MATCH_3}")

    # ------------------------------------------------------------
    # Extract repository name (after last '/' or '\')
    # ------------------------------------------------------------
    string(REGEX MATCH "([^/\\\\]+)$" _ "${FULL_PATH}")
    set(NAME "${CMAKE_MATCH_1}")
    if(NOT NAME)
        message(FATAL_ERROR "BPM: Could not extract the repository name. Expected: 'paht/name' or `NAME ... GIT_REPOSITORY ... GIT_TAG ...` but got: ${FULL_PATH}")
    endif()

    if(NOT INPUT)
        message(FATAL_ERROR "BPM [${NAME}]: No version string provided. Expected: 'path/name@version'")
    endif()

    # ------------------------------------------------------------
    # Export results
    # ------------------------------------------------------------
          
    set(${out_git_repo} "${FULL_PATH}" PARENT_SCOPE)
    set(${out_name} "${NAME}" PARENT_SCOPE)
    set(${out_tag} "${VERSION_PART}" PARENT_SCOPE)

endfunction()

function(bpm_parse_arguments INPUT out_name out_repo out_tag out_build_type out_options out_packages out_quiet out_version)

    # Parse arguments in long form
    set(options QUIET)
    set(oneValueArgs NAME GIT_REPOSITORY GIT_TAG BUILD_TYPE)
    set(multiValueArgs PACKAGES OPTIONS)
    cmake_parse_arguments(PKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${INPUT})

    # Parse arguments in short form
    if(NOT PKG_NAME AND NOT PKG_GIT_REPOSITORY AND NOT PKG_GIT_TAG)
        list(GET INPUT 0 FIRST_ARG)
        bpm_parse_short_dependency(${FIRST_ARG} PKG_GIT_REPOSITORY PKG_NAME PKG_GIT_TAG)
    endif()
        
        
    # Validate arguments
    if(NOT PKG_NAME)
        message(FATAL_ERROR "BPM: NAME is required")
    endif()

    if(BPM_${PKG_NAME}_ADDED)
        message(STATUS "${BPM_NAME} was already added")
        return()
    endif()

    if(NOT PKG_PACKAGES)
        set(PKG_PACKAGES ${PKG_NAME})
    endif()
    
    if(NOT PKG_GIT_REPOSITORY)
        message(FATAL_ERROR "BPM [${PKG_NAME}]: GIT_REPOSITORY is required")
    endif()

    if(NOT PKG_GIT_TAG)
        message(FATAL_ERROR "BPM [${PKG_NAME}]: GIT_TAG is required")
    else()
        bpm_parse_version_string("${PKG_GIT_TAG}" PKG_VERSION)
    endif()

    if(NOT PKG_BUILD_TYPE)
        set(BPM_BUILD_TYPE Release)
    endif()

    if(BPM_QUIET)
        set(out_quiet ON)
    else()
        set(out_quiet OFF)
    endif()
      
    set(${out_name} ${PKG_NAME} PARENT_SCOPE)
    set(${out_repo} ${PKG_GIT_REPOSITORY} PARENT_SCOPE)
    set(${out_tag} ${PKG_GIT_TAG} PARENT_SCOPE)
    set(${out_build_type} ${PKG_BUILD_TYPE} PARENT_SCOPE)
    set(${out_version_qualifier} ${PKG_VERSION_QUALIFIER} PARENT_SCOPE)
    set(${out_version} ${PKG_VERSION} PARENT_SCOPE)
    set(${out_options} ${PKG_OPTIONS} PARENT_SCOPE)
    set(${out_packages} ${PKG_PACKAGES} PARENT_SCOPE)

endfunction()

# @brief sets `out_upgradeable` to `TRUE` if the version A, with its qualifier can be upgraded to version B
function(bpm_is_version_upgradeable QUALIFIER_A MAJOR_A MINOR_A PATCH_A MAJOR_B MINOR_B PATCH_B out_upgradeable)
    if(QUALIFIER_A STREQUAL ">=")
        # check if every part of B is larger or equal than A
        if(MAJOR_A LESS MAJOR_B)
            set(${out_upgradeable} TRUE PARENT_SCOPE)
        elseif(MAJOR_A EQUAL MAJOR_B AND MINOR_A LESS MINOR_B)
            set(${out_upgradeable} TRUE PARENT_SCOPE)
        elseif(MAJOR_A EQUAL MAJOR_B AND MINOR_A EQUAL MINOR_B AND PATCH_A LESS_EQUAL PATCH_B)
            set(${out_upgradeable} TRUE PARENT_SCOPE)
        else()
            set(${out_upgradeable} FALSE PARENT_SCOPE)
        endif()
    elseif(QUALIFIER_A STREQUAL "^")
        # check if major is equal and others are larger or equal
        if(MAJOR_A EQUAL MAJOR_B AND MINOR_A LESS MINOR_B)
            set(${out_upgradeable} TRUE PARENT_SCOPE)
        elseif(MAJOR_A EQUAL MAJOR_B AND MINOR_A EQUAL MINOR_B AND PATCH_A LESS_EQUAL PATCH_B)
            set(${out_upgradeable} TRUE PARENT_SCOPE)
        else()
            set(${out_upgradeable} FALSE PARENT_SCOPE)
        endif()
    elseif(QUALIFIER_A STREQUAL "~")
        # check if major and minor are equal and others are larger or equal
        if(MAJOR_A EQUAL MAJOR_B AND MINOR_A EQUAL MINOR_B AND PATCH_A LESS_EQUAL PATCH_B)
            set(${out_upgradeable} TRUE PARENT_SCOPE)
        else()
            set(${out_upgradeable} FALSE PARENT_SCOPE)
        endif()
    else()# if(INPUT STREQUAL "=")
        # check if all are equal
        if(MAJOR_A EQUAL MAJOR_B AND MINOR_A EQUAL MINOR_B AND PATCH_A EQUAL PATCH_B)
            set(${out_upgradeable} TRUE PARENT_SCOPE)
        else()
            set(${out_upgradeable} FALSE PARENT_SCOPE)
        endif()
    endif()
endfunction()

# @brief sets out to true if A < B
function(bpm_version_less MAJOR_A MINOR_A PATCH_A MAJOR_B MINOR_B PATCH_B out)
    if(MAJOR_A LESS MAJOR_B)
        set(${out} TRUE PARENT_SCOPE)
    elseif(MAJOR_A EQUAL MAJOR_B AND MINOR_A LESS MINOR_B)
        set(${out} TRUE PARENT_SCOPE)
    elseif(MAJOR_A EQUAL MAJOR_B AND MINOR_A EQUAL MINOR_B AND PATCH_A LESS PATCH_B)
        set(${out} TRUE PARENT_SCOPE)
    else() 
        set(${out} FALSE PARENT_SCOPE)
    endif()
endfunction()

# @brief sets out to true if a has A stricter qualifier than B
function(bpm_is_stricter_qualifier QUALIFIER_A QUALIFIER_B OUT)
    if(QUALIFIER_A STREQUAL ">=")
        set(${OUT} FALSE PARENT_SCOPE)
    elseif(QUALIFIER_A STREQUAL "^")
        if(QUALIFIER_B STREQUAL ">=")
            set(${OUT} TRUE PARENT_SCOPE)
        else()
            set(${OUT} FALSE PARENT_SCOPE)
        endif()
    elseif(QUALIFIER_A STREQUAL "~")
        if(QUALIFIER_B STREQUAL ">=" OR QUALIFIER_B STREQUAL "^")
            set(${OUT} TRUE PARENT_SCOPE)
        else()
            set(${OUT} FALSE PARENT_SCOPE)
        endif()
    elseif(QUALIFIER_A STREQUAL "=")
        if(QUALIFIER_B STREQUAL "=")
            set(${OUT} FALSE PARENT_SCOPE)
        else()
            set(${OUT} TRUE PARENT_SCOPE)
        endif()
    else()
        message(FATAL_ERROR "BPM: Unsupported qualifier '${QUALIFIER_A}'")
    endif()
endfunction()

# TODO: This funtion
# write a function that selects the lowest version with the strongest qualifier that is within both versions
# @brief outputs the intersection of both versions and qualifiers
# @param QUALIFIER_A the version qualifier: '>=', '^',  '~' or '='
# @param QUALIFIER_A_SETTER the project name that has set that qualifier
# @param MAJOR_A The major version number
# @param MINOR_A The minor version number
# @param PATCH_A The patch version number
# @param VERSION_A_SETTER The project name that has set the version numbers
function(bpm_upgrade_version VERSION_A QUALIFIER_A_SETTER VERSION_A_SETTER VERSION_B QUALIFIER_B_SETTER VERSION_B_SETTER out_version out_qualifier_setter out_version_setter)
    list(LENGTH VERSION_A len)
    if(NOT len EQUAL 4)
        message(FATAL_ERROR "BPM: In function: bpm_upgrade_version only semver version are supported. Git tags or hashes are not supported yet. len: ${len}")
    endif()

    list(LENGTH VERSION_B len)
    if(NOT len EQUAL 4)
        message(FATAL_ERROR "BPM: In function: bpm_upgrade_version only semver version are supported. Git tags or hashes are not supported yet. len: ${len}")
    endif()
    
    list(GET VERSION_A 0 QUALIFIER_A)
    list(GET VERSION_A 1 MAJOR_A)
    list(GET VERSION_A 2 MINOR_A)
    list(GET VERSION_A 3 PATCH_A)

    list(GET VERSION_B 0 QUALIFIER_B)
    list(GET VERSION_B 1 MAJOR_B)
    list(GET VERSION_B 2 MINOR_B)
    list(GET VERSION_B 3 PATCH_B)

    bpm_version_less(${MAJOR_A} ${MINOR_A} ${PATCH_A} ${MAJOR_B} ${MINOR_B} ${PATCH_B} va_less_vb)
    set(is_upgradeable FALSE)
    if(va_less_vb)
        bpm_is_version_upgradeable(${QUALIFIER_A} ${MAJOR_A} ${MINOR_A} ${PATCH_A} ${MAJOR_B} ${MINOR_B} ${PATCH_B} is_upgradeable)
        if(is_upgradeable)
            set(out_major ${MAJOR_B})
            set(out_minor ${MINOR_B})
            set(out_patch ${PATCH_B}) 
            set(out_version_setter ${VERSION_B_SETTER})
        endif()
    else()
        bpm_is_version_upgradeable(${QUALIFIER_B} ${MAJOR_B} ${MINOR_B} ${PATCH_B} ${MAJOR_A} ${MINOR_A} ${PATCH_A} is_upgradeable)
        if(is_upgradeable)
            set(out_major ${MAJOR_A})
            set(out_minor ${MINOR_A})
            set(out_patch ${PATCH_A}) 
            set(out_version_setter ${VERSION_A_SETTER})
        endif()
    endif()

    if(NOT is_upgradeable)
        if(VERSION_A_SETTER STREQUAL QUALIFIER_A_SETTER)
            set(ERR_MSG_A "${QUALIFIER_A}${MAJOR_A}.${MINOR_A}.${PATCH_A} set by ${VERSION_A_SETTER}")
        else()
            set(ERR_MSG_A "${QUALIFIER_A}${MAJOR_A}.${MINOR_A}.${PATCH_A} set by ${QUALIFIER_A_SETTER} and ${VERSION_A_SETTER}")
        endif()
        if(VERSION_B_SETTER STREQUAL QUALIFIER_B_SETTER)
            set(ERR_MSG_B "${QUALIFIER_B}${MAJOR_B}.${MINOR_B}.${PATCH_B} set by ${VERSION_B_SETTER}")
        else()
            set(ERR_MSG_B "${QUALIFIER_B}${MAJOR_B}.${MINOR_B}.${PATCH_B} set by ${QUALIFIER_B_SETTER} and ${VERSION_B_SETTER}")
        endif()
        message(FATAL_ERROR "BPM [${PKG_NAME}]: Version conflict: ${ERR_MSG_A} <-- vs -->  ${ERR_MSG_B}")
    endif()
    
    bpm_is_stricter_qualifier(${QUALIFIER_A} ${QUALIFIER_B} qa_stricter_than_qb)
    if(qa_stricter_than_qb)
        set(out_qualifier ${QUALIFIER_A})
        set(${out_qualifier_setter} ${QUALIFIER_A_SETTER} PARENT_SCOPE)
    else()
        set(out_qualifier ${QUALIFIER_B})
        set(${out_qualifier_setter} ${QUALIFIER_B_SETTER} PARENT_SCOPE)
    endif()

    set(${out_version} ${out_qualifier} ${out_major} ${out_minor} ${out_patch} PARENT_SCOPE)
endfunction()

# @brief Creates a package registry and resolves versions
#
# Accepts shorthand reposiotories like: 
# ```
# https://github.com/org/repo@1.2.3
# ```
# or:
# ```
# BPMAddPackage(
#     NAME <name>
#     GIT_REPOSITORY <repo address>
#     GIT_TAG <version tag>
#     BUILD_TYPE <type: Release/Debug>
#     OPTIONS <Optional args>
# )
# ```

function(BPMAddInstallPackage)
    bpm_parse_arguments("${ARGN}" PKG_NAME PKG_GIT_REPOSITORY PKG_GIT_TAG PKG_BUILD_TYPE PKG_OPTIONS PKG_PACKAGES PKG_QUIET PKG_VERSION)

    

    # Create the Registry and delete the old one
    # --------------------------------------------------------------------------------
    get_property(BPM_REGISTRY_ GLOBAL PROPERTY BPM_REGISTRY)
    if(BPM_REGISTRY_)
        # uniquely add the package name to the list
        get_property(BPM_${PKG_NAME}_ADDED_ GLOBAL PROPERTY BPM_${PKG_NAME}_ADDED)
        if(NOT BPM_${PKG_NAME}_ADDED_)
            list(APPEND BPM_REGISTRY_ "${PKG_NAME}")
            set_property(GLOBAL PROPERTY BPM_REGISTRY "${BPM_REGISTRY_}")
        endif()
    else()

        set_property(GLOBAL PROPERTY BPM_REGISTRY "${PKG_NAME}")

        # also delete the old registry file when creating a new one
        if(PROJECT_IS_TOP_LEVEL)
            if(EXISTS "${CMAKE_BINARY_DIR}/BPM/BPM_REGISTRY")
                file(REMOVE "${CMAKE_BINARY_DIR}/BPM/BPM_REGISTRY")
            endif()
        endif()
    endif()

    # Build the local registry based on its provided version
    # --------------------------------------------------------------------------------
    get_property(BPM_${PKG_NAME}_ADDED_ GLOBAL PROPERTY BPM_${PKG_NAME}_ADDED)
    if(NOT BPM_${PKG_NAME}_ADDED_)
        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION ${PKG_VERSION})
        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_REQUIRED_FROM "") # empty equals root
        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_LAST_SET_BY ${PROJECT_NAME})
        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_QUALIFIER_LAST_SET_BY ${PROJECT_NAME})
    else()
        # check if the version number can be updated 
        get_property(VERSION_A GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION)
        get_property(QUALIFIER_A_SETTER GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_QUALIFIER_LAST_SET_BY)
        get_property(VERSION_A_SETTER GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_LAST_SET_BY)

        bpm_upgrade_version("${VERSION_A}" "${QUALIFIER_A_SETTER}" "${VERSION_A_SETTER}"
            "${PKG_VERSION}" "${PROJECT_NAME}" "${PROJECT_NAME}"
            out_version out_qualifier_setter out_version_setter)

        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION ${out_version})
        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_QUALIFIER_LAST_SET_BY ${out_qualifier_setter})
        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_LAST_SET_BY ${out_version_setter})
    endif()

    set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_INSTALL TRUE)
    set_property(GLOBAL PROPERTY BPM_${PKG_NAME}_ADDED ON)

    # Get the BPM Cache location from `-DBPM_CACHE=` or environment variable or set it do default
    set(bpm_cache_dir "")

    get_property(BPM_CHACHE_LOCATION_RESOLVED_ GLOBAL PROPERTY BPM_CHACHE_LOCATION_RESOLVED)
    if(NOT BPM_CHACHE_LOCATION_RESOLVED_)
        set_property(GLOBAL PROPERTY BPM_CHACHE_LOCATION_RESOLVED ON)
    endif()

    if(DEFINED BPM_CACHE AND NOT "${BPM_CACHE}" STREQUAL "")
        if(NOT BPM_CHACHE_LOCATION_RESOLVED_) # only print it the first time
            message(STATUS "BPM: resolve BPM_CACHE - from CMAKE_ARG: ${BPM_CACHE}")
        endif()
        set(bpm_cache_dir ${BPM_CACHE})
    elseif(DEFINED ENV{BPM_CACHE} AND NOT "$ENV{BPM_CACHE}" STREQUAL "")
        set(bpm_cache_dir "$ENV{BPM_CACHE}")
        if(NOT BPM_CHACHE_LOCATION_RESOLVED_) # only print it the first time
            message(STATUS "BPM: resolve BPM_CACHE - from environment variable: ${bpm_cache_dir}")
        endif()
    else()
        file(RELATIVE_PATH rel_build_dir "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}")
        if(NOT BPM_CHACHE_LOCATION_RESOLVED_) # only print it the first time
            message(STATUS "BPM: resolve ${RESULT_VAR} - no cache provided: use local: ./${rel_build_dir}/_deps")
        endif()
        set(bpm_cache_dir "./${rel_build_dir}/_deps")
    endif()


endfunction()

function(BPMAddSourcePackage)

    bpm_parse_arguments("${ARGN}" PKG_NAME PKG_GIT_REPOSITORY PKG_GIT_TAG PKG_BUILD_TYPE PKG_OPTIONS PKG_PACKAGES PKG_QUIET PKG_VERSION_QUALIFIER PKG_V_MAJOR PKG_V_MINOR PKG_V_PATCH)

    # TODO:

endfunction()


function(bpm_write_registry_file)

    get_property(BPM_REGISTRY_ GLOBAL PROPERTY BPM_REGISTRY)
    foreach(pkg_name IN LISTS BPM_REGISTRY_)
        get_property(pkg_v_qualifier GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_VERSION_QUALIFIER)
        get_property(pkg_v_qualifier_setter GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_VERSION_QUALIFIER_LAST_SET_BY)
        
        get_property(pkg_major GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_VERSION_MAJOR)
        get_property(pkg_minor GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_VERSION_MINOR)
        get_property(pkg_patch GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_VERSION_PATCH)
        get_property(pkg_version_setter GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_VERSION_LAST_SET_BY)

        get_property(pkg_install GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_INSTALL)

        get_property(pkg_from GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_REQUIRED_FROM)
        get_property(pkg_from_major GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_REQUIRED_FROM_MAJOR)
        get_property(pkg_from_minor GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_REQUIRED_FROM_MINOR)
        get_property(pkg_from_patch GLOBAL PROPERTY BPM_REGISTRY_${pkg_name}_REQUIRED_FROM_PATCH)

        set(write_string "FROM ${pkg_from} FROM_VERSION ${pkg_from_version} NAME ${pkg_name} QUALIFIER ${pkg_v_qualifier} QUALIFIER_SETTER ${pkg_v_qualifier_setter} VERSION_MAJOR ${pkg_major} VERSION_MINOR ${pkg_minor} VERSION_PATCH ${pkg_patch} VERSION_SETTER ${pkg_version_setter} INSTALL ${pkg_install}")
        file(APPEND "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry" "${write_string}\n")

    endforeach()

endfunction()

function(BPMMakeAvailable)

    bpm_write_registry_file()

    set(PKG_CMAKE_ARGS "")
    if(PKG_OPTIONS)
        foreach(opt IN LISTS PKG_OPTIONS)
            list(APPEND PKG_CMAKE_ARGS "-D${opt}")
        endforeach()
    endif()

endfunction()


# -----------------------------------------------------
#                   Install
# -----------------------------------------------------

function(BPMCreateInstallPackage)
    include(CMakePackageConfigHelpers)

    if(ARGC EQUAL 1)
        # infere everything from the passed library target
        set(PKG_NAME ${ARGV0})
        set(PKG_NAMESPACE ${ARGV0})
        set(PKG_LIBRARIES ${ARGV0})
    else()
        # provide specific arguments
        set(options "")
        set(oneValueArgs NAME NAMESPACE)
        set(multiValueArgs LIBRARIES PUBLIC_INCLUDE_DIRS HEADER_FILES_MATCHING)
        cmake_parse_arguments(PKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    endif()

    if(NOT PKG_NAME)
        message(FATAL_ERROR "BPMInstall: No NAME provided for the package")
    endif()
    
    if(NOT PKG_LIBRARIES)
        message(FATAL_ERROR "BPMInstall [${PKG_NAME}]: No LIBRARIES provided for the package")
    endif()
    
    if(NOT PKG_NAMESPACE)
        set(PKG_NAMESPACE ${PROJECT_NAME})
    endif()

    if(NOT PKG_HEADER_FILES_MATCHING)
        set(PKG_HEADER_FILES_MATCHING "*.h" "*.hh" "*.hpp" "*.hxx")
    endif()

    if(NOT PKG_PUBLIC_INCLUDE_DIRS)
        set(PKG_PUBLIC_INCLUDE_DIRS "include")
    endif()

    install(TARGETS ${PKG_LIBRARIES}
        EXPORT ${PKG_NAME}_export_set
        ARCHIVE DESTINATION lib
        LIBRARY DESTINATION lib
        RUNTIME DESTINATION bin
        INCLUDES DESTINATION include
    )
    
    set(files_matching "")
    foreach(m IN LISTS PKG_HEADER_FILES_MATCHING)
        LIST(APPEND files_matching "PATTERN" )
        LIST(APPEND files_matching "${m}")
    endforeach()
    
    foreach(dir IN LISTS PKG_PUBLIC_INCLUDE_DIRS)
        # add '/' to the end of the string if it does not have one already
        if(NOT dir MATCHES "/$")
            set(dir "${dir}/")
        endif()

        # add the include directory
        install(
            DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${dir}"
            DESTINATION "${dir}"
            FILES_MATCHING ${files_matching}
        )
    endforeach()

    install(EXPORT ${PKG_NAME}_export_set
        FILE "${PKG_NAME}Targets.cmake"
        NAMESPACE "${PKG_NAMESPACE}::"
        DESTINATION "lib/cmake/${PKG_NAME}"
    )

    set(config_file_in "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}Config.cmake.in")
    set(config_file "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}Config.cmake")
    set(version_file "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}ConfigVersion.cmake")
    file(WRITE "${config_file_in}" "@PACKAGE_INIT@\n\ninclude(\"\${CMAKE_CURRENT_LIST_DIR}/${PKG_NAME}Targets.cmake\")\n")

    configure_package_config_file(
        "${config_file_in}"
        "${config_file}"
        INSTALL_DESTINATION "lib/cmake/${PKG_NAME}"
    )

    install(FILES
        "${config_file}"
        DESTINATION "lib/cmake/${PKG_NAME}"
    )

    if(PROJECT_VERSION)
        write_basic_package_version_file(
            "${version_file}"
            VERSION "${PROJECT_VERSION}"
            COMPATIBILITY SameMajorVersion
        )

        install(FILES
            "${version_file}"
            DESTINATION "lib/cmake/${PKG_NAME}"
        )
    endif()

    
endfunction()