cmake_minimum_required(VERSION 3.22)

project(depend_on_B_and_DepC)

if(NOT BPM_ROOT)
    message(FATAL_ERROR "Needed: -DBPM_ROOT=path/to/BPM.cmake/")
else()
    string(REPLACE "\\" "/" BPM_ROOT "${BPM_ROOT}")
    message(STATUS "BPM_ROOT: ${BPM_ROOT}")
endif()

include(${BPM_ROOT}/BPM.cmake)

BPMAddInstallPackage("${BPM_ROOT}/tests/libraryB#~0.0.1" PACKAGES libB OPTIONS "BPM_ROOT=${BPM_ROOT}")
BPMAddInstallPackage("${BPM_ROOT}/tests/libraryDepC#^0.0.1" PACKAGES libDepC OPTIONS "BPM_ROOT=${BPM_ROOT}")

BPMMakeAvailable()

add_executable(main
    main.cpp
)

target_link_libraries(main
    libB::libB
    libDepC::libDepC
)