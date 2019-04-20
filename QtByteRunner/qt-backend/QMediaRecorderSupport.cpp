#include "QMediaRecorderSupport.h"

#include "core/RunnerMacros.h"
#include "qt-gui/VideoWidget.h"

QMediaRecorderSupport::QMediaRecorderSupport(ByteCodeRunner *Runner, QString dirPath) : MediaRecorderSupport(Runner), owner(Runner)
{
}

IMPLEMENT_FLOW_NATIVE_OBJECT(QMediaRecorderSupport::FlowNativeMediaRecorder, FlowNativeObject)

QMediaRecorderSupport::FlowNativeMediaRecorder::FlowNativeMediaRecorder(QMediaRecorderSupport *owner) : FlowNativeObject(owner->getFlowRunner()) {
    recorderBin = NULL;
    audioValve = NULL;
    videoValve = NULL;
    muxer = NULL;
    sender = NULL;
}

void QMediaRecorderSupport::FlowNativeMediaRecorder::setDrop(bool drop) {
    if (audioValve)
       g_object_set(audioValve, "drop", drop, NULL);
    if (videoValve)
       g_object_set(videoValve, "drop", drop, NULL);
}

VideoSender::VideoSender(ByteCodeRunner *owner, QString url, int timeslice, int onErrorRoot)
{
    this->owner = owner;
    this->timeslice = timeslice;
    this->onErrorRoot = onErrorRoot;

    timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &VideoSender::sendStoredData);

    connect(&webSocket, &QWebSocket::connected, this, &VideoSender::onSocketConnected);
    connect(&webSocket, QOverload<QAbstractSocket::SocketError>::of(&QWebSocket::error), this, &VideoSender::onSocketError);
    webSocket.open(QUrl(url));
}

void VideoSender::onSocketConnected()
{
    timer->start(timeslice);
}

void VideoSender::onSocketError(QAbstractSocket::SocketError error)
{
    RUNNER_VAR = owner;
    RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, RUNNER->AllocateString(webSocket.errorString()));
    webSocket.close();
}

void VideoSender::sendStoredData()
{
    bufferMutex.lock();
    if (buffer.size()) {
        webSocket.sendBinaryMessage(buffer);
        buffer.clear();
    }
    bufferMutex.unlock();
}

void VideoSender::addData(char *data, int size)
{
    bufferMutex.lock();
    buffer.append(data, size);
    bufferMutex.unlock();
}

void VideoSender::stop()
{
    timer->stop();
    timer->deleteLater();
    webSocket.abort();
}

GstFlowReturn QMediaRecorderSupport::newVideoSampleFromSink(GstAppSink *sink, gpointer data)
{
    GstSample *sample = gst_app_sink_pull_sample(sink);
    VideoSender *sender = static_cast<VideoSender*>(data);
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

void QMediaRecorderSupport::makeMediaRecorder(unicode_string websocketUri, unicode_string filePath, StackSlot mediaStream, int timeslice,
                        int onReadyRoot, int onErrorRoot)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder *flowRecorder = new FlowNativeMediaRecorder(this);
    flowRecorder->mediaStream = RUNNER->GetNative<QMediaStreamSupport::FlowNativeMediaStream*>(mediaStream);

    try {
        addMediaStreamMuxer(flowRecorder);

        if (!filePath.empty()) {
            addFilesink(flowRecorder, filePath);
        }

        if (!websocketUri.empty()) {
            flowRecorder->sender = new VideoSender(this->getFlowRunner(), unicode2qt(websocketUri), timeslice, onErrorRoot);
            addWebsocketSender(flowRecorder);
        }

        RUNNER->EvalFunction(RUNNER->LookupRoot(onReadyRoot), 1, flowRecorder->getFlowValue());
    } catch(const std::runtime_error& e) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(onErrorRoot), 1, RUNNER->AllocateString(qt2unicode(e.what())));
    }
}

void QMediaRecorderSupport::addMediaStreamMuxer(FlowNativeMediaRecorder *flowRecorder)
{
    flowRecorder->recorderBin = gst_bin_new(NULL);
    flowRecorder->muxer = gst_element_factory_make("qtmux", NULL);
    if (!flowRecorder->recorderBin || flowRecorder->muxer) {
        throw std::runtime_error("GStreamer: Failed to create media stream muxer");
    }
    g_object_set(flowRecorder->muxer, "fragment-duration", 100, NULL);
    gst_bin_add(GST_BIN(flowRecorder->recorderBin), flowRecorder->muxer);

    if (flowRecorder->mediaStream->audio_stream) {
        addAudioStreamReceiver(flowRecorder);
    }

    if (flowRecorder->mediaStream->video_stream) {
        addVideoStreamReceiver(flowRecorder);
    }

    flowRecorder->setDrop(true);
    gst_element_set_state(flowRecorder->recorderBin, GST_STATE_PAUSED);
    gst_bin_add(GST_BIN(flowRecorder->mediaStream->bin), flowRecorder->recorderBin);


    if (flowRecorder->mediaStream->audio_stream) {
        gst_element_link(flowRecorder->audioValve, flowRecorder->audio_stream_receiver);
    }

    if (flowRecorder->mediaStream->video_stream) {
        gst_element_link(flowRecorder->videoValve, flowRecorder->video_steram_receiver);
    }
}

void QMediaRecorderSupport::addAudioStreamReceiver(FlowNativeMediaRecorder *flowRecorder)
{
    flowRecorder->audioValve = gst_element_factory_make("valve", NULL);

    if (!flowRecorder->audioValve) {
        throw std::runtime_error("GStreamer: Failed to create audio valve");
    }

    gst_element_set_state(flowRecorder->audioValve, GST_STATE_PLAYING);

    gst_bin_add_many(GST_BIN(flowRecorder->mediaStream->bin), flowRecorder->audioValve, NULL);
    gst_element_link_many(flowRecorder->mediaStream->audio_stream, flowRecorder->audioValve, NULL);

    flowRecorder->audio_stream_receiver = flowRecorder->muxer;
}

void QMediaRecorderSupport::addVideoStreamReceiver(FlowNativeMediaRecorder *flowRecorder)
{
    flowRecorder->videoValve = gst_element_factory_make("valve", NULL);
    gst_element_set_state(flowRecorder->videoValve, GST_STATE_PLAYING);

#ifdef TARGET_OS_MAC
    GstElement *encoder = gst_element_factory_make("vtenc_h264_hw", NULL);
#elif defined(WIN32)
    GstElement *encoder = gst_element_factory_make("openh264enc", NULL);
#else
#endif
    GstElement *videoconvert = gst_element_factory_make("videoconvert", NULL);
    GstElement *videosource_queue = gst_element_factory_make("queue", NULL);
    GstElement *video_parser = gst_element_factory_make("h264parse", NULL);

    if (!flowRecorder->videoValve || !encoder || !videoconvert || !videosource_queue || !video_parser) {
        throw std::runtime_error("GStreamer: Failed to create bin for video processing");
    }

    gst_bin_add_many(GST_BIN(flowRecorder->recorderBin), videosource_queue, videoconvert, encoder, video_parser, NULL);
    gst_element_link_many(videosource_queue, videoconvert, encoder, video_parser, flowRecorder->muxer, NULL);

    gst_bin_add_many(GST_BIN(flowRecorder->mediaStream->bin), flowRecorder->videoValve, NULL);
    gst_element_link_many(flowRecorder->mediaStream->video_stream, flowRecorder->videoValve, NULL);

    flowRecorder->video_steram_receiver = videosource_queue;
}

void QMediaRecorderSupport::addFilesink(FlowNativeMediaRecorder *flowRecorder, unicode_string filePath)
{
    GstElement *filesink = gst_element_factory_make("filesink", NULL);
    GstElement *fs_queue = gst_element_factory_make("queue", NULL);
    if (!filesink || !fs_queue) {
        throw std::runtime_error("GStreamer: Failed filesink initialization");
    }
    g_object_set(filesink, "location", encodeUtf8(filePath).c_str(), NULL);

    gst_bin_add_many(GST_BIN(flowRecorder->recorderBin), fs_queue, filesink, NULL);
    gst_element_link_many(flowRecorder->muxer, fs_queue, filesink, NULL);
}

void QMediaRecorderSupport::addWebsocketSender(FlowNativeMediaRecorder *flowRecorder)
{
    GstElement *socketSink = gst_element_factory_make("appsink", NULL);
    GstElement *socket_queue = gst_element_factory_make("queue", NULL);
    if (!socketSink || !socket_queue) {
        throw std::runtime_error("GStreamer: Failed socketSink initialization");
    }
    GstAppSinkCallbacks *appsink_callbacks = new GstAppSinkCallbacks();
    appsink_callbacks->eos = NULL;
    appsink_callbacks->new_preroll = NULL;
    appsink_callbacks->new_sample = QMediaRecorderSupport::newVideoSampleFromSink;

    gst_app_sink_set_callbacks(GST_APP_SINK(socketSink),
                               appsink_callbacks,
                               flowRecorder->sender,
                               NULL);
    gst_app_sink_set_drop(GST_APP_SINK(socketSink), true);
    g_object_set(socketSink,
                 "sync", false,
                 NULL);

    gst_bin_add_many(GST_BIN(flowRecorder->recorderBin), socket_queue, socketSink, NULL);
    gst_element_link_many(flowRecorder->muxer, socket_queue, socketSink, NULL);
}

void QMediaRecorderSupport::startMediaRecorder(StackSlot recorder, int timeslice = 0)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);
    gst_element_set_state(flowRecorder->recorderBin, GST_STATE_PLAYING);
    flowRecorder->setDrop(false);
}

void QMediaRecorderSupport::resumeMediaRecorder(StackSlot recorder)
{
}

void QMediaRecorderSupport::pauseMediaRecorder(StackSlot recorder)
{
}

void QMediaRecorderSupport::stopMediaRecorder(StackSlot recorder)
{
    RUNNER_VAR = owner;
    FlowNativeMediaRecorder* flowRecorder = RUNNER->GetNative<FlowNativeMediaRecorder*>(recorder);

    gst_element_send_event(flowRecorder->muxer, gst_event_new_eos());
    flowRecorder->setDrop(true);

    if (flowRecorder->sender) {
        flowRecorder->sender->stop();
        flowRecorder->sender->deleteLater();
    }
}
