# Mobile release gates

Desktop and Web prereleases do not depend on mobile credentials.

## Android

Enable Android exports only after configuring:

- OpenJDK 17.
- Android SDK platform/build tools required by Godot 4.7.2.
- NDK and CMake versions required by the Godot Android build template.
- The Godot Gradle build template.
- A permanent package identifier.
- Repository secrets:
  - `ANDROID_KEYSTORE_BASE64`
  - `ANDROID_KEY_ALIAS`
  - `ANDROID_KEYSTORE_PASSWORD`
  - `ANDROID_KEY_PASSWORD`

The same release key must sign every APK/AAB so users can upgrade.

## iOS

Enable iOS exports only after configuring:

- A macOS runner with Xcode.
- Apple Developer Team ID and permanent bundle identifier.
- Distribution certificate and password.
- App Store provisioning profile.
- Xcode archive/export configuration.

The job must use a temporary keychain, export a signed IPA, and delete the
keychain before completion. Do not publish an unsigned IPA.

