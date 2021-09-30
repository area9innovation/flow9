QT += core
QMAKE_TARGET_BUNDLE_PREFIX = dk.area9

CONFIG(no_gui) {
} else {
    CONFIG += use_gui
}

# Uncomment to enable Flow Cpp native build (without bytecode)
#CONFIG += native_build

win32:contains(QMAKE_TARGET.arch, x86_64) {
    CONFIG += use_jit
}

unix:contains(QMAKE_HOST.arch,x86_64) {
    CONFIG += use_jit
}

DEFINES += FLOW_COMPACT_STRUCTS

#  Exclude some deprecated classes from Qt4
DEFINES += QT_NO_BEARERMANAGEMENT

CONFIG(use_gui) {
    QT += gui opengl multimedia multimediawidgets

    CONFIG += c++11 dfield_fonts

    QT += opengl
    QT += widgets gui
    QT += webenginewidgets webchannel

    #QMAKE_CXXFLAGS_DEBUG   += -std=c++11
    #QMAKE_CXXFLAGS_RELEASE += -std=c++11

    macx {
        # -O2 is too crashy on Mac; see #34057 - ST 12/17/14, 3/30/15
        INCLUDEPATH += /usr/local/include
        QMAKE_CFLAGS_RELEASE -= -O2
        QMAKE_CXXFLAGS_RELEASE -= -O2
        LIBS += -framework GLUT
        LIBS += -L$$PWD/libs
    }

    win32 {
        INCLUDEPATH += win32-libs/include

        contains(QMAKE_TARGET.arch, x86_64) {
            LIBS += -L$$PWD/win32-libs/lib64
        } else {
            LIBS += -L$$PWD/win32-libs/lib
        }

        LIBS += -lglew32 -lopengl32 -lglu32
    }

    unix:!macx {
        LIBS += -lGLU
    }

    CONFIG(dfield_fonts) {
        DEFINES += FLOW_DFIELD_FONTS
        LIBS += -lz
    } else {
        INCLUDEPATH += /usr/include/freetype2
        INCLUDEPATH += /usr/local/include/freetype2
        LIBS += -lfreetype
    }

    LIBS += -ljpeg -lpng
} else {
    QT -= gui opengl
}

QT += sql
QT += network
QT += websockets

TARGET = %TARGET
TEMPLATE = app

PRECOMPILED_HEADER = %FLOWDIR/platforms/qt/pcheader.h

INCLUDEPATH += \
    %FLOWDIR/platforms/common/cpp \
    %FLOWDIR/platforms/common/cpp/include \
    %FLOWDIR/platforms/qt \
    %FLOWDIR/platforms/qt/qt-gui \
    %FLOWDIR/platforms/qt/qt-backend \
    %FLOWDIR/platforms/common/cpp/asmjit/src

CONFIG += console

#QMAKE_CXXFLAGS_DEBUG += -fpermissive
#QMAKE_CXXFLAGS_RELEASE += -fpermissive

#QMAKE_CXXFLAGS_DEBUG += -pg
#QMAKE_LFLAGS_DEBUG += -pg

isEmpty(TARGET_EXT) {
    win32 {
        TARGET_CUSTOM_EXT = .exe
    }
    macx {
        TARGET_CUSTOM_EXT = .app
    }
} else {
    TARGET_CUSTOM_EXT = $${TARGET_EXT}
}

CONFIG(debug, debug|release) {
    DEFINES += DEBUG_FLOW
    DEPLOY_DIR = $$shell_quote($$shell_path($${OUT_PWD}/debug))
    DEPLOY_TARGET = $$shell_quote($$shell_path($${OUT_PWD}/debug/$${TARGET}$${TARGET_CUSTOM_EXT}))
} else {
    DEFINES += NDEBUG
    DEPLOY_DIR = $$shell_quote($$shell_path($${OUT_PWD}/release))
    DEPLOY_TARGET = $$shell_quote($$shell_path($${OUT_PWD}/release/$${TARGET}$${TARGET_CUSTOM_EXT}))
}

win32 {
    QMAKE_POST_LINK = windeployqt $${DEPLOY_TARGET}

    contains(QMAKE_TARGET.arch, x86_64) {
        QMAKE_POST_LINK += & copy $$shell_quote($$shell_path($${PWD}/win32-libs/bin64/*)) $${DEPLOY_DIR}
    } else {
        QMAKE_POST_LINK += & copy $$shell_quote($$shell_path($${PWD}/win32-libs/bin/*)) $${DEPLOY_DIR}
    }
}

macx {
    QMAKE_POST_LINK = macdeployqt $$shell_quote($$shell_path($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}))
}

# Core

SOURCES += \
    %FLOWDIR/platforms/common/cpp/core/ByteCodeRunner.cpp \
    %FLOWDIR/platforms/common/cpp/core/ByteMemory.cpp \
    %FLOWDIR/platforms/common/cpp/core/CodeMemory.cpp \
    %FLOWDIR/platforms/common/cpp/core/MemoryArea.cpp \
    %FLOWDIR/platforms/common/cpp/core/GarbageCollector.cpp \
    %FLOWDIR/platforms/common/cpp/core/HeapWalker.cpp \
    %FLOWDIR/platforms/common/cpp/core/Natives.cpp \
    %FLOWDIR/platforms/common/cpp/core/Utf8.cpp \
    %FLOWDIR/platforms/common/cpp/core/Utf32.cpp \
    %FLOWDIR/platforms/common/cpp/utils/md5.cpp \
    %FLOWDIR/platforms/common/cpp/utils/base64.cpp \
    %FLOWDIR/platforms/common/cpp/utils/AbstractHttpSupport.cpp \
    %FLOWDIR/platforms/common/cpp/utils/AbstractSoundSupport.cpp \
    %FLOWDIR/platforms/common/cpp/utils/FileLocalStore.cpp \
    %FLOWDIR/platforms/common/cpp/utils/FileSystemInterface.cpp \
    %FLOWDIR/platforms/common/cpp/utils/AbstractNotificationsSupport.cpp \
    %FLOWDIR/platforms/common/cpp/utils/AbstractGeolocationSupport.cpp \
    %FLOWDIR/platforms/common/cpp/utils/flowfilestruct.cpp \
    %FLOWDIR/platforms/common/cpp/utils/AbstractWebSocketSupport.cpp \
    %FLOWDIR/platforms/qt/qt-backend/NotificationsSupport.cpp \
    %FLOWDIR/platforms/qt/qt-backend/QtGeolocationSupport.cpp \
    %FLOWDIR/platforms/qt/qt-backend/qfilesysteminterface.cpp \
    %FLOWDIR/platforms/qt/qt-backend/RunParallel.cpp \
    %FLOWDIR/platforms/qt/qt-backend/QWebSocketSupport.cpp \
	%FLOWDIR/platforms/qt/qt-backend/QtNatives.cpp

CONFIG(use_gui) {
    SOURCES += \
        %FLOWDIR/platforms/qt/qt-gui/VideoWidget.cpp \
        %FLOWDIR/platforms/qt/qt-gui/mainwindow.cpp
}

HEADERS += \
    %FLOWDIR/platforms/qt/pcheader.h \
    %FLOWDIR/platforms/common/cpp/core/ByteCodeRunner.h \
    %FLOWDIR/platforms/common/cpp/core/CommonTypes.h \
    %FLOWDIR/platforms/common/cpp/core/nativefunction.h \
    %FLOWDIR/platforms/common/cpp/core/ByteMemory.h \
    %FLOWDIR/platforms/common/cpp/core/CodeMemory.h \
    %FLOWDIR/platforms/common/cpp/core/MemoryArea.h \
    %FLOWDIR/platforms/common/cpp/core/GarbageCollector.h \
    %FLOWDIR/platforms/common/cpp/core/HeapWalker.h \
    %FLOWDIR/platforms/common/cpp/core/opcodes.h \
    %FLOWDIR/platforms/common/cpp/core/RunnerMacros.h \
    %FLOWDIR/platforms/common/cpp/core/STLHelpers.h \
    %FLOWDIR/platforms/common/cpp/utils/md5.h \
    %FLOWDIR/platforms/common/cpp/utils/base64.h \
    %FLOWDIR/platforms/common/cpp/utils/AbstractHttpSupport.h \
    %FLOWDIR/platforms/common/cpp/utils/AbstractSoundSupport.h \
    %FLOWDIR/platforms/common/cpp/utils/FileLocalStore.h \
    %FLOWDIR/platforms/common/cpp/core/NativeProgram.h \
    %FLOWDIR/platforms/common/cpp/utils/FileSystemInterface.h \
    %FLOWDIR/platforms/common/cpp/utils/AbstractNotificationsSupport.h \
    %FLOWDIR/platforms/common/cpp/utils/AbstractGeolocationSupport.h \
    %FLOWDIR/platforms/common/cpp/utils/flowfilestruct.h \
    %FLOWDIR/platforms/common/cpp/utils/AbstractWebSocketSupport.h \
    %FLOWDIR/platforms/qt/qt-backend/NotificationsSupport.h \
    %FLOWDIR/platforms/qt/qt-backend/QtGeolocationSupport.h \
    %FLOWDIR/platforms/qt/qt-backend/qfilesysteminterface.h \
    %FLOWDIR/platforms/qt/qt-backend/RunParallel.h \
    %FLOWDIR/platforms/qt/qt-backend/QWebSocketSupport.h \
	%FLOWDIR/platforms/qt/qt-backend/QtNatives.h

CONFIG(use_gui) {
	HEADERS += \
    	%FLOWDIR/platforms/qt/qt-gui/VideoWidget.h \
    	%FLOWDIR/platforms/qt/qt-gui/testopengl.h \
    	%FLOWDIR/platforms/qt/qt-gui/mainwindow.h
}

# Asmjit

CONFIG(use_jit) {
        DEFINES += FLOW_JIT
        DEFINES += ASMJIT_STATIC
        DEFINES += ASMJIT_DISABLE_COMPILER

        SOURCES += %FLOWDIR/platforms/common/cpp/core/JitProgram.cpp
        HEADERS += %FLOWDIR/platforms/common/cpp/core/JitProgram.h

        SOURCES += \
            $$files(%FLOWDIR/platforms/common/cpp/asmjit/src/asmjit/base/*.cpp) \
            $$files(%FLOWDIR/platforms/common/cpp/asmjit/src/asmjit/x86/*.cpp)
        HEADERS += \
            $$files(%FLOWDIR/platforms/common/cpp/asmjit/src/asmjit/*.h) \
            $$files(%FLOWDIR/platforms/common/cpp/asmjit/src/asmjit/base/*.h) \
            $$files(%FLOWDIR/platforms/common/cpp/asmjit/src/asmjit/x86/*.h)
}

# Non-gui

SOURCES += \
    %FLOWDIR/platforms/qt/main.cpp\
    %FLOWDIR/platforms/qt/debugger.cpp \
    %FLOWDIR/platforms/qt/qt-backend/DatabaseSupport.cpp \
    %FLOWDIR/platforms/qt/qt-backend/HttpSupport.cpp \
    %FLOWDIR/platforms/qt/qt-backend/QtTimerSupport.cpp \
    %FLOWDIR/platforms/qt/qt-backend/CgiSupport.cpp \
    %FLOWDIR/platforms/qt/qt-backend/StartProcess.cpp

HEADERS  += \
    %FLOWDIR/platforms/qt/debugger.h \
    %FLOWDIR/platforms/qt/qt-backend/HttpSupport.h \
    %FLOWDIR/platforms/qt/qt-backend/DatabaseSupport.h \
    %FLOWDIR/platforms/qt/qt-backend/QtTimerSupport.h \
    %FLOWDIR/platforms/qt/qt-backend/CgiSupport.h \
    %FLOWDIR/platforms/qt/qt-backend/StartProcess.h

# Native program

CONFIG(native_build) {
    DEFINES += NATIVE_BUILD

    SOURCES += $$files(./*.cpp)
    HEADERS += $$files(./*.h)
} else {
    SOURCES += %FLOWDIR/platforms/qt/native_program_stub.cpp
}

# Gui

CONFIG(use_gui) {
    SOURCES += \
        %FLOWDIR/platforms/qt/swfloader.cpp \
        %FLOWDIR/platforms/qt/qt-gui/beveleffect.cpp \
        %FLOWDIR/platforms/qt/qt-gui/QGraphicsItemWrapper.cpp \
        %FLOWDIR/platforms/qt/qt-gui/soundsupport.cpp \
        %FLOWDIR/platforms/qt/qt-gui/QGLRenderSupport.cpp \
        %FLOWDIR/platforms/qt/qt-backend/QGLTextEdit.cpp \
        %FLOWDIR/platforms/qt/qt-backend/QGLLineEdit.cpp \
        %FLOWDIR/platforms/qt/qt-gui/QGLWebPage.cpp \
        %FLOWDIR/platforms/qt/qt-gui/QGLClipTreeModel.cpp \
        %FLOWDIR/platforms/qt/qt-gui/QGLClipTreeBrowser.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLRenderSupport.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLRenderer.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLUtils.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLClip.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLGraphics.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLPictureClip.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLVideoClip.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLTextClip.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLWebClip.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLFont.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLFilter.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLSchedule.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLCamera.cpp \
        %FLOWDIR/platforms/common/cpp/gl-gui/ImageLoader.cpp \
        %FLOWDIR/platforms/common/cpp/font/TextFont.cpp

    HEADERS  += \
        %FLOWDIR/platforms/qt/swfloader.h \
        %FLOWDIR/platforms/qt/qt-gui/beveleffect.h \
        %FLOWDIR/platforms/qt/qt-gui/GradientMatrix.h \
        %FLOWDIR/platforms/qt/qt-gui/soundsupport.h \
        %FLOWDIR/platforms/qt/qt-gui/QGLRenderSupport.h \
        %FLOWDIR/platforms/qt/qt-gui/QGraphicsItemWrapper.h \
        %FLOWDIR/platforms/qt/qt-backend/QGLTextEdit.h \
        %FLOWDIR/platforms/qt/qt-backend/QGLLineEdit.h \
        %FLOWDIR/platforms/qt/qt-gui/QGLWebPage.h  \
        %FLOWDIR/platforms/qt/qt-gui/QGLClipTreeModel.h \
        %FLOWDIR/platforms/qt/qt-gui/QGLClipTreeBrowser.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLRenderSupport.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/shaders/code.inc \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLRenderer.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLUtils.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLClip.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLGraphics.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLPictureClip.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLVideoClip.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLTextClip.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLWebClip.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLFont.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLFilter.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLSchedule.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/GLCamera.h \
        %FLOWDIR/platforms/common/cpp/gl-gui/ImageLoader.h \
        %FLOWDIR/platforms/common/cpp/font/Headers.h \
        %FLOWDIR/platforms/common/cpp/font/TextFont.h

    RESOURCES += \
        %FLOWDIR/platforms/qt/QtByteRunnerRes.qrc

#    CONFIG(debug, debug|release) {
#        HEADERS += \
#            %FLOWDIR/platforms/qt/qt-gui/FlowClipTreeModel.h
#        SOURCES += \
#            %FLOWDIR/platforms/qt/qt-gui/FlowClipTreeModel.cpp
#    }
}

OTHER_FILES += \
    %FLOWDIR/platforms/qt/%TARGET.pro \
    %FLOWDIR/platforms/qt/readme.md

# MediaRecorder
if(false) { # true to put MediaRecorder on
    DEFINES += FLOW_MEDIARECORDER

    SOURCES+= \
        %FLOWDIR/platforms/common/cpp/utils/MediaRecorderSupport.cpp \
        %FLOWDIR/platforms/common/cpp/utils/MediaStreamSupport.cpp \
        %FLOWDIR/platforms/common/cpp/utils/WebRTCSupport.cpp \
        %FLOWDIR/platforms/qt/qt-backend/QMediaRecorderSupport.cpp \
        %FLOWDIR/platforms/qt/qt-backend/QMediaStreamSupport.cpp


    HEADERS += \
        %FLOWDIR/platforms/common/cpp/utils/MediaRecorderSupport.h \
        %FLOWDIR/platforms/common/cpp/utils/MediaStreamSupport.h \
        %FLOWDIR/platforms/common/cpp/utils/WebRTCSupport.h \
        %FLOWDIR/platforms/qt/qt-backend/QMediaRecorderSupport.h \
        %FLOWDIR/platforms/qt/qt-backend/QMediaStreamSupport.h

    macx {
        SOURCES += %FLOWDIR/platforms/qt/qt-backend/macos/VideoDevicesControl.mm
        HEADERS += %FLOWDIR/platforms/qt/qt-backend/macos/VideoDevicesControl.h

        FRAMEWORKS_FOLDER = /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks
        INCLUDEPATH += $${FRAMEWORKS_FOLDER}/AVFoundation.framework/Headers \
                    $${FRAMEWORKS_FOLDER}/CoreMedia.framework/Headers
        LIBS += -F$${FRAMEWORKS_FOLDER} \
                -framework AVFoundation \
                -framework CoreMedia \
                -framework Cocoa

        INCLUDEPATH += /Library/Frameworks/GStreamer.framework/Headers
        LIBS += -F/Library/Frameworks -framework GStreamer
        exists($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}/Contents/Frameworks/GStreamer.framework) {}
        else {
            exists($$shell_quote($$shell_path($${PWD}/GeneratedFiles/GStreamer.framework))) {}
            else {
                QMAKE_POST_LINK += & sh $$shell_quote($$shell_path($${PWD}/mediarecorder.sh))
            }
            QMAKE_POST_LINK += & mkdir -p $$shell_quote($$shell_path($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}/Contents/Frameworks/GStreamer.framework))
            QMAKE_POST_LINK += & cp -a $$shell_quote($$shell_path($${PWD}/GeneratedFiles/GStreamer.framework)) \
                                $$shell_quote($$shell_path($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}/Contents/Frameworks))

        }
        QMAKE_POST_LINK += & install_name_tool -change \
                       /Library/Frameworks/GStreamer.framework/Versions/1.0/lib/GStreamer \
                        @executable_path/../Frameworks/GStreamer.framework/Versions/1.0/lib/GStreamer \
                        $${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}/Contents/MacOS/$${TARGET}
    }

    win32 {
        contains(QMAKE_TARGET.arch, x86_64) {
            GstreamerDir=$$(GSTREAMER_1_0_ROOT_X86_64)
        } else {
            GstreamerDir=$$(GSTREAMER_1_0_ROOT_X86)
        }

        INCLUDEPATH += $${GstreamerDir}include/gstreamer-1.0
        INCLUDEPATH += $${GstreamerDir}include/glib-2.0
        INCLUDEPATH += $${GstreamerDir}lib/glib-2.0/include
        INCLUDEPATH += $${GstreamerDir}lib/gstreamer-1.0/include

        LIBS += -L$${GstreamerDir}lib/ -lgstreamer-1.0 -lgstapp-1.0 -lgstbase-1.0 -lgstvideo-1.0 -lgobject-2.0 -lglib-2.0

        PLUGINS_DIR = $${DEPLOY_DIR}/gst-plugins
        exists(PLUGINS_DIR) {}
        else {
            QMAKE_POST_LINK += & mkdir $$shell_quote($$shell_path($${PLUGINS_DIR}))
        }

        GST_PLUGINS = app \
            audioconvert \
            coreelements \
            directsoundsrc \
            isomp4 \
            openh264 \
            videoconvert \
            videoparsersbad \
            voaacenc \
            winks
        for(plugin, GST_PLUGINS) {
            QMAKE_POST_LINK += & copy $$shell_quote($$shell_path($${GstreamerDir}/lib/gstreamer-1.0/libgst$${plugin}.dll)) $$shell_quote($$shell_path($${PLUGINS_DIR}))
        }

        GST_LIBS = libgstreamer-1.0-0.dll \
            libgstapp-1.0-0.dll \
            libgstbase-1.0-0.dll \
            libwinpthread-1.dll \
            libintl-8.dll \
            libgmodule-2.0-0.dll \
            libgobject-2.0-0.dll \
            libffi-7.dll \
            libglib-2.0-0.dll
        for(filename, GST_LIBS) {
            QMAKE_POST_LINK += & copy $$shell_quote($$shell_path($${GstreamerDir}lib/$${filename})) $$shell_quote($$shell_path($${DEPLOY_DIR}))
        }
    }
}
