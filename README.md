android-gradle-plugin-dash-docset
=================================

A quickly hacked ruby script to generate a docset from the [Android Gradle Plugin DSL Reference](https://developer.android.com/tools/building/plugin-for-gradle.html)

Steps to generate the docset:
* Download the plugin command reference package from the [Android Plug-in for Gradle page](https://developer.android.com/tools/building/plugin-for-gradle.html) ([direct link](https://developer.android.com/shareables/sdk-tools/android-gradle-plugin-dsl.zip)).
* Run it giving the zip file as first argument (Tested on Mac OS X, requires ruby and sqlite3 gem)

```
./android-gradle-plugin-dash-docset.rb android-gradle-plugin-dsl.zip
```
