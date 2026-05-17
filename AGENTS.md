# AGENTS.md

## Project

Neiroha is a Flutter app for an AI audio middleware and dubbing workstation.

Primary local targets:
- Windows desktop
- Android phone and tablet

Use the existing Flutter/Riverpod/Drift patterns in the repository. Keep changes scoped and run the relevant Flutter checks before reporting success.

## Local Toolchain

This Windows machine has the following local SDKs:

| Tool | Path / Value |
| --- | --- |
| Workspace | `D:\Web_Project\Neiroha` |
| Flutter SDK | `D:\Programs\Flutter_SDK\flutter` |
| Dart SDK | `D:\Programs\Flutter_SDK\flutter\bin\cache\dart-sdk` |
| Dart executable | `D:\Programs\Flutter_SDK\flutter\bin\cache\dart-sdk\bin\dart.exe` |
| Android SDK | `D:\Programs\Android_SDK` |
| Android cmdline-tools | `D:\Programs\Android_SDK\cmdline-tools\latest\bin` |
| Android platform-tools | `D:\Programs\Android_SDK\platform-tools` |
| Android emulator | `D:\Programs\Android_SDK\emulator` |
| JDK 17 | `D:\Programs\JDK17` |
| Pub cache | `D:\Programs\Pub_Cache` |

Installed Android packages include:
- `cmdline-tools;latest`
- `platform-tools` 37.0.0
- `build-tools;36.1.0`
- `platforms;android-36`
- `emulator` 36.5.11
- `ndk;28.2.13676358`

## Shell Setup

Before running Flutter, Dart, Gradle, adb, sdkmanager, or avdmanager from an automated agent shell, set the process environment explicitly:

```powershell
$env:ANDROID_HOME = 'D:\Programs\Android_SDK'
$env:ANDROID_SDK_ROOT = 'D:\Programs\Android_SDK'
$env:JAVA_HOME = 'D:\Programs\JDK17'
$env:FLUTTER_ROOT = 'D:\Programs\Flutter_SDK\flutter'
$env:PUB_CACHE = 'D:\Programs\Pub_Cache'
$env:Path = 'D:\Programs\Flutter_SDK\flutter\bin\cache\dart-sdk\bin;D:\Programs\Flutter_SDK\flutter\bin;D:\Programs\Android_SDK\platform-tools;D:\Programs\Android_SDK\cmdline-tools\latest\bin;D:\Programs\Android_SDK\emulator;D:\Programs\JDK17\bin;D:\Programs\Pub_Cache\bin;' + $env:Path
```

The Dart executable in the Flutter cache is preferred over relying on `dart.bat`, because the batch wrapper can touch Flutter cache locks. If a command must call `dart`, make sure the Dart SDK `bin` path is prepended before Flutter `bin`.

The Flutter SDK repository is configured as a Git safe directory for this user:

```powershell
git config --global --add safe.directory D:/Programs/Flutter_SDK/flutter
git config --global --add safe.directory D:/Web_Project/Neiroha
flutter config --jdk-dir='D:\Programs\JDK17'
```

## Reliable Commands

Use these from the workspace root unless noted otherwise:

```powershell
flutter doctor -v
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run -d windows
flutter build apk --debug
```

Android Gradle wrapper commands live under `android`:

```powershell
Push-Location android
.\gradlew.bat --version
.\gradlew.bat assembleDebug --no-daemon
Pop-Location
```

If Android Kotlin compilation reports incremental cache problems involving different drive roots, first run `flutter pub get` with `PUB_CACHE=D:\Programs\Pub_Cache`, then retry with:

```powershell
$env:GRADLE_OPTS = '-Dkotlin.incremental=false -Dhttps.protocols=TLSv1.2,TLSv1.3'
Push-Location android
.\gradlew.bat assembleDebug --no-daemon
Pop-Location
```

## Android Notes

`flutter doctor -v` is expected to show no issues on this machine.

For Android publishing work:
- Replace the placeholder Android application id before release if needed.
- Do not ship release builds with the debug signing config.
- Add a real signing config using keystore properties outside source control.
- Validate tablet layouts using width-based adaptive breakpoints, not device-name checks.

## Flutter Skills Installed For Codex

Flutter skills from `github.com/flutter/skills` were installed under `C:\Users\minec\.codex\skills`. Restart Codex before expecting them to appear in the active skills list.

Most relevant installed skills for this project:
- `flutter-build-responsive-layout`: best first choice for Android phone/tablet layout adaptation.
- `flutter-fix-layout-issues`: best for overflow, unbounded height, and constraint errors.
- `flutter-add-widget-test`: useful once layout behavior is stabilized.
- `flutter-add-integration-test`: useful before Android release flows.

## Adaptive Layout Guidance

Prefer layout decisions based on available width from `LayoutBuilder` or `MediaQuery.sizeOf(context)`, not hardware type or orientation.

Suggested breakpoints:
- `< 600`: phone layout
- `600..839`: compact tablet or unfolded small large-screen layout
- `>= 840`: tablet, desktop, or wide layout

For phone layouts, favor single-column flows, bottom navigation, compact panels, and full-screen detail pages.

For tablet layouts, favor master-detail surfaces, navigation rail/sidebar, constrained readable content widths, and multi-column grids using `SliverGridDelegateWithMaxCrossAxisExtent`.
