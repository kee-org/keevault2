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

### ios iapdevcert

```sh
[bundle exec] fastlane ios iapdevcert
```

Get IAP development certificates

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

Get certificates

### ios generate_new_certificates

```sh
[bundle exec] fastlane ios generate_new_certificates
```

Generate new certificates

### ios beta_stage

```sh
[bundle exec] fastlane ios beta_stage
```

Push a new beta build to test service

### ios prod_stage_testflight

```sh
[bundle exec] fastlane ios prod_stage_testflight
```

Push a new prod build to testflight

### ios beta_local_device

```sh
[bundle exec] fastlane ios beta_local_device
```

Push a new beta build to local device

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
