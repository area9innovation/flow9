#include <QVideoSurfaceFormat>
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
        player->setMedia(QUrl::fromLocalFile(full_path));
    else if (QFile::exists(name))
        player->setMedia(QUrl::fromLocalFile(name));
    else if (video_clip->isHeadersSet()) {
        this->setMediaFromCustomRequest(rq_url, [this](QString errorText){ this->onError(errorText); });
    } else {
        player->setMedia(rq_url);
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

VideoSurface::VideoSurface(QObject *parent)
	: QAbstractVideoSurface(parent)
	, m_brightness(0)
	, m_contrast(0)
	, m_hue(0)
	, m_saturation(0)
	, m_size(ivec2(0, 0))
	, m_pixelFormat(QVideoFrame::Format_Invalid)
	, m_ready(false)
{
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

QList<QVideoFrame::PixelFormat> VideoSurface::supportedPixelFormats(QAbstractVideoBuffer::HandleType /*handleType*/) const
{
    return QList<QVideoFrame::PixelFormat>() << QVideoFrame::Format_ARGB32;//QVideoFrame::Format_ARGB32_Premultiplied;

}

bool VideoSurface::isFormatSupported(const QVideoSurfaceFormat &format) const
{
    return supportedPixelFormats().contains(format.pixelFormat());
}

bool VideoSurface::start(const QVideoSurfaceFormat &format)
{
	if (m_videoTextureBitmap)
        m_videoTextureBitmap->setSwizzleRB(needsSwizzling(format));

	return QAbstractVideoSurface::start(format);
}

void VideoSurface::stop()
{
	QAbstractVideoSurface::stop();
}

bool VideoSurface::present(const QVideoFrame &frame)
{
    // VideoClip detaches earlier than player stops
    if (!m_videoClip) {
        return true;
    }

    if (frame.width() > 0 && frame.height() > 0 && (frame.width() != m_size.x || frame.height() != m_size.y)) {
        m_size = ivec2(frame.width(), frame.height());
        m_videoClip->notify(GLVideoClip::SizeChange, m_size.x, m_size.y);
    }

    QVideoFrame videoFrame(frame);

    if (videoFrame.map(QAbstractVideoBuffer::ReadOnly)) {
        int realFrameWidth = videoFrame.bytesPerLine() / 4;

        if (m_videoTextureBitmap->getSize() != ivec2(realFrameWidth, frame.height()))
            m_videoTextureBitmap->resize(ivec2(realFrameWidth, frame.height()));

        int bytes = videoFrame.mappedBytes();
        int dsize = m_videoTextureBitmap->getDataSize();
        Q_ASSERT(bytes == dsize);

        memcpy(m_videoTextureBitmap->getDataPtr(), videoFrame.bits(), bytes);
        m_videoTextureBitmap->invalidate();

        videoFrame.unmap();
    }

    emit frameUpdate();
	return true;
}

int VideoSurface::brightness() const
{
	return m_brightness;
}

void VideoSurface::setBrightness(int brightness)
{
	m_brightness = brightness;
}

int VideoSurface::contrast() const
{
	return m_contrast;
}
	
void VideoSurface::setContrast(int contrast)
{
	m_contrast = contrast;
}

int VideoSurface::hue() const
{
	return m_hue;
}
	
void VideoSurface::setHue(int hue)
{
	m_hue = hue;
}

int VideoSurface::saturation() const
{
	return m_saturation;
}
	
void VideoSurface::setSaturation(int saturation)
{
	m_saturation = saturation;
}

bool VideoSurface::isReady() const
{
	return m_ready;
}

void VideoSurface::setReady(bool ready)
{
	m_ready = ready;
}

bool VideoSurface::needsSwizzling(const QVideoSurfaceFormat &format) const
{
    return format.pixelFormat() == QVideoFrame::Format_RGB32 ||
    	   format.pixelFormat() == QVideoFrame::Format_ARGB32;
}

VideoCustomRequest::VideoCustomRequest(QWidget *parent)
{
    this->manager = new QNetworkAccessManager();
}

void VideoCustomRequest::setMediaFromCustomRequest(QUrl qUrl, GLVideoClip* video_clip, QMediaPlayer* player, std::function<void (QString)> onError)
{
    this->request = QNetworkRequest(qUrl);
    video_clip->applyHeaders(&request);

    connect(manager, &QNetworkAccessManager::finished, this, [this, player, onError](QNetworkReply* reply)
    {
        if (reply->error() == QNetworkReply::NoError) {
            player->setMedia(QMediaContent(), setMediaBuffer(reply->readAll()));
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
