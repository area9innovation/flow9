#-------------------------------------------------
#
# Project created by QtCreator 2011-01-14T12:35:23
#
#-------------------------------------------------

QT       += core
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

TARGET = QtByteRunner
TEMPLATE = app

PRECOMPILED_HEADER = pcheader.h

INCLUDEPATH += include core qt-gui qt-backend asmjit/src

CONFIG          += console

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
    core/ByteCodeRunner.cpp \
    core/ByteMemory.cpp \
    core/CodeMemory.cpp \
    core/GarbageCollector.cpp \
    core/HeapWalker.cpp \
    core/Natives.cpp \
    core/Utf8.cpp \
    core/Utf32.cpp \
    core/md5.cpp \
    utils/AbstractHttpSupport.cpp \
    utils/AbstractSoundSupport.cpp \
    utils/FileLocalStore.cpp \
    utils/FileSystemInterface.cpp \
    utils/AbstractNotificationsSupport.cpp \
    qt-backend/NotificationsSupport.cpp \
    utils/AbstractGeolocationSupport.cpp \
    qt-backend/QtGeolocationSupport.cpp \
    qt-gui/VideoWidget.cpp \
    core/MemoryArea.cpp \
    qt-backend/qfilesysteminterface.cpp \
    utils/flowfilestruct.cpp \
    qt-backend/RunParallel.cpp \
    utils/AbstractWebSocketSupport.cpp \
    qt-backend/QWebSocketSupport.cpp \
    qt-gui/mainwindow.cpp

HEADERS  += \
    core/ByteCodeRunner.h \
    core/CommonTypes.h \
    core/nativefunction.h \
    core/ByteMemory.h \
    core/CodeMemory.h \
    core/GarbageCollector.h \
    core/HeapWalker.h \
    core/opcodes.h \
    core/RunnerMacros.h \
    core/STLHelpers.h \
    core/md5.h \
    pcheader.h \
    utils/AbstractHttpSupport.h \
    utils/AbstractSoundSupport.h \
    utils/FileLocalStore.h \
    core/NativeProgram.h \
    utils/FileSystemInterface.h \
    utils/AbstractNotificationsSupport.h \
    qt-backend/NotificationsSupport.h \
    utils/AbstractGeolocationSupport.h \
    qt-backend/QtGeolocationSupport.h \
    qt-gui/VideoWidget.h \
    core/MemoryArea.h \
    qt-gui/testopengl.h \
    utils/flowfilestruct.h \
    qt-backend/qfilesysteminterface.h \
    qt-backend/RunParallel.h \
    utils/AbstractWebSocketSupport.h \
    qt-backend/QWebSocketSupport.h \
    qt-gui/mainwindow.h

# Asmjit

CONFIG(use_jit) {
	DEFINES += FLOW_JIT
	DEFINES += ASMJIT_STATIC
	DEFINES += ASMJIT_DISABLE_COMPILER

	SOURCES += core/JitProgram.cpp
	HEADERS += core/JitProgram.h

	SOURCES += $$files(asmjit/src/asmjit/base/*.cpp) $$files(asmjit/src/asmjit/x86/*.cpp)
	HEADERS += $$files(asmjit/src/asmjit/*.h) $$files(asmjit/src/asmjit/base/*.h) $$files(asmjit/src/asmjit/x86/*.h)
}

# Non-gui

SOURCES += main.cpp\
    debugger.cpp \
    qt-backend/DatabaseSupport.cpp \
    qt-backend/HttpSupport.cpp \
    qt-backend/QtTimerSupport.cpp \
    qt-backend/CgiSupport.cpp \
    qt-backend/StartProcess.cpp

HEADERS  += \
    debugger.h \
    qt-backend/HttpSupport.h \
    qt-backend/DatabaseSupport.h \
    qt-backend/QtTimerSupport.h \
    qt-backend/CgiSupport.h \
    qt-backend/StartProcess.h

# Native program

CONFIG(native_build) {
    DEFINES += NATIVE_BUILD

    SOURCES += $$files(flowgen/*.cpp)
    HEADERS += $$files(flowgen/*.h)
} else {
    SOURCES += native_program_stub.cpp
}

# Gui

CONFIG(use_gui) {
    SOURCES += \
        swfloader.cpp \
        qt-gui/beveleffect.cpp \
        qt-gui/QGraphicsItemWrapper.cpp \
        qt-gui/soundsupport.cpp \
        gl-gui/GLRenderSupport.cpp \
        qt-gui/QGLRenderSupport.cpp \
        gl-gui/GLRenderer.cpp \
        gl-gui/GLUtils.cpp \
        gl-gui/GLClip.cpp \
        gl-gui/GLGraphics.cpp \
        gl-gui/GLPictureClip.cpp \
        gl-gui/GLVideoClip.cpp \
        gl-gui/GLTextClip.cpp \
        gl-gui/GLWebClip.cpp \
        gl-gui/GLFont.cpp \
        gl-gui/GLFilter.cpp \
        gl-gui/GLSchedule.cpp \
        gl-gui/GLCamera.cpp \
        gl-gui/ImageLoader.cpp \
        qt-backend/QGLTextEdit.cpp \
        qt-backend/QGLLineEdit.cpp \
        qt-gui/QGLWebPage.cpp \
        qt-gui/QGLClipTreeModel.cpp \
        qt-gui/QGLClipTreeBrowser.cpp

    HEADERS  += \
        swfloader.h \
        qt-gui/beveleffect.h \
        qt-gui/GradientMatrix.h \
        qt-gui/soundsupport.h \
        qt-gui/QGraphicsItemWrapper.h \
        gl-gui/GLRenderSupport.h \
        qt-gui/QGLRenderSupport.h \
        gl-gui/shaders/code.inc \
        gl-gui/GLRenderer.h \
        gl-gui/GLUtils.h \
        gl-gui/GLClip.h \
        gl-gui/GLGraphics.h \
        gl-gui/GLPictureClip.h \
        gl-gui/GLVideoClip.h \
        gl-gui/GLTextClip.h \
        gl-gui/GLWebClip.h \
        gl-gui/GLFont.h \
        gl-gui/GLFilter.h \
        gl-gui/GLSchedule.h \
        gl-gui/GLCamera.h \
        gl-gui/ImageLoader.h \
        qt-backend/QGLTextEdit.h \
        qt-backend/QGLLineEdit.h \
        qt-gui/QGLWebPage.h  \
        qt-gui/QGLClipTreeModel.h \
        qt-gui/QGLClipTreeBrowser.h \
        font/Headers.h

    RESOURCES += \
        QtByteRunnerRes.qrc

#    CONFIG(debug, debug|release) {
#        HEADERS += \
#            qt-gui/FlowClipTreeModel.h
#        SOURCES += \
#            qt-gui/FlowClipTreeModel.cpp
#    }
}

OTHER_FILES += \
    QtByteRunner.pro.user \
    readme.txt

# MediaRecorder
if(true) { # true to put MediaRecorder on
    DEFINES += FLOW_MEDIARECORDER

    SOURCES+= utils/MediaRecorderSupport.cpp \
        qt-backend/QMediaRecorderSupport.cpp

    HEADERS += utils/MediaRecorderSupport.h \
        qt-backend/QMediaRecorderSupport.h

    macx {
        SOURCES += qt-backend/macos/VideoDevicesControl.mm
        HEADERS += qt-backend/macos/VideoDevicesControl.h

        INCLUDEPATH += /System/Library/Frameworks/AVFoundation.framework/Headers \
                    /System/Library/Frameworks/CoreMedia.framework/Headers
        LIBS += -F/System/Library/Frameworks \
                -framework AVFoundation \
                -framework CoreMedia \
                -framework Cocoa
        INCLUDEPATH += /Library/Frameworks/GStreamer.framework/Headers
        LIBS += -F/Library/Frameworks -framework GStreamer
        exists($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}/Contents/Frameworks/GStreamer.framework) {}
        else {
            QMAKE_POST_LINK += & $$shell_quote($$shell_path($${PWD}/mediarecorder.sh))
            QMAKE_POST_LINK += & mkdir -p $$shell_quote($$shell_path($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}/Contents/Frameworks/GStreamer.framework))
            QMAKE_POST_LINK += & cp -a $$shell_quote($$shell_path($${PWD}/GeneratedFiles/GStreamer.framework/)) \
                                $$shell_quote($$shell_path($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}/Contents/Frameworks/GStreamer.framework/))

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
