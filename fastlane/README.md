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

### ios refresh_profiles

```sh
[bundle exec] fastlane ios refresh_profiles
```

Refresh Certificates And Profiles

### ios refresh_adhoc_profiles

```sh
[bundle exec] fastlane ios refresh_adhoc_profiles
```

Refresh AdHoc Profiles

### ios download_certificates

```sh
[bundle exec] fastlane ios download_certificates
```

Download Certificates And Profiles

### ios download_push_certificate

```sh
[bundle exec] fastlane ios download_push_certificate
```

Get Push Certificates

### ios build_appstore

```sh
[bundle exec] fastlane ios build_appstore
```

Build Appstore

### ios upload_to_itunes_connect

```sh
[bundle exec] fastlane ios upload_to_itunes_connect
```

Upload to iTunes Connect

### ios upload_to_firebase_crashlytics

```sh
[bundle exec] fastlane ios upload_to_firebase_crashlytics
```

Upload to Firebase Crashlytics

### ios new_version

```sh
[bundle exec] fastlane ios new_version
```

Change marketing_version

### ios new_build_version

```sh
[bundle exec] fastlane ios new_build_version
```

Change currnt_project_version

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
