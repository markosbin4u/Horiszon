# Salawati build log

run: https://github.com/markosbin4u/Horiszon/actions/runs/45900888861

```

::group::✅ Passing tests
✅ prayer times a winter day in Batna matches the reference
✅ prayer times the summer solstice matches the reference
✅ prayer times every prayer falls in the order a day has them
✅ prayer times Dhuhr is around solar noon everywhere
✅ prayer times a place where the sun never reaches the angle has no such prayer
✅ prayer times Umm al-Qura puts Isha ninety minutes after Maghrib
✅ prayer times the Hanafi Asr comes later than the Shafi'i one
✅ prayer times every method produces a whole day of times
✅ next prayer before Fajr the next prayer is today's Fajr
✅ next prayer after Fajr the next prayer is Dhuhr
✅ next prayer between Maghrib and Isha the next is Isha
✅ next prayer after Isha the next is tomorrow's Fajr, not nothing
✅ next prayer the countdown is the real remaining time
✅ next prayer a prayer turned off is skipped
✅ qibla from Batna the Kaaba lies to the east-south-east
✅ qibla the bearing matches published values for known cities
✅ qibla from due north of Makkah the bearing is south
✅ qibla from Makkah itself the distance is zero
✅ qibla Batna is about four thousand kilometres from Makkah
✅ qibla the cardinal name fits the bearing
::endgroup::

🎉 20 tests passed.
Analyzing salawati...                                           

   info • Dangling library doc comment. Add a 'library' directive after the library comment • lib/core/prayer_times.dart:1:1 • dangling_library_doc_comments
   info • Dangling library doc comment. Add a 'library' directive after the library comment • lib/core/qibla.dart:1:1 • dangling_library_doc_comments
   info • 'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre. Try replacing the use of the deprecated member with the replacement • lib/main.dart:4:1 • deprecated_member_use
  error • Undefined name 'math'. Try correcting the name to one that is defined, or defining the name • lib/main.dart:659:34 • undefined_identifier
  error • Undefined name 'math'. Try correcting the name to one that is defined, or defining the name • lib/main.dart:659:67 • undefined_identifier
  error • Undefined name 'math'. Try correcting the name to one that is defined, or defining the name • lib/main.dart:683:32 • undefined_identifier
  error • Undefined name 'math'. Try correcting the name to one that is defined, or defining the name • lib/main.dart:683:65 • undefined_identifier
  error • Arguments of a constant creation must be constant expressions. Try making the argument a valid constant, or use 'new' to call the constructor • lib/main.dart:893:37 • const_with_non_constant_argument
  error • The getter 'city' isn't defined for the type 'Icons'. Try importing the library that defines 'city', correcting the name to the name of an existing getter, or defining a getter or field named 'city' • lib/main.dart:893:43 • undefined_getter
warning • Unused import: 'package:flutter/foundation.dart'. Try removing the import directive • lib/services/compass_stub.dart:1:8 • unused_import

10 issues found. (ran in 5.6s)
Upgrading build.gradle.kts
Upgrading gradle.properties
Running Gradle task 'assembleRelease'...                        

FAILURE: Build failed with an exception.

* Where:
Build file '/home/runner/work/Horiszon/Horiszon/salawati/android/app/build.gradle.kts' line: 1

* What went wrong:
An exception occurred applying plugin request [id: 'dev.flutter.flutter-gradle-plugin']
> Failed to apply plugin 'dev.flutter.flutter-gradle-plugin'.
   > Error: Your project's Gradle version (8.12.0) is lower than Flutter's minimum supported version of 9.3.1. Please upgrade your Gradle version. 
     Alternatively, use the flag "--android-skip-build-dependency-validation" to bypass this check.

     Potential fix: Your project's gradle version is typically defined in the gradle wrapper file. By default, this can be found at /home/runner/work/Horiszon/Horiszon/salawati/android/gradle/wrapper/gradle-wrapper.properties. 
     For more information, see https://docs.gradle.org/current/userguide/gradle_wrapper.html.


* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.

BUILD FAILED in 1m 27s
Running Gradle task 'assembleRelease'...                           88.6s
Gradle task assembleRelease failed with exit code 1
```
