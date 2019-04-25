#-------------------------------------------------
#
# Project created by QtCreator 2011-01-14T12:35:23
#
#-------------------------------------------------

QT       += core gui

CONFIG(android) {
    DEFINES += FLOW_ANDROID
} else {
    QT += opengl
    QT += phonon
}

QT += sql
QT += network

TARGET = QtByteRunner
TEMPLATE = app

CONFIG          += console

#QMAKE_CXXFLAGS_DEBUG += -pg
#QMAKE_LFLAGS_DEBUG += -pg

CONFIG(debug, debug|release) {
    DEFINES += DEBUG_FLOW
}

SOURCES += main.cpp\
    Natives.cpp \
    GarbageCollector.cpp \
    CodeMemory.cpp \
    ByteMemory.cpp \
    ByteCodeRunner.cpp \
    Array.cpp \
    md5.cpp \
    RenderSupport.cpp \
    QGraphicsItemWrapper.cpp \
    flowclip.cpp \
    FlowClipScene.cpp \
    swfloader.cpp \
    beveleffect.cpp \
    flowvideostream.cpp \
    soundsupport.cpp \
    flowsound.cpp \
    debugger.cpp \
    DatabaseSupport.cpp \
    HttpSupport.cpp

HEADERS  += \
    opcodes.h \
    HashTable.h \
    GarbageCollector.h \
    CommonTypes.h \
    CodeMemory.h \
    ByteMemory.h \
    ByteCodeRunner.h \
    Array.h \
    md5.h \
    QGraphicsItemWrapper.h \
    flowclip.h \
    GradientMatrix.h \
    nativefunction.h \
    RunnerMacros.h \
    RenderSupport.h \
    FlowClipScene.h \
    swfloader.h \
    beveleffect.h \
    flowvideostream.h \
    soundsupport.h \
    flowsound.h \
    debugger.h \
    DatabaseSupport.h \
    HttpSupport.h

CONFIG(debug, debug|release) {
    HEADERS += \
        FlowClipTreeModel.h
    SOURCES += \
        FlowClipTreeModel.cpp
}

OTHER_FILES += \
    QtByteRunner.pro.user

CONFIG(android) {
    OTHER_FILES += \
        android/res/drawable-hdpi/icon.png \
        android/res/values/strings.xml \
        android/res/values/libs.xml \
        android/res/drawable-mdpi/icon.png \
        android/res/drawable-ldpi/icon.png \
        android/AndroidManifest.xml \
        android/src/eu/licentia/necessitas/ministro/IMinistro.aidl \
        android/src/eu/licentia/necessitas/ministro/IMinistroCallback.aidl \
        android/src/eu/licentia/necessitas/industrius/QtApplication.java \
        android/src/eu/licentia/necessitas/industrius/QtSurface.java \
        android/src/eu/licentia/necessitas/industrius/QtActivity.java
}

RESOURCES += \
    driver.qrc
