#ifndef QMEDIARECORDERSUPPORT_H
#define QMEDIARECORDERSUPPORT_H

#include <QObject>
#include <QImage>
#include <QAbstractVideoSurface>
#include <QtWebSockets/QtWebSockets>
#include <QTimer>

#include <gst/gst.h>
#include <gst/video/video.h>
#include <gst/app/gstappsink.h>

#include "core/ByteCodeRunner.h"
#include "utils/MediaRecorderSupport.h"
#include "qt-backend/QMediaStreamSupport.h"

class VideoSender : public QObject
{
    Q_OBJECT
private:
    QByteArray buffer;
    QMutex bufferMutex;
    QWebSocket webSocket;
    QTimer *timer;
    int timeslice;
    int onErrorRoot;

    ByteCodeRunner *owner;
public:
    VideoSender(ByteCodeRunner *owner, QString url, int timeslice, int onErrorRoot);
    void addData(char *data, int size);
    void stop();

private Q_SLOTS:
    void onSocketConnected();
    void onSocketError(QAbstractSocket::SocketError error);
    void sendStoredData();
};

class QMediaRecorderSupport : public MediaRecorderSupport
{
    ByteCodeRunner* owner;

public:


    class FlowNativeMediaRecorder : public FlowNativeObject
    {
    public:

        FlowNativeMediaRecorder(QMediaRecorderSupport* owner);

        QMediaStreamSupport::FlowNativeMediaStream *mediaStream;

        GstElement *recorderBin;
        GstElement *audioValve;
        GstElement *videoValve;
        GstElement *muxer;

        VideoSender *sender;

        GstElement *audio_stream_receiver;
        GstElement *video_steram_receiver;

        void setDrop(bool drop);

        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaRecorder, FlowNativeObject)
    };

    QMediaRecorderSupport(ByteCodeRunner *Runner, QString dirPath);

private:
    void makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice,
                            int onReadyRoot, int onErrorRoot);

    void startMediaRecorder(StackSlot recorder, int timeslice);
    void resumeMediaRecorder(StackSlot recorder);
    void pauseMediaRecorder(StackSlot recorder);
    void stopMediaRecorder(StackSlot recorder);

    void addMediaStreamMuxer(FlowNativeMediaRecorder *flowRecorder);
    void addAudioStreamReceiver(FlowNativeMediaRecorder *flowRecorder);
    void addVideoStreamReceiver(FlowNativeMediaRecorder *flowRecorder);

    void addFilesink(FlowNativeMediaRecorder *flowRecorder, unicode_string filePath);
    void addWebsocketSender(FlowNativeMediaRecorder *flowRecorder);

protected:
    static GstFlowReturn newVideoSampleFromSink(GstAppSink *sink, gpointer data);
};

#endif // QMEDIARECORDERSUPPORT_H
