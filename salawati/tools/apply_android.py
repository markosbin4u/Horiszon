#!/usr/bin/env python3
"""Apply Salawati's identity to a freshly generated Flutter Android project.

`flutter create` writes the Gradle files, the manifest and the resources, so their versions
always match the Flutter that is building. This script only changes the parts that make the
project *this* app:

* the package name and the app label,
* the two location permissions and the optional compass feature,
* the release build signed with the debug key, so the APK installs on any phone without a
  keystore,
* minSdk 23 (geolocator and audioplayers need a modern baseline).

Usage: python3 tools/apply_android.py android
"""

from __future__ import annotations

import pathlib
import re
import sys

PACKAGE = "com.youcef.salawati"
LABEL = "صلواتي"
MIN_SDK = 23
# AndroidX libraries that geolocator and audioplayers pull in demand compiling against 34+,
# and a plugin's own module is compiled against whatever the app asks for, so the app asks
# for the newest platform the runner's SDK ships.
COMPILE_SDK = 36

PERMISSIONS = """    <!-- The position is what the prayer times and the qibla are computed from. -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- A phone with no compass still gets times, adhkar and duas. -->
    <uses-feature
        android:name="android.hardware.sensor.compass"
        android:required="false" />
"""


def sub_once(pattern: str, replacement: str, text: str, what: str) -> str:
    new, count = re.subn(pattern, replacement, text, count=1)
    if count != 1:
        raise SystemExit(f"apply_android: could not find {what} to change")
    return new


def fix_gradle(path: pathlib.Path) -> None:
    text = path.read_text()
    text = sub_once(r'namespace\s*=\s*"[^"]*"', f'namespace = "{PACKAGE}"', text,
                    "namespace")
    text = sub_once(r'applicationId\s*=\s*"[^"]*"', f'applicationId = "{PACKAGE}"', text,
                    "applicationId")
    # compileSdk: the template writes flutter.compileSdkVersion.
    if "compileSdk = flutter.compileSdkVersion" in text:
        text = text.replace("compileSdk = flutter.compileSdkVersion",
                            f"compileSdk = {COMPILE_SDK}")
    elif "compileSdkVersion flutter.compileSdkVersion" in text:
        text = text.replace("compileSdkVersion flutter.compileSdkVersion",
                            f"compileSdkVersion {COMPILE_SDK}")

    # minSdk: the template writes either flutter.minSdkVersion or a literal.
    if "minSdk = flutter.minSdkVersion" in text:
        text = text.replace("minSdk = flutter.minSdkVersion", f"minSdk = {MIN_SDK}")
    else:
        text = sub_once(r"minSdk\s*=\s*\d+", f"minSdk = {MIN_SDK}", text, "minSdk")

    # A release build needs a signing config. The debug key keeps the APK installable
    # everywhere; publishing on Play would want a real keystore instead.
    if 'signingConfigs.getByName("debug")' not in text:
        text = sub_once(
            r"buildTypes\s*\{",
            'buildTypes {\n        release {\n            signingConfig = '
            'signingConfigs.getByName("debug")\n        }\n',
            text,
            "buildTypes",
        )
    path.write_text(text)
    print(f"apply_android: {path} -> {PACKAGE}, compileSdk {COMPILE_SDK}, "
          f"minSdk {MIN_SDK}, debug-signed release")


def fix_manifest(path: pathlib.Path) -> None:
    text = path.read_text()
    if "ACCESS_FINE_LOCATION" not in text:
        text = sub_once(r"(<manifest[^>]*>\n)", r"\1" + PERMISSIONS, text, "manifest open tag")
    text = sub_once(r'android:label="[^"]*"', f'android:label="{LABEL}"', text, "app label")
    path.write_text(text)
    print(f"apply_android: {path} -> label {LABEL}, location permission")


def main(argv: list[str]) -> int:
    root = pathlib.Path(argv[1] if len(argv) > 1 else "android")
    if not root.is_dir():
        raise SystemExit(f"apply_android: {root} does not exist")

    gradle = root / "app" / "build.gradle.kts"
    manifest = root / "app" / "src" / "main" / "AndroidManifest.xml"
    if gradle.is_file():
        fix_gradle(gradle)
    elif (root / "app" / "build.gradle").is_file():
        raise SystemExit(
            "apply_android: the template wrote build.gradle (Groovy); this script edits the "
            "Kotlin DSL. Update apply_android or pin the Flutter version."
        )
    else:
        raise SystemExit("apply_android: no app/build.gradle.kts in the template")

    if not manifest.is_file():
        raise SystemExit("apply_android: no AndroidManifest.xml in the template")
    fix_manifest(manifest)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
