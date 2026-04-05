cmake_minimum_required(VERSION 3.20)

project(bpm)

include(BPM.cmake)

BPMAddInstallPackage("https://github.com/fmtlib/fmt#^v9.0.0")

BPMAddSourcePackage("../BPM_external_repo#^v0.7.0" PACKAGES greet)

BPMMakeAvailable(NO_DOWNLOAD_UPDATES)

add_executable(main main.cpp)

target_link_libraries(main PRIVATE greet)