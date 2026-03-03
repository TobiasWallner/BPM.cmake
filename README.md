BPM — Binary Package Manager for CMake
======================================

BPM is a lightweight, CMake-native package manager that allows you to fetch, build, cache, and reuse CMake-based dependencies directly from Git repositories.

It works entirely inside CMake — no Python, no external runtime, no registry required.

BPM is designed for:

- Deterministic builds
- Local or shared binary caching
- Git-based dependencies
- Projects that want reproducible dependency builds without adopting a full external ecosystem

✨ Features
------------

### 🔹 Git-Based Dependencies

- Fetch dependencies directly from Git repositories
- Supports tags, branches, or commit hashes
- Fully supports recursive Git submodules

### 🔹 Deterministic Binary Builds

- BPM builds dependencies into content-addressed install directories.
- BPM rebuilds automatically if: Compiler, compiler version, toolchain file, Git tag/commit, Build type, CMake arguments change. If none of these change, the binary is reused.
- BPM resolves packages only from its computed install directory. It does not rely on system-wide installations
- No External tooling required: just CMake

### 🔹 Content-Addressed Install Layout

Each build is stored under a unique hash derived from its configuration (Compiler, CPU, Flags, Toolchain, ...).

This means:

- No accidental overwriting
- No cross-project contamination
- Safe reuse of identical builds
- Multiple configurations can coexist

### 🔹 Local or Global Cache

By default, dependencies are installed into:

```
<build>/_deps/
```

You can optionally enable a shared/global cache:

```bash
cmake -DBPM_CACHE=/path/to/cache
```

or via environment variable:

```bash
export BPM_CACHE=/path/to/cache
```

This allows multiple projects to reuse the same compiled binaries.


🚀 Basic Usage
---------------
```cmake
include(BPM.cmake)

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

🧠 Supported Options
---------------------
### Required
- `Argument`: Description
- `NAME`: Logical dependency name
- `PACKAGES`: CMake package names to expose
- `GIT_REPOSITORY`: Git repository URL

### Optional
- `Argument`: Description
- `GIT_TAG`: Tag, branch, or commit
- `BUILD_TYPE`: Release / Debug / etc (default: Release)
- `ARGS`: Additional -D flags forwarded to the dependency
- `TRANSITIVE_COMPILER_FLAGS`: Optional compiler flags for dependency builds
  
🗂 Directory Layout
-------------------

### Default (local mode)
```
build/
 └─ _deps/
     └─ <NAME>/
         ├─ mirror/
         └─ install/<HASH>/
            └─ <HASH>.manifest
```

### Global cache mode
```
<BPM_CACHE>/
 └─ <NAME>/
     ├─ mirror/
     └─ install/<HASH>/
        └─ <HASH>.manifest
```


❓ What BPM Is Not
------------------

- Not a central package registry
- Not a lockfile-based ecosystem
- Not a prebuilt binary distribution system
- Not a replacement for Conan/vcpkg in large-scale environments
  - It is a lightweight, deterministic, Git-first dependency solution for CMake projects.