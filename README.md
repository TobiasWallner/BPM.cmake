BPM - Binary Package Manager
============================

BPM is a CMake-native package manager that allows you to fetch, build, cache, and reuse CMake-based dependencies directly from Git repositories.

Dependencies:
-------------
- CMake: https://cmake.org/

Usage Examples:
---------------

Shorthand:
```cmake
BPMCreatePackage("https://github.com/fmtlib/fmt@12.1.0")
```

Long form
```cmake
BPMCreatePackage(
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
BPMCreatePackage(https://github.com/org/repo@1.2.3)
BPMCreatePackage(https://github.com/org/repo@v1.2.3)
BPMCreatePackage(https://github.com/org/repo@>=1.2.3)
BPMCreatePackage(https://github.com/org/repo@^1.2.3)
BPMCreatePackage(https://github.com/org/repo@~1.2.3)
BPMCreatePackage(https://github.com/org/repo@=1.2.3)
BPMCreatePackage(https://github.com/org/repo@>=v1.2.3)
BPMCreatePackage(https://github.com/org/repo@^v1.2.3)
BPMCreatePackage(https://github.com/org/repo@~v1.2.3)
BPMCreatePackage(https://github.com/org/repo@=v1.2.3)
BPMCreatePackage(https://github.com/org/repo@git-tag)
BPMCreatePackage(https://github.com/org/repo@>=git-tag)
BPMCreatePackage(https://github.com/org/repo@=git-tag)
BPMCreatePackage(https://github.com/org/repo@>=commit-hash)
BPMCreatePackage(https://github.com/org/repo@=commit-hash)
```

The following are not allowed:
```
BPMCreatePackage(https://github.com/org/repo)
https://github.com/org/repo@^git-tag
https://github.com/org/repo@~git-tag
https://github.com/org/repo@^a5486b
https://github.com/org/repo@~a5486b
BPMCreatePackage(https://github.com/org/repo@^commit-hash)
BPMCreatePackage(https://github.com/org/repo@~commit-hash)
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


