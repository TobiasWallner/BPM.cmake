cmake_minimum_required(VERSION 3.20)

# @parses a constraint + version string into a closed-open range of allowed version
# 
# input: >=1.2.3 --> output: LIST 1.2.3;inf.inf.inf -- meaning: from version 1.2.3 to upper bound inf.inf.inf
# input: ^1.2.3 --> output: LIST 1.2.3;2.0.0 -- meaning from version 1.2.3 to upper bound 2.0.0
function(bpm_parse_version_string in_pkg_name INPUT out_version_range)
    string(REPLACE ";" "\\;" SAFE_INPUT "${INPUT}")

    set(VERSION_QUALIFIER "")
    set(VERSION_MAJOR "")
    set(VERSION_MINOR "")
    set(VERSION_PATCH "")

    string(REGEX MATCH "^[ \t]*(>=|\\^|~|=)?[ \t]*v?([0-9]+\\.[0-9]+\\.[0-9]+)(.*(<)[ \t]*v?([0-9]+\\.[0-9]+\\.[0-9]+)[^<]*)?[ \t]*$" _match_result "${SAFE_INPUT}")

    # message(STATUS "_match_result: ${_match_result}")
    # message(STATUS "CMAKE_MATCH_0: ${CMAKE_MATCH_0}")
    # message(STATUS "CMAKE_MATCH_1: ${CMAKE_MATCH_1}")
    # message(STATUS "CMAKE_MATCH_2: ${CMAKE_MATCH_2}")
    # message(STATUS "CMAKE_MATCH_3: ${CMAKE_MATCH_3}")
    # message(STATUS "CMAKE_MATCH_4: ${CMAKE_MATCH_4}")
    # message(STATUS "CMAKE_MATCH_5: ${CMAKE_MATCH_5}")

    if(_match_result)
        # has a semver version qualifier
        if(CMAKE_MATCH_1)
            set(version_qualifier "${CMAKE_MATCH_1}")
        else()
            set(version_qualifier "=")
        endif()
        set(lower_bound_version "${CMAKE_MATCH_2}")
        set(upper_bound_version "${CMAKE_MATCH_5}")

        if(lower_bound_version)
            if(upper_bound_version)
                if(NOT "${lower_bound_version}" VERSION_LESS "${upper_bound_version}")
                    message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Invalid version constraint: ${version_qualifier}${lower_bound_version} <${upper_bound_version}. The lower bound (${lower_bound_version}) has to be strictly less than the uper bound ${upper_bound_version}")
                endif()
            endif()
        endif()

        string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" _match_result "${lower_bound_version}")
        if(_match_result)
            set(major_lower "${CMAKE_MATCH_1}")
            set(minor_lower "${CMAKE_MATCH_2}")
            set(patch_lower "${CMAKE_MATCH_3}")

            if(version_qualifier STREQUAL ">=")
                set(major_upper "inf")
                set(minor_upper "inf")
                set(patch_upper "inf")
            elseif(version_qualifier STREQUAL "^")
                if(major_lower EQUAL 0)
                    set(major_upper "0")
                    math(EXPR minor_upper "${minor_lower} + 1")
                    set(patch_upper "0")
                else()
                    math(EXPR major_upper "${major_lower} + 1")
                    set(minor_upper "0")
                    set(patch_upper "0")
                endif()
            elseif(version_qualifier STREQUAL "~")
                set(major_upper "${major_lower}")
                math(EXPR minor_upper "${minor_lower} + 1")
                set(patch_upper "0")
            else()
                set(major_upper ${major_lower})
                set(minor_upper ${minor_lower})
                math(EXPR patch_upper "${patch_lower} + 1") # upper bound is non inclusive
            endif()
            
            set(out_version_range_0 "${major_lower}.${minor_lower}.${patch_lower}")
            set(out_version_range_1 "${major_upper}.${minor_upper}.${patch_upper}")

            if(BPM_VERBOSE)
                message(STATUS "BPM [${PROJECT_NAME}:${in_pkg_name}]: range from lowerbound constraint '${version_qualifier}${lower_bound_version}' --> ${out_version_range_0}-${out_version_range_1}")
            endif()

            if(upper_bound_version)
                if("${out_version_range_1}" STREQUAL "inf.inf.inf")
                    set(out_version_range_1 "${upper_bound_version}")
                elseif("${upper_bound_version}" VERSION_LESS out_version_range_1)
                    set(out_version_range_1 "${upper_bound_version}")
                endif()

                if(BPM_VERBOSE)
                    message(STATUS "BPM [${PROJECT_NAME}:${in_pkg_name}]: range from lower- & upper-bound constraints '${version_qualifier}${lower_bound_version} <${upper_bound_version}' --> ${out_version_range_0}-${out_version_range_1}")
                endif()
            endif()
            
            # Valid semver
            set(${out_version_range} "${out_version_range_0}" "${out_version_range_1}" PARENT_SCOPE)
            return()
        else()
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: lower_bound_version (${lower_bound_version}) not semver")
        endif()
    else()
        # no semver version qualifier --> assume git-tag or git-commit-hash
        string(REGEX MATCH "^[ \t]*((>=|\\^|~|=)?[ \t]*(.*[^ \t]))[ \t]*$" _match_result "${SAFE_INPUT}")
        
        # message(STATUS "_match_result: ${_match_result}")
        # message(STATUS "CMAKE_MATCH_0: ${CMAKE_MATCH_0}")
        # message(STATUS "CMAKE_MATCH_1: ${CMAKE_MATCH_1}")
        # message(STATUS "CMAKE_MATCH_2: ${CMAKE_MATCH_2}")
        # message(STATUS "CMAKE_MATCH_3: ${CMAKE_MATCH_3}")
        
        if(_match_result)
            set(git_tag "${CMAKE_MATCH_1}")

            set(version_qualifier "${CMAKE_MATCH_2}")
            if(version_qualifier)
                message(WARNING "BPM [${PROJECT_NAME}:${in_pkg_name}]: Version constraints (like '${version_qualifier}') are not supported for named-git-tags or git-commit-hashes '${git_tag}'.")
            endif()

            string(REGEX MATCH "[ \t\r\n]" has_ws "${git_tag}")
            if(has_ws)
                message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Git-tag or commit-hash '${git_tag}' cannot contain whitespaces.")
            endif()

            set(${out_version_range} "${git_tag}" PARENT_SCOPE)
            return()
        else()
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Could not parse version string ${INPUT}")
        endif()
    endif()

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
    # Try semantic version
    # --------------------------------------------------------
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${SAFE_INPUT}")

    if(CMAKE_MATCH_0)
        set(major_lower "${CMAKE_MATCH_1}")
        set(minor_lower "${CMAKE_MATCH_2}")
        set(patch_lower "${CMAKE_MATCH_3}")

        if(VERSION_QUALIFIER STREQUAL ">=")
            set(major_upper "inf")
            set(minor_upper "inf")
            set(patch_upper "inf")
        elseif(VERSION_QUALIFIER STREQUAL "^")
            if(major_lower EQUAL 0)
                set(major_upper "0")
                math(EXPR minor_upper "${minor_lower} + 1")
                set(patch_upper "0")
            else()
                math(EXPR major_upper "${major_lower} + 1")
                set(minor_upper "0")
                set(patch_upper "0")
            endif()
        elseif(VERSION_QUALIFIER STREQUAL "~")
            set(major_upper "${major_lower}")
            math(EXPR minor_upper "${minor_lower} + 1")
            set(patch_upper "0")
        else()
            set(major_upper ${major_lower})
            set(minor_upper ${minor_lower})
            math(EXPR patch_upper "${patch_lower} + 1") # upper bound is non inclusive
        endif()

        # Valid semver
        set(${out_version_range} 
            "${major_lower}.${minor_lower}.${patch_lower}" 
            "${major_upper}.${minor_upper}.${patch_upper}"
            PARENT_SCOPE)
        return()
    else()
        # check for user input errors
        if(NOT (VERSION_QUALIFIER STREQUAL ">=" OR VERSION_QUALIFIER STREQUAL "^" OR VERSION_QUALIFIER STREQUAL "~" OR VERSION_QUALIFIER STREQUAL "="))
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${NAME}]: Invalid qualifier '${VERSION_QUALIFIER}'. Allowed are: '>=', '^', '~', '=' and ''")
        endif()

        # ------------------ ----------------------------------
        # Not semver → treat as tag or commit hash
        # ----------------------------------------------------

        # Disallow ^ and ~ for non-semver
        if(VERSION_QUALIFIER STREQUAL ">=" OR VERSION_QUALIFIER STREQUAL "^" OR VERSION_QUALIFIER STREQUAL "~")
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${NAME}]: Invalid constraint '${VERSION_QUALIFIER}' for non-semver reference '${VALUE}'")
        endif()

        set(${out_version_range} "${VALUE}" PARENT_SCOPE)
        return()
    endif()
endfunction()


function(bpm_parse_short_dependency INPUT out_git_repo out_name out_tag)

    # ------------------------------------------------------------
    # Split into FULL_PATH and optional VERSION_PART using '#'
    # ------------------------------------------------------------
    string(REGEX MATCH "^([^#]+)(#(.+))?$" _ "${INPUT}")

    set(FULL_PATH "${CMAKE_MATCH_1}")
    if(BPM_VERBOSE)
        message(STATUS "${INPUT} --> Full Path: ${FULL_PATH}")
    endif()

    set(VERSION_PART "${CMAKE_MATCH_3}")
    if(BPM_VERBOSE)
        message(STATUS "${INPUT} --> Full Path: ${VERSION_PART}")
    endif()

    # ------------------------------------------------------------
    # Extract repository name (after last '/' or '\')
    # ------------------------------------------------------------
    #string(REGEX MATCH "([^/\\\\]+)\\.git$" _ "${FULL_PATH}")
    string(REGEX MATCH "^.*[/\\\\]([^/\\\\]+)$" _ "${FULL_PATH}")
    set(NAME "${CMAKE_MATCH_1}")
    if(BPM_VERBOSE)
        message(STATUS "${INPUT} --> Name: ${NAME}")
    endif()

    string(REGEX REPLACE "\\.git[ \t]*$" "" NAME "${NAME}")
    if(BPM_VERBOSE)
        message(STATUS "${INPUT} --> Name (removed '.git'): ${NAME}")
    endif()

    if(NOT NAME)
        message(FATAL_ERROR "BPM [${PROJECT_NAME}]: Could not extract the repository name. Expected: 'path/name' or `NAME ... GIT_REPOSITORY ... GIT_TAG ...` but got: ${FULL_PATH}")
    endif()

    if(NOT VERSION_PART)
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${NAME}]: No version string provided. Expected: 'path/name#version'")
    endif()

    # ------------------------------------------------------------
    # Export results
    # ------------------------------------------------------------
          
    set(${out_git_repo} "${FULL_PATH}" PARENT_SCOPE)
    set(${out_name} "${NAME}" PARENT_SCOPE)
    set(${out_tag} "${VERSION_PART}" PARENT_SCOPE)

endfunction()

function(bpm_parse_arguments INPUT out_name out_repo out_tag out_options out_packages out_version)

    # Parse arguments in long form
    set(options QUIET)
    set(oneValueArgs NAME GIT_REPOSITORY GIT_TAG)
    set(multiValueArgs PACKAGES OPTIONS)
    cmake_parse_arguments(PKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${INPUT})

    # Parse arguments in short form
    if(NOT PKG_NAME AND NOT PKG_GIT_REPOSITORY AND NOT PKG_GIT_TAG)
        list(GET INPUT 0 FIRST_ARG)
        bpm_parse_short_dependency(${FIRST_ARG} PKG_GIT_REPOSITORY PKG_NAME PKG_GIT_TAG)
    endif()
        
    # Validate arguments
    if(NOT PKG_NAME)
        message(FATAL_ERROR "BPM [${PROJECT_NAME}]: NAME is required")
    endif()

    if(BPM_${PKG_NAME}_ADDED)
        message(STATUS "${BPM_NAME} was already added")
        return()
    endif()

    if(NOT PKG_PACKAGES)
        set(PKG_PACKAGES "${PKG_NAME}")
    endif()
    
    if(NOT PKG_GIT_REPOSITORY)
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: GIT_REPOSITORY is required")
    endif()

    if(NOT PKG_GIT_TAG)
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: git-tag or version constraint is required")
    else()
        bpm_parse_version_string("${PKG_NAME}" "${PKG_GIT_TAG}" PKG_VERSION)
    endif()
      
    set(${out_name} ${PKG_NAME} PARENT_SCOPE)
    set(${out_repo} ${PKG_GIT_REPOSITORY} PARENT_SCOPE)
    set(${out_tag} ${PKG_GIT_TAG} PARENT_SCOPE)
    set(${out_version_qualifier} ${PKG_VERSION_QUALIFIER} PARENT_SCOPE)
    set(${out_version} ${PKG_VERSION} PARENT_SCOPE)
    set(${out_options} ${PKG_OPTIONS} PARENT_SCOPE)
    set(${out_packages} ${PKG_PACKAGES} PARENT_SCOPE)

endfunction()

function(bpm_version_range_intersection in_version_range_a in_version_range_b out_version_range)
    list(GET in_version_range_a 0 a_lower)
    list(GET in_version_range_a 1 a_upper)

    list(GET in_version_range_b 0 b_lower)
    list(GET in_version_range_b 1 b_upper)


    if(a_lower VERSION_LESS b_lower)
        set(lower_bound ${b_lower})
    else()
        set(lower_bound ${a_lower})
    endif()

    if((a_upper STREQUAL "inf.inf.inf") AND (b_upper STREQUAL "inf.inf.inf"))
        set(upper_bound "inf.inf.inf")
    elseif((NOT a_upper STREQUAL "inf.inf.inf") AND (b_upper STREQUAL "inf.inf.inf"))
        set(upper_bound "${a_upper}")
    elseif((a_upper STREQUAL "inf.inf.inf") AND (NOT b_upper  STREQUAL "inf.inf.inf"))
        set(upper_bound "${b_upper}")
    elseif(a_upper VERSION_LESS b_upper)
        set(upper_bound "${a_upper}")
    else()
        set(upper_bound "${b_upper}")
    endif()

    if((NOT upper_bound STREQUAL "inf.inf.inf") AND (upper_bound VERSION_LESS lower_bound))
        # version conflict: return without result
        return()
    endif()

    set(${out_version_range} "${lower_bound}" "${upper_bound}" PARENT_SCOPE)
endfunction()

# #brief Creates a package registry and resolves versions
#
# Accepts shorthand reposiotories like: 
# ```
# https://github.com/org/repo#1.2.3
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

function(bpm_add_package_to_registry PKG_NAME PKG_GIT_REPOSITORY PKG_GIT_TAG PKG_OPTIONS PKG_PACKAGES PKG_VERSION_RANGE TYPE)
    if(NOT (("${TYPE}" STREQUAL "INSTALL") OR ("${TYPE}" STREQUAL "ADD_SUBDIR")))
        message(FATAL_ERROR "BPM: Internal error: TYPE (${TYPE}) should be 'INSTALL' or 'ADD_SUBDIR'")
    endif()

    get_property(BPM_REGISTRY_ GLOBAL PROPERTY BPM_REGISTRY)
    if(BPM_REGISTRY_)
        # uniquely add the package name to the list
        get_property("BPM_${PKG_NAME}_ADDED_" GLOBAL PROPERTY "BPM_${PKG_NAME}_ADDED")
        if(NOT BPM_${PKG_NAME}_ADDED_)
            list(APPEND BPM_REGISTRY_ "${PKG_NAME}")
            set_property(GLOBAL PROPERTY BPM_REGISTRY "${BPM_REGISTRY_}")
        endif()
    else()
        set_property(GLOBAL PROPERTY BPM_REGISTRY "${PKG_NAME}")
    endif()

    get_property(BPM_${PKG_NAME}_ADDED_ GLOBAL PROPERTY BPM_${PKG_NAME}_ADDED)
    if(NOT BPM_${PKG_NAME}_ADDED_)
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE" "${PKG_VERSION_RANGE}")
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_TAG" "${PKG_GIT_TAG}") # TODO rename to constraint
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_REPOSITORY" "${PKG_GIT_REPOSITORY}")
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_PACKAGES" "${PKG_PACKAGES}")
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_TYPE" "${TYPE}")

        # sort options
        list(SORT PKG_OPTIONS)
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_OPTIONS" "${PKG_OPTIONS}")
    else()
        #message(WARNING "BPM [${PROJECT_NAME}:${PKG_NAME}]: Defined twice in the same project")

        get_property(REGISTERED_GIT_REPOSITORY GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_REPOSITORY")
        if(NOT "${REGISTERED_GIT_REPOSITORY}" STREQUAL "${PKG_GIT_REPOSITORY}")
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}}: Repository Conflict: new: ${PKG_GIT_REPOSITORY}, previously defined: ${REGISTERED_GIT_REPOSITORY}")
        endif()

        get_property(REGISTERED_VERSION_RANGE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE")

        bpm_version_range_intersection("${REGISTERED_VERSION_RANGE}" "${PKG_VERSION_RANGE}" intersec_version_range)
        if(NOT intersec_version_range)
            message(FATAL_ERROR 
                "BPM ${PKG_NAME}: Version Conflict, new: ${PKG_VERSION_RANGE}, previously defined: ${REGISTERED_VERSION_RANGE}")
        endif()

        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE "${intersec_version_range}")

        # check if there is an option conflict:
        list(SORT PKG_OPTIONS)
        get_property(REGISTERED_OPTIONS GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_OPTIONS")
        if(NOT "${REGISTERED_OPTIONS}" STREQUAL "${PKG_OPTIONS}")
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: options conflict: new: '${REGISTERED_OPTIONS}', previously defined: '${PKG_OPTIONS}'")
        endif()

        # check if there is a packages conflict
        get_property(REGISTERED_PACKAGES GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_PACKAGES")
        set(JOINED_PACKAGES ${PKG_PACKAGES} ${REGISTERED_PACKAGES})
        list(REMOVE_DUPLICATES JOINED_PACKAGES)
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_PACKAGES" "${JOINED_PACKAGES}")

        # check if there is a type conflict
        get_property(REGISTERED_TYPE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_TYPE")
        if(NOT "${REGISTERED_TYPE}" STREQUAL "${TYPE}")
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Package added, onece as 'INSTALL' (find_package) and once as 'SOURCE' (add_subdirectory). Decide on one to prevent target-name conflicts.")
        endif()

    endif()

    set_property(GLOBAL PROPERTY "BPM_${PKG_NAME}_ADDED" TRUE)
endfunction()


function(BPMAddInstallPackage)

    if(NOT PROJECT_IS_TOP_LEVEL)
        return()
    endif()

    bpm_parse_arguments("${ARGN}"
        PKG_NAME PKG_GIT_REPOSITORY PKG_GIT_TAG 
        PKG_OPTIONS PKG_PACKAGES PKG_VERSION_RANGE)

    bpm_add_package_to_registry("${PKG_NAME}" "${PKG_GIT_REPOSITORY}" "${PKG_GIT_TAG}" "${PKG_OPTIONS}" "${PKG_PACKAGES}" "${PKG_VERSION_RANGE}" "INSTALL")

endfunction()

function(BPMAddSourcePackage)

    if(NOT PROJECT_IS_TOP_LEVEL)
        return()
    endif()

    bpm_parse_arguments("${ARGN}"
        PKG_NAME PKG_GIT_REPOSITORY PKG_GIT_TAG 
        PKG_OPTIONS PKG_PACKAGES PKG_VERSION_RANGE)

    bpm_add_package_to_registry("${PKG_NAME}" "${PKG_GIT_REPOSITORY}" "${PKG_GIT_TAG}" "${PKG_OPTIONS}" "${PKG_PACKAGES}" "${PKG_VERSION_RANGE}" "ADD_SUBDIR")

endfunction()

function(bpm_get_cache_dir RESULT_VAR)
    set(_value "")

    if(DEFINED BPM_CACHE AND NOT "${BPM_CACHE}" STREQUAL "")
        set(_value "${BPM_CACHE}")
        message(STATUS "BPM [${PROJECT_NAME}]: resolve BPM_CACHE - from CMAKE_ARG: ${BPM_CACHE}")
    elseif(DEFINED ENV{BPM_CACHE} AND NOT "$ENV{BPM_CACHE}" STREQUAL "")
        set(_value "$ENV{BPM_CACHE}")
        message(STATUS "BPM [${PROJECT_NAME}]: resolve BPM_CACHE - from environment variable: ${_value}")
    else()
        set(_value "${CMAKE_BINARY_DIR}/_deps")
        message(STATUS "BPM [${PROJECT_NAME}]: resolve BPM_CACHE - no cache provided: use local: ${_value}")
    endif()

    set(${RESULT_VAR} "${_value}" PARENT_SCOPE)
endfunction()

function(bpm_fully_contains_tag_range IN_VERSIONS RANGE OUT)
    list(LENGTH RANGE LIST_SIZE)

    # check if it is a range or a singular version (like for named git tags or hashes)
    if(LIST_SIZE EQUAL 1)
        # it is a named tag (not a version tag) or a commit hash
        list(GET RANGE 0 tag_or_hash)
        message(FATAL_ERROR "Continue working here. Allowing git tags and hashes. tag or hash: '${tag_or_hash}'. versions: '${IN_VERSIONS}'")
        return()
    endif()

    list(GET RANGE 0 version_lower)
    list(GET RANGE 1 version_upper)

    if("${version_upper}" STREQUAL "inf.inf.inf")
        set(${OUT} FALSE PARENT_SCOPE)
        return()
    endif()

    # check if we are searching for an exact match
    set(exact_match FALSE)
    string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)" _ "${version_lower}")
    if(CMAKE_MATCH_0)
        set(major_lower ${CMAKE_MATCH_1})
        set(minor_lower ${CMAKE_MATCH_2})
        set(patch_lower ${CMAKE_MATCH_3})
    else()
        message(FATAL_ERROR "BPM [${PROJECT_NAME}]: Internal error: version string is not correct: ${version_lower}")
    endif()

    math(EXPR patch_lower_plus_one "${patch_lower} + 1")
    set(version_lower_plus_one "${major_lower}.${minor_lower}.${patch_lower_plus_one}")

    if(version_lower_plus_one VERSION_EQUAL version_upper)
        # find exact match
        set(find_exact_match TRUE)
        foreach(tag IN LISTS IN_VERSIONS)
            string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${tag}")
            if(CMAKE_MATCH_1)
                set(vtag ${CMAKE_MATCH_1})
                if("${version_lower}" VERSION_LESS_EQUAL "${vtag}")
                    set(${OUT} TRUE PARENT_SCOPE)
                    return()
                endif()
            endif()
        endforeach()
    else()
        # find range
        set(has_larger FALSE)
        set(contains_at_least_one FALSE)
        if("${version_upper}" STREQUAL "inf.inf.inf")
            set(has_larger FALSE)
        else()
            foreach(tag IN LISTS IN_VERSIONS)
                string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${tag}")
                if(CMAKE_MATCH_1)
                    set(vtag ${CMAKE_MATCH_1})
                    if(("${version_lower}" VERSION_LESS_EQUAL "${vtag}") AND "${vtag}" VERSION_LESS "${version_upper}")
                        set(contains_at_least_one TRUE)
                    elseif("${version_upper}" VERSION_LESS_EQUAL "${vtag}")
                        # found a version that is larger than the range
                        set(${OUT} ${contains_at_least_one} PARENT_SCOPE)
                        return()
                    endif()
                endif()
            endforeach()
        endif()
        
        set(${OUT} FALSE PARENT_SCOPE)
    endif()
endfunction()

#
# @param IN_TAGS a sorted list of tags (newest first)
#
function(bpm_filter_version_tags IN_TAGS IN_RANGE OUT_FILTERED_TAGS)

    list(GET IN_RANGE 0 version_lower)
    list(GET IN_RANGE 1 version_upper)

    # filter tags that match the version range
    set(filtered_version_tags "")

    foreach(tag IN LISTS IN_TAGS)
        string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${tag}")
        if(CMAKE_MATCH_1)
            set(vtag ${CMAKE_MATCH_1})
            if("${version_lower}" VERSION_LESS_EQUAL "${vtag}")
                if("${version_upper}" STREQUAL "inf.inf.inf")
                    LIST(APPEND filtered_version_tags "${tag}")
                elseif("${vtag}" VERSION_LESS "${version_upper}")
                    LIST(APPEND filtered_version_tags "${tag}")
                endif()
            endif()
        endif()
    endforeach()

    set(${OUT_FILTERED_TAGS} "${filtered_version_tags}" PARENT_SCOPE)
endfunction()

function(bpm_is_version_in_range in_pkg_name in_mirror in_mirror_lock_file in_tag in_range out)
    list(LENGTH in_range range_size)
    if(range_size EQUAL 1)
        # range is only 1 element.
        # this means we are looking for an exact match
        # also semver compliant git tags will always have a range of 2.
        # so in_range is not version
        # compare git hashes for equality

        file(LOCK "${in_mirror_lock_file}")
            execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "${in_tag}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE PKG_GIT_COMMIT_A OUTPUT_STRIP_TRAILING_WHITESPACE)
            if(NOT res EQUAL 0)
                message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Cannot convert tag: ${in_tag} to commit-hash")
            endif()
            
            execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "${in_range}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE PKG_GIT_COMMIT_B OUTPUT_STRIP_TRAILING_WHITESPACE)
            if(NOT res EQUAL 0)
                # try again with leading v
                execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "v${in_range}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE PKG_GIT_COMMIT_B OUTPUT_STRIP_TRAILING_WHITESPACE)
                if(NOT res EQUAL 0)
                    message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Cannot convert tag: '${in_range}' to commit-hash")
                endif()
            endif()
        file(LOCK "${in_mirror_lock_file}" RELEASE)

        if("${PKG_GIT_COMMIT_A}" STREQUAL "${PKG_GIT_COMMIT_B}")
            message(STATUS "out: true")
            set(${out} TRUE PARENT_SCOPE)   
            return()
        else()
            message(STATUS "out: false")
            set(${out} FALSE PARENT_SCOPE)
            return()
        endif()
    endif()

    if(NOT range_size EQUAL 2)
        message(FATAL_ERROR "'in_range' (${in_range}) has wrong size. should be 1 or 2")
    endif()

    list(GET in_range 0 range_lower)
    list(GET in_range 1 range_upper)

    string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${in_tag}")
    if(CMAKE_MATCH_1)
        set(in_version ${CMAKE_MATCH_1})
        
        if("${range_lower}" VERSION_LESS_EQUAL "${in_version}")
            if("${range_upper}" STREQUAL "inf.inf.inf")
                set(${out} TRUE PARENT_SCOPE)
                return()
            elseif("${in_version}" VERSION_LESS "${range_upper}")
                set(${out} TRUE PARENT_SCOPE)
                return()
            else()
                set(${out} FALSE PARENT_SCOPE)
                return()
            endif()
        else()
            set(${out} FALSE PARENT_SCOPE)
            return()
        endif()
    else()
        file(LOCK "${in_mirror_lock_file}")
            execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "${in_tag}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE tag_commit OUTPUT_STRIP_TRAILING_WHITESPACE)
            if(NOT res EQUAL 0)
                message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Cannot convert tag: '${in_tag}' to commit-hash")
            endif()
            
            execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "${range_lower}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE range_low_commit OUTPUT_STRIP_TRAILING_WHITESPACE)
            if(NOT res EQUAL 0)
                # try again with leading v
                execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "'v${range_lower}'^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE range_low_commit OUTPUT_STRIP_TRAILING_WHITESPACE)
                if(NOT res EQUAL 0)
                    message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Cannot convert tag: '${range_lower}' to commit-hash")
                endif()
            endif()   
        file(LOCK "${in_mirror_lock_file}" RELEASE)

        execute_process(COMMAND git --git-dir "${in_mirror}" merge-base --is-ancestor "${range_low_commit}" "${tag_commit}" RESULT_VARIABLE res)
        
        if(res EQUAL 0)
            # yes commit A is older than commit B

            if("${range_upper}" STREQUAL "inf.inf.inf")
                set(${out} TRUE PARENT_SCOPE)
                return()
            else()
                # convert upper range to commit
                execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "${range_upper}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE range_high_commit OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
                if(NOT res EQUAL 0)
                    # try again with leading v
                    execute_process(COMMAND git --git-dir "${in_mirror}" rev-parse "v${range_upper}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE range_low_commit OUTPUT_STRIP_TRAILING_WHITESPACE)
                    if(NOT res EQUAL 0)
                        # check if the tag is semver compliant
                        string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${range_upper}")
                        if(CMAKE_MATCH_0)
                            # tag is semver compliant - assume upper bound is a made up tag that does not exist yet --> treat like inf
                            set(${out} TRUE PARENT_SCOPE)
                            return()
                        else()
                            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${in_pkg_name}]: Cannot convert tag: '${range_upper}' to commit-hash")
                        endif()
                    endif()
                endif()

                if("${tag_commit}" STREQUAL "${range_high_commit}")
                    # range high is an open range border --> so if equal --> false
                    set(${out} FALSE PARENT_SCOPE)
                    return()
                else()
                    execute_process(COMMAND git --git-dir "${in_mirror}" merge-base --is-ancestor "${tag_commit}" "${range_high_commit}" RESULT_VARIABLE res)
                    if(res EQUAL 0)
                        # success --> tag is in the range
                        set(${out} TRUE PARENT_SCOPE)
                    else()
                        # failure --> tag is not in the range
                        set(${out} FALSE PARENT_SCOPE)
                    endif()
                endif()
        
            endif()
        else()
            # not commit A is older than commit B
            set(${out} FALSE PARENT_SCOPE)
        endif()   
    endif()
    
endfunction()

function(git_repo_normalize INPUT OUTPUT)
    set(url "${INPUT}")

    # remove trailing whitespace
    string(STRIP "${url}" url)

    # remove trailing .git
    string(REGEX REPLACE "\\.git$" "" url "${url}")

    # remove trailing slash
    string(REGEX REPLACE "/$" "" url "${url}")

    # ssh form: git@host:user/repo
    if(url MATCHES "^[^@]+@([^:]+):(.+)$")
        string(REGEX REPLACE "^[^@]+@([^:]+):(.+)$" "\\1/\\2" url "${url}")
    endif()

    # ssh://git@host/user/repo
    if(url MATCHES "^ssh://")
        string(REGEX REPLACE "^ssh://([^@]+@)?" "web://" url "${url}")
    endif()

    # http(s)://host/user/repo
    if(url MATCHES "^https?://")
        string(REGEX REPLACE "^https?://" "web://" url "${url}")
    endif()

    # normalize slashes in case of Windows paths
    file(TO_CMAKE_PATH "${url}" url)

    set(${OUTPUT} "${url}" PARENT_SCOPE)
endfunction()

function(git_repo_equal A B RESULT)
    git_repo_normalize("${A}" A_NORM)
    git_repo_normalize("${B}" B_NORM)

    if(A_NORM STREQUAL B_NORM)
        set(${RESULT} TRUE PARENT_SCOPE)
    else()
        set(${RESULT} FALSE PARENT_SCOPE)
    endif()
endfunction()
 
function(bpm_load_tag_list mirror_dir mirror_lock_file out_tags)
    file(LOCK "${mirror_lock_file}")
        execute_process(COMMAND git --git-dir "${mirror_dir}" tag --sort=-committerdate RESULT_VARIABLE res OUTPUT_VARIABLE tags ERROR_QUIET)
    file(LOCK "${mirror_lock_file}" RELEASE)

    if(NOT res EQUAL 0)
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Failed to get tags from mirror: ${mirror_dir}." )
    endif()

    # turn the console output into a CMake list
    string(REPLACE "\r\n" "\n" tags "${tags}")
    string(REPLACE "\n" ";" tags "${tags}")
    set(${out_tags} ${tags} PARENT_SCOPE)
endfunction()

function(bpm_solve_dependencies BPM_CACHE_DIR in_packages out_selected_list)

    set(decision_counter "0")
    set(decision_${decision_counter}_todo_list "${in_packages}")
    set(decision_${decision_counter}_selected_list "")
    set(decision_${decision_counter}_pkg_name "")
    set(decision_${decision_counter}_version "")
    set(decision_${decision_counter}_range "")
    set(decision_${decision_counter}_tag_wheel "")
    set(decision_${decision_counter}_git_tag "")
    set(decision_${decision_counter}_git_repo "")
    set(decision_${decision_counter}_type "")

    # print current decision
    if(BPM_VERBOSE)
        set(short_to_do "")
        foreach(todo IN LISTS decision_${decision_counter}_todo_list)
            set(options)
            set(oneValueArgs NAME)
            set(multiValueArgs)
            separate_arguments(todo_tokens UNIX_COMMAND "${todo}")
            cmake_parse_arguments(TODO "${options}" "${oneValueArgs}" "${multiValueArgs}" ${todo_tokens})
            list(APPEND short_to_do "${TODO_NAME}")
        endforeach()
        message(STATUS "decision: ${decision_counter} | todo: [${short_to_do}], pkg: ${decision_${decision_counter}_pkg_name}, version: ${decision_${decision_counter}_version}, range: ${decision_${decision_counter}_range}, wheel: ${decision_${decision_counter}_tag_wheel}")
    endif()

    set(solved_one FALSE)
    set(version_conflict FALSE)

    while(decision_${decision_counter}_todo_list)
    
        set(todo_list ${decision_${decision_counter}_todo_list})
        list(POP_FRONT todo_list pkg)

        set(options)
        set(oneValueArgs NAME VERSION_RANGE GIT_TAG GIT_REPOSITORY TYPE)
        set(multiValueArgs)
        separate_arguments(pkg_tokens UNIX_COMMAND "${pkg}")
        cmake_parse_arguments(PKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${pkg_tokens})
        string(REPLACE "-" ";" PKG_VERSION_RANGE ${PKG_VERSION_RANGE})

        set(mirror_lock_file "${BPM_CACHE_DIR}/${PKG_NAME}/mirror.lock")
        set(mirror_dir "${BPM_CACHE_DIR}/${PKG_NAME}/mirror")

        if(version_conflict) # if there was a version conflict
            if(decision_${decision_counter}_tag_wheel)
                # get next version from tag wheel
                list(POP_FRONT decision_${decision_counter}_tag_wheel top_version)

                set(decision_${decision_counter}_version ${top_version})
                
                set(entry "NAME ${decision_${decision_counter}_pkg_name} VERSION ${top_version} GIT_TAG ${decision_${decision_counter}_git_tag} GIT_REPO ${decision_${decision_counter}_git_repo} TYPE ${decision_${decision_counter}_type")
                math(EXPR prev_decision_counter "${decision_counter} - 1")
                set(decision_${decision_counter}_selected_list "${decision_${prev_decision_counter}_selected_list}")
                LIST(APPEND decision_${decision_counter}_selected_list "${entry}")

                # print current decision
                if(BPM_VERBOSE)
                    set(short_to_do "")
                    foreach(todo IN LISTS decision_${decision_counter}_todo_list)
                        set(options)
                        set(oneValueArgs NAME)
                        set(multiValueArgs)
                        separate_arguments(todo_tokens UNIX_COMMAND "${todo}")
                        cmake_parse_arguments(TODO "${options}" "${oneValueArgs}" "${multiValueArgs}" ${todo_tokens})
                        list(APPEND short_to_do "${TODO_NAME}")
                    endforeach()
                    message(STATUS "update decision: ${decision_counter} | todo: [${short_to_do}], pkg: ${decision_${decision_counter}_pkg_name}, version: ${decision_${decision_counter}_version}, range: ${decision_${decision_counter}_range}, wheel: ${decision_${decision_counter}_tag_wheel}")
                endif()

                # retry logic with lower version
                set(version_conflict FALSE)
                continue()
                
            else()
                # no more versions to try
                # delete this entry 
                if(BPM_VERBOSE)
                    message(STATUS "version conflict: pop decision: ${decision_counter}")
                endif()

                set(decision_${decision_counter}_todo_list "")
                set(decision_${decision_counter}_selected_list "")
                set(decision_${decision_counter}_pkg_name "")
                set(decision_${decision_counter}_version "")
                set(decision_${decision_counter}_range "")
                set(decision_${decision_counter}_tag_wheel "")
                set(decision_${decision_counter}_git_tag "")
                set(decision_${decision_counter}_git_repo "")
                set(decision_${decision_counter}_type "")

                # pop
                math(EXPR decision_counter "${decision_counter} - 1")
                if(decision_counter LESS 0)
                    message(FATAL_ERROR "Dependency resolution failed - TODO: better error message")
                endif()
                continue()
            endif()
        endif()

        set(solved_one FALSE)
        set(version_conflict FALSE)

        # check if the package is already in the selected list
        foreach(selected IN LISTS decision_${decision_counter}_selected_list)
            set(options)
            set(oneValueArgs NAME VERSION GIT_TAG GIT_REPO TYPE)
            set(multiValueArgs)
            separate_arguments(selected_tokens UNIX_COMMAND "${selected}")
            cmake_parse_arguments(SEL "${options}" "${oneValueArgs}" "${multiValueArgs}" ${selected_tokens})

            if(("${SEL_NAME}" STREQUAL "${PKG_NAME}") OR ("${PKG_GIT_REPOSITORY}" STREQUAL "${SEL_GIT_REPO}"))
                # repo conflict?
                git_repo_equal("${PKG_GIT_REPOSITORY}" "${SEL_GIT_REPO}" are_repos_equal)

                if(NOT are_repos_equal)
                    message(FATAL_ERROR  "BPM [${PROJECT_NAME}:${PKG_NAME}]: Repository conflict: '${PKG_GIT_REPOSITORY}' vs '${SEL_GIT_REPO}'")
                endif()

                # package name conflict ? 
                if(NOT "${PKG_NAME}" STREQUAL "${SEL_NAME}")
                    message(FATAL_ERROR  "BPM [${PROJECT_NAME}:${PKG_GIT_REPOSITORY}]: Package name conflict:  '${PKG_NAME}' vs  '${SEL_NAME}'")
                endif()

                # type conflict?
                if(NOT "${PKG_TYPE}" STREQUAL "${SEL_TYPE}")
                    message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Package type conflict: '${PKG_TYPE}' vs '${SEL_TYPE}'")
                endif()

                # check if the selected version is in the constraint
                bpm_is_version_in_range("${PKG_NAME}" "${mirror_dir}" "${mirror_lock_file}" "${SEL_VERSION}" "${PKG_VERSION_RANGE}" is_in_range)
                
                if(is_in_range)
                    # no version conflict - already part of the list
                    # record decision
                    math(EXPR next_decision_counter "${decision_counter} + 1")

                    set(decision_${next_decision_counter}_todo_list "${todo_list}")
                    set(decision_${next_decision_counter}_selected_list "${decision_${decision_counter}_selected_list}")
                    set(decision_${next_decision_counter}_pkg_name "${PKG_NAME}")
                    set(decision_${next_decision_counter}_version "${SEL_VERSION}")
                    set(decision_${next_decision_counter}_tag_wheel "${decision_${decision_counter}_tag_wheel}")
                    set(decision_${next_decision_counter}_range "${PKG_VERSION_RANGE}")
                    set(decision_${next_decision_counter}_git_tag "${PKG_GIT_TAG}")
                    set(decision_${next_decision_counter}_git_repo "${PKG_GIT_REPOSITORY}")
                    set(decision_${decision_counter}_type "${PKG_TYPE}")

                    set(decision_counter "${next_decision_counter}")

                    # print current decision
                    if(BPM_VERBOSE)
                        set(short_to_do "")
                        foreach(todo IN LISTS decision_${decision_counter}_todo_list)
                            set(options)
                            set(oneValueArgs NAME)
                            set(multiValueArgs)
                            separate_arguments(todo_tokens UNIX_COMMAND "${todo}")
                            cmake_parse_arguments(TODO "${options}" "${oneValueArgs}" "${multiValueArgs}" ${todo_tokens})
                            list(APPEND short_to_do "${TODO_NAME}")
                        endforeach()
                        message(STATUS "decision: ${decision_counter} | todo: [${short_to_do}], pkg: ${decision_${decision_counter}_pkg_name}, version: ${decision_${decision_counter}_version}, range: ${decision_${decision_counter}_range}, wheel: ${decision_${decision_counter}_tag_wheel}")
                    endif()

                    set(solved_one TRUE)
                    break() # to leave for loop and then continue in the while loop
                else()
                    # found a version conflict
                    if(BPM_VERBOSE)
                        message(STATUS "version: conflict of ${PKG_NAME}: range ${PKG_VERSION_RANGE}, existing version: ${SEL_VERSION}")
                    endif()
                    set(version_conflict TRUE)
                    break() # to leave for loop and then continue in the while loop
                endif()
            endif()
        endforeach()

        # continue whith the next package if one decision got solved in the for loop
        if(solved_one)
            continue()
        endif()

        if(version_conflict)
            continue()
        endif()

        string(REPLACE ";" "_" temp_version_range_str "${PKG_VERSION_RANGE}")
        string(REPLACE "-" "_" temp_version_range_str "${temp_version_range_str}")
        string(REPLACE "." "_" temp_version_range_str "${temp_version_range_str}")
        if(NOT DEFINED cached_tag_wheel_${PKG_NAME}_${temp_version_range_str})
            # all the following can be skipped if the tag wheel was already cached

            # package is not yet in the selected list
            # build the version wheel for this package
            if(NOT mirror_${PKG_NAME}_up_to_date)
                if(NOT EXISTS "${mirror_dir}/HEAD")
                    message(STATUS "BPM [${PROJECT_NAME}:${PKG_NAME}]: Cloning git repository: ${PKG_GIT_REPOSITORY} into: ${mirror_dir}")
                    if(BPM_NO_DOWNLOAD)
                        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Mirror does not exist: '${mirror_dir}'. Cannot download from '${PKG_GIT_REPOSITORY}', because `NO_DOWNLOAD` was provided.")
                    endif()
                    file(LOCK "${mirror_lock_file}")
                        if(NOT EXISTS "${mirror_dir}/HEAD")
                            if(BPM_VERBOSE)
                                execute_process(COMMAND git clone --mirror "${PKG_GIT_REPOSITORY}" "${mirror_dir}" --recursive -c advice.detachedHead=false RESULT_VARIABLE res)
                            else()
                                execute_process(COMMAND git clone --mirror "${PKG_GIT_REPOSITORY}" "${mirror_dir}" --recursive -c advice.detachedHead=false RESULT_VARIABLE res OUTPUT_QUIET)
                            endif()
                        endif()
                    file(LOCK "${mirror_lock_file}" RELEASE)

                    if(res EQUAL 0)
                        message(STATUS "BPM [${PROJECT_NAME}:${PKG_NAME}]: Cloning git repository - success")
                        set(mirror_${PKG_NAME}_up_to_date TRUE)
                    else() 
                        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Cloning git repository - failed")
                    endif()
                endif()
            endif()

            # see if tags have already been acquired
            if(DEFINED BPM_REGISTRY_${PKG_NAME}_GIT_TAGS)
                set(tags "${BPM_REGISTRY_${PKG_NAME}_GIT_TAGS}")
            else()
                # if tags have not been acquired - load them
                bpm_load_tag_list("${mirror_dir}" "${mirror_lock_file}" tags)
                if(NOT tags)
                    message(FATAL_ERROR "BPM [${PKG_NAME}]: Has no tags to checkout. Mirror: ${mirror_dir}")
                endif()
                # cache tags
                set("BPM_REGISTRY_${PKG_NAME}_GIT_TAGS" "${tags}")
            endif()

            if(NOT mirror_${PKG_NAME}_up_to_date)
                # check if the version range is fully contained with the mirrors tags
                list(LENGTH PKG_VERSION_RANGE range_size)
                if(range_size EQUAL 1)
                    # it is a named tag (not a version tag) or a commit hash
                    set(tag_or_hash "${PKG_VERSION_RANGE}")
                    file(LOCK "${mirror_lock_file}")
                        execute_process(COMMAND git --git-dir "${mirror_dir}" cat-file -e "${tag_or_hash}^{commit}" RESULT_VARIABLE res )
                    file(LOCK "${mirror_lock_file}" RELEASE)
                                        
                    if(res EQUAL 0)
                        set(contains TRUE)
                    else()
                        set(contains FALSE)
                    endif()
                else()
                    # is a regular version tag that spans a version range
                    bpm_fully_contains_tag_range("${tags}" "${PKG_VERSION_RANGE}" contains)
                endif()


                # fetch if upper version bound is inf or tag is not contained
                if(NOT contains)
                    message(STATUS "BPM [${PROJECT_NAME}:${PKG_NAME}]: mirror might be out-of-date - fetch for updates")
                    
                    if(BPM_NO_DOWNLOAD)
                        message(STATUS "BPM [${PROJECT_NAME}:${PKG_NAME}]: mirror might be out-of-date - fetch - skipped due to `NO_DOWNLOAD`")
                    else()
                        file(LOCK "${mirror_lock_file}")
                            if(BPM_VERBOSE)
                                execute_process(COMMAND git --git-dir "${mirror_dir}" fetch --tags --prune RESULT_VARIABLE res)
                            else()
                                execute_process(COMMAND git --git-dir "${mirror_dir}" fetch --tags --prune RESULT_VARIABLE res OUTPUT_QUIET ERROR_QUIET)
                            endif()
                        file(LOCK "${mirror_lock_file}" RELEASE)

                        if(res EQUAL 0)
                            message(STATUS "BPM [${PROJECT_NAME}:${PKG_NAME}]: mirror might be out-of-date - fetch for updates - success")
                        else() 
                            message(WARNING "BPM [${PROJECT_NAME}:${PKG_NAME}]: mirror might be out-of-date - fetch for updates - failed")
                        endif()

                        # re-update tags after fetching
                        bpm_load_tag_list("${mirror_dir}" "${mirror_lock_file}" tags)
                        if(NOT tags)
                            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Has no tags to checkout. Mirror: ${mirror_dir}")
                        endif()
    
                        # cache tags
                        set("BPM_REGISTRY_${PKG_NAME}_GIT_TAGS" "${tags}")

                        # TODO: check if at least one element is contained --> error if not
                        set(mirror_${PKG_NAME}_up_to_date TRUE)
                    endif()
                endif()
            endif()


            list(LENGTH PKG_VERSION_RANGE range_size)
            if(range_size EQUAL 1)
                # is a single/exact tag or commit hash
                set(tag_wheel ${PKG_VERSION_RANGE})
            else()
                # is an actual range
                bpm_filter_version_tags("${tags}" "${PKG_VERSION_RANGE}" tag_wheel)
                if(NOT tag_wheel)
                    list(GET IN_RANGE 0 version_lower)
                    list(GET IN_RANGE 1 version_upper)
                    message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: No tags in range ${version_lower}-${version_upper}. Mirror: ${mirror_dir}")
                endif()
            endif()

            set(cached_tag_wheel_${PKG_NAME}_${temp_version_range_str} "${tag_wheel}")
        else()
            set(tag_wheel "${cached_tag_wheel_${PKG_NAME}_${temp_version_range_str}}")
        endif()

        list(POP_FRONT tag_wheel top_version)

        # load and cache metadata
        if(NOT DEFINED metadata_${PKG_NAME}_${top_version})
            file(LOCK "${mirror_lock_file}")
                execute_process(COMMAND git --git-dir "${mirror_dir}" cat-file blob "${top_version}:.bpm-registry" RESULT_VARIABLE res OUTPUT_VARIABLE metadata_tmp ERROR_QUIET)
            file(LOCK "${mirror_lock_file}" RELEASE)

            string(REPLACE "\r\n" "\n" metadata_tmp "${metadata_tmp}") # replace new lines windows to unix style
            string(REPLACE "\n" ";" metadata_${PKG_NAME}_${top_version} "${metadata_tmp}") # replace new lines with ; for list seperators
        endif()

                 
        foreach(line IN LISTS metadata_${PKG_NAME}_${top_version})
            if(line)
                list(APPEND todo_list ${line})
            endif()
        endforeach()
        

        # no registry found --> no more entries added to the todo list --> make decision and continue
        math(EXPR next_decision_counter "${decision_counter} + 1")
        

        set(entry "NAME ${PKG_NAME} VERSION ${top_version} GIT_TAG ${PKG_GIT_TAG} GIT_REPO ${PKG_GIT_REPOSITORY} TYPE ${PKG_TYPE}")

        set(decision_${next_decision_counter}_todo_list "${todo_list}")
        set(decision_${next_decision_counter}_selected_list "${decision_${decision_counter}_selected_list}")
        LIST(APPEND decision_${next_decision_counter}_selected_list "${entry}")
        set(decision_${next_decision_counter}_pkg_name "${PKG_NAME}")
        set(decision_${next_decision_counter}_version "${top_version}")
        set(decision_${next_decision_counter}_tag_wheel "${tag_wheel}")
        set(decision_${next_decision_counter}_range "${PKG_VERSION_RANGE}")
        set(decision_${next_decision_counter}_git_tag "${PKG_GIT_TAG}")
        set(decision_${next_decision_counter}_git_repo "${PKG_GIT_REPOSITORY}")
        set(decision_${decision_counter}_type "${PKG_TYPE}")

        set(decision_counter "${next_decision_counter}")

        # print current decision
        if(BPM_VERBOSE)
            set(short_to_do "")
            foreach(todo IN LISTS decision_${decision_counter}_todo_list)
                set(options)
                set(oneValueArgs NAME)
                set(multiValueArgs)
                separate_arguments(todo_tokens UNIX_COMMAND "${todo}")
                cmake_parse_arguments(TODO "${options}" "${oneValueArgs}" "${multiValueArgs}" ${todo_tokens})
                list(APPEND short_to_do "${TODO_NAME}")
            endforeach()
            message(STATUS "new decision: ${decision_counter} | todo: [${short_to_do}], pkg: ${decision_${decision_counter}_pkg_name}, version: ${decision_${decision_counter}_version}, range: ${decision_${decision_counter}_range}, wheel: ${decision_${decision_counter}_tag_wheel}")
        endif()
        
    endwhile()

    set("${out_selected_list}" "${decision_${decision_counter}_selected_list}" PARENT_SCOPE)

endfunction()

function(bpm_create_manifest OUT_MANIFEST)
    set(_manifest "")
    foreach(var IN LISTS ARGN)
        if(DEFINED ${var})
            set(_value "${${var}}")
        else()
            set(_value "")
        endif()
        string(APPEND _manifest "${var}=${_value}\n")
    endforeach()
    set(${OUT_MANIFEST} "${_manifest}" PARENT_SCOPE)
endfunction()

function(bpm_try_find_packages lib_name packages lib_install_dir OUT_FOUND_ALL)
    set(all_packages_found TRUE)
    foreach(package IN LISTS packages)
        # unset for deterministic find without sideeffects
        unset(${package}_DIR CACHE)
        if(PKG_VERBOSE)
            find_package(${package} CONFIG NO_DEFAULT_PATH PATHS "${lib_install_dir}")
        else()
            find_package(${package} QUIET CONFIG NO_DEFAULT_PATH PATHS "${lib_install_dir}")
        endif()
        unset(${package}_DIR)
        if(${package}_FOUND)
            message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Find package : ${package} - found in: ${lib_install_dir}")
        else()
            message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: WARNING: Find package : ${package} - missing")
            set(all_packages_found FALSE)
        endif()
    endforeach()

    set(${OUT_FOUND_ALL} ${all_packages_found} PARENT_SCOPE)
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

function(bpm_clone_from_mirror lib_name library_mirror_dir lib_src_dir git_tag lib_mirror_lock_file lib_src_lock_file)

    if(BPM_VERBOSE)
        message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Cloning mirror '${library_mirror_dir}' into source dir '${lib_src_dir}' at '${git_tag}'")
    endif()

    if(NOT EXISTS ${lib_src_dir}/.git)
        file(LOCK "${lib_src_lock_file}") # lockorder: install -> build -> source -> mirror
            if(NOT EXISTS ${lib_src_dir}/.git)
                file(LOCK "${lib_mirror_lock_file}")
                    # CLONE
                    if(BPM_VERBOSE)
                        execute_process(COMMAND git clone --reference "${library_mirror_dir}" --no-checkout "${library_mirror_dir}" "${lib_src_dir}" -c advice.detachedHead=false RESULT_VARIABLE res)
                    else()
                        execute_process(COMMAND git clone --reference "${library_mirror_dir}" --no-checkout "${library_mirror_dir}" "${lib_src_dir}" -c advice.detachedHead=false RESULT_VARIABLE res OUTPUT_QUIET ERROR_QUIET)
                    endif()
                    if(NOT res EQUAL 0)
                        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${lib_name}]: Failed to clone mirror '${library_mirror_dir}' into source dir '${lib_src_dir}'.")
                    endif()

                    if(BPM_VERBOSE)
                        execute_process(COMMAND git -C "${lib_src_dir}" checkout "${git_tag}" RESULT_VARIABLE res )
                    else()
                        execute_process(COMMAND git -C "${lib_src_dir}" checkout "${git_tag}" RESULT_VARIABLE res OUTPUT_QUIET ERROR_QUIET)
                    endif()
                    if(NOT res EQUAL 0)
                        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${lib_name}]: Failed to checkout '${git_tag}' in source dir '${lib_src_dir}'.")
                    endif()
                
                file(LOCK "${lib_mirror_lock_file}" RELEASE)

                if(res EQUAL 0)
                    if(BPM_VERBOSE)
                        message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Cloning mirror into source dir - success")
                    endif()
                else()
                    message(FATAL_ERROR "BPM [${PROJECT_NAME}:${lib_name}]: Cloning mirror '${library_mirror_dir}' into source dir '${lib_src_dir}' - failed")
                endif()
                
                # SUBMODULES
                if(BPM_VERBOSE)
                    message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Updating git-submodules")
                endif()

                if(BPM_VERBOSE)
                    execute_process(COMMAND git -C "${lib_src_dir}" submodule update --init --recursive RESULT_VARIABLE res)
                else()
                    execute_process(COMMAND git -C "${lib_src_dir}" submodule update --init --recursive RESULT_VARIABLE res OUTPUT_QUIET)
                endif()
            endif()
        file(LOCK "${lib_src_lock_file}" RELEASE)

        if(res EQUAL 0)
            if(BPM_VERBOSE)
                message(STATUS "Updating git-submodules - success")
            endif()
        else()
            message(FATAL_ERROR "Updating git-submodules - failed")
        endif()
    else()
        if(BPM_VERBOSE)
            message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Cloning mirror into source dir - skipped")
        endif()
    endif()

endfunction()

function(bpm_configure_library BPM_CACHE_DIR lib_name lib_src_dir lib_build_dir options dependency_solution lib_src_lock_file lib_build_lock_file )

    message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Configuring")

    set(cmake_build_args "")
    if(options)
        foreach(opt IN LISTS options)
            list(APPEND cmake_build_args "-D${opt}")
        endforeach()
    endif()

    # parse the libraries cmake lists for flags that enable tests and disable them
    bpm_find_test_example_options_r("${lib_src_dir}" test_example_options)
    set(cmake_disable_test_example_flags "")

    foreach(flag ${test_example_options})
        list(APPEND cmake_disable_test_example_flags "-D${flag}=OFF")
    endforeach()

    set(toolchain_args)
    if(CMAKE_TOOLCHAIN_FILE)
        set(toolchain_args "-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}")
    else()
        set(toolchain_args
            "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
            "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
        )
    endif()

    # lockorder: install -> build -> source -> mirror
    file(LOCK "${lib_build_lock_file}")
        file(LOCK "${lib_src_lock_file}")  

            # Check if this library uses BPM (has a .bpm-registry). If yes: pass the version solutions as a variable
            set(dependencies_arg)
            set(bpm_cache_arg)
            if(EXISTS "${lib_src_dir}/.bpm-registry")
                set(dependencies_arg "-DBPM_DEPENDENCY_SOLUTION=${CMAKE_BINARY_DIR}/bpm-dependency-solution.cmake")
                set(bpm_cache_arg "-DBPM_CACHE=${BPM_CACHE_DIR}")
            endif()
            
            # TODO: Optimisation: skip instead of re-configuring
            execute_process(
                COMMAND ${CMAKE_COMMAND}
                -S "${lib_src_dir}"
                -B "${lib_build_dir}"
                -G "${CMAKE_GENERATOR}"
                
                "-DCMAKE_MAKE_PROGRAM=${CMAKE_MAKE_PROGRAM}"
                "-DCMAKE_GENERATOR=${CMAKE_GENERATOR}"

                -DCMAKE_BUILD_TYPE=Release

                ${bpm_cache_arg}
                "-DCMAKE_INSTALL_PREFIX=${lib_install_dir}"
                "-DCMAKE_POSITION_INDEPENDENT_CODE=${CMAKE_POSITION_INDEPENDENT_CODE}"
                "-DBUILD_SHARED_LIBS=${BUILD_SHARED_LIBS}"
                
                ${cmake_build_args}
                ${toolchain_args}
                ${cmake_disable_test_example_flags}
                ${dependencies_arg}

                RESULT_VARIABLE res
            )

        file(LOCK "${lib_build_lock_file}" RELEASE)
    file(LOCK "${lib_src_lock_file}" RELEASE)

    if(res EQUAL 0)
        message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Configuring - done")
    else() 
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${lib_name}]: Configuring - failed")
    endif()

endfunction()

function(bpm_build_library lib_name library_build_dir lib_build_lock_file)

    message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Building")

    set(parallel 8)
    if(CMAKE_BUILD_PARALLEL_LEVEL)
        set(parallel ${CMAKE_BUILD_PARALLEL_LEVEL})
    endif()

    file(LOCK "${lib_build_lock_file}")
        execute_process(COMMAND ${CMAKE_COMMAND} --build "${library_build_dir}" --config Release --parallel ${parallel} RESULT_VARIABLE res)
    file(LOCK "${lib_build_lock_file}" RELEASE)

    if(res EQUAL 0)
        message(NOTICE "BPM [${PROJECT_NAME}:${lib_name}]: Building - done")
    else() 
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${lib_name}]: Building - failed")
    endif()

endfunction()

function(bpm_install_library lib_name lib_build_dir lib_install_dir lib_build_lock_file lib_install_lock_file)
    message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Installing")

    # lockorder: install -> build -> source -> mirror
    file(LOCK "${lib_install_lock_file}")
        file(LOCK "${lib_build_lock_file}")
            if(BPM_VERBOSE)
                execute_process(COMMAND ${CMAKE_COMMAND} --install ${lib_build_dir} --prefix ${lib_install_dir} --config Release RESULT_VARIABLE res)
            else()
                execute_process(COMMAND ${CMAKE_COMMAND} --install ${lib_build_dir} --prefix ${lib_install_dir} --config Release RESULT_VARIABLE res OUTPUT_QUIET)
            endif()
        file(LOCK "${lib_build_lock_file}" RELEASE)
    file(LOCK "${lib_install_lock_file}" RELEASE)

    if(res EQUAL 0)
        message(STATUS "BPM [${PROJECT_NAME}:${lib_name}]: Installing - done")
    else() 
        # clean install on error
        file(REMOVE_RECURSE "${library_install_dir}")
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${lib_name}]: Installing - failed")
    endif()

endfunction()

function(bpm_show_installed_packages PKG_NAME lib_install_dir)
    file(GLOB_RECURSE config_files "${lib_install_dir}/*Config.cmake" "${lib_install_dir}/*config.cmake")
    if(config_files)
        message("")
        message(STATUS "==================== BPM [${PROJECT_NAME}:${PKG_NAME}]: Installed ===================")
        foreach(config_file IN LISTS config_files)
            get_filename_component(config_dir "${config_file}" DIRECTORY)
            get_filename_component(package_name "${config_dir}" NAME)
            message(STATUS " - ${package_name}")
        endforeach()
        message(STATUS "=============================== END =================================")
        message("")
    else()
        message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Installed, but no CMake package config files found.")
    endif()
endfunction()

#
function(BPMMakeAvailable)

    set(options VERBOSE NO_DOWNLOAD)
    set(oneValueArgs)
    set(multiValueArgs)
    cmake_parse_arguments(BPM "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    bpm_get_cache_dir(BPM_CACHE_DIR)

    # -------------------------------
    # Write local repository to file
    # -------------------------------

    get_property(BPM_REGISTRY_ GLOBAL PROPERTY BPM_REGISTRY)
    foreach(PKG_NAME IN LISTS BPM_REGISTRY_)
        # write local registry
        get_property(VERSION_RANGE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE")
        get_property(GIT_TAG GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_TAG")
        get_property(GIT_REPOSITORY GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_REPOSITORY")
        get_property(TYPE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_TYPE")

        string(REPLACE ";" "-" SAFE_VERSION_RANGE "${VERSION_RANGE}")

        string(APPEND registry_content
            "NAME ${PKG_NAME} VERSION_RANGE ${SAFE_VERSION_RANGE} "
            "GIT_TAG ${GIT_TAG} GIT_REPOSITORY ${GIT_REPOSITORY} TYPE ${TYPE};"
        )
        
        string(APPEND registry_file_content
            "NAME ${PKG_NAME} VERSION_RANGE ${SAFE_VERSION_RANGE} "
            "GIT_TAG ${GIT_TAG} GIT_REPOSITORY ${GIT_REPOSITORY} TYPE ${TYPE}\n"
        )
    endforeach()
    
    # TODO: sort fily by package names before writing for improved robustness
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry")
        file(READ "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry" old_registry_file_content)
        if(NOT "${registry_file_content}\n" STREQUAL "${old_registry_file_content}")
            file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry" "${registry_file_content}\n")
        endif()
    else()
        file(WRITE "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry" "${registry_file_content}\n")
    endif()

    # -------------------------------
    # Solve Dependency Graph
    # -------------------------------

    if(NOT DEFINED BPM_DEPENDENCY_SOLUTION)
        bpm_solve_dependencies(${BPM_CACHE_DIR} "${registry_content}" solution)
        
        # write/update solution on change
        file(WRITE "${CMAKE_BINARY_DIR}/bpm-dependency-solution.cmake" "${solution}")

        message(STATUS "")
        message(STATUS "================= Dependency Graph Solution =================")

        foreach(pkg IN LISTS solution)
            set(options)
            set(oneValueArgs NAME VERSION GIT_REPO)
            set(multiValueArgs)
            separate_arguments(pkg_tokens UNIX_COMMAND "${pkg}")
            cmake_parse_arguments(PKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${pkg_tokens})

            message(STATUS "BPM [${PROJECT_NAME}]: Resolved: ${PKG_NAME}#${PKG_VERSION} : ${PKG_GIT_REPO}")
            
        endforeach()

        message(STATUS "============================ END ===========================")
        message(STATUS "")
    else()
        file(READ "${BPM_DEPENDENCY_SOLUTION}" solution)
    endif()

    # ------------------------------------------------------------------------------
    # Add package with `add_subdirectory` or install and add with `find_package`
    # ------------------------------------------------------------------------------

    
    foreach(pkg IN LISTS solution)

        # Prevent double adding through subdirectory packages
        get_property(PKG_MADE_AVAILABLE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_MADE_AVAILABLE")
        if(PKG_MADE_AVAILABLE)
            continue()
        endif()
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_MADE_AVAILABLE" TRUE)

        set(options)
        set(oneValueArgs NAME VERSION GIT_REPO)
        set(multiValueArgs)
        separate_arguments(pkg_tokens UNIX_COMMAND "${pkg}")
        cmake_parse_arguments(PKG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${pkg_tokens})

        set(lib_mirror_dir "${BPM_CACHE_DIR}/${PKG_NAME}/mirror")
        set(lib_mirror_lock_file "${BPM_CACHE_DIR}/${PKG_NAME}/mirror.lock")

        # repository already cloned with `bpm_solve_dependencies`

        # -------------------------------
        # create manifest
        # -------------------------------

        file(SHA256 "${CMAKE_C_COMPILER}" C_COMPILER_HASH)
        file(SHA256 "${CMAKE_CXX_COMPILER}" CXX_COMPILER_HASH)

        get_property(PKG_OPTIONS GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_OPTIONS")

        file(LOCK "${lib_mirror_lock_file}")
            execute_process(COMMAND git --git-dir "${lib_mirror_dir}" rev-parse "${PKG_VERSION}^{commit}" RESULT_VARIABLE res OUTPUT_VARIABLE PKG_GIT_COMMIT OUTPUT_STRIP_TRAILING_WHITESPACE)
        file(LOCK "${lib_mirror_lock_file}" RELEASE)

        if(NOT res EQUAL 0)
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Could not convert '${PKG_VERSION}' to commit-hash in mirror '${lib_mirror_dir}'")
        endif()

        # turn tag into commit hash
        bpm_create_manifest(manifest
            CMAKE_C_COMPILER_ID
            C_COMPILER_HASH
            CMAKE_C_COMPILER_VERSION
            CMAKE_CXX_COMPILER_ID
            CXX_COMPILER_HASH
            CMAKE_CXX_COMPILER_VERSION
            CMAKE_SYSTEM_NAME
            CMAKE_SYSTEM_PROCESSOR
            CMAKE_VERSION
            BUILD_SHARED_LIBS
            CMAKE_POSITION_INDEPENDENT_CODE
            CMAKE_INTERPROCEDURAL_OPTIMIZATION
            CMAKE_C_FLAGS  
            CMAKE_CXX_FLAGS
            CMAKE_EXE_LINKER_FLAGS
            CMAKE_SHARED_LINKER_FLAGS
            TOOLCHAIN_HASH
            PKG_NAME
            PKG_VERSION
            PKG_GIT_COMMIT
            PKG_GIT_REPO
            PKG_OPTIONS
        ) 

        string(SHA256 manifest_hash "${manifest}")
        string(SUBSTRING "${manifest_hash}" 0 16 SHORT_MANIFEST_HASH)
        string(SUBSTRING "${PKG_GIT_COMMIT}" 0 16 PKG_GIT_COMMIT_HASH)

        # -------------------------------
        # Define hashed directories
        # -------------------------------

        set(lib_src_dir "${BPM_CACHE_DIR}/${PKG_NAME}/src/${PKG_GIT_COMMIT_HASH}")
        set(lib_src_lock_file "${BPM_CACHE_DIR}/${PKG_NAME}/src/${PKG_GIT_COMMIT_HASH}.lock")

        set(lib_build_dir "${BPM_CACHE_DIR}/${PKG_NAME}/build/${SHORT_MANIFEST_HASH}")
        set(lib_build_lock_file "${BPM_CACHE_DIR}/${PKG_NAME}/build/${SHORT_MANIFEST_HASH}.lock")

        set(lib_install_dir "${BPM_CACHE_DIR}/${PKG_NAME}/install/${SHORT_MANIFEST_HASH}")
        set(lib_install_lock_file "${BPM_CACHE_DIR}/${PKG_NAME}/install/${SHORT_MANIFEST_HASH}.lock")

        set(manifest_dir "${BPM_CACHE_DIR}/${PKG_NAME}/manifest")
        set(manifest_file_path "${BPM_CACHE_DIR}/${PKG_NAME}/manifest/${SHORT_MANIFEST_HASH}.manifest")

        # write manifest
        if(NOT EXISTS ${manifest_dir})
            file(MAKE_DIRECTORY "${manifest_dir}")
        endif()

        if(NOT EXISTS ${manifest_file_path})
            file(WRITE "${manifest_file_path}" "${manifest}")
        endif()

        get_property("BPM_${PKG_NAME}_TYPE" GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_TYPE")
        if("${BPM_${PKG_NAME}_TYPE}" STREQUAL "INSTALL")
            message(STATUS "BPM [${PROJECT_NAME}]: Adding Install: ${PKG_NAME}#${PKG_VERSION} : ${PKG_GIT_REPO}")

            get_property(REGISTERED_PACKAGES GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_PACKAGES")

            bpm_try_find_packages("${PKG_NAME}" "${REGISTERED_PACKAGES}" "${lib_install_dir}" all_packages_found)
            if(NOT all_packages_found)
                message(STATUS "BPM [${PROJECT_NAME}:${PKG_NAME}]: Find packages - failed: attempt install")

                # clone mirror into source dir
                bpm_clone_from_mirror("${PKG_NAME}" "${lib_mirror_dir}" "${lib_src_dir}" "${PKG_VERSION}" "${lib_mirror_lock_file}" "${lib_src_lock_file}")

                # configure the project
                bpm_configure_library("${BPM_CACHE_DIR}" "${PKG_NAME}" "${lib_src_dir}" "${lib_build_dir}" "${PKG_OPTIONS}" "${solution}" "${lib_src_lock_file}" "${lib_build_lock_file}")

                # build the library
                bpm_build_library("${PKG_NAME}" "${lib_build_dir}" "${lib_build_lock_file}")

                # install the library
                bpm_install_library("${PKG_NAME}" "${lib_build_dir}" "${lib_install_dir}" "${lib_build_lock_file}" "${lib_install_lock_file}")

                # print which packages have been installed
                bpm_show_installed_packages("${PKG_NAME}" "${lib_install_dir}")

                # try to make the packagse available
                bpm_try_find_packages("${PKG_NAME}" "${REGISTERED_PACKAGES}" "${lib_install_dir}" all_packages_found)

                # delete source and build directory
                file(LOCK "${lib_build_lock_file}")
                    file(LOCK "${lib_src_lock_file}")
                        message(STATUS "BPM [${PROJECT_NAME}:${BPM_NAME}] Cleaning: '${lib_src_dir}' + '${lib_build_dir}'")
                        file(REMOVE_RECURSE "${lib_src_dir}")
                        file(REMOVE_RECURSE "${lib_build_dir}")
                        message(STATUS "BPM [${PROJECT_NAME}:${BPM_NAME}] Cleaning - done")
                    file(LOCK "${lib_src_lock_file}" RELEASE)
                file(LOCK "${lib_build_lock_file}" RELEASE)

                if(NOT all_packages_found)
                    message(FATAL_ERROR "BPM [${PROJECT_NAME}:${BPM_NAME}]: Find package - failed after (re-)install")
                endif()
            endif()

        elseif("${BPM_${PKG_NAME}_TYPE}" STREQUAL "ADD_SUBDIR")

            message(STATUS "BPM [${PROJECT_NAME}]: Adding Subdirectory: ${PKG_NAME}#${PKG_VERSION} : ${PKG_GIT_REPO}")

            # clone mirror into source dir
            bpm_clone_from_mirror("${PKG_NAME}" "${lib_mirror_dir}" "${lib_src_dir}" "${PKG_VERSION}" "${lib_mirror_lock_file}" "${lib_src_lock_file}")

            # provide options
            foreach(opt IN LISTS PKG_OPTIONS)
                string(REPLACE "=" ";" opt_list "${opt}")
                list(GET opt 0 opt_name)
                list(GET opt 1 opt_value)
                set("${opt_name}" "${opt_value}")
            endforeach()

            # provide solution
            set(BPM_DEPENDENCY_SOLUTION "${CMAKE_BINARY_DIR}/bpm-dependency-solution.cmake")

            # provide cache dir
            set(BPM_CACHE "${BPM_CACHE_DIR}")

            # disable test and example build targets if possible
            bpm_find_test_example_options_r("${lib_src_dir}" test_example_options)
            foreach(flag IN LISTS test_example_options)
                set(${flag} OFF)
            endforeach()

            add_subdirectory("${lib_src_dir}" "${lib_build_dir}")
        else()
            message(FATAL_ERROR "BPM [${PROJECT_NAME}:${PKG_NAME}]: Internal error. Unknown TYPE '${BPM_${PKG_NAME}_TYPE}'. Shoule be 'INSTALL' or 'ADD_SUBDIR'")
        endif()
    endforeach()

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