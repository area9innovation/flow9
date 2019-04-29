QT       += core gui opengl 

TARGET = FlowFontConvertor
TEMPLATE = app

PRECOMPILED_HEADER = pcheader.h

macx {
    INCLUDEPATH += /usr/X11/include
    LIBS += -L/opt/local/lib
}

win32 {
    INCLUDEPATH += win32-libs/include
    LIBS += -L$$PWD/win32-libs/lib -lglew32
}


INCLUDEPATH += /usr/include/freetype2
LIBS += -lfreetype -lz

INCLUDEPATH += include core qt-gui qt-backend

CONFIG          += console

QMAKE_CXXFLAGS_DEBUG += -Wno-deprecated
QMAKE_CXXFLAGS_RELEASE += -Wno-deprecated

CONFIG(debug, debug|release) {
    DEFINES += DEBUG_FLOW
}

# Core

SOURCES += \
    font/BezierUtils.cpp \
    font/ConvertorMain.cpp \
    core/Utf8.cpp \
    core/Utf32.cpp \

HEADERS  += \
    pcheader.h \
    font/BezierUtils.h \
    gl-gui/GLFont.h \
    core/STLHelpers.h \
    font/Headers.h
