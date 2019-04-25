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

INCLUDEPATH += ../cpp ../cpp/include qt-gui qt-backend asmjit/src

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
        QMAKE_POST_LINK += & copy $$shell_quote($$shell_path($${PWD}/win32-libs/bin64/*)) $${DEPLOY_DIR};
    } else {
        QMAKE_POST_LINK += & copy $$shell_quote($$shell_path($${PWD}/win32-libs/bin/*)) $${DEPLOY_DIR};
    }
}

macx {
    QMAKE_POST_LINK = macdeployqt $$shell_quote($$shell_path($${OUT_PWD}/$${TARGET}$${TARGET_CUSTOM_EXT}))
}

# Core

SOURCES += \
    ../cpp/core/ByteCodeRunner.cpp \
    ../cpp/core/ByteMemory.cpp \
    ../cpp/core/CodeMemory.cpp \
    ../cpp/core/MemoryArea.cpp \
    ../cpp/core/GarbageCollector.cpp \
    ../cpp/core/HeapWalker.cpp \
    ../cpp/core/Natives.cpp \
    ../cpp/core/Utf8.cpp \
    ../cpp/core/Utf32.cpp \
    ../cpp/core/md5.cpp \
    ../cpp/utils/AbstractHttpSupport.cpp \
    ../cpp/utils/AbstractSoundSupport.cpp \
    ../cpp/utils/FileLocalStore.cpp \
    ../cpp/utils/FileSystemInterface.cpp \
    ../cpp/utils/AbstractNotificationsSupport.cpp \
    ../cpp/utils/AbstractGeolocationSupport.cpp \
    ../cpp/utils/flowfilestruct.cpp \
    ../cpp/utils/AbstractWebSocketSupport.cpp \
    qt-backend/NotificationsSupport.cpp \
    qt-backend/QtGeolocationSupport.cpp \
    qt-backend/qfilesysteminterface.cpp \
    qt-backend/RunParallel.cpp \
    qt-backend/QWebSocketSupport.cpp \
    qt-gui/VideoWidget.cpp \
    qt-gui/mainwindow.cpp

HEADERS  += \
    pcheader.h \
    ../cpp/core/ByteCodeRunner.h \
    ../cpp/core/CommonTypes.h \
    ../cpp/core/nativefunction.h \
    ../cpp/core/ByteMemory.h \
    ../cpp/core/CodeMemory.h \
    ../cpp/core/MemoryArea.h \
    ../cpp/core/GarbageCollector.h \
    ../cpp/core/HeapWalker.h \
    ../cpp/core/opcodes.h \
    ../cpp/core/RunnerMacros.h \
    ../cpp/core/STLHelpers.h \
    ../cpp/core/md5.h \
    ../cpp/utils/AbstractHttpSupport.h \
    ../cpp/utils/AbstractSoundSupport.h \
    ../cpp/utils/FileLocalStore.h \
    ../cpp/core/NativeProgram.h \
    ../cpp/utils/FileSystemInterface.h \
    ../cpp/utils/AbstractNotificationsSupport.h \
    ../cpp/utils/AbstractGeolocationSupport.h \
    ../cpp/utils/flowfilestruct.h \
    ../cpp/utils/AbstractWebSocketSupport.h \
    qt-backend/NotificationsSupport.h \
    qt-backend/QtGeolocationSupport.h \
    qt-backend/qfilesysteminterface.h \
    qt-backend/RunParallel.h \
    qt-backend/QWebSocketSupport.h \
    qt-gui/VideoWidget.h \
    qt-gui/testopengl.h \
    qt-gui/mainwindow.h

# Asmjit

CONFIG(use_jit) {
	DEFINES += FLOW_JIT
	DEFINES += ASMJIT_STATIC
	DEFINES += ASMJIT_DISABLE_COMPILER

        SOURCES += ../cpp/core/JitProgram.cpp
        HEADERS += ../cpp/core/JitProgram.h

        SOURCES += $$files(../cpp/asmjit/src/asmjit/base/*.cpp) $$files(../cpp/asmjit/src/asmjit/x86/*.cpp)
        HEADERS += $$files(../cpp/asmjit/src/asmjit/*.h) $$files(../cpp/asmjit/src/asmjit/base/*.h) $$files(../cpp/asmjit/src/asmjit/x86/*.h)
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
        qt-gui/QGLRenderSupport.cpp \
        qt-backend/QGLTextEdit.cpp \
        qt-backend/QGLLineEdit.cpp \
        qt-gui/QGLWebPage.cpp \
        qt-gui/QGLClipTreeModel.cpp \
        qt-gui/QGLClipTreeBrowser.cpp \
        ../cpp/gl-gui/GLRenderSupport.cpp \
        ../cpp/gl-gui/GLRenderer.cpp \
        ../cpp/gl-gui/GLUtils.cpp \
        ../cpp/gl-gui/GLClip.cpp \
        ../cpp/gl-gui/GLGraphics.cpp \
        ../cpp/gl-gui/GLPictureClip.cpp \
        ../cpp/gl-gui/GLVideoClip.cpp \
        ../cpp/gl-gui/GLTextClip.cpp \
        ../cpp/gl-gui/GLWebClip.cpp \
        ../cpp/gl-gui/GLFont.cpp \
        ../cpp/gl-gui/GLFilter.cpp \
        ../cpp/gl-gui/GLSchedule.cpp \
        ../cpp/gl-gui/GLCamera.cpp \
        ../cpp/gl-gui/ImageLoader.cpp

    HEADERS  += \
        swfloader.h \
        qt-gui/beveleffect.h \
        qt-gui/GradientMatrix.h \
        qt-gui/soundsupport.h \
        qt-gui/QGLRenderSupport.h \
        qt-gui/QGraphicsItemWrapper.h \
        qt-backend/QGLTextEdit.h \
        qt-backend/QGLLineEdit.h \
        qt-gui/QGLWebPage.h  \
        qt-gui/QGLClipTreeModel.h \
        qt-gui/QGLClipTreeBrowser.h \
        ../cpp/gl-gui/GLRenderSupport.h \
        ../cpp/gl-gui/shaders/code.inc \
        ../cpp/gl-gui/GLRenderer.h \
        ../cpp/gl-gui/GLUtils.h \
        ../cpp/gl-gui/GLClip.h \
        ../cpp/gl-gui/GLGraphics.h \
        ../cpp/gl-gui/GLPictureClip.h \
        ../cpp/gl-gui/GLVideoClip.h \
        ../cpp/gl-gui/GLTextClip.h \
        ../cpp/gl-gui/GLWebClip.h \
        ../cpp/gl-gui/GLFont.h \
        ../cpp/gl-gui/GLFilter.h \
        ../cpp/gl-gui/GLSchedule.h \
        ../cpp/gl-gui/GLCamera.h \
        ../cpp/gl-gui/ImageLoader.h \
        ../cpp/font/Headers.h

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
