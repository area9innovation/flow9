#include "QMediaRecorderSupport.h"

#include "core/RunnerMacros.h"
#include "qt-gui/VideoWidget.h"
#ifdef TARGET_OS_MAC
#include "qt-backend/macos/VideoDevicesControl.h"
#endif

QMediaRecorderSupport::QMediaRecorderSupport(ByteCodeRunner *Runner, QString dirPath) : MediaRecorderSupport(Runner), owner(Runner)
{
#ifdef TARGET_OS_MAC
    qputenv("GST_PLUGIN_SCANNER", dirPath.toUtf8() + "/../Frameworks/GStreamer.framework/Versions/1.0/libexec/gstreamer-1.0/gst-plugin-scanner");
    qputenv("GST_PLUGIN_SYSTEM_PATH", dirPath.toUtf8() + "/../Frameworks/GStreamer.framework/Versions/1.0/lib");
#endif
    gst_init(NULL, NULL);
}

IMPLEMENT_FLOW_NATIVE_OBJECT(QMediaRecorderSupport::FlowNativeMediaRecorder, FlowNativeObject)

QMediaRecorderSupport::FlowNativeMediaRecorder::FlowNativeMediaRecorder(QMediaRecorderSupport *owner) : FlowNativeObject(owner->getFlowRunner()) {}

IMPLEMENT_FLOW_NATIVE_OBJECT(QMediaRecorderSupport::FlowNativeVideoSurface, FlowNativeObject)

QMediaRecorderSupport::FlowNativeVideoSurface::FlowNativeVideoSurface(QMediaRecorderSupport *owner) : FlowNativeObject(owner->getFlowRunner()) {}

CameraInfo::CameraInfo(QString id, QString name, int width, int height) : id(id), name(name), max_width(width), max_height(height) {}

MediaStreamSender::MediaStreamSender(ByteCodeRunner *owner, QString url, int timeslice, int cbOnWebsocketErrorId)
{
    this->timeslice = timeslice;
    this->owner = owner;
    this->cbOnWebsocketErrorId = cbOnWebsocketErrorId;

    timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &MediaStreamSender::sendStoredData);

    connect(&webSocket, &QWebSocket::connected, this, &MediaStreamSender::onSocketConnected);
    connect(&webSocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error), this, &MediaStreamSender::onSocketError);
    webSocket.open(QUrl(url));
}

void MediaStreamSender::onSocketConnected()
{
    timer->start(timeslice);
}

void MediaStreamSender::onSocketError(QAbstractSocket::SocketError error)
{
    RUNNER_VAR = owner;
    RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnWebsocketErrorId), 1, RUNNER->AllocateString(webSocket.errorString()));
    webSocket.close();
}

void MediaStreamSender::sendStoredData()
{
    bufferMutex.lock();
    if (buffer.size()) {
        webSocket.sendBinaryMessage(buffer);
        buffer.clear();
    }
    bufferMutex.unlock();
}

void MediaStreamSender::addData(char *data, int size)
{
    bufferMutex.lock();
    buffer.append(data, size);
    bufferMutex.unlock();
}

void MediaStreamSender::stop()
{
    timer->stop();
    timer->deleteLater();
    webSocket.abort();
}

GstFlowReturn QMediaRecorderSupport::newFrameSampleFromSink(GstAppSink *sink, gpointer data)
{
    FlowNativeVideoSurface *flowVideoSurface = (FlowNativeVideoSurface*)data;
    if (!flowVideoSurface->videoSurface) {
        return GST_FLOW_OK;
    }
    GstSample *sample = gst_app_sink_pull_sample(sink);
    if (sample) {
        GstBuffer* buffer = gst_sample_get_buffer(sample);

        GstMemory* memory = gst_buffer_get_all_memory(buffer);
        GstMapInfo map_info;
        if (gst_memory_map(memory, &map_info, GST_MAP_READ)) {
            QImage img = QImage(map_info.data, flowVideoSurface->width, flowVideoSurface->height,
                                ((flowVideoSurface->width * 4) + 3) & ~3, QImage::Format_RGBA8888);

            flowVideoSurface->videoSurface->present(QVideoFrame(img));
        }
        gst_memory_unmap(memory, &map_info);
        gst_memory_unref(memory);
        gst_sample_unref(sample);
        return GST_FLOW_OK;
    }
    return GST_FLOW_ERROR;
}

GstFlowReturn QMediaRecorderSupport::newVideoSampleFromSink(GstAppSink *sink, gpointer data)
{
    GstSample *sample = gst_app_sink_pull_sample(sink);
    MediaStreamSender *sender = (MediaStreamSender*)data;
    if (sample) {
        GstBuffer* buffer = gst_sample_get_buffer(sample);
        GstMemory* memory = gst_buffer_get_all_memory(buffer);
        GstMapInfo map_info;
        if (gst_memory_map(memory, &map_info, GST_MAP_READ)) {
            sender->addData((char*)map_info.data, map_info.size);
        }
        gst_memory_unmap(memory, &map_info);
        gst_memory_unref(memory);
        gst_sample_unref(sample);        
        return GST_FLOW_OK;
    }
    return GST_FLOW_ERROR;
}

void QMediaRecorderSupport::recordMedia(unicode_string websocketUri, unicode_string filePath, int timeslice, unicode_string videoMimeType,
                                             bool recordAudio, bool recordVideo, unicode_string videoDeviceId, unicode_string audioDeviceId,
                                             int cbOnWebsocketErrorRoot, int cbOnRecorderReadyRoot,
                                             int cbOnMediaStreamReadyRoot, int cbOnRecorderErrorRoot)
{
    RUNNER_VAR = owner;

    FlowNativeMediaRecorder* flowRecorder = new FlowNativeMediaRecorder(this);
    FlowNativeVideoSurface* flowVideoSurface = new FlowNativeVideoSurface(this);
    flowVideoSurface->width = 800;
    flowVideoSurface->height = 600;
    QList<CameraInfo>::Iterator it = std::find_if(videoDevices.begin(), videoDevices.end(), [videoDeviceId](CameraInfo dev){
            return dev.id == videoDeviceId;
    });
    if (it != videoDevices.end()) {
        flowVideoSurface->width = (*it).max_width;
        flowVideoSurface->height = (*it).max_height;
    }

    try {
        GstElement *pipeline = gst_pipeline_new("my_pipeline");
        GstElement *bin = gst_bin_new("my_bin");

        GstElement *muxer = gst_element_factory_make("qtmux", NULL);
        GstElement *output_tee = gst_element_factory_make("tee", NULL);
        if (!muxer || !output_tee) {
            throw std::runtime_error("GStreamer: Initialization failed");
        }
        g_object_set(muxer, "fragment-duration", 100, NULL);

        gst_bin_add_many(GST_BIN(bin), muxer, output_tee);
        gst_element_link(muxer, output_tee);

        if (!filePath.empty()) {
            GstElement *filesink = gst_element_factory_make("filesink", NULL);
            GstElement *fs_queue = gst_element_factory_make("queue", NULL);
            if (!filesink || !fs_queue) {
                throw std::runtime_error("GStreamer: Failed filesink initialization");
            }
            g_object_set(filesink, "location", encodeUtf8(filePath).c_str(), NULL);

            gst_bin_add_many(GST_BIN(bin), fs_queue, filesink, NULL);
            gst_element_link_many(output_tee, fs_queue, filesink, NULL);
        }

        if (!websocketUri.empty()) {
            flowRecorder->sender = new MediaStreamSender(this->getFlowRunner(), unicode2qt(websocketUri), timeslice, cbOnWebsocketErrorRoot);

            GstElement *socketSink = gst_element_factory_make("appsink", NULL);
            GstElement *socket_queue = gst_element_factory_make("queue", NULL);
            if (!socketSink || !socket_queue) {
                throw std::runtime_error("GStreamer: Failed socketSink initialization");
            }
            GstAppSinkCallbacks *appsink_callbacks1 = new GstAppSinkCallbacks();
            appsink_callbacks1->eos = NULL;
            appsink_callbacks1->new_preroll = NULL;
            appsink_callbacks1->new_sample = QMediaRecorderSupport::newVideoSampleFromSink;

            gst_app_sink_set_callbacks(GST_APP_SINK(socketSink),
                                       appsink_callbacks1,
                                       flowRecorder->sender,
                                       NULL);
            gst_app_sink_set_drop(GST_APP_SINK(socketSink), true);
            g_object_set(socketSink,
                         "sync", false,
                         NULL);

            gst_bin_add_many(GST_BIN(bin), socket_queue, socketSink, NULL);
            gst_element_link_many(output_tee, socket_queue, socketSink, NULL);

        }

        if (recordVideo) {
            GstElement *videosource = gst_element_factory_make("avfvideosrc", NULL);
            GstElement *videoconvert_source = gst_element_factory_make("videoconvert", NULL);
            GstElement *encoder = gst_element_factory_make("vtenc_h264_hw", NULL);
            GstElement *videosource_tee = gst_element_factory_make("tee", NULL);
            GstElement *appsink = gst_element_factory_make("appsink", NULL);
            GstElement *videoconvert_t = gst_element_factory_make("videoconvert", NULL);
            GstElement *appsink_queue = gst_element_factory_make("queue", NULL);
            GstElement *videosource_queue = gst_element_factory_make("queue", NULL);
            GstElement *caps_filter1 = gst_element_factory_make("capsfilter", NULL);
            GstCaps *video_caps = gst_caps_new_simple("video/x-raw",
                                                      "format", G_TYPE_STRING, "RGBA",
                                                      "width", G_TYPE_INT, flowVideoSurface->width,
                                                      "height", G_TYPE_INT, flowVideoSurface->height,
                                                      NULL);

            if (!videosource || !videoconvert_source || !encoder || !videosource_tee || !videosource_queue || !appsink || !videoconvert_t || !appsink_queue || !caps_filter1 || !video_caps) {
                throw std::runtime_error("GStreamer: Failed video recording initialization");
            }

            g_object_set(G_OBJECT(caps_filter1), "caps", video_caps, NULL);
            gst_caps_unref(video_caps);

            GstAppSinkCallbacks *appsink_callbacks = new GstAppSinkCallbacks();
            appsink_callbacks->eos = NULL;
            appsink_callbacks->new_preroll = NULL;
            appsink_callbacks->new_sample = QMediaRecorderSupport::newFrameSampleFromSink;
            gst_app_sink_set_callbacks(GST_APP_SINK(appsink),
                                       appsink_callbacks,
                                       flowVideoSurface,
                                       NULL);
            gst_app_sink_set_max_buffers(GST_APP_SINK(appsink), 1);
            gst_app_sink_set_drop(GST_APP_SINK(appsink), true );
            g_object_set(appsink, "sync", false, NULL);

            if (!videoDeviceId.empty()) {
                g_object_set(videosource, "device-index", unicode2qt(videoDeviceId).toInt(), NULL);
            }

            gst_bin_add_many(GST_BIN(bin), videoconvert_t, videosource, videosource_tee, videosource_queue, encoder, appsink_queue, appsink, caps_filter1, videoconvert_source, NULL);

            gst_element_link_many(videosource, videoconvert_t, caps_filter1, videosource_tee, videosource_queue, videoconvert_source, encoder, muxer, NULL);
            gst_element_link_many(videosource_tee, appsink_queue, appsink, NULL);

        }

        if (recordAudio) {
            GstElement *audiosource = gst_element_factory_make("osxaudiosrc", "audiosource");
            GstElement *audioconvert = gst_element_factory_make("audioconvert", "audioconvert");
            GstElement *avenc_aac = gst_element_factory_make("avenc_aac", "avenc_aac");

            if (!audiosource || !audioconvert || !avenc_aac) {
                throw std::runtime_error("GStreamer: Failed audio initialization");
            }

            gst_bin_add_many(GST_BIN(bin), audiosource, audioconvert, avenc_aac, NULL);
            gst_element_link_many(audiosource, audioconvert, avenc_aac, muxer, NULL);

            if (!audioDeviceId.empty()) {
                g_object_set(audiosource, "device", unicode2qt(audioDeviceId).toInt(), NULL);
            }
        }

        gst_bin_add(GST_BIN(pipeline), bin);

        flowRecorder->pipeline = pipeline;

        RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnRecorderReadyRoot), 1, flowRecorder->getFlowValue());
        RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnMediaStreamReadyRoot), 1, flowVideoSurface->getFlowValue());
    } catch(const std::runtime_error& e) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(cbOnRecorderErrorRoot), 1, RUNNER->AllocateString(qt2unicode(e.what())));
    }
}

void QMediaRecorderSupport::freeMediaRecorderResources(FlowNativeMediaRecorder *flowRecorder)
{
    GstState state, pending;
    gst_element_get_state(flowRecorder->pipeline, &state, &pending, GST_CLOCK_TIME_NONE);
    if (state == GST_STATE_NULL) {
        gst_object_unref(flowRecorder->pipeline);
    }

    if (flowRecorder->sender) {
        flowRecorder->sender->stop();
        flowRecorder->sender->deleteLater();
    }
}

void QMediaRecorderSupport::initializeDeviceInfo(int OnDeviceInfoReadyRoot)
{
    RUNNER_VAR = owner;

    audioDevices.clear();
    videoDevices.clear();

    GstDeviceMonitor *monitor;

    monitor = gst_device_monitor_new();
    if (!monitor){
        qDebug() << "Device monitor wasn't created";
    }
    gst_device_monitor_add_filter(monitor, "Video/Source", NULL);
    gst_device_monitor_add_filter(monitor, "Audio/Source", NULL);

    gst_device_monitor_start(monitor);

    GList* device = gst_device_monitor_get_devices(monitor);
    while (device) {
        GstDevice* currentDevice = (GstDevice*)device->data;
        GstElement *element;
        GParamSpec **properties;
        guint number_of_properties;
        GValue value = G_VALUE_INIT;

        element = gst_device_create_element(currentDevice, NULL);

        if (!element)
            continue;

        properties = g_object_class_list_properties(G_OBJECT_GET_CLASS(element), &number_of_properties);

        if (properties) {
            for (guint i = 0; i < number_of_properties; i++) {
                if (strcmp(properties[i]->name, "device") == 0) {
                    g_value_init(&value, properties[i]->value_type);
                    g_object_get_property(G_OBJECT(element), properties[i]->name, &value);

                    gchar *valuestr = gst_value_serialize(&value);

                    if (strcmp(gst_device_get_device_class(currentDevice), "Audio/Source") == 0) {
                        audioDevices.append(QPair<QString, QString>(QString(valuestr), QString(gst_device_get_display_name(currentDevice))));
                    } else {                        
                        videoDevices.append(CameraInfo(QString(valuestr), QString(gst_device_get_display_name(currentDevice))));
                    }

                    g_free(valuestr);
                    g_value_unset(&value);

                    break;
                }
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

    #ifdef TARGET_OS_MAC
        videoDevices = VideoDevicesControl::getVideoDevices();
    #endif

    RUNNER->EvalFunction(RUNNER->LookupRoot(OnDeviceInfoReadyRoot), 0);
}

void QMediaRecorderSupport::getAudioInputDevices(int OnDeviceInfoReadyRoot)
{
    RUNNER_VAR = owner;
    RUNNER_DefSlots2(deviceIds, labels);
    deviceIds = RUNNER->AllocateArray(audioDevices.size());
    labels = RUNNER->AllocateArray(audioDevices.size());
    for (int i = 0; i < audioDevices.size(); i++) {
        RUNNER->SetArraySlot(deviceIds, i, RUNNER->AllocateString(audioDevices[i].first));
        RUNNER->SetArraySlot(labels, i, RUNNER->AllocateString(audioDevices[i].second));
    }
    RUNNER->EvalFunction(RUNNER->LookupRoot(OnDeviceInfoReadyRoot), 2, deviceIds, labels);
}

void QMediaRecorderSupport::getVideoInputDevices(int OnDeviceInfoReadyRoot)
{
    RUNNER_VAR = owner;
    RUNNER_DefSlots2(deviceIds, labels);
    deviceIds = RUNNER->AllocateArray(videoDevices.size());
    labels = RUNNER->AllocateArray(videoDevices.size());
    for (int i = 0; i < videoDevices.size(); i++) {
        RUNNER->SetArraySlot(deviceIds, i, RUNNER->AllocateString(videoDevices[i].id));
        RUNNER->SetArraySlot(labels, i, RUNNER->AllocateString(videoDevices[i].name));
    }
    RUNNER->EvalFunction(RUNNER->LookupRoot(OnDeviceInfoReadyRoot), 2, deviceIds, labels);
}

void QMediaRecorderSupport::startMediaRecorder(StackSlot recorder, int timeslice)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);
    gst_element_set_state(flowRecorder->pipeline, GST_STATE_PLAYING);
}

void QMediaRecorderSupport::resumeMediaRecorder(StackSlot recorder)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);
    gst_element_set_state(flowRecorder->pipeline, GST_STATE_PLAYING);
}

void QMediaRecorderSupport::pauseMediaRecorder(StackSlot recorder)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);
    gst_element_set_state(flowRecorder->pipeline, GST_STATE_PAUSED);
}

bool QMediaRecorderSupport::waitForEOS(GstBus* bus, GstMessage* message, void* loop)
{
    switch (GST_MESSAGE_TYPE(message))
    {
    case GST_MESSAGE_EOS:
        g_main_loop_quit((GMainLoop *)loop);
        return false;
    }
    return true;
}

void QMediaRecorderSupport::stopMediaRecorder(StackSlot recorder)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = (FlowNativeMediaRecorder*)RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);

    GMainLoop *stopLoop;
    stopLoop = g_main_loop_new(NULL, FALSE);

    GstBus* bus = gst_pipeline_get_bus(GST_PIPELINE(flowRecorder->pipeline));
    gst_bus_add_watch(bus, GstBusFunc(QMediaRecorderSupport::waitForEOS), stopLoop);
    gst_object_unref(bus);

    gst_element_send_event(flowRecorder->pipeline, gst_event_new_eos());
    g_main_loop_run(stopLoop);
    gst_element_set_state(flowRecorder->pipeline, GST_STATE_NULL);
    freeMediaRecorderResources(flowRecorder);
}
