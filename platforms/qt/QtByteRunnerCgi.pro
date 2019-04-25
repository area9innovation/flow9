#-------------------------------------------------
#
# Project created by QtCreator 2011-03-17T17:24:20
#
#-------------------------------------------------

QT       += core sql network

QT       -= gui

TARGET = QtByteRunner.fcgi
CONFIG   += console
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

INCLUDEPATH += core qt-backend asmjit/src

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
    core/ByteCodeRunner.cpp \
    core/ByteMemory.cpp \
    core/CodeMemory.cpp \
    core/MemoryArea.cpp \
    core/GarbageCollector.cpp \
    core/Natives.cpp \
    core/Utf8.cpp \
    core/Utf32.cpp \
    core/md5.cpp \
    utils/AbstractHttpSupport.cpp \
    utils/AbstractSoundSupport.cpp \
    utils/FileLocalStore.cpp \
    utils/FileSystemInterface.cpp \
    utils/flowfilestruct.cpp

HEADERS  += \
    core/ByteCodeRunner.h \
    core/CommonTypes.h \
    core/nativefunction.h \
    core/ByteMemory.h \
    core/CodeMemory.h \
    core/MemoryArea.h \
    core/GarbageCollector.h \
    core/opcodes.h \
    core/RunnerMacros.h \
    core/STLHelpers.h \
    core/md5.h \
    pcheader.h \
    utils/AbstractHttpSupport.h \
    utils/AbstractSoundSupport.h \
    utils/FileLocalStore.h \
    utils/FileSystemInterface.h \
    utils/flowfilestruct.h

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
