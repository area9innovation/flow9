LOCAL_PATH:= $(call my-dir)

# Profiling
MY_PROF_FLAGS :=
MY_PROF_LIB := 
#include $(LOCAL_PATH)/android-ndk-profiler.mk

# Generated code
MY_GEN_LIB :=
MY_GEN_FLAGS :=
ifeq ($(WITH_FLOWGEN),true)
    include $(LOCAL_PATH)/flowgen-code.mk
endif

# Runner core
include $(CLEAR_VARS)

LOCAL_MODULE    := librunnercore
LOCAL_CFLAGS    := -DFLOW_EMBEDDED $(MY_PROF_FLAGS) $(MY_GEN_FLAGS)
LOCAL_LDLIBS    := -lstdc++ -llog

APP_ALLOW_MISSING_DEPS := true

LOCAL_SRC_FILES := \
    core/ByteCodeRunner.cpp \
    core/ByteMemory.cpp \
    core/CodeMemory.cpp \
    core/MemoryArea.cpp \
    core/GarbageCollector.cpp \
    core/Natives.cpp \
    core/Utf8.cpp \
    core/Utf32.cpp \

include $(BUILD_STATIC_LIBRARY)

# Compound shared lib
include $(CLEAR_VARS)

LOCAL_C_INCLUDES := \
	$(LOCAL_PATH)/include \
	$(LOCAL_PATH)/freetype/include \
	$(LOCAL_PATH)/jpeg \
	$(LOCAL_PATH)/libpng \
	$(LOCAL_PATH)/font

LOCAL_MODULE    := libflowrunner
LOCAL_CFLAGS    := -DFLOW_EMBEDDED $(MY_PROF_FLAGS) $(MY_GEN_FLAGS)
LOCAL_LDLIBS    := -lstdc++ -llog -lGLESv2 -lz

LOCAL_SRC_FILES := \
    AndroidUtils.cpp \
    RunnerWrapper.cpp

LOCAL_SRC_FILES += \
    gl-gui/GLRenderSupport.cpp \
    gl-gui/GLRenderer.cpp \
    gl-gui/GLUtils.cpp \
    gl-gui/GLClip.cpp \
    gl-gui/GLGraphics.cpp \
    gl-gui/GLPictureClip.cpp \
    gl-gui/GLVideoClip.cpp \
    gl-gui/GLTextClip.cpp \
    gl-gui/GLWebClip.cpp \
    gl-gui/GLCamera.cpp \
    gl-gui/GLFont.cpp \
    gl-gui/GLFilter.cpp \
    gl-gui/GLSchedule.cpp \
    gl-gui/ImageLoader.cpp \
    utils/AbstractHttpSupport.cpp \
    utils/AbstractSoundSupport.cpp \
    utils/AbstractNotificationsSupport.cpp \
    utils/AbstractLocalyticsSupport.cpp \
    utils/AbstractInAppPurchase.cpp \
    utils/AbstractGeolocationSupport.cpp \
    utils/flowfilestruct.cpp \
    utils/FileLocalStore.cpp \
    utils/FileSystemInterface.cpp \
    utils/PrintingSupport.cpp \
    utils/MediaStreamSupport.cpp \
    utils/WebRTCSupport.cpp \
    utils/MediaRecorderSupport.cpp \
    utils/AbstractWebSocketSupport.cpp \
    utils/md5.cpp \
    utils/base64.cpp \
    font/TextFont.cpp

LOCAL_STATIC_LIBRARIES := librunnercore $(MY_PROF_LIB) $(MY_GEN_LIB)

LOCAL_CFLAGS += -DFLOW_DFIELD_FONTS

LOCAL_STATIC_LIBRARIES += libpng libjpeg libft2

include $(BUILD_SHARED_LIBRARY)

# Reference external library makefiles
MY_PATH := $(LOCAL_PATH)
BUILD_HOST_STATIC_LIBRARY := $(CLEAR_VARS)

include $(MY_PATH)/libpng/Android.mk
include $(MY_PATH)/jpeg.mk
include $(MY_PATH)/freetype/Android.mk
