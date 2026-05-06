fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios test

```sh
[bundle exec] fastlane ios test
```

运行所有单元测试

### ios build_debug

```sh
[bundle exec] fastlane ios build_debug
```

构建 Debug 版本（模拟器）

### ios build

```sh
[bundle exec] fastlane ios build
```

构建 Release 版本并打包

### ios beta

```sh
[bundle exec] fastlane ios beta
```

上传到 TestFlight

### ios bump

```sh
[bundle exec] fastlane ios bump
```

递增构建号

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
