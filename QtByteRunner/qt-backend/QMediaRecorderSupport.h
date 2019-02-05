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

class CameraInfo
{
public:
    int max_width;
    int max_height;
    QString id;
    QString name;
    CameraInfo(QString id, QString name, int width=0, int height=0);
};

class MediaStreamSender : public QObject
{
    Q_OBJECT
private:
    QByteArray buffer;
    QMutex bufferMutex;
    QWebSocket webSocket;
    QTimer *timer;
    int timeslice;
    int cbOnWebsocketErrorId;

    ByteCodeRunner *owner;
public:
    MediaStreamSender(ByteCodeRunner *owner, QString url, int timeslice, int cbOnWebsocketErrorId);
    void addData(char *data, int size);
    void addSocketErrorCallback();
    void stop();

private Q_SLOTS:
    void onSocketConnected();
    void onSocketError(QAbstractSocket::SocketError error);
    void sendStoredData();
};

class QMediaRecorderSupport : public MediaRecorderSupport
{

    ByteCodeRunner* owner;

    QList<CameraInfo> videoDevices;
    QList<QPair<QString, QString>> audioDevices;

public:

    class FlowNativeVideoSurface : public FlowNativeObject
    {
    public:

        FlowNativeVideoSurface(QMediaRecorderSupport* owner);

        int width;
        int height;
        QAbstractVideoSurface *videoSurface;

        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeVideoSurface, FlowNativeObject)
    };

    class FlowNativeMediaRecorder : public FlowNativeObject
    {
    public:

        FlowNativeMediaRecorder(QMediaRecorderSupport* owner);

        GstElement* pipeline;
        MediaStreamSender* sender;

        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaRecorder, FlowNativeObject)
    };

    QMediaRecorderSupport(ByteCodeRunner *Runner, QString dirPath);

private:

    void recordMedia(unicode_string websocketUri, unicode_string filePath, int timeslice, unicode_string videoMimeType,
                            bool recordAudio, bool recordVideo, unicode_string videoDeviceId, unicode_string audioDeviceId,
                            int cbOnWebsocketErrorRoot, int cbOnRecorderReadyRoot,
                            int cbOnMediaStreamReadyRoot, int cbOnRecorderErrorRoot);
    void initializeDeviceInfo(int OnDeviceInfoReadyRoot);
    void getAudioInputDevices(int OnDeviceInfoReadyRoot);
    void getVideoInputDevices(int OnDeviceInfoReadyRoot);

    void startMediaRecorder(StackSlot recorder, int timeslice);
    void resumeMediaRecorder(StackSlot recorder);
    void pauseMediaRecorder(StackSlot recorder);
    void stopMediaRecorder(StackSlot recorder);

    void addAudioDevice(GstElement *element, GstDevice* currentDevice, GParamSpec **properties, guint number_of_properties);
    void addVideoDevice(GstElement *element, GstDevice* currentDevice, GParamSpec **properties, guint number_of_properties);

    void addFilesink(GstElement *bin, GstElement *output_tee, unicode_string filePath);
    void addWebsocketSender(FlowNativeMediaRecorder* flowRecorder, GstElement *bin, GstElement *output_tee, unicode_string websocketUri, int timeslice, int cbOnWebsocketErrorRoot);

    void addVideoCapture(FlowNativeVideoSurface *flowVideoSurface, GstElement *bin, GstElement *muxer, unicode_string videoDeviceId);
    void addVideoCapturePreview(FlowNativeVideoSurface *flowVideoSurface, GstElement *bin, GstElement *videosource_tee);
    void addAudioCapture(GstElement *bin, GstElement *muxer, unicode_string audioDeviceId);

    QString formatGSTDeviceId(QString deviceId);
    QString getPropertyValue(GstElement *element, GParamSpec **properties, guint number_of_properties, char const* name);

protected:
    static void freeMediaRecorderResources(FlowNativeMediaRecorder *flowRecorder);
    static bool waitForEOS(GstBus* bus, GstMessage* message, void* loop);
    static GstFlowReturn newFrameSampleFromSink(GstAppSink *sink, gpointer data);
    static GstFlowReturn newVideoSampleFromSink(GstAppSink *sink, gpointer data);
};

#endif // MEDIARECORDERSUPPORT_H
