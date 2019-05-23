#include "QMediaStreamSupport.h"

#include "core/RunnerMacros.h"
#include "qt-gui/VideoWidget.h"
#ifdef TARGET_OS_MAC
#include "qt-backend/macos/VideoDevicesControl.h"
#endif

CameraInfo::CameraInfo(QString id, QString name, int width, int height) : id(id), name(name), max_width(width), max_height(height) {}

QMediaStreamSupport::QMediaStreamSupport(ByteCodeRunner *Runner, QString dirPath) : MediaStreamSupport(Runner), owner(Runner)
{
#ifdef TARGET_OS_MAC

    qputenv("GST_PLUGIN_SCANNER", dirPath.toUtf8() + "/../Frameworks/GStreamer.framework/Versions/1.0/libexec/gstreamer-1.0/gst-plugin-scanner");
    qputenv("GST_PLUGIN_SYSTEM_PATH", dirPath.toUtf8() + "/../Frameworks/GStreamer.framework/Versions/1.0/lib");
#elif defined(WIN32)
    qputenv("GST_PLUGIN_SYSTEM_PATH", dirPath.toUtf8() + "/gst-plugins");
#else
#endif

#ifdef FLOW_DEBUGGER
    qputenv("GST_DEBUG", "1");
#endif
    gst_init(NULL, NULL);
}

IMPLEMENT_FLOW_NATIVE_OBJECT(QMediaStreamSupport::FlowNativeMediaStream, FlowNativeObject)

QMediaStreamSupport::FlowNativeMediaStream::FlowNativeMediaStream(QMediaStreamSupport *owner) : FlowNativeObject(owner->getFlowRunner()) {
    pipeline = NULL;
    bin = NULL;
    video_stream = NULL;
    audio_stream = NULL;
}

void QMediaStreamSupport::initializeDeviceInfo(int onDeviceInfoReadyRoot)
{
    RUNNER_VAR = owner;

    audioDevices.clear();
    videoDevices.clear();

    GstDeviceMonitor *monitor;

    monitor = gst_device_monitor_new();
    if (!monitor){
        qDebug() << "Device monitor wasn't created";
    }

    //use AVFoundation to get video devices for mac, otherwise use GStreamer device monitor
#ifdef TARGET_OS_MAC
    videoDevices = VideoDevicesControl::getVideoDevices();
#else
    gst_device_monitor_add_filter(monitor, "Video/Source", NULL);
#endif
    gst_device_monitor_add_filter(monitor, "Audio/Source", NULL);

    gst_device_monitor_start(monitor);

    GList* device = gst_device_monitor_get_devices(monitor);
    while (device) {
        GstDevice* currentDevice = (GstDevice*)device->data;
        GstElement *element;
        GParamSpec **properties;
        guint number_of_properties;

        element = gst_device_create_element(currentDevice, NULL);

        if (!element)
            continue;

        properties = g_object_class_list_properties(G_OBJECT_GET_CLASS(element), &number_of_properties);

        if (properties) {
            if (strcmp(gst_device_get_device_class(currentDevice), "Audio/Source") == 0) {
                addAudioDevice(element, currentDevice, properties, number_of_properties);
            } else {
                addVideoDevice(element, currentDevice, properties, number_of_properties);
            }
            g_free(properties);
        }

        gst_object_unref(element);
        gst_object_unref(device->data);

        device = device->next;
    }

    g_list_free(g_list_first(device));

    gst_device_monitor_stop(monitor);
    gst_object_unref(monitor);

    RUNNER->EvalFunction(RUNNER->LookupRoot(onDeviceInfoReadyRoot), 0);
}

void QMediaStreamSupport::addAudioDevice(GstElement *element, GstDevice* currentDevice, GParamSpec **properties, guint number_of_properties)
{
    bool isValid = true;
#if defined(WIN32)
    QString deviceApi = getPropertyValue(element, properties, number_of_properties, "name");
    isValid = deviceApi.startsWith("directsoundsrc");
#elif TARGET_MAC_OS
#else
#endif
    if (isValid) {
        QString deviceId = formatGSTDeviceId(getPropertyValue(element, properties, number_of_properties, "device"));
        audioDevices.append(QPair<QString, QString>(deviceId, QString(gst_device_get_display_name(currentDevice))));
    }
}
void QMediaStreamSupport::addVideoDevice(GstElement *element, GstDevice* currentDevice, GParamSpec **properties, guint number_of_properties)
{
#if defined(WIN32)
    QString devicePath = formatGSTDeviceId(getPropertyValue(element, properties, number_of_properties, "device-path"));
    int maxWidth = 0;
    int maxHeight = 0;

    GstCaps *caps = gst_device_get_caps (currentDevice);
    guint size = 0;
    if (caps != NULL)
        size = gst_caps_get_size (caps);

    for (guint i = 0; i < size; ++i) {
        GstStructure *structure = gst_caps_get_structure (caps, i);
        int width = g_value_get_int(gst_structure_get_value(structure, "width"));
        int height = g_value_get_int(gst_structure_get_value(structure, "height"));
        if (width * height > maxWidth * maxHeight) {
           maxWidth = width;
           maxHeight = height;
        }
    }

    videoDevices.append(CameraInfo(devicePath, QString(gst_device_get_display_name(currentDevice)), maxWidth, maxHeight));
#else
#endif
}

//GStreamer returns device id in such format "\{8CB22C2C-B59F-4636-A769-82D9C55446F9\}"
//But accepts in such format {8CB22C2C-B59F-4636-A769-82D9C55446F9}
QString QMediaStreamSupport::formatGSTDeviceId(QString deviceId)
{
    QString output;
    int start = 0;
    int end = deviceId.size();
    for (int i = start; i < end; i++) {
        if (deviceId[i] == '\\') {
            i++;
        }
        output.push_back(deviceId[i]);
    }
    if(output.startsWith("\"")) output.remove(0,1);
    if(output.endsWith("\"")) output.remove(output.size()-1,1);
    return output;
}

QString QMediaStreamSupport::getPropertyValue(GstElement *element, GParamSpec **properties, guint number_of_properties, char const* propertyName)
{
    QString qvalue = "";
    for (guint i = 0; i < number_of_properties; i++) {
        if (strcmp(properties[i]->name, propertyName) == 0) {
            GValue value = G_VALUE_INIT;
            g_value_init(&value, properties[i]->value_type);
            g_object_get_property(G_OBJECT(element), properties[i]->name, &value);

            gchar *valuestr = gst_value_serialize(&value);

            qvalue = QString(valuestr);

            g_free(valuestr);
            g_value_unset(&value);
            break;
        }
    }
    return qvalue;
}

void QMediaStreamSupport::getAudioInputDevices(int onDeviceInfoReadyRoot)
{
    RUNNER_VAR = owner;
    StackSlot devicesArray = RUNNER->AllocateArray(audioDevices.size());
    for (int i = 0; i < audioDevices.size(); i++) {
        StackSlot device = RUNNER->AllocateArray(2);
        RUNNER->SetArraySlot(device, 0, RUNNER->AllocateString(audioDevices[i].first));
        RUNNER->SetArraySlot(device, 1, RUNNER->AllocateString(audioDevices[i].second));

        RUNNER->SetArraySlot(devicesArray, i, device);
    }
    RUNNER->EvalFunction(RUNNER->LookupRoot(onDeviceInfoReadyRoot), 1, devicesArray);
}

void QMediaStreamSupport::getVideoInputDevices(int onDeviceInfoReadyRoot)
{
    RUNNER_VAR = owner;
    StackSlot devicesArray = RUNNER->AllocateArray(videoDevices.size());
    for (int i = 0; i < videoDevices.size(); i++) {
        StackSlot device = RUNNER->AllocateArray(2);
        RUNNER->SetArraySlot(device, 0, RUNNER->AllocateString(videoDevices[i].id));
        RUNNER->SetArraySlot(device, 1, RUNNER->AllocateString(videoDevices[i].name));

        RUNNER->SetArraySlot(devicesArray, i, device);
    }
    RUNNER->EvalFunction(RUNNER->LookupRoot(onDeviceInfoReadyRoot), 1, devicesArray);
}

void QMediaStreamSupport::makeStream(bool recordAudio, bool recordVideo, unicode_string audioDeviceId, unicode_string videoDeviceId, int onReadyRoot, int onErrorRoot)
{
    RUNNER_VAR = owner;
    FlowNativeMediaStream* mediaStream = new FlowNativeMediaStream(this);
    mediaStream->width = 800;
    mediaStream->height = 600;
    QList<CameraInfo>::Iterator it = std::find_if(videoDevices.begin(), videoDevices.end(), [videoDeviceId](CameraInfo dev){
            return dev.id == videoDeviceId;
    });
    if (it != videoDevices.end()) {
        mediaStream->width = (*it).max_width;
        mediaStream->height = (*it).max_height;
    }

    try {
        mediaStream->pipeline = gst_pipeline_new(NULL);
        mediaStream->bin = gst_bin_new(NULL);

        if (!mediaStream->pipeline || !mediaStream->bin) {
            throw std::runtime_error("GStreamer: Initialization failed");
        }

        if (recordVideo) {
            addVideoCapture(mediaStream, videoDeviceId);
        }

        if (recordAudio) {
            addAudioCapture(mediaStream, audioDeviceId);
        }

        gst_bin_add(GST_BIN(mediaStream->pipeline), mediaStream->bin);
        gst_element_set_state(mediaStream->pipeline, GST_STATE_PLAYING);

        RUNNER->EvalFunction(RUNNER->LookupRoot(onReadyRoot), 1, mediaStream->getFlowValue());
    } catch(const std::runtime_error& e) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, RUNNER->AllocateString(qt2unicode(e.what())));
    }
}

void QMediaStreamSupport::stopStream(StackSlot mediaStream)
{
    RUNNER_VAR = owner;
    FlowNativeMediaStream* stream = RUNNER->GetNative<FlowNativeMediaStream*>(mediaStream);
    gst_element_set_state(stream->pipeline, GST_STATE_NULL);
    gst_object_unref(stream->pipeline);
}

void QMediaStreamSupport::addVideoCapture(FlowNativeMediaStream *mediaStream, unicode_string videoDeviceId)
{
#ifdef TARGET_OS_MAC
    GstElement *videosource = gst_element_factory_make("avfvideosrc", NULL);
#elif defined(WIN32)
    GstElement *videosource = gst_element_factory_make("ksvideosrc", NULL);
#else
#endif
    GstElement *videoconvert_source = gst_element_factory_make("videoconvert", NULL);
    GstElement *videosource_tee = gst_element_factory_make("tee", NULL);
    GstElement *caps_filter = gst_element_factory_make("capsfilter", NULL);
    GstCaps *video_caps = gst_caps_new_simple("video/x-raw",
                                              "format", G_TYPE_STRING, "RGBA",
                                              "width", G_TYPE_INT, mediaStream->width,
                                              "height", G_TYPE_INT, mediaStream->height,
                                              NULL);

    if (!videosource || !videoconvert_source || !videosource_tee || !caps_filter || !video_caps) {
        throw std::runtime_error("GStreamer: Failed video recording initialization");
    }

    g_object_set(G_OBJECT(caps_filter), "caps", video_caps, NULL);
    gst_caps_unref(video_caps);

    if (!videoDeviceId.empty()) {
    #ifdef TARGET_OS_MAC
        qDebug() << unicode2qt(videoDeviceId);
        g_object_set(videosource, "device-index", unicode2qt(videoDeviceId).toInt(), NULL);
    #elif defined(WIN32)
        g_object_set(videosource, "device-path", encodeUtf8(videoDeviceId).c_str(), NULL);
    #else
    #endif
    }

    gst_bin_add_many(GST_BIN(mediaStream->bin), videosource, videoconvert_source, caps_filter, videosource_tee, NULL);
    gst_element_link_many(videosource, videoconvert_source, caps_filter, videosource_tee, NULL);
    mediaStream->video_stream = videosource_tee;
    addVideoCapturePreview(mediaStream, videosource_tee);
}

void QMediaStreamSupport::addVideoCapturePreview(FlowNativeMediaStream *mediaStream, GstElement *videosource_tee)
{
    GstElement *appsink = gst_element_factory_make("appsink", NULL);
    GstElement *appsink_queue = gst_element_factory_make("queue", NULL);

    if (!appsink || !appsink_queue) {
        throw std::runtime_error("GStreamer: Failed video preview initialization");
    }

    GstAppSinkCallbacks *appsink_callbacks = new GstAppSinkCallbacks();
    appsink_callbacks->eos = NULL;
    appsink_callbacks->new_preroll = NULL;
    appsink_callbacks->new_sample = QMediaStreamSupport::newFrameSampleFromSink;
    gst_app_sink_set_callbacks(GST_APP_SINK(appsink),
                               appsink_callbacks,
                               mediaStream,
                               NULL);
    gst_app_sink_set_max_buffers(GST_APP_SINK(appsink), 1);
    gst_app_sink_set_drop(GST_APP_SINK(appsink), true );
    g_object_set(appsink, "sync", false, NULL);

    g_object_set(appsink_queue, "flush-on-eos", true, NULL);

    gst_bin_add_many(GST_BIN(mediaStream->bin), appsink_queue, appsink, NULL);
    gst_element_link_many(videosource_tee, appsink_queue, appsink, NULL);
}

void QMediaStreamSupport::addAudioCapture(FlowNativeMediaStream *mediaStream, unicode_string audioDeviceId)
{
#ifdef TARGET_OS_MAC
    GstElement *audiosource = gst_element_factory_make("osxaudiosrc", NULL);
    GstElement *audio_encoder = gst_element_factory_make("avenc_aac", NULL);
#elif defined(WIN32)
    GstElement *audiosource = gst_element_factory_make("directsoundsrc", NULL);
    GstElement *audio_encoder = gst_element_factory_make("voaacenc", NULL);
#else
#endif
    GstElement *audioconvert = gst_element_factory_make("audioconvert", NULL);
    GstElement *audioqueue = gst_element_factory_make("queue", NULL);
    GstElement *audiosource_tee = gst_element_factory_make("tee", NULL);
    GstElement *sink = gst_element_factory_make("fakesink", NULL);

    if (!audiosource || !audioconvert || !audio_encoder || !audioqueue || !audiosource_tee || !sink) {
        throw std::runtime_error("GStreamer: Failed audio initialization");
    }

    if (!audioDeviceId.empty()) {
    #ifdef TARGET_OS_MAC
        g_object_set(audiosource, "device", unicode2qt(audioDeviceId).toInt(), NULL);
    #elif defined(WIN32)
        g_object_set(audiosource, "device", encodeUtf8(audioDeviceId).c_str(), NULL);
    #else
    #endif
    }

    gst_bin_add_many(GST_BIN(mediaStream->bin), audiosource, audioconvert, audio_encoder, audioqueue, audiosource_tee, sink, NULL);
    gst_element_link_many(audiosource, audioconvert, audio_encoder, audioqueue, audiosource_tee, sink, NULL);
    mediaStream->audio_stream = audiosource_tee;
}

GstFlowReturn QMediaStreamSupport::newFrameSampleFromSink(GstAppSink *sink, gpointer data)
{
    FlowNativeMediaStream *flowMediaStream = (FlowNativeMediaStream*)data;
    if (!flowMediaStream->videoSurface) {
        return GST_FLOW_OK;
    }
    GstSample *sample = gst_app_sink_pull_sample(sink);
    if (sample) {
        GstBuffer* buffer = gst_sample_get_buffer(sample);

        GstMemory* memory = gst_buffer_get_all_memory(buffer);
        GstMapInfo map_info;
        if (gst_memory_map(memory, &map_info, GST_MAP_READ)) {
            QImage img = QImage(map_info.data, flowMediaStream->width, flowMediaStream->height,
                                ((flowMediaStream->width * 4) + 3) & ~3, QImage::Format_RGBA8888);

            flowMediaStream->videoSurface->present(QVideoFrame(img));
        }
        gst_memory_unmap(memory, &map_info);
        gst_memory_unref(memory);
        gst_sample_unref(sample);
        return GST_FLOW_OK;
    }
    return GST_FLOW_ERROR;
}
