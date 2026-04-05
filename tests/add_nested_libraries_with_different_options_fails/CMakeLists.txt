cmake_minimum_required(VERSION 3.22)

project(add_nested_libraries_with_different_options)

if(NOT BPM_LOCATION)
    message(FATAL_ERROR "Needed: -DBPM_LOCATION=path/to/BPM.cmake")
endif()

include(${BPM_LOCATION})


BPMAddSourcePackage("../libraryB#=0.0.1" PACKAGES libB OPTIONS "BPM_LOCATION=../../../../../${BPM_LOCATION}" "LIB_OPTION=OFF")
BPMAddSourcePackage("../libraryBoption#=0.0.1" PACKAGES libBopt OPTIONS "BPM_LOCATION=../../../../../${BPM_LOCATION}")

BPMMakeAvailable()