#-------------------------------------------------
#
# Project created by QtCreator 2011-01-14T12:35:23
#
#-------------------------------------------------

DEFINES += FLOW_COMPACT_STRUCTS

QT += core sql network
QT -= gui opengl

TARGET = QtNativeCgi
TEMPLATE = app

PRECOMPILED_HEADER = pcheader.h

INCLUDEPATH += include core qt-backend

CONFIG          += console

QMAKE_CXXFLAGS_DEBUG += -Wno-deprecated
QMAKE_CXXFLAGS_RELEASE += -Wno-deprecated

#QMAKE_CXXFLAGS_DEBUG += -pg
#QMAKE_LFLAGS_DEBUG += -pg

CONFIG(debug, debug|release) {
    DEFINES += DEBUG_FLOW
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
    utils/FileLocalStore.cpp

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
    core/NativeProgram.h

# Non-gui

SOURCES += cgimain-native.cpp\
    qt-backend/DatabaseSupport.cpp \
    qt-backend/HttpSupport.cpp \
    qt-backend/QtTimerSupport.cpp \
    qt-backend/CgiSupport.cpp

HEADERS  += \
    qt-backend/HttpSupport.h \
    qt-backend/DatabaseSupport.h \
    qt-backend/QtTimerSupport.h \
    qt-backend/CgiSupport.h

# Native program

SOURCES += $$files(flowcpp/*.cpp)
HEADERS += $$files(flowcpp/*.h)
