cmake_minimum_required(VERSION 3.22)

project(add_install_compatible_version)



if(NOT BPM_LOCATION)
    message(FATAL_ERROR "Needed: -DBPM_LOCATION=path/to/BPM.cmake")
endif()

include(${BPM_LOCATION})


BPMAddInstallPackage("../libraryA#^1.2.3" PACKAGES libA OPTIONS "BPM_LOCATION=../../../../../${BPM_LOCATION}")

BPMMakeAvailable()

add_executable(${PROJECT_NAME}
    main.cpp
)

target_link_libraries(${PROJECT_NAME} PRIVATE
    libA::libA
)

enable_testing()
add_test(NAME ${PROJECT_NAME} COMMAND ${PROJECT_NAME})