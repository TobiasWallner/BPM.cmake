BPMCreatePackage
=================

`BPMCreatePackage()` is a small convenience wrapper around the standard CMake install/export/package steps for a library package.

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

`BPMCreatePackage()` assumes that:
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

BPMCreatePackage(<target>)
```

### Longhand form

Use this when you want to set the package name, namespace, multiple library targets, or custom header patterns.
```cmake
add_library(<target> ...)

target_include_directories(<target> PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

BPMCreatePackage(
    NAME <package-name>
    [NAMESPACE <namespace>]
    LIBRARIES <target> [<target> ...]
    [HEADER_FILES_MATCHING <pattern> [<pattern> ...]]
)
```

- `NAME`: required | exactly 1 argument  
  - package name used for:
    - install location lib/cmake/<NAME>
    - <NAME>Config.cmake
    - <NAME>Targets.cmake

- `LIBRARIES` required | 1 or more arguments
  - each argument must be an existing CMake target (from `add_library` or `add_executable`)
  - Targets that will be installed and exported into the package


- `NAMESPACE`: optional | exactly 1 argument  
  - namespace prefix for exported targets
  - Default if omitted: `NAMESPACE=<NAME>`

- `HEADER_FILES_MATCHING`: optional | 1 or more arguments
  - Default if omitted: `*.h`, `*.hh`, `*.hpp`, `*.hxx`