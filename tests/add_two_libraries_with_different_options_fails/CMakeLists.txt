cmake_minimum_required(VERSION 3.22)

project(add_source_exact_version)

if(NOT BPM_LOCATION)
    message(FATAL_ERROR "Needed: -DBPM_LOCATION=path/to/BPM.cmake")
endif()

include(${BPM_LOCATION})

BPMAddSourcePackage("../libraryA#=3.2.1" PACKAGES libA OPTIONS "BPM_LOCATION=../../../../../${BPM_LOCATION}" "LIB_OPTION=ON")
BPMAddSourcePackage("../libraryA#=3.2.1" PACKAGES libA OPTIONS "BPM_LOCATION=../../../../../${BPM_LOCATION}" "LIB_OPTION=OFF")

BPMMakeAvailable()
