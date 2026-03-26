# Enable flexible page size support for Android 15 compatibility with 16KB page sizes
APP_SUPPORT_FLEXIBLE_PAGE_SIZES := true

APP_STL := c++_shared
APP_ABI := armeabi-v7a arm64-v8a
APP_CPPFLAGS += -w -frtti -fexceptions -Ofast -std=c++11
