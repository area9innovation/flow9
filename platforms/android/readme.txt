------ Building with Android Studio ------

1) Install Android Studio: https://developer.android.com/studio/index.html

2) Install the latest SDK (at least v26) and NDK versions: 
AS Menu -> Edit -> Preferences -> Appearance & Behavior -> System Settings -> Android SDK.

3) Set up desired flow bytecode: replace QtByteRunner/android/app/src/main/assets/default.b content with 
your bytecode.

4) Set correct app id: gradle.properties file - PACKAGE_ID value.

5) QtByteRunner/android/app/src/main/AndroidManifest.xml contains manifest for the app.
One can set permissions, URL parameters etc. here.
In the manifest it is set if it the package starts FlowRunner with bytecode launcher form or a separate flow app:
	FlowRunner (by default): <activity android:name="dk.area9.flowrunner.LauncherActivity">
	Separate app: <activity ... android:name="dk.area9.flowrunner.FlowRunnerActivity">
Examples for standalone apps is in the AndroidManifest.LearnSmart.xml and others.

After that project is ready for building.

Helpful tips:
 - to run in the emulator, you may need to enable building for x86-64 - to do that, replace line
		abiFilters 'armeabi-v7a'
	with
		abiFilters 'armeabi-v7a', 'x86_64'
	in app/build.gradle.
 - instead of packaging your bytecode into the apk, you can download it from the launcher - it will 
 prompt you to do that - use your local machine, refer to this guide how to access it from the emulator:
 https://developer.android.com/studio/run/emulator-networking 

------ Building with SDK and NDK on Windows ------

1) Install Android Studio: https://developer.android.com/studio/index.html
Alternatively sdk-tools-windows<xxx>.zip can be dowloaded and
sdkmanager included be used to install all SDK-packages included in the Studio by default

2*) Download and unpack NDK (tested on android-ndk-r12b): https://developer.android.com/ndk/downloads/older_releases
Add it to the path: set PATH=%PATH%;<pat_to_ndk_dir>

3*) Download and unpack SDK build-tools (tested on 25.0.2): https://developer.android.com/studio/releases/build-tools
Add it to the path: set PATH=%PATH%;<pat_to_build_tools_dir>

4) Make symbolic links instead files in your <flow9>\platforms\android\app\src\main\jni folder.
Currently the files to be changed are as follows: core, font, gl-gui, include, utils.
Example: del core; mklink /D core ..\..\..\..\..\common\cpp\core

5) Set environment variables:
set JAVA_HOME=<path_to_jdk1.8.0_221>
set ANDROID_HOME=<path_to_sdk_dir>
set ANDROID_NDK_HOME=<pat_to_ndk_dir>

Note, build may not working with the latest Java.

6) Run the build:
gradlew build

Note, when gradle starts first time it downloads to %userprofile%\.gradle. The .android is also created

7) When you want to clean build, invoke: git clean -fdx --dry-run and remove the files/folders.

* - seems to be excessive

------ Building with Eclipse (obsolete) ------

1) It looks better to check that JNI part works fine at first.
- Go to QtByteRunner/android/jni.
- Make sure 'core', 'gl-gui', 'font' etc is checked out correctly as links to subfolders of QtByteRunner

- Clone standard libraries - run get-freetype.sh That gives jpeg, libpng, freetype folders

- Install android NDK (https://developer.android.com/tools/sdk/ndk/index.html)
- May be it will be convenient to add NDK folder to your PATH variable
- Run ndk-build in the android/jni folder. You probably will have such output:

>>>>>
Android NDK: Trying to define local module 'png' in /Users/vzakharov/gitflow/QtByteRunner/android/jni/libpng/Android.mk.    
Android NDK: But this module was already defined by /Users/vzakharov/gitflow/QtByteRunner/android/jni/libpng/Android.mk.    
/Users/vzakharov/adt/android-ndk-r10/build/core/build-module.mk:34: *** Android NDK: Aborting.    .  Stop.
>>>>

Then go to libpng/Android.mk and remove "For device shared" and "For testing" sections. It needs only static png library to link with flowrunner.so

- Run ndk-build again. And you shoud have success build:
>>>>>>
armeabi-v7a] Gdbserver      : [arm-linux-androideabi-4.6] libs/armeabi-v7a/gdbserver
[armeabi-v7a] Gdbsetup       : libs/armeabi-v7a/gdb.setup
[armeabi-v7a] Compile++ thumb: flowrunner <= AndroidUtils.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= RunnerWrapper.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLRenderSupport.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLRenderer.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLUtils.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLClip.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLGraphics.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLPictureClip.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLVideoClip.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLTextClip.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLWebClip.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLCamera.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLFont.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLFilter.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= GLSchedule.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= ImageLoader.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= AbstractHttpSupport.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= AbstractSoundSupport.cpp
[armeabi-v7a] Compile++ thumb: flowrunner <= FileLocalStore.cpp
[armeabi-v7a] Compile++ thumb: runnercore <= ByteCodeRunner.cpp
[armeabi-v7a] Compile++ thumb: runnercore <= ByteMemory.cpp
[armeabi-v7a] Compile++ thumb: runnercore <= CodeMemory.cpp
[armeabi-v7a] Compile++ thumb: runnercore <= GarbageCollector.cpp
[armeabi-v7a] Compile++ thumb: runnercore <= Natives.cpp
[armeabi-v7a] Compile++ thumb: runnercore <= Utf8.cpp
[armeabi-v7a] Compile++ thumb: runnercore <= Utf32.cpp
[armeabi-v7a] StaticLibrary  : librunnercore.a
[armeabi-v7a] SharedLibrary  : libflowrunner.so
[armeabi-v7a] Install        : libflowrunner.so => libs/armeabi-v7a/libflowrunner.so>>>
>>>>>>>
So now we have libflowrunner.so for ARMv7 builded. If you need another architecture (ARMv6 for example) then you need to add that to jni/Application.mk 

2) Now when JNI part is working fine we should create an android project in the Eclipse.
- You need Eclipse + ADT plugin (http://developer.android.com/sdk/installing/installing-adt.html)
- After installing Eclipse and ADT you need to create project from existing sources: 
	File->New->Other->Android->Project from existing sources . . and select QtByteRunner/android folder

3) Configure Eclipse Project properties:
- Project -> Properties -> Android : Set correct android SDK version: Android  4.2.2
- Project -> Properties -> Builders (configure eclipse builders) : 
	- JNI header gen: Be sure it contains correct path : /usr/bin/javah for example
	- Make sure the arguments are correct : -jni -classpath ${project_classpath:AndroidFlowRunner} -bootclasspath /Users/vzakharov/adt/sdk/platforms/android-17/android.jar -o jni/JniNatives.inc dk.area9.flowrunner.FlowRunnerWrapper
	for example. i.e. path to android jar should be correct and correspond currect API level (Android 4.2.2 - API level 17) 
- Project -> Properties -> C/C++ build
	- Make sure build command contains correct path to your ndk-build
	For example: nice /Users/vzakharov/adt/android-ndk-r10/ndk-build
- Add Google play services(located here: flow9\QtByteRunner\google-play-services_lib\), following this instructions for eclipse ADT: https://developers.google.com/android/guides/setup
	now line "android.library.reference.1=../../../Users/Anatoly/workspace/google-play-services_lib" in project.properties should reference to your local google play services lib from workspace

4) Try to build the project


