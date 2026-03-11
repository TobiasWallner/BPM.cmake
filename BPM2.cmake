cmake_minimum_required(VERSION 3.20)

# @parses a constraint + version string into a closed-open range of allowed version
# 
# input: >=1.2.3 --> output: LIST 1.2.3;inf.inf.inf -- meaning: from version 1.2.3 to upper bound inf.inf.inf
# input: ^1.2.3 --> output: LIST 1.2.3;2.0.0 -- meaning from version 1.2.3 to upper bound 2.0.0
function(bpm_parse_version_string INPUT out_version_range)
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
        set(PKG_BUILD_TYPE Release)
    endif()

    if(PKG_QUIET)
        set(${out_quiet} ON PARENT_SCOPE)
    else()
        set(${out_quiet} OFF PARENT_SCOPE)
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

    bpm_parse_arguments("${ARGN}"
        PKG_NAME PKG_GIT_REPOSITORY PKG_GIT_TAG PKG_BUILD_TYPE 
        PKG_OPTIONS PKG_PACKAGES PKG_QUIET PKG_VERSION_RANGE)


    # Create the Registry and delete the old one
    # --------------------------------------------------------------------------------
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

        # also delete the old registry file when creating a new one
        if(PROJECT_IS_TOP_LEVEL)
            if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry")
                file(REMOVE "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry")
            endif()
        endif()
    endif()

    get_property(BPM_${PKG_NAME}_ADDED_ GLOBAL PROPERTY BPM_${PKG_NAME}_ADDED)
    if(NOT BPM_${PKG_NAME}_ADDED_)
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_REQUIRED_FROM" "/") # from root
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE" "${PKG_VERSION_RANGE}")
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_TAG" "${PKG_GIT_TAG}")
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_REPOSITORY" "${PKG_GIT_REPOSITORY}")
    else()
        get_property(REGISTERED_GIT_REPOSITORY GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_REPOSITORY")
        if(NOT "${REGISTERED_GIT_REPOSITORY}" STREQUAL "${PKG_GIT_REPOSITORY}")
            message(FATAL_ERROR 
                "BPM: Repository Conflict\n"
                "  Package: ${PKG_NAME}\n"
                "  Required from: /\n"
                "  New repo: ${PKG_GIT_REPOSITORY}\n"
                "  In registry: ${REGISTERED_GIT_REPOSITORY}")
        endif()

        get_property(REGISTERED_VERSION_RANGE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE")

        bpm_version_range_intersection("${REGISTERED_VERSION_RANGE}" "${PKG_VERSION_RANGE}" intersec_version_range)
        if(NOT intersec_version_range)
            message(FATAL_ERROR 
                "BPM: Version Conflict\n" 
                "  Package: ${PKG_NAME}\n"
                "  Required from: /\n"
                "  New repo: ${PKG_VERSION_RANGE}\n"
                "  In registry: ${REGISTERED_VERSION_RANGE}")
        endif()

        set_property(GLOBAL PROPERTY BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE "${intersec_version_range}")
    endif()

    set_property(GLOBAL PROPERTY "BPM_${PKG_NAME}_ADDED" TRUE)

endfunction()

function(BPMAddSourcePackage)

    bpm_parse_arguments("${ARGN}" PKG_NAME PKG_GIT_REPOSITORY PKG_GIT_TAG PKG_BUILD_TYPE PKG_OPTIONS PKG_PACKAGES PKG_QUIET PKG_VERSION_QUALIFIER PKG_V_MAJOR PKG_V_MINOR PKG_V_PATCH)

    # TODO:

endfunction()

function(bpm_get_cache_dir RESULT_VAR)
    set(_value "")

    if(DEFINED BPM_CACHE AND NOT "${BPM_CACHE}" STREQUAL "")
        message(STATUS "BPM: resolve BPM_CACHE - from CMAKE_ARG: ${BPM_CACHE}")
        return()
    endif()

    if(DEFINED ENV{BPM_CACHE} AND NOT "$ENV{BPM_CACHE}" STREQUAL "")
        set(_value "$ENV{BPM_CACHE}")
        message(STATUS "BPM: resolve BPM_CACHE - from environment variable: ${_value}")
    else()
        set(_value "${CMAKE_SOURCE_DIR}/_deps")
        file(RELATIVE_PATH rel_build_dir "${CMAKE_SOURCE_DIR}" "${CMAKE_BINARY_DIR}")
        message(STATUS "BPM: resolve BPM_CACHE - no cache provided: use local: ./${rel_build_dir}/_deps")
    endif()

    set(${RESULT_VAR} "${_value}" PARENT_SCOPE)
endfunction()

function(bpm_clone_repository_if_needed lib_name git_repo mirror_dir)
    if(NOT EXISTS "${mirror_dir}/HEAD")
        message(STATUS "BPM [${lib_name}]: Cloning git repository: ${git_repo} into: ${mirror_dir}")
        
        execute_process(
            COMMAND git clone --mirror "${git_repo}" "${mirror_dir}" --recursive -c advice.detachedHead=false
            RESULT_VARIABLE res
        )
    
        if(res EQUAL 0)
            message(STATUS "BPM [${lib_name}]: Cloning git repository - success")
        else() 
            message(FATAL_ERROR "BPM [${lib_name}]: Cloning git repository - failed")
        endif()
    endif()
endfunction()

function(bpm_mirror_fetch_new_tags lib_name mirror_dir)
    message(STATUS "BPM [${lib_name}]: Fetching newest version")
    execute_process(
        COMMAND git "--git-dir=${mirror_dir}" fetch --tags --prune
        RESULT_VARIABLE res
    )
    if(res EQUAL 0)
        message(STATUS "BPM [${lib_name}]: Fetching newest version - success")
    else() 
        message(WARNING "BPM [${lib_name}]: Fetching newest version - failed")
    endif()
endfunction()

function(bpm_fully_contains_tag_range IN_VERSIONS RANGE OUT)
    if("${version_upper}" STREQUAL "inf.inf.inf")
        set(${OUT} FALSE PARENT_SCOPE)
        return()
    endif()

    list(GET RANGE 0 version_lower)
    list(GET RANGE 1 version_upper)

    # check if we are searching for an exact match
    set(exact_match FALSE)
    string(REGEX MATCH "([0-9]+)\\.([0-9]+)\\.([0-9]+)$" _ "${version_lower}")
    if(CMAKE_MATCH_0)
        set(major_lower ${CMAKE_MATCH_1})
        set(minor_lower ${CMAKE_MATCH_2})
        set(patch_lower ${CMAKE_MATCH_3})
    else()
        message(FATAL_ERROR "BPM: Internal error: version string is not correct: ${version_lower}")
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
        message(STATUS "find range")
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

function(bpm_highest_version IN_TAGS out_var)

    set(max_version "")
    set(max_tag "")

    foreach(tag IN LISTS IN_TAGS)
        string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${tag}")
        if(CMAKE_MATCH_1)
            set(vtag ${CMAKE_MATCH_1})
            if(max_version STREQUAL "")
                set(max_version "${vtag}")
                set(max_tag "${tag}")
            elseif("${vtag}" VERSION_GREATER "${max_version}")
                set(max_version "${vtag}")
                set(max_tag "${tag}")
            endif()
        endif()
    endforeach()

    set(${out_var} "${max_tag}" PARENT_SCOPE)

endfunction()

function(bpm_parse_registry_range_entry INPUT_LIST OUT_NAME OUT_VERSION_RANGE OUT_GIT_TAG OUT_GIT_REPOSITORY)
    separate_arguments(tokens UNIX_COMMAND "${line}")

    set(name "")
    set(version_range "")
    set(git_tag "")
    set(git_repository "")

    set(expect "")

    foreach(arg IN LISTS tokens)

        if(arg STREQUAL "NAME")
            set(expect "NAME")
            continue()
        elseif(arg STREQUAL "VERSION_RANGE")
            set(expect "VERSION_RANGE")
            continue()
        elseif(arg STREQUAL "GIT_TAG")
            set(expect "GIT_TAG")
            continue()
        elseif(arg STREQUAL "GIT_REPOSITORY")
            set(expect "GIT_REPOSITORY")
            continue()
        endif()

        if(expect STREQUAL "NAME")
            set(name "${arg}")
            set(expect "")
        elseif(expect STREQUAL "VERSION_RANGE")
            set(version_range "${arg}")
            string(REPLACE "-" ";" version_range ${version_range})
            set(expect "")
        elseif(expect STREQUAL "GIT_TAG")
            set(git_tag "${arg}")
            set(expect "")
        elseif(expect STREQUAL "GIT_REPOSITORY")
            set(git_repository "${arg}")
            set(expect "")
        endif()

    endforeach()

    set(${OUT_NAME} "${name}" PARENT_SCOPE)
    set(${OUT_VERSION_RANGE} "${version_range}" PARENT_SCOPE)
    set(${OUT_GIT_TAG} "${git_tag}" PARENT_SCOPE)
    set(${OUT_GIT_REPOSITORY} "${git_repository}" PARENT_SCOPE)

endfunction()

function(bpm_parse_registry_version_entry INPUT_LIST OUT_NAME OUT_VERSION OUT_GIT_TAG OUT_GIT_REPOSITORY)
    separate_arguments(tokens UNIX_COMMAND "${line}")

    set(name "")
    set(version "")
    set(git_tag "")
    set(git_repository "")

    set(expect "")

    foreach(arg IN LISTS tokens)

        if(arg STREQUAL "NAME")
            set(expect "NAME")
            continue()
        elseif(arg STREQUAL "VERSION")
            set(expect "VERSION")
            continue()
        elseif(arg STREQUAL "GIT_TAG")
            set(expect "GIT_TAG")
            continue()
        elseif(arg STREQUAL "GIT_REPOSITORY")
            set(expect "GIT_REPOSITORY")
            continue()
        endif()

        if(expect STREQUAL "NAME")
            set(name "${arg}")
            set(expect "")
        elseif(expect STREQUAL "VERSION")
            set(version "${arg}")
            set(expect "")
        elseif(expect STREQUAL "GIT_TAG")
            set(git_tag "${arg}")
            set(expect "")
        elseif(expect STREQUAL "GIT_REPOSITORY")
            set(git_repository "${arg}")
            set(expect "")
        endif()

    endforeach()

    set(${OUT_NAME} "${name}" PARENT_SCOPE)
    set(${OUT_VERSION} "${version}" PARENT_SCOPE)
    set(${OUT_GIT_TAG} "${git_tag}" PARENT_SCOPE)
    set(${OUT_GIT_REPOSITORY} "${git_repository}" PARENT_SCOPE)

endfunction()

function(bpm_is_version_in_range in_version in_range out)
    list(GET VERSION_RANGE 0 range_lower)
    list(GET VERSION_RANGE 1 range_upper)

    if("${range_lower}" VERSION_LESS_EQUAL "${in_version}")
        if("${range_upper}" STREQUAL "inf.inf.inf")
            set(${out} TRUE PARENT_SCOPE)
        elseif("${in_version}" VERSION_LESS "${range_upper}")
            set(${out} TRUE PARENT_SCOPE)
        else()
            set(${out} FALSE PARENT_SCOPE)
        endif()
    else()
        set(${out} FALSE PARENT_SCOPE)
    endif()
    
endfunction()


function(bpm_solve_dependencies in_packages out_selected_list)
    set(packages_to_do ${in_packages})

    set(decision_counter "0")
    set("decision_${decision_counter}_todo_list" "${in_packages}")
    set("decision_${decision_counter}_selected_list" "")
    set("decision_${decision_counter}_pkg_name" "")
    set("decision_${decision_counter}_version" "")
    set("decision_${decision_counter}_range" "")
    set("decision_${decision_counter}_tag_wheel" "")
    set("decision_${decision_counter}_git_tag" "")
    set("decision_${decision_counter}_git_repo" "")

    while("decision_${decision_counter}_todo_list")
        set(todo_list "${decision_${decision_counter}_todo_list}")
        list(POP_FRONT todo_list pkg)
        if(decision_${decision_counter}_pkg_name) # if entry exists --> this is a retry --> go and select a lower version
            if("decision_${decision_counter}_tag_wheel")
                list(POP_FRONT "decision_${decision_counter}_tag_wheel" top_version)

                # retry logic with lower version

                # TODO: consider caching the metadata registry files to safe on calls to git
                execute_process(COMMAND "git --git-dir=${mirror_dir} show ${top_version}:.bpm-registry" RESULT_VARIABLE res OUTPUT_VARIABLE metadata ERROR_QUIET)
        
                string(REPLACE "\r\n" "\n" metadata_list "${metadata}") # replace new lines windows to unix style
                string(REPLACE "\n" ";" metadata_list "${metadata_list}") # replace new lines with ; for list seperators

                message(STATUS "${metadata_list}")

                if(res EQUAL 0)
                    foreach(line IN LISTS "${metadata_list}")
                        if(line)
                            list(APPEND todo_list line)
                        endif()
                    endforeach()
                endif()

                # no registry found --> no more entries added to the todo list --> make decision and continue
                math(EXPR next_decision_counter "${decision_counter} + 1")
                
                set(entry "NAME ${pkg_name} VERSION ${top_version} GIT_REPO ${git_repo}")

                set("decision_${next_decision_counter}_todo_list" "${todo_list}")
                set("decision_${next_decision_counter}_selected_list" "${decision_${decision_counter}_selected_list};${entry}")
                set("decision_${next_decision_counter}_pkg_name" "${pkg_name}")
                set("decision_${next_decision_counter}_version" "${top_version}")
                set("decision_${next_decision_counter}_tag_wheel" "${tag_wheel}")
                set("decision_${next_decision_counter}_range" "${pkg_version_range}")
                set("decision_${next_decision_counter}_git_tag" "${pkg_git_tag}")
                set("decision_${next_decision_counter}_git_repo" "${pkg_git_repo}")

                set(decision_counter "${next_decision_counter}")
                
                continue()
            else()
                # no more versions to try
                # delete this entry 
                set("decision_${decision_counter}_todo_list" "")
                set("decision_${decision_counter}_selected_list" "")
                set("decision_${decision_counter}_pkg_name" "")
                set("decision_${decision_counter}_version" "")
                set("decision_${decision_counter}_range" "")
                set("decision_${decision_counter}_tag_wheel" "")
                set("decision_${decision_counter}_git_tag" "")
                set("decision_${decision_counter}_git_repo" "")

                # pop
                math(EXPR decision_counter "${decision_counter} - 1")
                continue()
            endif()
        endif()

        set(solved_one FALSE)
        # check if the package is already in the selected list
        foreach(selected IN LISTS "decision_${decision_counter}_selected_list")
            bpm_parse_registry_version_entry("${selected}" sel_name sel_version sel_git_tag sel_git_repo)
            if(("${sel_name}" STREQUAL "${pkg_name}") OR ("${pkg_git_repo}" STREQUAL "${sel_git_repo}"))
                # repo conflict?
                if(NOT "${pkg_git_repo}" STREQUAL "${sel_git_repo}")
                    message(FATAL_ERROR  "Repository conflict\n  Package: ${pkg_name}\n  Repository 1: ${pkg_git_repo}\n  Repository 2: ${sel_git_repo}")
                endif()

                # package name conflict ? 
                if(NOT "${pkg_name}" STREQUAL "${sel_name}")
                    message(FATAL_ERROR  "Package name conflict\n  Repository: ${pkg_git_repo}\n  Package 1: ${pkg_name}\n  Package 2: ${sel_name}")
                endif()

                # check if the selected version is in the constraint
                bpm_is_version_in_range("${sel_version}" "${pkg_version_range}" is_in_range)
                if(is_in_range)
                    # no version conflict - already part of the list
                    # record decision
                    math(EXPR next_decision_counter "${decision_counter} + 1")

                    set("decision_${next_decision_counter}_todo_list" "${todo_list}")
                    set("decision_${next_decision_counter}_selected_list" "${decision_${decision_counter}_selected_list}")
                    set("decision_${next_decision_counter}_pkg_name" "${pkg_name}")
                    set("decision_${next_decision_counter}_version" "${sel_version}")
                    set("decision_${next_decision_counter}_tag_wheel" "${decision_${decision_counter}_tag_wheel}")
                    set("decision_${next_decision_counter}_range" "${pkg_version_range}")
                    set("decision_${next_decision_counter}_git_tag" "${pkg_git_tag}")
                    set("decision_${next_decision_counter}_git_repo" "${pkg_git_repo}")

                    set(decision_counter "${next_decision_counter}")
                    set(solved_one TRUE)
                    break()
                elseif()
                    # found a version conflict 
                    break()
                endif()
            endif()
        endforeach()
        
        # continue whith the next package if one decision got solved in the for loop
        if(solved_one)
            continue()
        elseif()

        if(version_conflict)
            continue()
        elseif()

        # package is not yet in the selected list
        # build the version wheel for this pakcage
        set(mirror_dir "${BPM_CACHE_DIR}/${pkg_name}/mirror")

        # see if tags have already been acquired
        get_property("BPM_REGISTRY_${pkg_name}_GIT_TAGS_" GLOBAL PROPERTY "BPM_REGISTRY_${pkg_name}_GIT_TAGS")

        if("BPM_REGISTRY_${pkg_name}_GIT_TAGS_")
            set(tags "${BPM_REGISTRY_${pkg_name}_GIT_TAGS_}")
        else()
            # if tags have not been acquired - load them
            execute_process(COMMAND "git --git-dir=${mirror_dir} tag" RESULT_VARIABLE res OUTPUT_VARIABLE tags)
            if(NOT res EQUAL 0)
                message(FATAL_ERROR "BPM [${pkg_name}]: Failed to get tags from mirror: ${mirror_dir}. `git --git-dir=${mirror_dir} tag` returned: ${res}")
            endif()

            # turn the console output into a CMake list
            string(REPLACE "\r\n" "\n" tags "${tags}")
            string(REPLACE "\n" ";" tags "${tags}")

            # cache tags
            set_property(GLOBAL PROPERTY "BPM_REGISTRY_${pkg_name}_GIT_TAGS" "${tags}")
        endif()

        # check if the version range is fully contained with the mirrors tags
        bpm_fully_contains_tag_range("${tags}" "${pkg_version_range}" contains)

        # fetch if upper version bound is inf or tag is not contained
        if(NOT contains)
            bpm_mirror_fetch_new_tags(${pkg_name} ${mirror_dir})
        endif()

        bpm_filter_version_tags("${tags}" "${VERSION_RANGE}" tag_wheel)

        # extract the version numbers from the tag_wheel
        set(version_wheel "")
        foreach(tag IN LISTS tag_wheel)
            string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${VALUE}")
            if(CMAKE_MATCH_0)
                set(version ${CMAKE_MATCH_1})
                LIST(APPEND version_wheel "${version}")
                # also make a quick lookup
                set("tag_lookup_${version}" "${tag}")
            endif()
        endforeach()

        endforeach()
        if(NOT version_wheel)
            message(FATAL_ERROR "BPM: Error: no version tags match the version range\n  Package: ${PKG_NAME}\n  Required from: ${REQUIRED_FROM}\n  Version range: ${version_lower} - ${version_upper}\n  Version Tags: ${tags}")
        endif()

        set(tag_wheel "")

        # now try all version from high to low
        list(SORT version_wheel COMPARE VERSION ORDER DESCENDING)

        # build tag wheel from version wheel
        foreach(version IN LISTS version_wheel)
            # build new selected list
            set(git_tag "${tag_lookup_${version}}")
            list(APPEND tag_wheel ${git_tag})
        endforeach()

        list(POP_FRONT tag_wheel top_version)

        execute_process(COMMAND "git --git-dir=${mirror_dir} show ${top_version}:.bpm-registry" RESULT_VARIABLE res OUTPUT_VARIABLE metadata ERROR_QUIET)
        
        string(REPLACE "\r\n" "\n" metadata_list "${metadata}") # replace new lines windows to unix style
        string(REPLACE "\n" ";" metadata_list "${metadata_list}") # replace new lines with ; for list seperators

        message(STATUS "${metadata_list}")

        if(res EQUAL 0)
            foreach(line IN LISTS "${metadata_list}")
                if(line)
                    list(APPEND todo_list line)
                endif()
            endforeach()
        endif()

        # no registry found --> no more entries added to the todo list --> make decision and continue
        math(EXPR next_decision_counter "${decision_counter} + 1")
        
        set(entry "NAME ${pkg_name} VERSION ${top_version} GIT_REPO ${git_repo}")

        set("decision_${next_decision_counter}_todo_list" "${todo_list}")
        set("decision_${next_decision_counter}_selected_list" "${decision_${decision_counter}_selected_list};${entry}")
        set("decision_${next_decision_counter}_pkg_name" "${pkg_name}")
        set("decision_${next_decision_counter}_version" "${top_version}")
        set("decision_${next_decision_counter}_tag_wheel" "${tag_wheel}")
        set("decision_${next_decision_counter}_range" "${pkg_version_range}")
        set("decision_${next_decision_counter}_git_tag" "${pkg_git_tag}")
        set("decision_${next_decision_counter}_git_repo" "${pkg_git_repo}")

        set(decision_counter "${next_decision_counter}")

    endwhile()

endfunction()

#
# @param in_pkg the package to solve for given as the string: "NAME <name> VERSION_RANGE <version-range> GIT_TAG <git_tag> GIT_REPO <git_repo>"
# @param in_selected_list a list of the selected package names and versions: "NAME <name> VERSION <version> GIT_TAG <git_tag> GIT_REPO <git_repo>"
#
# failed if out_selected_list is empty
#
function(bpm_solve_dependencies in_pkg in_selected_list out_selected_list out_success)
    bpm_parse_registry_range_entry("${in_pkg}" pkg_name pkg_version_range pkg_git_tag pkg_git_repo)
    
    # check if the package is already in the selected list
    foreach(selected IN LISTS in_selected_list)
        bpm_parse_registry_version_entry("${selected}" sel_name sel_version sel_git_tag sel_git_repo)
        if(("${sel_name}" STREQUAL "${pkg_name}") OR ("${pkg_git_repo}" STREQUAL "${sel_git_repo}"))
            # repo conflict?
            if(NOT "${pkg_git_repo}" STREQUAL "${sel_git_repo}")
                message(FATAL_ERROR  "Repository conflict\n  Package: ${pkg_name}\n  Repository 1: ${pkg_git_repo}\n  Repository 2: ${sel_git_repo}")
            endif()

            # package name conflict ? 
            if(NOT "${pkg_name}" STREQUAL "${sel_name}")
                message(FATAL_ERROR  "Package name conflict\n  Repository: ${pkg_git_repo}\n  Package 1: ${pkg_name}\n  Package 2: ${sel_name}")
            endif()

            # check if the selected version is in the constraint
            bpm_is_version_in_range("${sel_version}" "${pkg_version_range}" is_in_range)
            if(is_in_range)
                # no version conflict
                # version resolved - no need to go through dependencies - another recursion is already doing it
                set(out_selected_list "${in_selected_list}" PARENT_SCOPE) # empty list
                set(out_success TRUE PARENT_SCOPE) # no success
                return()
            elseif()
                # found a version conflict --> pop
                set(out_selected_list "" PARENT_SCOPE) # empty list
                set(out_success FALSE PARENT_SCOPE) # no success
                return()
            endif()
        endif()
    endforeach()

    # package is not yet in the selected list
    # build the version wheel for this pakcage
    set(mirror_dir "${BPM_CACHE_DIR}/${pkg_name}/mirror")

    # see if tags have already been acquired
    get_property("BPM_REGISTRY_${pkg_name}_GIT_TAGS_" GLOBAL PROPERTY "BPM_REGISTRY_${pkg_name}_GIT_TAGS")

    if("BPM_REGISTRY_${pkg_name}_GIT_TAGS_")
        set(tags "${BPM_REGISTRY_${pkg_name}_GIT_TAGS_}")
    else()
        # if tags have not been acquired - load them
        execute_process(COMMAND "git --git-dir=${mirror_dir} tag" RESULT_VARIABLE res OUTPUT_VARIABLE tags)
        if(NOT res EQUAL 0)
            message(FATAL_ERROR "BPM [${pkg_name}]: Failed to get tags from mirror: ${mirror_dir}. `git --git-dir=${mirror_dir} tag` returned: ${res}")
        endif()

        # turn the console output into a CMake list
        string(REPLACE "\r\n" "\n" tags "${tags}")
        string(REPLACE "\n" ";" tags "${tags}")

        # cache tags
        set_property(GLOBAL PROPERTY "BPM_REGISTRY_${pkg_name}_GIT_TAGS" "${tags}")
    endif()

    # check if the version range is fully contained with the mirrors tags
    bpm_fully_contains_tag_range("${tags}" "${pkg_version_range}" contains)

    # fetch if upper version bound is inf
    if(NOT contains)
        bpm_mirror_fetch_new_tags(${pkg_name} ${mirror_dir})
    endif()

    bpm_filter_version_tags("${tags}" "${VERSION_RANGE}" tag_wheel)

    # extract the version numbers from the tag_wheel
    set(version_wheel "")
    foreach(tag IN LISTS tag_wheel)
        string(REGEX MATCH "([0-9]+\\.[0-9]+\\.[0-9]+)" _ "${VALUE}")
        if(CMAKE_MATCH_0)
            set(version ${CMAKE_MATCH_1})
            LIST(APPEND version_wheel "${version}")
            # also make a quick lookup
            set("tag_lookup_${version}" "${tag}")
        endif()
    endforeach()

    endforeach()
    if(NOT version_wheel)
        message(FATAL_ERROR "BPM: Error: no version tags match the version range\n  Package: ${PKG_NAME}\n  Required from: ${REQUIRED_FROM}\n  Version range: ${version_lower} - ${version_upper}\n  Version Tags: ${tags}")
    endif()

    # now try all version from high to low
    list(SORT version_wheel COMPARE VERSION ORDER DESCENDING)
    foreach(version IN LISTS version_wheel)
        # build new selected list
        set(git_tag "${tag_lookup_${version}}")
        set(entry "NAME ${pkg_name} VERSION ${version} GIT_TAG ${git_tag} GIT_REPO ${pkg_git_repo}")
        set(new_selected_list "${in_selected_list};entry")

        # fetch dependency list from the package
        execute_process(COMMAND "git --git-dir=${mirror_dir} show ${highest_version}:.bpm-registry" RESULT_VARIABLE res OUTPUT_VARIABLE metadata ERROR_QUIET)
        if(NOT res EQUAL 0)
            # package does not have extra dependencies to look at --> finished
            #### FUUUUK I MESSED UP
            #### I DO NOT HAVE PERFECT BACK PROPAGATION THIS WAY, I NEED TO PROPAGATE INTO VISITED DEPENDENCY BRANCHES FIRST BEFORE POPPING TO 
            #### THE MAIN NODE AND TRYING A NEW VERSION NUMBER ON IT
        endif()
    endforeach()
endfunction()

function(BPMMakeAvailable)

    bpm_get_cache_dir(BPM_CACHE_DIR)

    # write the local registry
    get_property(BPM_REGISTRY_ GLOBAL PROPERTY BPM_REGISTRY)
    foreach(PKG_NAME IN LISTS BPM_REGISTRY_)
        # write local registry
        get_property(REQUIRED_FROM GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_REQUIRED_FROM")
        get_property(VERSION_RANGE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE")
        get_property(GIT_TAG GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_TAG")
        get_property(GIT_REPOSITORY GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_REPOSITORY")

        string(REPLACE ";" "-" SAFE_VERSION_RANGE "${VERSION_RANGE}")

        string(APPEND registry_content
            "REQUIRED_FROM ${REQUIRED_FROM} NAME ${PKG_NAME} VERSION_RANGE ${SAFE_VERSION_RANGE} "
            "GIT_TAG ${GIT_TAG} GIT_REPOSITORY ${GIT_REPOSITORY} INSTALL ${pkg_install}\n"
        )
        
    endforeach()
    file(APPEND "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry" "${registry_content}\n")

    # get registries from all dependencies
    set(BPM_EXTERNAL_REGISTRY "")
    foreach(PKG_NAME IN LISTS BPM_REGISTRY_)

        get_property(REQUIRED_FROM GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_REQUIRED_FROM")
        get_property(VERSION_RANGE GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_VERSION_RANGE")
        get_property(GIT_TAG GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_TAG")
        get_property(GIT_REPOSITORY GLOBAL PROPERTY "BPM_REGISTRY_${PKG_NAME}_GIT_REPOSITORY")

        if(VERSION_RANGE)
            list(GET VERSION_RANGE 0 version_lower)
            list(GET VERSION_RANGE 1 version_upper)
        else()
            message(FATAL_ERROR "BPM: BPMMakeAvailable: Non-version tags are not supported yet.")
        endif()

        # make sure that all mirrors are downloaded
        set(mirror_dir ${BPM_CACHE_DIR}/${PKG_NAME}/mirror)
        bpm_clone_repository_if_needed("${PKG_NAME}" "${GIT_REPOSITORY}" ${mirror_dir})
        
        # find all tags that match the version range
        execute_process(COMMAND "git --git-dir=${mirror_dir} tag" RESULT_VARIABLE res OUTPUT_VARIABLE tags)
        if(NOT res EQUAL 0)
            message(FATAL_ERROR "BPM [${PKG_NAME}]: Failed to get tags from mirror: ${mirror_dir}. `git --git-dir=${mirror_dir} tag` returned: ${res}")
        endif()

        # turn the console command into a CMake list
        string(REPLACE "\r\n" "\n" tags "${tags}")
        string(REPLACE "\n" ";" tags "${tags}")

        # check if the version range is fully contained with the mirrors tags
        bpm_fully_contains_tag_range("${tags}" "${VERSION_RANGE}" contains)

        # fetch if upper version bound is inf
        if(NOT contains)
            bpm_mirror_fetch_new_tags(${PKG_NAME} ${mirror_dir})
        endif()

        bpm_filter_version_tags("${tags}" "${VERSION_RANGE}" filtered_version_tags)
        if(NOT filtered_version_tags)
            message(FATAL_ERROR 
                "BPM: Error: no version tags match the version range\n"
                "  Package: ${PKG_NAME}\n"
                "  Required from: ${REQUIRED_FROM}\n"
                "  Version range: ${version_lower} - ${version_upper}\n"
                "  Version Tags: ${tags}")
        endif()

        bpm_highest_version("${filtered_version_tags}" highest_version)
        message(STATUS "BPM [${PKG_NAME}]: highest_version: ${highest_version}")

        # record the highest versions of all packages
        list(APPEND "BPM_REGISTRY_PACKAGE_VERSIONS_${PKG_NAME}" "${highest_version}")
        list(REMOVE_DUPLICATES "BPM_REGISTRY_PACKAGE_VERSIONS_${PKG_NAME}")

        # TODO: continue building the external registry
        # grab the .bpm-registry from library, if it exists and add its dependencies

        execute_process(COMMAND "git --git-dir=${mirror_dir} show ${highest_version}:.bpm-registry" RESULT_VARIABLE res OUTPUT_VARIABLE metadata ERROR_QUIET)
        if(res EQUAL 0)
            # replace: root requirement with the actual package and version that requires it
            string(REPLACE "REQUIRED_FROM /" "REQUIRED_FROM ${PKG_NAME}_${highest_version}" metadata "${metadata}")

            if(NOT "${BPM_EXTERNAL_REGISTRY_${PKG_NAME}_${highest_version}_ADDED}")
                list(APPEND BPM_EXTERNAL_REGISTRY "${PKG_NAME}_${highest_version}")
                set("BPM_EXTERNAL_REGISTRY_${PKG_NAME}_${highest_version}_ADDED" TRUE)
                
                set("BPM_EXTERNAL_REGISTRY_${PKG_NAME}_${highest_version}_DEPS" "")

                string(REPLACE "\r\n" "\n" metadata_list "${metadata}") # replace new lines windows to unix style
                string(REPLACE "\n" ";" metadata_list "${metadata_list}") # replace new lines with ; for list seperators

                message(STATUS "${metadata_list}")

                
                foreach(line IN LISTS metadata_list)
                    bpm_parse_registry_entry("${line}" dep_name dep_version_range dep_git_tag dep_git_repository)
                    if(dep_name)
                        # assume an empty line otherwise
                        list(APPEND "BPM_EXTERNAL_REGISTRY_${PKG_NAME}_${highest_version}_DEPS" "${dep_name}")
                        list(APPEND "BPM_EXTERNAL_REGISTRY_${dep_name}_PARENTS" "${PKG_NAME}_${highest_version}")
                        list(REMOVE_DUPLICATES "BPM_EXTERNAL_REGISTRY_${dep_name}_PARENTS")
                        set("BPM_EXTERNAL_REGISTRY_${PKG_NAME}_${highest_version}_${dep_name}_VERSION_RANGE" "${dep_version_range}")
                        set("BPM_EXTERNAL_REGISTRY_${PKG_NAME}_${highest_version}_${dep_name}_GIT_TAG" "${dep_git_tag}")
                        set("BPM_EXTERNAL_REGISTRY_${PKG_NAME}_${highest_version}_${dep_name}_GIT_REPOSITORY" "${dep_git_repository}")
                    endif()

                endforeach()
            else()
                # TODO: Verify and double check the existing entry

            endif()

            message(STATUS "BPM [${PKG_NAME}]: ${metadata}")
            file(APPEND "${CMAKE_CURRENT_SOURCE_DIR}/.bpm-registry" "${metadata}\n")
            
        else()
            message(STATUS "BPM [${PKG_NAME}]: Does not contain a bpm registry file `.bpm-registry`")
        endif()
        
    endforeach()

    # print the registry:
    message(STATUS "BPM_EXTERNAL_REGISTRY: ")
    foreach(ext_reg IN LISTS BPM_EXTERNAL_REGISTRY)
        message(STATUS "  ${ext_reg}")
        foreach(dep IN LISTS BPM_EXTERNAL_REGISTRY_${ext_reg}_DEPS)
            set(version_range "${BPM_EXTERNAL_REGISTRY_${ext_reg}_${dep}_VERSION_RANGE}")
            set(git_tag "${BPM_EXTERNAL_REGISTRY_${ext_reg}_${dep}_GIT_TAG}")
            set(git_repository "${BPM_EXTERNAL_REGISTRY_${ext_reg}_${dep}_GIT_REPOSITORY}")
            set(parents "${BPM_EXTERNAL_REGISTRY_${dep}_PARENTS}")
            set(highest_versions "${BPM_REGISTRY_PACKAGE_VERSIONS_${PKG_NAME}}")
            message(STATUS "    ${dep}: version range: ${version_range}, tag: ${git_tag}, repo: ${git_repository}, parents: ${parents}, highest_versions: ${highest_versions}")
            message(FATAL_ERROR "TODO: record the hightes version of all packages")
        endforeach()
        
    endforeach()
    

    #message(FATAL_ERROR "TODO: Now to the real part, build the actual solver")

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