cmake_minimum_required(VERSION 3.22)

project(add_source_exact_version)

if(NOT BPM_ROOT)
    message(FATAL_ERROR "Needed: -DBPM_ROOT=path/to/BPM.cmake/")
else()
    string(REPLACE "\\" "/" BPM_ROOT "${BPM_ROOT}")
    message(STATUS "BPM_ROOT: ${BPM_ROOT}")
endif()

include(${BPM_ROOT}/BPM.cmake)

BPMAddSourcePackage("${BPM_ROOT}/tests/libraryA#=3.2.1" PACKAGES libA OPTIONS "BPM_LOCATION=${BPM_ROOT}/BPM.cmake" "LIB_OPTION=ON")
BPMAddSourcePackage("${BPM_ROOT}/tests/libraryA#=3.2.1" PACKAGES libA OPTIONS "BPM_LOCATION=${BPM_ROOT}/BPM.cmake" "LIB_OPTION=OFF")

BPMMakeAvailable()
