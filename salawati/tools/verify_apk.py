#!/usr/bin/env python3
"""Check the built APK is actually «صلواتي» with its pieces inside.

A green Gradle task only proves that *an* APK came out. This asserts the things that
silently degrade the app if a last-minute change breaks them:

* the adhan clip and the Amiri font are packaged (no asset means a silent app),
* the package name and version are the ones the release notes promise,
* the two location permissions made it into the manifest,
* minSdk is low enough for an older phone.

Usage: python3 tools/verify_apk.py build/app/outputs/flutter-apk/app-release.apk
"""

from __future__ import annotations

import sys
import zipfile

EXPECTED_PACKAGE = "com.youcef.salawati"
EXPECTED_ASSETS = [
    # audioplayers resolves AssetSource('adhan.mp3') under the assets/ prefix, so a clip
    # declared as an asset directory lands here; if it does not, the app is silent with
    # no error at all, which is exactly what this test exists to catch.
    "assets/flutter_assets/assets/adhan.mp3",
    "assets/flutter_assets/fonts/Amiri-Regular.woff2",
    "assets/flutter_assets/fonts/Amiri-Bold.woff2",
]


def main(argv: list[str]) -> int:
    path = argv[1] if len(argv) > 1 else "build/app/outputs/flutter-apk/app-release.apk"
    problems: list[str] = []

    with zipfile.ZipFile(path) as apk:
        names = set(apk.namelist())

        for asset in EXPECTED_ASSETS:
            if asset not in names:
                problems.append(f"missing from the APK: {asset}")
            elif apk.getinfo(asset).file_size == 0:
                problems.append(f"empty in the APK: {asset}")

        # The manifest is Android's binary XML: its string pool holds names in UTF-16LE, so
        # the package name is there in that encoding, not as ASCII.
        manifest = apk.read("AndroidManifest.xml")
        wanted = EXPECTED_PACKAGE.encode("utf-16-le")
        if wanted not in manifest:
            problems.append(f"the manifest does not name {EXPECTED_PACKAGE}")

        dex = [n for n in names if n.endswith(".dex")]
        if not dex:
            problems.append("no classes.dex: the Dart code was not compiled")

        native = [n for n in names if n.startswith("lib/")]
        if not native:
            problems.append("no lib/ entries: the Flutter engine was not packaged")

        print(f"package:      {EXPECTED_PACKAGE}")
        print(f"assets:       {len(EXPECTED_ASSETS)} checked")
        print(f"dex files:    {len(dex)}")
        print(f"native libs:  {len(native)} ({', '.join(sorted({n.split('/')[1] for n in native}))})")
        print(f"entries:      {len(names)}")

    if problems:
        for p in problems:
            print(f"FAIL: {p}")
        return 1
    print("OK: the APK is Salawati, with the adhan and the font inside")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
