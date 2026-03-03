BPM — Binary Package Manager for CMake
======================================

BPM is a lightweight, CMake-native package manager that allows you to fetch, build, cache, and reuse CMake-based dependencies directly from Git repositories.


Get BPM.cmake
--------------

### Linux

```bash
curl -o cmake/BPM.cmake https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.2.0/BPM.cmake -L
```

### Windows

```powershell
mkdir cmake
Invoke-WebRequest -Uri "https://github.com/TobiasWallner/BPM.cmake/releases/download/v0.2.0/BPM.cmake" -OutFile "cmake/BPM.cmake"
```

🚀 Basic Usage
---------------
```cmake
include(cmake/BPM.cmake)

BPMInstallPackage(
    NAME <name>
    PACKAGES <packages for find_package>
    GIT_REPOSITORY <repo address>
    GIT_TAG <version tag>
    BUILD_TYPE <type: Release/Debug>
    ARGS <Optional args>
)

target_link_libraries(my_target PRIVATE <library>)
```

### Supported Options

#### Required
- `NAME`: Logical dependency name
- `PACKAGES`: CMake package names to expose
- `GIT_REPOSITORY`: Git repository URL

#### Optional
- `GIT_TAG`: Tag, branch, or commit
- `BUILD_TYPE`: Release / Debug / etc (default: Release)
- `ARGS`: Additional -D flags forwarded to the dependency

#### Implicit
- `CMAKE_TOOLCHAIN_FILE`:  A toolchain file required at the top level. Will be passed transitively to all packages.

✨ Features
------------

### 🔹 Content-Addressed Install Layout

Each build is stored under a unique hash derived from its configuration (Compiler, CPU, Flags, Toolchain, ...).

This means:

- No accidental overwriting
- No cross-project contamination
- Safe reuse of identical builds
- Multiple configurations can coexist

### 🔹 Local or Global Cache

#### Default (local mode)

By default, dependencies are installed into:

```
<build>/_deps/
```

And structured into the following layout
```
build/
 └─ _deps/
     └─ <NAME>/
         ├─ mirror/
         └─ install/<HASH>/
            └─ <HASH>.manifest
```

#### Global cache mode
You can optionally enable a shared/global cache:

```bash
cmake -DBPM_CACHE=/path/to/cache
```

or via environment variable:

```bash
export BPM_CACHE=/path/to/cache
```

This allows multiple projects to reuse the same compiled binaries.

The global cache is structured in the following way:
```
<BPM_CACHE>/
 └─ <NAME>/
     ├─ mirror/
     └─ install/<HASH>/
        └─ <HASH>.manifest
```

Writing Libraries for BPM
--------------------------

BPM requires dependencies to provide proper CMake `install()` rules and `*Config.cmake` exports.


📦 What Happens Automatically
-------------------------------

When BPMInstallPackage() is called:

- The dependency configuration is fingerprinted.
- BPM checks whether a matching binary already exists.
- If found → it is reused. If not: The Git repository is cloned (using a local mirror).
- The requested tag/commit is checked out.
- Submodules are initialized.
- The project is configured, built, and installed.
- The package is made available via `find_package()`.
- Temporary build directories are cleaned automatically.


  
