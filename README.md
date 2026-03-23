BPM - Binary Package Manager
============================

BPM is a **CMake-native** package and **dependency manager**.

Accepts **arbitrary git repositories** as libraries, as long as they have a `CMakeLists.txt` to build them.

BPM is capable of understanding **semver versions** (1.2.3 or v1.2.3) and can infer them from git tags. Together with the following **version constraints**: 
- `>=`: Greater or equal versions
- `^`: Compatible version (has to have the same leading non-zero number and be greater or equal)
- `~`: Patched version (Allows greater or equal patched versions)
- `=`: Exact version (default if nothing is provided)
- `<`: Smaller versions, provides an upper bound

Also supports arbitrary git-tags or git-commit-hashes.

BPM will record all libraries from all included packages recursively, create and **solve the version graph**. BPM is capable of solving **Diamond dependencies**.

Packages can be integrated either:
  - trough **installations** (internally uses `find_package`), which prevents polluting the global namespace and mitigates target clashes.
  - or through **source integrations** (internally uses `add_subdirectory`), in case the repository/library is not `cmake --install`-able.

Sources, builds and installations of packages/libraries/repositories are **chached** and seperated by **manifests** that contain all relevant environment and build variables for **deterministic builds**.

BPM is further capable of inspecting `CMakeLists.txt` and automatically **disabling test and example targets**.

Get BPM.cmake
--------------
In your project do:

for Linux:
```bash
mkdir cmake -p
curl -o cmake/BPM.cmake https://github.com/TobiasWallner/BPM.cmake/releases/download/0.4.0/BPM.cmake -L
```

for Windows:
```powershell
mkdir cmake
Invoke-WebRequest -Uri "https://github.com/TobiasWallner/BPM.cmake/releases/download/0.4.0/BPM.cmake" -OutFile "cmake/BPM.cmake"
```

Dependencies:
-------------
- CMake: https://cmake.org/
- Git: https://git-scm.com/


Usage
-----

Example:
```cmake
############################# LIBRARIES ##################################

# ---- Include BPM -------------------------------------------------------
include(cmake/BPM.cmake)

# ---- Declare Installable Dependencies ----------------------------------
BPMAddInstallPackage("https://github.com/fmtlib/fmt@>=10.0.0")

# ---- Declare Source Dependencies ---------------------------------------
BPMAddSourcePackage("https://github.com/stephenberry/glaze"@^v7.2.1)

# ---- Make packages available -------------------------------------------
BPMMakeAvailable()

############################# EXECUTABLE ##################################

add_executable(main
  main.cpp
)

target_link_libraries(main PRIVATE
  fmt::fmt
  glaze::glaze
)

########################### CREATE LIBRARY #################################

add_library(main_lib STATIC
  main_lib.cpp
)

target_link_libraries(main_lib PRIVATE
  fmt::fmt
  glaze::glaze
)

# ---- Create Installable Library ------------------------------------------
BPMCreateInstallPackage(greet)
```

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

`BPMAddInstallPackage()` is used to register packages that should be installed.

`BPMAddSourcePackage()` is used to register packages that should be integrated as source projects.

The functions have two ways they can be used. A **short-** and a **long-form**.

### Short-Form

The following short form is provided to quickly add libraries in one line to your project.

```cmake
BPMAddInstallPackage("path/name@<constraint/version/tag/commit>")
BPMAddSourcePackage("path/name@<constraint/version/tag/commit>")

# with optional arguments
BPMAddInstallPackage("path/name@<constraint/version/tag/commit>" PACKAGES <list-of-packages> OPTIONS <list-of-options>)
BPMAddSourcePackage("path/name@<constraint/version/tag/commit>" OPTIONS <list-of-options>)
```

Required: `<path/name>@<constraint/version/tag/commit>`
  - `<path/name>` The path to the git repository. The name of the library is infered from the path. E.g.: ``
  - `<constraint/version/tag/commit>`
    - The constraint: `>=` greater equal, `^` compatible, `~` patched, `=` exact, `<` smaller.
    - The version: `major.minor.path`, `1.2.3` or optionally with leading `v`: `v1.2.3`.
    - An arbitrary git-tag or git-commit-hash

Optional: 
  - `PACKAGES <list-of-packages`: (only for `BPMAddInstallPackage()`)
    - If not provided BPM assumes that the package to integrate with `find_package` has the same name as the package name.
    - If provided the packages from the list will be integrated with `find_package`.
  - `OPTIONS <list-of-options>`
    - A list of options that should be set before building the package

- The repository name will be infered from the last path segment
- The repository package (if it is an installation target) will be infered from the name or the optional `PACKAGES`
- The version will be infered from the string after the `@`
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
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt@>=10.0.0")`
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt@>=10.0.0<11.1.0")`
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt@12.1.0" PACKAGES fmt)` 
- `BPMAddInstallPackage("https://github.com/fmtlib/fmt@12.1.0" OPTIONS BUILD_EXAMPLES=ON)` ... BPM turns examples off by default.

- `BPMAddSourcePackage("https://github.com/fmtlib/fmt@>=10.0.0")`
- `BPMAddSourcePackage("https://github.com/fmtlib/fmt@>=10.0.0<11.1.0")`
- `BPMAddSourcePackage("https://github.com/fmtlib/fmt@12.1.0" OPTIONS BUILD_EXAMPLES=ON)` ... BPM turns examples off by default.

### Long-Form

If you need more control you can use the following long form instead:

```cmake
BPMAddInstallPackage(
  NAME <name>
  PACKAGES <list of packages>
  GIT_REPOSITOR <path to repo>
  GIT_TAG <constraint/version/tag/commit>
  OPTIONS <optional-list-of-options>
)
```

```cmake
BPMAddSourcePackage(
  NAME <name>
  GIT_REPOSITOR <path to repo>
  GIT_TAG <constraint/version/tag/commit>
  OPTIONS <optional-list-of-options>
)
```

Required:
- `NAME`: The name of the package/library
- `GIT_REPOSITOR`: Path to the git repository
- `GIT_TAG`: Provide the git tag, version, version constraints, a commit-hash here.

Optional:
- `PACKAGES`: A list of packages, from the library, that shall be integrated using `find_package`. Default is infered from the package name. (only for `BPMAddInstallPackage()`)
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
  - if the repository might be out of date --> skipps the fetching (will result in faster configurations)

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
  - Setting the environment variable `export BPM_CACH=path/to/cache`
  - Setting the cmake configuration flag `-DBPM_CACHE=path/to/cache` (has precidence over environment variables)

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
- your librarys public include directory is `include/` (default) or provided via `PUBLIC_INCLUDE_DIRS`.
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
add_library(<target> ...)

target_include_directories(<target> PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

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

The second parameter after the double-colon `:` in the square-brackets `[]` is the package that BPM was processing when the error occured.