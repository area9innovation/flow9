# Flow9 Android Platform — Build Guide

## 1. Prerequisites

### 1.1 Install Android Studio

Download and install **the latest** Android Studio from https://developer.android.com/studio

Android Studio **Panda (2025.x) and newer** ships with **JDK 21** (JetBrains Runtime)
bundled on all platforms (Windows, Linux, macOS). This JDK is used for the Gradle
build — no separate JDK installation is required.

> **Note:** Older Android Studio versions (before Panda) bundle JDK 17, which is
> not sufficient for AGP 9.x used by this project. Make sure you have the latest
> Android Studio, or install JDK 21 separately (e.g., from https://adoptium.net).

### 1.2 Install SDK components

Open Android Studio, go to **Settings → Languages & Frameworks → Android SDK** and install:

- **SDK Platforms tab**: Android 15.0 (API 35)
- **SDK Tools tab** (check "Show Package Details"):
  - Android SDK Build-Tools **36.1.0**
  - NDK (Side by side) **30.0.14904198**
  - Android SDK Command-line Tools (latest)
  - Android SDK Platform-Tools

Or install from the command line:

```bash
sdkmanager "platforms;android-35" "build-tools;36.1.0" "ndk;30.0.14904198" "platform-tools" "cmdline-tools;latest"
```

Gradle 9.3.1 is downloaded automatically by the wrapper — no manual install needed.

### Current build configuration

| Setting           | Value            |
|-------------------|------------------|
| compileSdk        | 35               |
| targetSdk         | 35               |
| minSdk            | 21 (default)     |
| NDK               | 30.0.14904198    |
| Build Tools       | 36.1.0           |
| AGP               | 9.1.0            |
| Gradle            | 9.3.1            |
| Java source/target| 11               |
| JDK for Gradle    | 21 (bundled)     |

## 2. local.properties

This file is machine-specific and **must not** be checked into version control.
Create it in the project root (`platforms/android/local.properties`) with two entries:
`sdk.dir` pointing to your Android SDK and `org.gradle.java.home` pointing to JDK 21.

> **Note:** Android Studio creates `local.properties` with `sdk.dir` automatically
> when you open the project. You only need to add the `org.gradle.java.home` line.

### Windows

```properties
sdk.dir=C\:\\Users\\YourName\\AppData\\Local\\Android\\Sdk
org.gradle.java.home=C\:\\Program Files\\Android\\Android Studio\\jbr
```

### Ubuntu

```properties
sdk.dir=/home/yourname/Android/Sdk
org.gradle.java.home=/opt/android-studio/jbr
```

If you installed Android Studio to your home directory:

```properties
org.gradle.java.home=/home/yourname/android-studio/jbr
```

### macOS

```properties
sdk.dir=/Users/yourname/Library/Android/sdk
org.gradle.java.home=/Applications/Android Studio.app/Contents/jbr/Contents/Home
```

Or, if you prefer a standalone JDK via Homebrew:

```properties
org.gradle.java.home=/usr/local/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home
```

## 3. gradle.properties

Project-level configuration checked into VCS. Key settings:

```properties
PACKAGE_ID=dk.area9.flowrunner     # Application ID and namespace
MIN_SDK_VERSION=21                 # Minimum Android API level
TARGET_SDK_VERSION=35              # Target Android API level
```

### Optional flags

| Property              | Effect                                              |
|-----------------------|-----------------------------------------------------|
| `SKIP_NDK=true`       | Skip native C++ build entirely                     |
| `NDK_ARGUMENTS=...`   | Extra arguments passed to ndk-build                 |
| `IGNORE_ASSETS=...`   | aapt ignoreAssetsPattern for release builds          |
| `LINK_GOOGLE_PLAY_LIB=true` | Include Firebase, GMS, and push notification dependencies |
| `LINK_LOCALYTICS=true` | Include Localytics analytics SDK                   |

## 4. Native Code (JNI)

The native C++ build produces `libflowrunner.so`. Skip this section if you set `SKIP_NDK=true`.

### 4.1 Symlinks

The following symlinks in `app/src/main/jni/` point to shared C++ sources and should
already be present in the repository:

```
core    → ../../../../../common/cpp/core
font    → ../../../../../common/cpp/font
gl-gui  → ../../../../../common/cpp/gl-gui
include → ../../../../../common/cpp/include
utils   → ../../../../../common/cpp/utils
```

If missing, recreate them.

**Windows** (run Command Prompt as Administrator, or enable Developer Mode):

```cmd
cd app\src\main\jni
mklink /D core ..\..\..\..\..\common\cpp\core
mklink /D font ..\..\..\..\..\common\cpp\font
mklink /D gl-gui ..\..\..\..\..\common\cpp\gl-gui
mklink /D include ..\..\..\..\..\common\cpp\include
mklink /D utils ..\..\..\..\..\common\cpp\utils
```

**Ubuntu / macOS**:

```bash
cd app/src/main/jni
ln -s ../../../../../common/cpp/core core
ln -s ../../../../../common/cpp/font font
ln -s ../../../../../common/cpp/gl-gui gl-gui
ln -s ../../../../../common/cpp/include include
ln -s ../../../../../common/cpp/utils utils
```

### 4.2 Native dependencies

Run once to clone `freetype`, `jpeg`, and `libpng` into the `jni/` directory:

**Windows** (Git Bash or WSL):

```bash
cd app/src/main/jni
bash get-freetype.sh
```

**Ubuntu / macOS**:

```bash
cd app/src/main/jni
./get-freetype.sh
```

## 5. Bytecode / Assets

Place your compiled Flow bytecode as:

```
app/src/main/assets/default.b
```

Alternatively, leave the asset empty and download bytecode at runtime through the launcher UI.

## 6. AndroidManifest.xml

Located at `app/src/main/AndroidManifest.xml`.

**Important:** The following values are set in `build.gradle` via `gradle.properties`
and must **not** be duplicated in the manifest:
- `package` / namespace → `PACKAGE_ID`
- `android:minSdkVersion` / `android:targetSdkVersion` → `MIN_SDK_VERSION` / `TARGET_SDK_VERSION`
- `android:versionCode` / `android:versionName`

What you **do** configure in the manifest:
- Permissions
- Launcher activity vs standalone activity mode
- Intent-filter URL schemes
- `android:networkSecurityConfig`

### Launcher vs standalone app

By default, the manifest declares `LauncherActivity` as the entry point — it shows
a bytecode URL input form. To ship a standalone app that runs bundled bytecode
directly, change the launcher intent-filter to point to `FlowRunnerActivity` instead.

## 7. Signing

For release builds, add signing properties to `gradle.properties`:

```properties
key.store=path/to/keystore.jks
key.store.password=yourStorePassword
key.alias=yourKeyAlias
key.alias.password=yourKeyPassword
```

The keystore path is relative to `platforms/android/`.

## 8. Building

**Windows** (Command Prompt):

```cmd
gradlew.bat assembleDebug
gradlew.bat assembleRelease
gradlew.bat clean
```

**Ubuntu / macOS**:

```bash
./gradlew assembleDebug
./gradlew assembleRelease
./gradlew clean
```

Output APK location:
- Debug: `app/build/outputs/apk/debug/app-debug.apk`
- Release: `app/build/outputs/apk/release/app-release.apk`

To stop Gradle daemons:

```bash
./gradlew --stop          # Ubuntu / macOS
gradlew.bat --stop        # Windows
```

## 9. Tips

### Running in the emulator

Add `x86_64` to `abiFilters` in `app/build.gradle` for emulator support:

```groovy
ndk {
    abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
}
```

To download bytecode from your local machine to the emulator, see:
https://developer.android.com/studio/run/emulator-networking

### Dependencies reference

| Dependency | Purpose |
|---|---|
| `com.android.billingclient:billing:6.2.1` | Google Play Billing Library v6 |
| `io.getstream:stream-webrtc-android:1.3.10` | WebRTC (pre-compiled native + Java) |
| `io.socket:socket.io-client:1.0.0` | Socket.IO client |
| `org.java-websocket:Java-WebSocket:1.3.0` | WebSocket client |
| `androidx.legacy:legacy-support-v4:1.0.0` | AndroidX legacy support |
| `androidx.annotation:annotation:1.7.0` | AndroidX annotations |
