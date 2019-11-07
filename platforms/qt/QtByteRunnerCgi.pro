#-------------------------------------------------
#
# Project created by QtCreator 2011-03-17T17:24:20
#
#-------------------------------------------------

QT       += core sql network

QT       -= gui

TARGET = QtByteRunner.fcgi
CONFIG   += console c++11
CONFIG   -= app_bundle

unix {
    QMAKE_CXXFLAGS_DEBUG += -Wno-deprecated
    QMAKE_CXXFLAGS_RELEASE += -Wno-deprecated
}

win32:contains(QMAKE_TARGET.arch, x86_64) {
    CONFIG += use_jit
}

unix:contains(QMAKE_HOST.arch,x86_64) {
    CONFIG += use_jit
}

# Disable jit for cgi because currently loading and initializing jit
# takes longer than running bytecode through cgi.
CONFIG -= use_jit

INCLUDEPATH += ../common/cpp qt-backend asmjit/src

INCLUDEPATH += $$PWD/include/fcgi

LIBS += -lfcgi

unix:!macx {
  QMAKE_RPATHDIR += lib
}

win32 {
    debug {
        LIBS += -L$$PWD/win32-libs/lib/debug
    } else {
        LIBS += -L$$PWD/win32-libs/lib/release
    }
    LIBS += -L$$PWD/win32-libs/lib
}

CONFIG(debug, debug|release) {
    DEFINES += DEBUG_FLOW
}

DEFINES += FASTCGI

TEMPLATE = app

SOURCES += \
    ../common/cpp/core/ByteCodeRunner.cpp \
    ../common/cpp/core/ByteMemory.cpp \
    ../common/cpp/core/CodeMemory.cpp \
    ../common/cpp/core/MemoryArea.cpp \
    ../common/cpp/core/GarbageCollector.cpp \
    ../common/cpp/core/Natives.cpp \
    ../common/cpp/core/Utf8.cpp \
    ../common/cpp/core/Utf32.cpp \
    ../common/cpp/utils/md5.cpp \
    ../common/cpp/utils/base64.cpp \
    ../common/cpp/utils/AbstractHttpSupport.cpp \
    ../common/cpp/utils/AbstractSoundSupport.cpp \
    ../common/cpp/utils/FileLocalStore.cpp \
    ../common/cpp/utils/FileSystemInterface.cpp \
    ../common/cpp/utils/flowfilestruct.cpp

HEADERS  += \
    pcheader.h \
    ../common/cpp/core/ByteCodeRunner.h \
    ../common/cpp/core/CommonTypes.h \
    ../common/cpp/core/nativefunction.h \
    ../common/cpp/core/ByteMemory.h \
    ../common/cpp/core/CodeMemory.h \
    ../common/cpp/core/MemoryArea.h \
    ../common/cpp/core/GarbageCollector.h \
    ../common/cpp/core/opcodes.h \
    ../common/cpp/core/RunnerMacros.h \
    ../common/cpp/core/STLHelpers.h \
    ../common/cpp/utils/md5.h \
    ../common/cpp/utils/base64.h \
    ../common/cpp/utils/AbstractHttpSupport.h \
    ../common/cpp/utils/AbstractSoundSupport.h \
    ../common/cpp/utils/FileLocalStore.h \
    ../common/cpp/utils/FileSystemInterface.h \
    ../common/cpp/utils/flowfilestruct.h

# Asmjit

CONFIG(use_jit) {
    DEFINES += FLOW_JIT
    DEFINES += ASMJIT_STATIC
    DEFINES += ASMJIT_DISABLE_COMPILER

    SOURCES += ../common/cpp/core/JitProgram.cpp
    HEADERS += ../common/cpp/core/JitProgram.h

    SOURCES += $$files(../common/cpp/asmjit/src/asmjit/base/*.cpp) $$files(../common/cpp/asmjit/src/asmjit/x86/*.cpp)
    HEADERS += $$files(../common/cpp/asmjit/src/asmjit/*.h) $$files(../common/cpp/asmjit/src/asmjit/base/*.h) $$files(../common/cpp/asmjit/src/asmjit/x86/*.h)
}


SOURCES += cgimain.cpp \
    qt-backend/DatabaseSupport.cpp \
    qt-backend/HttpSupport.cpp \
    qt-backend/QtTimerSupport.cpp \
    qt-backend/CgiSupport.cpp

HEADERS  += \
    qt-backend/DatabaseSupport.h \
    qt-backend/HttpSupport.h \
    qt-backend/QtTimerSupport.h \
    qt-backend/CgiSupport.h
