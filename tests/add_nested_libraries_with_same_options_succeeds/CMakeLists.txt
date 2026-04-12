cmake_minimum_required(VERSION 3.22)

project(add_nested_libraries_with_different_options)

if(NOT BPM_ROOT)
    message(FATAL_ERROR "Needed: -DBPM_ROOT=path/to/BPM.cmake/")
else()
    string(REPLACE "\\" "/" BPM_ROOT "${BPM_ROOT}")
    message(STATUS "BPM_ROOT: ${BPM_ROOT}")
endif()

include(${BPM_ROOT}/BPM.cmake)


BPMAddSourcePackage("${BPM_ROOT}/tests/libraryB#=0.0.1" PACKAGES libB OPTIONS "BPM_ROOT=${BPM_ROOT}" "LIB_OPTION=ON")
BPMAddSourcePackage("${BPM_ROOT}/tests/libraryBoption#=0.0.1" PACKAGES libBopt OPTIONS "BPM_ROOT=${BPM_ROOT}")

BPMMakeAvailable()