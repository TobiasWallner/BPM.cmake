BPM
======

Status
-------

Experimental

[![Tests](https://github.com/TobiasWallner/BPM.cmake/actions/workflows/tests.yml/badge.svg)](https://github.com/TobiasWallner/BPM.cmake/actions/workflows/tests.yml)

What is BPM
------------

BPM.cmake makes it easy to include libraries in C/C++ projects.

It is a **CMake-native package manager and dependency solver** for CMake-based Git repositories.
- resolves version and constraints across your dependency graph (yes, even diamond dependencies)
- resolves package options across your dependency graph
- caches repositories, sources, builds and installations reproducibly
- separates builds and installations by versions, toolchains, environments and other build options
- integrates dependencies either as installed packages or source-only libraries.

Table of Contents 
------------------
- [Status](#status)
- [What is BPM](#what-is-bpm)
- [Quickstart](#quickstart)
- [Adding Dependencies](#adding-dependencies)
- [Make Dependencies Available](#make-dependencies-available)
- [Caching](#caching)
- [Create Installable CMake Packages](#create-installable-cmake-packages)
- [Additional Options](#additional-options)
- [Error Messages](#error-messages)

Quickstart
----------

### Requirements:
- CMake: https://cmake.org/
- Git: https://git-scm.com/

### Installation

In your project do:

for Linux:
```bash
mkdir -p cmake
curl -o cmake/BPM.cmake "https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.4.9/BPM.cmake" -L
```                     

for Windows:
```powershell
mkdir cmake
Invoke-WebRequest -Uri "https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.4.9/BPM.cmake" -OutFile "cmake/BPM.cmake"
```

### Example:
```cmake
cmake_minimum_required(VERSION 3.22)
############################# LIBRARIES ##################################

project(my_project)

# ---- Include BPM -------------------------------------------------------
include(cmake/BPM.cmake)

# ---- Declare Dependencies ----------------------------------
# get fmt library with exact version: exact `major.minor.patch`
# Infer package: `fmt`
BPMAddInstallPackage("https://github.com/fmtlib/fmt#10.0.0")

# get glaze library with version constraint `^` (compatible): exact `major`, equal or better `minor.patch`
BPMAddSourcePackage("https://github.com/stephenberry/glaze#^v7.2.1")

# get mqtt library with version constraint `~` (patch): exact `major.minor`, equal or better `patch`
# Pass the option: `PAHO_WITH_MQTT_C=ON` to the library
# Use the package: `PahoMqttCpp` 
BPMAddInstallPackage("https://github.com/eclipse-paho/paho.mqtt.cpp#~1.6.0" OPTIONS PAHO_WITH_MQTT_C=ON PACKAGES PahoMqttCpp)

# ---- Make packages available -------------------------------------------
# solves dependency graph, downloads and installs packages (see Caching)
# and integrates packages via `find_package` or `add_subdirectory` depending on how they were added
BPMMakeAvailable()

############################# EXECUTABLE ##################################

add_executable(${PROJECT_NAME}
  main.cpp
)

target_link_libraries(${PROJECT_NAME} PRIVATE
  fmt::fmt
  glaze::glaze
  PahoMqttCpp::paho-mqttpp3
)
```


Adding Dependencies
-------------------

- `BPMAddInstallPackage()`: is used to register packages that should be installed. Will install release builds.
- `BPMAddSourcePackage()`: is used to register packages that should be integrated as source projects.

The functions have two ways they can be used. A **short-** and a **long-form**.

### Short-Form

The following short form is provided to quickly add libraries in one line to your project.
Optional arguments are shown in square brackets `[...]`.

```cmake
BPMAddInstallPackage("path/name#<constraint/version/tag/commit>"
    [PACKAGES <list-of-packages>]
    [OPTIONS <list-of-options>]
    [PRIVATE]
)
BPMAddSourcePackage("path/name#<constraint/version/tag/commit>"
    [OPTIONS <list-of-options>]
    [PRIVATE]
)
```

Required: `<path/name>#<constraint/version/tag/commit>`
  - `<path/name>`: The path to the git repository. The package name is inferred from the last path segment, ignoring a trailing `.git`.
  Example: `https://github.com/fmtlib/fmt.git` becomes `fmt`.
  - `<constraint/version/tag/commit>` 

Optional: 
  - `PACKAGES <list-of-packages>`: (only for `BPMAddInstallPackage()`)
    - If not provided BPM assumes that the package to integrate with `find_package` has the same name as the package name.
    - If provided the packages from the list will be integrated with `find_package`.
  - `OPTIONS <name=value> [<name=value> ...]`
    - A list of options that should be set before building the package
    - Option resolving:
      - Options that are explicitly set will be compared during the configuration and if they are conflicting (same name with different values) an error is generated
      - If options are not explicitly set a library is allowed to inherit that option from a different package that has set it explicitly
  - `PRIVATE`: Libraries that are marked with `PRIVATE` will be added as a dependency to this project but not to other projects depending on it. Example use cases: 
    - You want to add a library like `googletest` or `catch2` for testing, but do not want that users of your library have that testing library as a dependency, since it is not involved in your actual library. 
    - You are using a library that is completely contained within your library and does not leak any API or side effects.

Implicitly inferred:
- `NAME` The repository name will be inferred from the last path segment (ignoring trailing `.git`)
- `PACKAGES` If not provided: the repository package (if it is an installation target) will be inferred from the name
- The version/git-tag/commit-hash will be inferred from the string after the `#`

The version can be:
- `1.2.3`: Major.Minor.Patch version numbers
- `v1.2.3`: Optionally have a leading `v`
- `>=v1.2.3`: Optionally with a leading constraint qualifier

Versions can optionally have constraint qualifiers:
- `>=`: This version or a greater major, minor or patch number
- `^`: This version or one with a greater minor or patch number
- `~`: This version or one with a greater patch number
- `=`: Exactly this version (default if none is provided)
- `<`: Only versions less than (has to be paired with one of other ones)

Git-Tags and Commit-Hashes can optionally have a constraint qualifiers:
- `>=`: This version or a greater major, minor or patch number
- `=`: Exactly this version (default if none is provided)

Examples:
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#>=10.0.0")`
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#>=10.0.0<11.1.0")`
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#12.1.0" PACKAGES fmt)` 
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#12.1.0" OPTIONS BUILD_EXAMPLES=ON)` ... BPM turns examples off by default.
- `BPMAddInstallPackage("https://github.com/google/googletest#v1.17.0" PRIVATE)` ... Do not export testing libraries as dependencies for the user of your library

Same for `BPMAddSourcePackage`.

### Long-Form

If you need more control you can use the following long form instead:

```cmake
BPMAddInstallPackage(
  NAME <name>
  PACKAGES <list of packages>
  GIT_REPOSITORY <path to repo>
  GIT_TAG <constraint/version/tag/commit>
  OPTIONS <optional-list-of-options>
)
```

```cmake
BPMAddSourcePackage(
  NAME <name>
  GIT_REPOSITORY <path to repo>
  GIT_TAG <constraint/version/tag/commit>
  OPTIONS <optional-list-of-options>
)
```

### Required:
- `NAME`: The name of the package/library
- `GIT_REPOSITORY`: Path to the git repository
- `GIT_TAG`: Provide the git tag, version, version constraints, a commit-hash here.

### Optional:
- `PACKAGES`: A list of packages, from the library, that shall be integrated using `find_package`. Default is inferred from the package name. (only for `BPMAddInstallPackage()`)
- `OPTIONS`: Optional list of options that will be passed when configuring the package.
  - Option resolving:
    - Options that are explicitly set will be compared during the configuration and if they are conflicting (same name with different values) an error is generated
    - If options are not explicitly set a library is allowed to inherit that option from a different package that has set it explicitly

Make Dependencies Available
-----------------------------

Call `BPMMakeAvailable()` once after you have declared all libraries to:
  - solve the dependency graph
    - even diamond dependencies
  - Download libraries into the cache (default is `${CMAKE_BINARY_DIR}/_deps`)
  - Create a manifest and unique build hash that depends on: System, compiler, options, flags, versions, cpu, toolchains ... etc.
  - Optionally build and installs libraries.
  - Integrates libraries with `find_package` or `add_subdirectory`
  
### Optional Flags:
- `NO_DOWNLOAD`: Will not download/clone/fetch repositories and only use what is already present
  - if the repository has not been mirrored yet --> fail instead of clone
  - if the repository might be out-of-date (triggered by '`>=`' and maybe '`^`', '`~`') --> skips the fetching (will result in faster configurations)
- `NO_DOWNLOAD_UPDATES`: Will allow to initially download/clone a repository but not to fetch and check for updates
  - if the repository is not part of the mirror --> will download/clone
  - if the repository might be out-of-date (triggered by '`>=`' and maybe '`^`', '`~`') --> skips the fetching (will result in faster configurations)
- `VERBOSE`: Will print intermediary steps and results, especially of the version solving process

`BPMMakeAvailable()` Also generates the file `.bpm-registry` in the projects source directory. 
It contains all the packages/libraries that this library needs (aka. that have been added with `BPMAddInstallPackage()` or `BPMAddSourcePackage()`). This file is needed another project that uses BPM and adds your project as a dependency.
Add that file to your git repository.
This file will only change if you change the added packages. 

Caching
-------

BPM will cache repository mirrors, sources, builds and installations.

The default cache, if none is provided, is inside the build directory `${CMAKE_BINARY_DIR}/_deps`.

However, one can provide a different cache directory by:
  - Setting the environment variable `export BPM_CACHE=path/to/cache`
  - Setting the cmake configuration flag `-DBPM_CACHE=path/to/cache` (has precedence over environment variables)

That way the same cache can be used for multiple projects which avoids re-downloading and re-building and re-installing the same library over and over again for every project. 

Each package has the following caches:
 - `/mirror`: A memory and disk size efficient mirror (clone) of the repository.
 - `src/<commit>`: Populated sources of the mirror at specific git-commits.
 - `build/<manifest-hash>`: Binary build directory for package builds.
 - `install/<manifest-hash>`: The directory where that specific build will be installed (only generated for `BPMAddInstallPackage()`)
 - `manifest/<manifest-hash>.manifest`: The manifest files containing: Compiler identity, System description, Versions, Flags, ... etc.

To allow concurrent builds, packages are protected by lock files.

Create Installable CMake Packages
---------------------------------

It is not necessary to use this function to create BPM package. 

You can still write your own installation procedure like you normally would. 

`BPMCreateInstallPackage()` just is a small convenience wrapper around the standard CMake 
install/export/package steps for a library package.

### What it does

It takes one or more already-defined library targets and sets up the usual package installation boilerplate:

- installs the target artifacts (.a, .lib, .so, .dll, etc.)
- installs public headers from the package’s include/ directory
- exports the targets as `<PackageName>Targets.cmake`
- generates and installs `<PackageName>Config.cmake`
- optionally generates and installs `<PackageName>ConfigVersion.cmake` if `PROJECT_VERSION` is set

### Library Structure Assumptions

`BPMCreateInstallPackage()` assumes that:
- your libraries public include directory is `include/` (default) or provided via `PUBLIC_INCLUDE_DIRS`.
- your targets already describe the correct build-time and install-time include paths:

```cmake
target_include_directories(${PROJECT_NAME} PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>
)
```

### Function signatures

#### Shorthand-form

Use this when the package contains a single target and you want the package name and namespace to match that target name.

```cmake
# create your library and add sources
add_library(<target> STATIC ...)

# add include directories to your library
target_include_directories(<target> PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# create an alias in case it is used as a source library with `add_subdirectory`
add_library(<namespace>::<target> ALIAS <target>)

# create an installable package so it can be used with `find_package`
BPMCreateInstallPackage(<target>)
```

Equivalent to the longhand form with:
- `PACKAGE_NAME` = `<target>`
- `NAMESPACE` = `<target>`
- `TARGETS` = `<target>`
- `PUBLIC_INCLUDE_DIRS` = `include`
- `HEADER_FILES_MATCHING` = `"*.h" "*.hh" "*.hpp" "*.hxx"`

##### Long-form

Use this when you want to set the package name, namespace, multiple library targets, or custom header patterns.
```cmake
add_library(<target> ...)

target_include_directories(<target> PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

BPMCreateInstallPackage(
    PACKAGE_NAME <package-name>
    [NAMESPACE <namespace>]
    TARGETS <target> [<target> ...]
    [HEADER_FILES_MATCHING <pattern> [<pattern> ...]]
)
```

##### Required Arguments

- `PACKAGE_NAME`: required | exactly 1 argument  
  - Package name that the user of your library can then integrate with `find_package(...)`
  - used for:
    - install location `lib/cmake/${PACKAGE_NAME}`
    - `${PACKAGE_NAME}Config.cmake`
    - `${PACKAGE_NAME}Targets.cmake`

- `TARGETS` required | 1 or more arguments
  - each argument must be an existing CMake target (from `add_library` or `add_executable`)
  - Targets that will be installed and exported into the package
  - to provide a custom name after installation use: `set_target_properties(your_target_name PROPERTIES EXPORT_NAME install_target_name)` 

##### Optional Arguments

- `NAMESPACE`: optional | exactly 1 argument  
  - namespace prefix for exported targets
  - Default if omitted: `NAMESPACE=<PACKAGE_NAME>`

- `PUBLIC_INCLUDE_DIRS`: optional | 0 or more
  - Public include directories that should be installed
  - Default if omitted: `include/`

- `HEADER_FILES_MATCHING`: optional | 1 or more arguments
  - Structure of header files to install
  - Default if omitted: `*.h`, `*.hh`, `*.hpp`, `*.hxx`
  

##### EXAMPLE

In your library do:
```cmake
project(foo)

# We declare the `faa` library target.
#
# We add the prefix `foo_` to prevent name collisions for when this project
# is integrated with `add_subdirectory()`
#
add_library(foo_faa ...)

# When the library is installed we want the user to use:
#
#       `foo::faa`,
#
# Instead of `foo_faa` or `foo::foo_faa`. 
#
# The namespace `foo::` is added later in `BPMCreateInstallPackage` 
# by `install(EXPORT ... NAMESPACE foo::)`.
#
# The `::` also helps CMake treat the name as an imported or alias target. 
#
set_target_properties(foo_faa PROPERTIES EXPORT_NAME faa)

# Give `BPMAddSourcePackage()` or `add_subdirectory()` users the same nice target name that installed-package
# users will get from `BPMAddInstallPackage()` or `find_package(foo)`.
#
add_library(foo::faa ALIAS foo_faa) 

# Define public include directories for both build-tree and install-tree usage.
target_include_directories(foo_faa PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# Declare another real build-tree target.
add_library(foo_bar ...)

# Export this target as foo::bar after installation.
set_target_properties(foo_bar PROPERTIES EXPORT_NAME bar)

# Also provide the same name for `add_subdirectory()` users.
add_library(foo::bar ALIAS foo_bar)

# Define include directories
target_include_directories(foo_bar PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# Create an installable CMake package.
#
# PACKAGE_NAME 
#   controls:
#
#       `BPMAddInstallPackage("path/to/repo/foo#v1.2.3" PACKAGES foo)`
#       or
#       `find_package(foo CONFIG REQUIRED)`
#       
#
# TARGETS 
#   are the real build-tree targets that should be installed/exported.
#   Aka. this libraries `add_library(<target> ...)`
#
# NAMESPACE 
#   controls the prefix added to all exported target names.
#   In this case we want it to be prefixed by `foo::`
#
BPMCreateInstallPackage(
    PACKAGE_NAME foo
    TARGETS foo_faa foo_bar
    NAMESPACE foo
)
```

Then the user can do:
```cmake
# add the library to the dependency graph
BPMAddInstallPackage("path/to/repo/foo#v1.2.3")

# solve the dependency graph, install libraries and integrate the added libraries
BPMMakeAvailable()

# declare your own project
add_executable(main main.cpp)

# link against the libraries from the package
target_link_libraries(main PRIVATE foo::faa foo::bar)
```

Or if your user does not use BPM and want to use `find_package` instead:
```cmake
# integrate a manually installed library
find_package(foo)

# declare your own project
add_executable(main main.cpp)

# link against the libraries from the package
target_link_libraries(main PRIVATE foo::faa foo::bar)
```


Additional Options
------------------

Additional options that can be set either as a CMake variable `set(...)` as a CMake argument `-D...` or as an environment variable.

- `BPM_CLEAN_SOURCE_AFTER_INSTALL`
  - Default: `TRUE`
  - If set: will delete the checked out source directory after installing to free space from your filesystem. Does not delete the local mirror, only the files that got created when checking out a specific version/commit.

- `BPM_CLEAN_BUILD_AFTER_INSTALL`
  - Default: `TRUE`
  - If set: will delete the build directory and its artifacts to free space from the filesystem.

Error Messages
--------------

Error messages are in the form:

```
BPM [project:package]: message
```

Error messages created by BPM will start with `"BPM"`.

The first parameter in the square-brackets `[]` is the project (aka. its `CMakeLists.txt`) currently being executed.

The second parameter after the double-colon `:` in the square-brackets `[]` is the package that BPM was processing when the error occurred.