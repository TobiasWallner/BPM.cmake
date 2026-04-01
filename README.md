BPM
======

Experimental

[![Tests](https://github.com/TobiasWallner/BPM.cmake/actions/workflows/tests.yml/badge.svg)](https://github.com/TobiasWallner/BPM.cmake/actions/workflows/tests.yml)

BPM.cmake is a **CMake-native package manager and dependency solver** for CMake-based git-repositories.
- resolves version and constraints across your dependency graph
- caches repositories, sources, builds and installations reproducibly
- separates builds and installations by versions, toolchains, environments and other build options
- integrate dependencies either as installations or source-only libraries.

Quickstart
----------

### Get BPM.cmake

In your project do:

for Linux:
```bash
mkdir -p cmake
curl -o cmake/BPM.cmake "https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.4.4/BPM.cmake" -L
```                     

for Windows:
```powershell
mkdir cmake
Invoke-WebRequest -Uri "https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.4.4/BPM.cmake" -OutFile "cmake/BPM.cmake"
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
# solves dependency graph and uses `find_package` or 
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

Requirements:
-------------
- CMake: https://cmake.org/
- Git: https://git-scm.com/

Functions
---------

BPM aims to provide the following 4 functions:

- `BPMAddInstallPackage()`:
  - Registers an installable package/library into your project. 
  - Builds a version graph.
  - Will use `find_package` in `BPMMakeAvailable`.
- `BPMAddSourcePackage()`:
  - Registers a source package/library into your project. 
  - Builds a version graph.
  - Will use `add_subdirectory` in `BPMMakeAvailable`.
- `BPMMakeAvailable()`:
  - Solves the version graph
  - Makes the packages available via `find_package` or `add_subdirectory`.
- `BPMCreateInstallPackage()`:
  - A helper that converts an `add_library` target into an `cmake --install`-able target.

`BPMAddInstallPackage()` and `BPMAddSourcePackage()`
----------------------------------------------------

- `BPMAddInstallPackage()`: is used to register packages that should be installed. Will install release builds.
- `BPMAddSourcePackage()`: is used to register packages that should be integrated as source projects.

The functions have two ways they can be used. A **short-** and a **long-form**.

### Short-Form

The following short form is provided to quickly add libraries in one line to your project.

```cmake
BPMAddInstallPackage("path/name#<constraint/version/tag/commit>")
BPMAddSourcePackage("path/name#<constraint/version/tag/commit>")

# with optional arguments
BPMAddInstallPackage("path/name#<constraint/version/tag/commit>" PACKAGES <list-of-packages> OPTIONS <list-of-options>)
BPMAddSourcePackage("path/name#<constraint/version/tag/commit>" OPTIONS <list-of-options>)
```

Required: `<path/name>#<constraint/version/tag/commit>`
  - `<path/name>` The path to the git repository. The name of the library is inferred from the path. E.g.: ``
  - `<constraint/version/tag/commit>`
    - The constraint: `>=` greater equal, `^` compatible, `~` patched, `=` exact, `<` smaller.
    - The version: `major.minor.patch`, `1.2.3` or optionally with leading `v`: `v1.2.3`.
    - An arbitrary git-tag or git-commit-hash

Optional: 
  - `PACKAGES <list-of-packages`: (only for `BPMAddInstallPackage()`)
    - If not provided BPM assumes that the package to integrate with `find_package` has the same name as the package name.
    - If provided the packages from the list will be integrated with `find_package`.
  - `OPTIONS <list-of-options>`
    - A list of options that should be set before building the package

- The repository name will be inferred from the last path segment
- The repository package (if it is an installation target) will be inferred from the name or the optional `PACKAGES`
- The version will be inferred from the string after the `#`
- Optionally allows to specify `PACKAGES` that will be integrated with `find_package`.
- Optionally allows to specify `OPTIONS` that will be passed as flags to the package


The version can be:
- `1.2.3`: Major.Minor.Patch version numbers
- `v1.2.3`: Optionally have a leading `v`
- `>=v1.2.3`: Optionally with a leading constraint qualifier

Version can optionally have a constraint qualifiers:
- `>=`: This version or a greater major, minor or patch number
- `^`: This version or one with a greater minor or patch number
- `~`: This version or one with a greater patch number
- `=`: Exactly this version (default if none is provided)
- `<`: Only versions less than (has to be paired with one of other ones)

Git-Tags and Commit-Hashes can optionally have a constraint qualifiers:
- `>=`: This version or a greater major, minor or patch number
- `=`: Exactly this version (default if none is provided)
- 

Examples:
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#>=10.0.0")`
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#>=10.0.0<11.1.0")`
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#12.1.0" PACKAGES fmt)` 
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt#12.1.0" OPTIONS BUILD_EXAMPLES=ON)` ... BPM turns examples off by default.

- `BPMAddSourcePackage("https://github.com/fmtlib/fmt#>=10.0.0")`
- `BPMAddSourcePackage("https://github.com/fmtlib/fmt#>=10.0.0<11.1.0")`
- `BPMAddSourcePackage("https://github.com/fmtlib/fmt#12.1.0" OPTIONS BUILD_EXAMPLES=ON)` ... BPM turns examples off by default.

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

Required:
- `NAME`: The name of the package/library
- `GIT_REPOSITORY`: Path to the git repository
- `GIT_TAG`: Provide the git tag, version, version constraints, a commit-hash here.

Optional:
- `PACKAGES`: A list of packages, from the library, that shall be integrated using `find_package`. Default is inferred from the package name. (only for `BPMAddInstallPackage()`)
- `OPTIONS`: Optional list of options that will be passed when configuring the package.

`BPMMakeAvailable()`
--------------------

Call make available once after you have declared all libraries. 
Make available will: 
  - solve the dependency graph
    - even diamond dependencies
  - Download libraries into the cache (default is `${CMAKE_BINARY_DIR}/_deps`)
  - Create a manifest and unique build hash that depends on: System, compiler, options, flags, versions, cpu, toolchains ... etc.
  - Optionally build and installs libraries.
  - Integrates libraries with `find_package` or `add_subdirectory`
  
Optional Flags:
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

However, one can provide a different cache directory directory by:
  - Setting the environment variable `export BPM_CACHE=path/to/cache`
  - Setting the cmake configuration flag `-DBPM_CACHE=path/to/cache` (has precedence over environment variables)

That way the same cache can be used for multiple projects which avoids re-downloading and re-building and re-installing the same library over and over again for every project. 

Each package has the following caches:
 - `/mirror`: A memory and disc size efficient mirror (clone) of the repository.
 - `src/<commit>`: Populated sources of the mirror at specific git-commits. (only kept for `BPMAddSourcePackage()`).
 - `build/<manifest-hash>`: Binary build directory (only kept for `BPMAddSourcePackage()`).
 - `install/<manifest-hash>`: The directory where that specific build will be installed (only generated for `BPMAddInstallPackage()`)
 - `manifest/<manifest-hash>.manifest`: The manifest files containing: Compiler identity, System description, Versions, Flags, ... ect.

To allow concurrent builds, packages are protected by lock files.

`BPMCreateInstallPackage()`
---------------------------

`BPMCreateInstallPackage()` is a small convenience wrapper around the standard CMake 
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
target_include_directories(greet PUBLIC
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
- `NAME` = `<target>`
- `NAMESPACE` = `<target>`
- `LIBRARIES` = `<target>`
- `PUBLIC_INCLUDE_DIRS` = `/include`
- `HEADER_FILES_MATCHING` = `"*.h" "*.hh" "*.hpp" "*.hxx"`

#### Long-form

Use this when you want to set the package name, namespace, multiple library targets, or custom header patterns.
```cmake
add_library(<target> ...)

target_include_directories(<target> PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

BPMCreateInstallPackage(
    NAME <package-name>
    [NAMESPACE <namespace>]
    LIBRARIES <target> [<target> ...]
    [HEADER_FILES_MATCHING <pattern> [<pattern> ...]]
)
```

#### Required Arguments

- `NAME`: required | exactly 1 argument  
  - package name used for:
    - install location `lib/cmake/<name>`
    - `<name>Config.cmake`
    - `<name>Targets.cmake`

- `LIBRARIES` required | 1 or more arguments
  - each argument must be an existing CMake target (from `add_library` or `add_executable`)
  - Targets that will be installed and exported into the package

#### Optional Arguments

- `NAMESPACE`: optional | exactly 1 argument  
  - namespace prefix for exported targets
  - Default if omitted: `NAMESPACE=<NAME>`

- `PUBLIC_INCLUDE_DIRS`: optional | 0 or more
  - Public include directories that should be installed
  - Default if omitted: `include/`

- `HEADER_FILES_MATCHING`: optional | 1 or more arguments
  - Structure of header files to install
  - Default if omitted: `*.h`, `*.hh`, `*.hpp`, `*.hxx`
  

Error Messages
--------------

Error messages are in the form:

```
BPM [project:package]: message
```

Error messages created by BPM will start with `"BPM"`.

The first parameter in the square-brackets `[]` is the project (aka. its `CMakeLists.txt`) currently being executed.

The second parameter after the double-colon `:` in the square-brackets `[]` is the package that BPM was processing when the error occurred.


Why BPM?
--------

### Compared to existing solutions

[**FetchContent**](https://cmake.org/cmake/help/latest/module/FetchContent.html) is the low-level native CMake solution for fetching external projects and making them available to your build. It works well for simple projects or shallow dependency graphs, and it gives you full control over how dependencies are integrated.

The downside appears once dependency graphs become deeper. If multiple dependencies require the same sub-dependency in different versions, resolving those conflicts manually can become difficult and fragile.

BPM aims to sit one level above `FetchContent` by providing a more package-oriented workflow with version constraints, dependency solving, and caching.

[**CPM.cmake**](https://github.com/cpm-cmake/CPM.cmake) is probably the closest comparison. CPM is a small and very useful CMake wrapper built around `FetchContent`, with a simpler API, caching, and version checking. It is an excellent choice if you want a lightweight, source-based dependency helper that stays close to plain CMake.

However, CPM does not fully resolve dependency conflicts for you - in conflicting transitive graphs, you still have to solve those situations manually. In addition, CPM integrates dependencies directly into the current project, which means everything lives in the same global CMake space. That can lead to target-name conflicts, which is a common problem when two repositories define targets with generic names such as `uninstall`.

Choose BPM if you want automatic dependency solving with version constraints, or if you want to install packages instead of always consuming source projects. Installing packages avoids recompiling the same dependency across multiple projects and helps prevent target conflicts by not polluting the global namespace.

[**Conan**](https://conan.io/) is a much larger package manager. It supports version ranges, dependency-graph solving, binary caching, and a broader packaging ecosystem (kinda similar to BPM). It integrates with CMake through generated toolchains and dependency files, and it can be a very strong solution for larger teams or projects that need a full package-management workflow.

The tradeoff is complexity. Conan can be simple when you only consume dependencies in a small endpoint application, but once you start building reusable libraries or more advanced setups, it usually introduces its own packaging layer and extra files to manage, for example:

- `src/library.cpp`, `include/library.hpp` - your actual library code
- `CMakeLists.txt` - your build configuration
- `conanfile.py` - Conan package recipe
- `test_package/` - usually with its own `conanfile.py` and `CMakeLists.txt`
- profiles - compiler, platform, and build settings

BPM takes a more minimal approach:

- one line such as `BPMAddInstallPackage(...)` or `BPMAddSourcePackage(...)` in your already existing `CMakeLists.txt` to consume a dependency
- no separate package recipe just to make a CMake project consumable
- one optional helper call, `BPMCreateInstallPackage(...)`, if you want to make your own library easier to install and reuse

In other words, BPM is for projects that want dependency management to stay inside CMake, without introducing a second packaging language or a larger external workflow.

[**vcpkg**](https://vcpkg.io/en/) focuses on a curated package ecosystem, versioning, registries, and either building from source or consuming prebuilt binaries. That is a great fit when you want broad library availability, standardization, and a package ecosystem that is already maintained for you.

BPM is more flexible when your dependencies are not already packaged in a curated registry, or when you want to depend directly on git repositories and make new CMake repositories reusable immediately. BPM is aimed at projects where the repository itself should already be enough to act as a consumable library.