BPM - Binary Package Manager
============================

BPM is a CMake-native package and dependency manager.
Intended for everyone who likes to program in C and C++ and cannot bother to learn more than just CMake to manage their projects.

Get BPM.cmake
--------------
In your project do:

for Linux:
```bash
mkdir cmake -p
curl -o cmake/BPM.cmake https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.3.0/BPM.cmake -L
```

for Windows:
```powershell
mkdir cmake
Invoke-WebRequest -Uri "https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.3.0/BPM.cmake" -OutFile "cmake/BPM.cmake"
```

Usage
-----

Example:
```cmake
# ---- Include BPM -------------------------------------------------------
include(cmake/BPM.cmake)

# ---- Declare Installable Dependencies ----------------------------------
BPMAddInstallPackage("https://github.com/fmtlib/fmt@>=10.0.0")
BPMAddInstallPackage("https://github.com/gabime/spdlog@~1.17.0")

# ---- Declare Source Dependencies ---------------------------------------
BPMAddSourcePackage("https://github.com/stephenberry/glaze"@^v7.2.1)

# ---- Make packages available -------------------------------------------
BPMMakeAvailable()
```

Cool features:
--------------
- Extremely small footprint in your `CMakeLists.txt`
- Caches sources, builds and installs. 
  - Either in the current build directory `./build/deps_` 
  - or in a user defined cache `export BPM_CACHE=path/to/cache`.
  - Seperates builds by hashes
    - hash contains: compiler, compiler-version, toolchain-files, versions, git-commit-hash, library-flags, ... and many more
- Infers versions from git tags: `v1.2.3` or `1.2.3` | `major.minor.patch`
- Supports semver version constraints
  - `>=`: Larger Versions - Selects this version or any newer version.
  - `^`: Compatible Versions - Allows compatible upgrades that do not change the leading non-zero version number.
  - `~`: Patched Versions - Allows patch updates within the same minor version.
  - `=`: Exact Version - Selects only the exact version.
- Resolves dependency version constraints 
  - even diamond-dependencies
- Cross compilation safe

Programming in C++ I always wanted a package manager where i can just say:
Here is a path to a library that i want to use. 
And it knows how to correctly resolve version constraints, build/install and include it in my project, without me learning yet another language. 

Dependencies:
-------------
- CMake: https://cmake.org/
- Git: https://git-scm.com/

That is it you literally need nothing more. 
BPM is an almost zero-dependency package and dependency manager.

Usage Examples:
---------------

Shorthand:
```cmake
BPMCreateInstallPackage("https://github.com/fmtlib/fmt@12.1.0")
```

Long form
```cmake
BPMCreateInstallPackage(
    NAME fmt
    GIT_REPOSITORY 
    GIT_TAG 12.1.0
)
```

Detailed Usage:
---------------

### Short form

The general idea is:

```
path/name@<version|git-tag|commit-hash>
```

- The repository name will be infered from the last path segment
- The repository package (if it is an installation target) will be infered from the name or the optional `PACKAGES`
- The version will be infered from the string after the `@`
- Optionally allows to specify `PACKAGES`
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

Git-Tags and Commit-Hashes can optionally have a constraint qualifiers:
- `>=`: This version or a greater major, minor or patch number
- `=`: Exactly this version (default if none is provided)

The following are allowed:
```cmake
BPMAddInstallPackage(https://github.com/org/repo@1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@v1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@>=1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@^1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@~1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@=1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@>=v1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@^v1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@~v1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@=v1.2.3)
BPMAddInstallPackage(https://github.com/org/repo@git-tag)
BPMAddInstallPackage(https://github.com/org/repo@>=git-tag)
BPMAddInstallPackage(https://github.com/org/repo@=git-tag)
BPMAddInstallPackage(https://github.com/org/repo@>=commit-hash)
BPMAddInstallPackage(https://github.com/org/repo@=commit-hash)
```

The following are not allowed:
```
BPMAddInstallPackage(https://github.com/org/repo)
https://github.com/org/repo@^git-tag
https://github.com/org/repo@~git-tag
https://github.com/org/repo@^a5486b
https://github.com/org/repo@~a5486b
BPMAddInstallPackage(https://github.com/org/repo@^commit-hash)
BPMAddInstallPackage(https://github.com/org/repo@~commit-hash)
```

### Long form

#### Required Arguments
- `NAME`: The name of the repository
- `REPOSITORY`: The path of the repository
- `GIT_TAG`: The tag to check out. Can be a named tag `tag1`, a version tag (`v`)`1.2.3` or a commit hash `407c905e45ad75fc29bf0f9bb7c5c2fd3475976f`. optionally with a constraint: `>=`, `^`, `~`, `=`

#### Optional Arguments
- `PACKAGES`: Specifies the installed packages that will be loaded. If non are provided, the packages `NAME` will be assumed as the only installed package name
- `OPTIONS`: Options that will be passed to the packages `CMakeLists.txt`
- `QUIET`: Will hide the output of commands
- `BUILD_TYPE`: The build type: Release or Debug





BPMCreateInstallPackage
=================

`BPMCreateInstallPackage()` is a small convenience wrapper around the standard CMake install/export/package steps for a library package.

What it does
-------------

It takes one or more already-defined library targets and sets up the usual package installation boilerplate:

- installs the target artifacts (.a, .lib, .so, .dll, etc.)
- installs public headers from the package’s include/ directory
- exports the targets as `<PackageName>Targets.cmake`
- generates and installs `<PackageName>Config.cmake`
- optionally generates and installs `<PackageName>ConfigVersion.cmake` if `PROJECT_VERSION` is set

Library Structure Assumptions
-----------------------------

`BPMCreateInstallPackage()` assumes that:
- your librarys public include directory is `include/`.
- your targets already describe the correct build-time and install-time include paths:
  ```cmake
  target_include_directories(greet PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
  )
  ```

Function signatures
-------------------

### Shorthand form

Use this when the package contains a single target and you want the package name and namespace to match that target name.

```cmake
add_library(<target> ...)

target_include_directories(<target> PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

BPMCreateInstallPackage(<target>)
```

Equivalent to:
- `NAME` = <target>
- `NAMESPACE` = <target>
- `LIBRARIES` = <target>

### Longhand form

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
    - install location lib/cmake/<NAME>
    - <NAME>Config.cmake
    - <NAME>Targets.cmake

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

Philosophy
-----------

- Package managers should not force you to program 
- Package managers should be teachable in 5min or less
- Package managers should be as easy as saying: I want this library at that version.
