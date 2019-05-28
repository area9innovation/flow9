#include <QVideoSurfaceFormat>
#include "VideoWidget.h"

VideoWidget::VideoWidget(QWidget *parent)
	: QWidget(parent)
	, m_videoSurface(new VideoSurface())
	, m_mediaObject(0)
{
}

VideoWidget::~VideoWidget()
{
    if(this->hasFocus()) {
        this->previousInFocusChain()->setFocus();
    }
    m_mediaObject->stop();
    m_mediaObject->deleteLater();
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
	, m_pixelFormat(QVideoFrame::Format_Invalid)
	, m_ready(false)
    , m_size(ivec2(0, 0))
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

QList<QVideoFrame::PixelFormat> VideoSurface::supportedPixelFormats(QAbstractVideoBuffer::HandleType handleType) const
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
