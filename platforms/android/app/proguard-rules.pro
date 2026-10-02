# =============================================================================
# R8 / ProGuard keep rules for the Flow9 Android runner.
#
# R8 shrinking, optimization and obfuscation are enabled via `minifyEnabled true`
# in app/build.gradle. Because this app has a large native (JNI) surface, the
# rules below protect every Java symbol that native C++ code resolves BY NAME at
# runtime. Renaming or removing any of these would crash the app.
#
# References (see app/src/main/jni/RunnerWrapper.cpp):
#   - GetFieldID(wclass, "c_ptr", "J")                    -> keep the c_ptr field
#   - GetMethodID(wclass, "cb...", ...)                   -> keep all cb* callbacks
#   - FindClass("dk/area9/flowrunner/FlowAccessibleClip") -> keep class + <init>
#   - FindClass(".../FlowMediaStreamSupport$FlowMediaStreamObject") and friends
#   - All `native` methods declared in FlowRunnerWrapper (JNI name mangling)
# =============================================================================

# -----------------------------------------------------------------------------
# JNI: native method declarations. R8 must never rename/remove these because the
# C++ side is bound to their exact fully-qualified names via JNI name mangling.
# -----------------------------------------------------------------------------
-keepclasseswithmembernames class * {
    native <methods>;
}

# -----------------------------------------------------------------------------
# FlowRunnerWrapper is the JNI bridge. Native code:
#   * reads the `c_ptr` long field (GetFieldID)
#   * invokes all cb* callback methods (GetMethodID)
#   * calls its native methods
#
# Keep the ENTIRE class (`*;`). Do NOT try to enumerate members by return type:
# an earlier version of this file listed `void/boolean/int/long/String/Object`
# cb* overloads and silently missed `byte[] cbLoadAssetData`, `int[]`, `float`
# and `WebSocketClient` returning callbacks. R8 renamed those, and the app died
# at startup with:
#   java.lang.NoSuchMethodError: no non-static method
#   "Ldk/area9/flowrunner/FlowRunnerWrapper;.cbLoadAssetData(Ljava/lang/String;)[B"
#       at dk.area9.flowrunner.FlowRunnerWrapper.initLibrary(Native Method)
# Because every member here is reachable only from C++, R8 can never prove
# reachability itself -- keeping the whole class is the only safe option.
# -----------------------------------------------------------------------------
-keep class dk.area9.flowrunner.FlowRunnerWrapper {
    *;
}

# -----------------------------------------------------------------------------
# Classes referenced from JNI by fully-qualified name (FindClass) and/or whose
# members/constructors are accessed from native code. Keep the classes and all
# of their members so field IDs / method IDs stay resolvable.
# -----------------------------------------------------------------------------

# Constructed from native via FindClass + <init> (Ljava/lang/String;Ljava/lang/String;IIII)V
-keep class dk.area9.flowrunner.FlowAccessibleClip {
    *;
}

# Nested object classes referenced from native (FindClass on the $-mangled name).
# Their fields are read/written directly by C++, so keep all members.
-keep class dk.area9.flowrunner.FlowMediaStreamSupport$FlowMediaStreamObject {
    *;
}
-keep class dk.area9.flowrunner.FlowMediaRecorderSupport$FlowMediaRecorderObject {
    *;
}
-keep class dk.area9.flowrunner.FlowWebRTCSupport$FlowMediaSenderObject {
    *;
}

# Keep the enclosing support classes (they hold the nested JNI object types and
# are wired into the native callbacks). Members are exercised via JNI/reflection.
-keep class dk.area9.flowrunner.FlowMediaStreamSupport { *; }
-keep class dk.area9.flowrunner.FlowMediaRecorderSupport { *; }
-keep class dk.area9.flowrunner.FlowWebRTCSupport { *; }

# -----------------------------------------------------------------------------
# Android components declared in AndroidManifest.xml. The Android framework
# instantiates these by name via reflection; keep them (AGP usually keeps
# manifest components automatically, but we are explicit for safety).
# -----------------------------------------------------------------------------
-keep class dk.area9.flowrunner.FlowRunnerActivity { *; }
-keep class dk.area9.flowrunner.LauncherActivity { *; }
-keep class dk.area9.flowrunner.FlowPreferenceActivity { *; }
-keep class dk.area9.flowrunner.FlowRunnerService { *; }
-keep class dk.area9.flowrunner.FlowRunnerOnRebootService { *; }
-keep class dk.area9.flowrunner.FlowNotificationsBroadcastReceiver { *; }
-keep class dk.area9.flowrunner.FlowRebootReceiver { *; }
-keep class dk.area9.flowrunner.FlowFirebaseMessagingService { *; }

# -----------------------------------------------------------------------------
# Optional Google Play / Firebase integration (only linked when
# LINK_GOOGLE_PLAY_LIB=true). Keep the pluggable factory/impl classes that are
# selected at runtime, and the firebase messaging service.
# -----------------------------------------------------------------------------
-keep class dk.area9.flowrunner.FlowGooglePlayServices* { *; }
-keep interface dk.area9.flowrunner.IFlowGooglePlayServices { *; }

# Keep JNI-exception classes referenced from native by FQN.
-keep class java.lang.RuntimeException
-keep class java.lang.IllegalStateException

# -----------------------------------------------------------------------------
# Annotations & generics/signatures needed for correct behavior and debugging.
# Keep line numbers so Play Console / crash reports remain deobfuscatable
# (the mapping file is uploaded to Play automatically for AABs).
# -----------------------------------------------------------------------------
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod, Exceptions
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile

# -----------------------------------------------------------------------------
# Third-party libraries. Most modern AARs ship their own consumer ProGuard rules
# (billing, WebRTC, Firebase), but we add defensive rules for libraries that do
# reflection and may not ship complete rules.
# -----------------------------------------------------------------------------

# socket.io-client / engine.io-client
-dontwarn io.socket.**
-keep class io.socket.** { *; }

# Java-WebSocket
-dontwarn org.java_websocket.**
-keep class org.java_websocket.** { *; }

# Google Play Billing (ships consumer rules, but keep interfaces defensively)
-dontwarn com.android.billingclient.**

# Stream WebRTC (ships consumer rules; suppress warnings from optional deps)
-dontwarn org.webrtc.**
-keep class org.webrtc.** { *; }

# org.json is provided by the Android platform (excluded from socket.io dep)
-dontwarn org.json.**
