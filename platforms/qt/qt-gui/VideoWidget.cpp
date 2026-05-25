#include <QVideoFrameFormat>
#include "VideoWidget.h"
#include <QNetworkReply>
#include <algorithm>

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
        // Disconnect ALL signals before stopping — stop()/delete can emit
        // positionChanged, mediaStatusChanged etc. during teardown, which
        // would call back into QGLRenderSupport with stale map entries.
        m_mediaObject->disconnect();
        m_mediaObject->stop();
        m_mediaObject->deleteLater();
    }
    m_videoSurface->setVideoClip(NULL);
    m_videoSurface->deleteLater();
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

// ---- Color Format Converters ----

// NV12 → RGBA (ITU-R BT.601 color space)
// NV12 is a 12-bit format: 8-bit Y plane followed by interleaved 4-bit UV plane (Cb/Cr)
static void convertNV12toRGBA(const QVideoFrame &frame, uint32_t *dest, int width, int height)
{
    const uint8_t *yData = static_cast<const uint8_t*>(frame.bits(0));
    const uint8_t *uvData = static_cast<const uint8_t*>(frame.bits(1));

    int yPitch = frame.bytesPerLine(0);
    int uvPitch = frame.bytesPerLine(1);

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint8_t Y = yData[y * yPitch + x];

            // UV are interleaved: U at even indices, V at odd indices
            int uvIdx = (y / 2) * uvPitch + (x / 2) * 2;
            uint8_t U = uvData[uvIdx];
            uint8_t V = uvData[uvIdx + 1];

            // BT.601 conversion
            int C = Y - 16;
            int D = U - 128;
            int E = V - 128;

            int R = (298 * C + 409 * E + 128) >> 8;
            int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
            int B = (298 * C + 516 * D + 128) >> 8;

            R = (R < 0) ? 0 : (R > 255) ? 255 : R;
            G = (G < 0) ? 0 : (G > 255) ? 255 : G;
            B = (B < 0) ? 0 : (B > 255) ? 255 : B;

            dest[y * width + x] = (0xFF << 24) | (B << 16) | (G << 8) | R;
        }
    }
}

// YUV420P → RGBA (ITU-R BT.601 color space)
// YUV420P has separate Y, U, V planes
static void convertYUV420PtoRGBA(const QVideoFrame &frame, uint32_t *dest, int width, int height)
{
    const uint8_t *yData = static_cast<const uint8_t*>(frame.bits(0));
    const uint8_t *uData = static_cast<const uint8_t*>(frame.bits(1));
    const uint8_t *vData = static_cast<const uint8_t*>(frame.bits(2));

    int yPitch = frame.bytesPerLine(0);
    int uPitch = frame.bytesPerLine(1);

    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            uint8_t Y = yData[y * yPitch + x];

            int uvIdx = (y / 2) * uPitch + (x / 2);
            uint8_t U = uData[uvIdx];
            uint8_t V = vData[uvIdx];

            // BT.601 conversion
            int C = Y - 16;
            int D = U - 128;
            int E = V - 128;

            int R = (298 * C + 409 * E + 128) >> 8;
            int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
            int B = (298 * C + 516 * D + 128) >> 8;

            R = (R < 0) ? 0 : (R > 255) ? 255 : R;
            G = (G < 0) ? 0 : (G > 255) ? 255 : G;
            B = (B < 0) ? 0 : (B > 255) ? 255 : B;

            dest[y * width + x] = (0xFF << 24) | (B << 16) | (G << 8) | R;
        }
    }
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
        int frameWidth = frame.width();
        int frameHeight = frame.height();
        QVideoFrameFormat::PixelFormat pixelFormat = frame.pixelFormat();

        // GPU NV12/YUV420P conversion: extract Y and UV planes separately
        if (pixelFormat == QVideoFrameFormat::Format_NV12 ||
            pixelFormat == QVideoFrameFormat::Format_YUV420P) {

            // Y plane: full resolution (frameWidth x frameHeight, GL_RED = 1 byte/pixel)
            // Use GL_RED (not GL_LUMINANCE) for macOS Core Profile compatibility.
            ivec2 ySize(frameWidth, frameHeight);
            if (!m_videoTextureBitmapY || m_videoTextureBitmapY->getSize() != ySize) {
                m_videoTextureBitmapY = GLTextureBitmap::Ptr(new GLTextureBitmap(ySize, GL_RED));
            }
            uint8_t *yBuffer = reinterpret_cast<uint8_t*>(m_videoTextureBitmapY->getDataPtr());
            const uint8_t *ySrc = static_cast<const uint8_t*>(videoFrame.bits(0));
            int yPitch = videoFrame.bytesPerLine(0);
            if (yPitch == frameWidth) {
                memcpy(yBuffer, ySrc, frameWidth * frameHeight);
            } else {
                // Stride differs from width — copy row by row
                for (int row = 0; row < frameHeight; row++)
                    memcpy(yBuffer + row * frameWidth, ySrc + row * yPitch, frameWidth);
            }
            m_videoTextureBitmapY->markDirty();

            // UV plane: half resolution (GL_RG = 2 bytes/pixel)
            // Use GL_RG (not GL_LUMINANCE_ALPHA) for macOS Core Profile compatibility.
            // Shader reads U from .r, V from .g.
            ivec2 uvSize(frameWidth / 2, frameHeight / 2);
            if (!m_videoTextureBitmapUV || m_videoTextureBitmapUV->getSize() != uvSize) {
                m_videoTextureBitmapUV = GLTextureBitmap::Ptr(new GLTextureBitmap(uvSize, GL_RG));
            }
            uint8_t *uvBuffer = reinterpret_cast<uint8_t*>(m_videoTextureBitmapUV->getDataPtr());

            if (pixelFormat == QVideoFrameFormat::Format_NV12) {
                // NV12: UV plane is interleaved [U0 V0 U1 V1 ...] in plane 1
                const uint8_t *uvSrc = static_cast<const uint8_t*>(videoFrame.bits(1));
                int uvPitch = videoFrame.bytesPerLine(1);
                int uvRowBytes = (frameWidth / 2) * 2;
                if (uvPitch == uvRowBytes) {
                    memcpy(uvBuffer, uvSrc, uvRowBytes * (frameHeight / 2));
                } else {
                    for (int row = 0; row < frameHeight / 2; row++)
                        memcpy(uvBuffer + row * uvRowBytes, uvSrc + row * uvPitch, uvRowBytes);
                }
            } else {
                // YUV420P: separate U (plane 1) and V (plane 2) — interleave into [U V] pairs
                const uint8_t *uData = static_cast<const uint8_t*>(videoFrame.bits(1));
                const uint8_t *vData = static_cast<const uint8_t*>(videoFrame.bits(2));
                int uPitch = videoFrame.bytesPerLine(1);
                int vPitch = videoFrame.bytesPerLine(2);
                int uvW = frameWidth / 2;
                int uvH = frameHeight / 2;
                for (int row = 0; row < uvH; row++) {
                    const uint8_t *uRow = uData + row * uPitch;
                    const uint8_t *vRow = vData + row * vPitch;
                    uint8_t *dst = uvBuffer + row * uvW * 2;
                    for (int x = 0; x < uvW; x++) {
                        dst[x * 2 + 0] = uRow[x];
                        dst[x * 2 + 1] = vRow[x];
                    }
                }
            }
            m_videoTextureBitmapUV->markDirty();

            // Activate GPU rendering path (GLTextureBitmap IS-A GLTextureImage)
            m_videoClip->setVideoTextureImage(m_videoTextureBitmapY);
            m_videoClip->setVideoTextureImageUV(m_videoTextureBitmapUV);
            m_videoClip->setYUVGPU(true);
        }
        else {
            // CPU conversion for RGBA, BGRA, or other formats
            bool isYUV = (pixelFormat == QVideoFrameFormat::Format_NV12 ||
                          pixelFormat == QVideoFrameFormat::Format_YUV420P);

            int bitmapWidth = isYUV ? frameWidth : (videoFrame.bytesPerLine(0) / 4);
            int bitmapHeight = frameHeight;

            if (m_videoTextureBitmap->getSize() != ivec2(bitmapWidth, bitmapHeight))
                m_videoTextureBitmap->resize(ivec2(bitmapWidth, bitmapHeight));

            uint32_t *destBuffer = reinterpret_cast<uint32_t*>(m_videoTextureBitmap->getDataPtr());

            // RGBA, BGRA, or unknown — direct memcpy from plane 0
            int bytes = videoFrame.mappedBytes(0);
            int dsize = m_videoTextureBitmap->getDataSize();
            memcpy(destBuffer, videoFrame.bits(0), std::min(bytes, dsize));

            m_videoTextureBitmap->markDirty();

            // Disable GPU path for non-YUV formats
            m_videoClip->setYUVGPU(false);
        }

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
