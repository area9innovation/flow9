#ifndef QMEDIASTREAMSUPPORT_H
#define QMEDIASTREAMSUPPORT_H

#include <QObject>
#include <QImage>
#include <QAbstractVideoSurface>
#include <QTimer>

#include <gst/gst.h>
#include <gst/video/video.h>
#include <gst/app/gstappsink.h>

#include "core/ByteCodeRunner.h"
#include "utils/MediaStreamSupport.h"

class CameraInfo
{
public:
    int max_width;
    int max_height;
    QString id;
    QString name;
    CameraInfo(QString id, QString name, int width=0, int height=0);
};

class QMediaStreamSupport : public MediaStreamSupport
{

    ByteCodeRunner* owner;

    QList<CameraInfo> videoDevices;
    QList<QPair<QString, QString>> audioDevices;

public:

    class FlowNativeMediaStream : public FlowNativeObject
    {
    public:

        FlowNativeMediaStream(QMediaStreamSupport* owner);

        int width;
        int height;
        QAbstractVideoSurface *videoSurface;

        GstElement *pipeline;
        GstElement *bin;

        GstElement *video_stream;
        GstElement *audio_stream;
        DEFINE_FLOW_NATIVE_OBJECT(FlowNativeVideoSurface, FlowNativeObject)
    };

    QMediaStreamSupport(ByteCodeRunner *Runner, QString dirPath);

private:
    void initializeDeviceInfo(int onDeviceInfoReadyRoot);
    void getAudioInputDevices(int onDeviceInfoReadyRoot);
    void getVideoInputDevices(int onDeviceInfoReadyRoot);

    void addAudioDevice(GstElement *element, GstDevice* currentDevice, GParamSpec **properties, guint number_of_properties);
    void addVideoDevice(GstElement *element, GstDevice* currentDevice, GParamSpec **properties, guint number_of_properties);
    QString formatGSTDeviceId(QString deviceId);
    QString getPropertyValue(GstElement *element, GParamSpec **properties, guint number_of_properties, char const* name);

    void makeStream(bool recordAudio, bool recordVideo, unicode_string audioDeviceId, unicode_string videoDeviceId, int onReadyRoot, int onErrorRoot);
    void stopStream(StackSlot mediaStream);

    void addVideoCapture(FlowNativeMediaStream *mediaStream, unicode_string videoDeviceId);
    void addVideoCapturePreview(FlowNativeMediaStream *mediaStream, GstElement *videosource_tee);
    void addAudioCapture(FlowNativeMediaStream *mediaStream, unicode_string audioDeviceId);

    static GstFlowReturn newFrameSampleFromSink(GstAppSink *sink, gpointer data);
};

#endif // QMEDIASTREAMSUPPORT_H
