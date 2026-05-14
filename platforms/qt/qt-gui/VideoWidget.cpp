#include <QVideoFrameFormat>
#include "VideoWidget.h"
#include <QNetworkReply>

VideoWidget::VideoWidget(QWidget *parent)
	: QWidget(parent)
	, m_videoSurface(new VideoSurface())
	, m_mediaObject(0)
{
}

VideoWidget::~VideoWidget()
{
    if (this->hasFocus()) {
        this->previousInFocusChain()->setFocus();
    }
    if (m_mediaObject) {
        m_mediaObject->stop();
        m_mediaObject->deleteLater();
    }
    m_videoSurface->deleteLater();
    m_videoSurface->setVideoClip(NULL);
}

void VideoWidget::setTargetVideoTexture(GLTextureBitmap::Ptr video_texture)
{
	m_videoSurface->setTargetVideoTexture(video_texture);
}

void VideoWidget::setVideoClip(GLVideoClip *videoClip)
{
	m_videoSurface->setVideoClip(videoClip);
}

VideoSurface *VideoWidget::videoSurface() const
{
	return m_videoSurface;
}

QVideoSink *VideoWidget::videoSink() const
{
	return m_videoSurface->sink();
}

void VideoWidget::setMediaPlayer(QMediaPlayer *mediaPlayer)
{
    m_mediaObject = mediaPlayer;
}

bool VideoWidget::setMediaSource(QString qtStrBase, std::function<QString (QString)> getFullResourcePath)
{
    GLVideoClip* video_clip = this->m_videoSurface->videoClip();
    QMediaPlayer* player = this->m_mediaObject;

    QString name = unicode2qt(video_clip->getName());
    QUrl base(qtStrBase);
    QString full_path = getFullResourcePath(name);
    QUrl rq_url = base.resolved(QUrl(name));

    if (QFile::exists(full_path))
        player->setSource(QUrl::fromLocalFile(full_path));
    else if (QFile::exists(name))
        player->setSource(QUrl::fromLocalFile(name));
    else if (video_clip->isHeadersSet()) {
        this->setMediaFromCustomRequest(rq_url, [this](QString errorText){ this->onError(errorText); });
    } else {
        player->setSource(rq_url);
    }

    return true;
}

void VideoWidget::setMediaFromCustomRequest(QUrl qUrl, std::function<void (QString)> onError)
{
    if (!m_customRequest) m_customRequest = new VideoCustomRequest();

    m_customRequest->setMediaFromCustomRequest(
                qUrl,
                this->m_videoSurface->videoClip(),
                this->m_mediaObject,
                onError
    );
}

QMediaPlayer *VideoWidget::mediaPlayer() const
{
	return m_mediaObject;
}

// ---- VideoSurface (Qt6 QVideoSink-based) ----

VideoSurface::VideoSurface(QObject *parent)
	: QObject(parent)
	, m_sink(new QVideoSink(this))
	, m_size(ivec2(0, 0))
	, m_ready(false)
	, m_videoClip(nullptr)
{
	connect(m_sink, &QVideoSink::videoFrameChanged, this, &VideoSurface::onVideoFrameChanged);
}

VideoSurface::~VideoSurface()
{
}

void VideoSurface::setTargetVideoTexture(GLTextureBitmap::Ptr video_texture)
{
	m_videoTextureBitmap = video_texture;
}

void VideoSurface::setVideoClip(GLVideoClip *videoClip)
{
	m_videoClip = videoClip;
}

GLVideoClip *VideoSurface::videoClip() const
{
    return m_videoClip;
}

bool VideoSurface::isReady() const
{
	return m_ready;
}

void VideoSurface::setReady(bool ready)
{
	m_ready = ready;
}

void VideoSurface::onVideoFrameChanged(const QVideoFrame &frame)
{
    // VideoClip detaches earlier than player stops
    if (!m_videoClip) {
        return;
    }

    if (frame.width() > 0 && frame.height() > 0 && (frame.width() != m_size.x || frame.height() != m_size.y)) {
        m_size = ivec2(frame.width(), frame.height());
        m_videoClip->notify(GLVideoClip::SizeChange, m_size.x, m_size.y);
    }

    QVideoFrame videoFrame(frame);

    if (videoFrame.map(QVideoFrame::ReadOnly)) {
        // In Qt6, bytesPerLine/bits take a plane index
        int realFrameWidth = videoFrame.bytesPerLine(0) / 4;

        if (m_videoTextureBitmap->getSize() != ivec2(realFrameWidth, frame.height()))
            m_videoTextureBitmap->resize(ivec2(realFrameWidth, frame.height()));

        int bytes = videoFrame.mappedBytes(0);
        int dsize = m_videoTextureBitmap->getDataSize();
        Q_ASSERT(bytes == dsize);

        memcpy(m_videoTextureBitmap->getDataPtr(), videoFrame.bits(0), bytes);
        m_videoTextureBitmap->invalidate();

        videoFrame.unmap();
    }

    emit frameUpdate();
}

// ---- VideoCustomRequest ----

VideoCustomRequest::VideoCustomRequest(QWidget *parent)
{
    this->manager = new QNetworkAccessManager();
}

void VideoCustomRequest::setMediaFromCustomRequest(QUrl qUrl, GLVideoClip* video_clip, QMediaPlayer* player, std::function<void (QString)> onError)
{
    this->request = QNetworkRequest(qUrl);
    HttpRequest::T_SMap headers = video_clip->getHeaders();

    // Set headers for HTTP request
    for (HttpRequest::T_SMap::iterator it = headers.begin(); it != headers.end(); ++it)
    {
        request.setRawHeader(
                    unicode2qt(it->first).toLatin1(),
                    unicode2qt(it->second).toUtf8()
        );
    }

    connect(manager, &QNetworkAccessManager::finished, this, [this, player, onError](QNetworkReply* reply)
    {
        if (reply->error() == QNetworkReply::NoError) {
            // Qt6: setMedia with QMediaContent removed.
            // Write to a temp buffer and use setSourceDevice.
            QBuffer *buf = setMediaBuffer(reply->readAll());
            player->setSourceDevice(buf);
        } else {
            onError(reply->errorString());
        }
    });

    manager->get(request);
}

QBuffer* VideoCustomRequest::setMediaBuffer(QByteArray qData)
{
    resetMediaBuffer();

    customHeadersRequestBuffer = new QBuffer();
    customHeadersRequestBuffer->setData(qData);
    customHeadersRequestBuffer->open(QIODevice::ReadOnly);

    return customHeadersRequestBuffer;
}

void VideoCustomRequest::resetMediaBuffer()
{
    if (customHeadersRequestBuffer)
    {
        if (customHeadersRequestBuffer->isOpen())
            customHeadersRequestBuffer->close();

        customHeadersRequestBuffer->setData(nullptr);
    }

    delete customHeadersRequestBuffer;
}

VideoCustomRequest::~VideoCustomRequest()
{
    resetMediaBuffer();
    delete manager;
}
