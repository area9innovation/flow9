#ifndef VIDEO_SURFACE_H
#define VIDEO_SURFACE_H

#include <QMediaPlayer>
#include <QAbstractVideoSurface>
#include <QWidget>
#include "gl-gui/GLRenderer.h"
#include "gl-gui/GLVideoClip.h"

class VideoSurface;

class VideoCustomRequest;

class VideoWidget : public QWidget
{
	Q_OBJECT

public:
	VideoWidget(QWidget *parent = 0);
	~VideoWidget();

	void setTargetVideoTexture(GLTextureBitmap::Ptr video_texture);
	void setVideoClip(GLVideoClip *videoClip);

	VideoSurface *videoSurface() const;

    void setMediaPlayer(QMediaPlayer *mediaPlayer);
    QMediaPlayer *mediaPlayer() const;

    bool setMediaSource(QString qtStrBase, std::function<QString (QString)> getFullResourcePath);

signals:
    void onError(QString errorText);

private:
	VideoSurface *m_videoSurface;
    QMediaPlayer *m_mediaObject;
    VideoCustomRequest *m_customRequest = nullptr;

    void setMediaFromCustomRequest(QUrl qUrl, std::function<void (QString)> onError);
};

class VideoSurface : public QAbstractVideoSurface
{
	Q_OBJECT

public:
	VideoSurface(QObject *parent = 0);
	~VideoSurface();

	void setTargetVideoTexture(GLTextureBitmap::Ptr video_texture);

	QList<QVideoFrame::PixelFormat> supportedPixelFormats(
		QAbstractVideoBuffer::HandleType handleType = QAbstractVideoBuffer::NoHandle) const;

	bool isFormatSupported(const QVideoSurfaceFormat &format) const;

	bool start(const QVideoSurfaceFormat &format);
	void stop();

	bool present(const QVideoFrame &frame);

	int brightness() const;
	void setBrightness(int brightness);

	int contrast() const;
	void setContrast(int contrast);

	int hue() const;
	void setHue(int hue);

	int saturation() const;
	void setSaturation(int saturation);

	bool isReady() const;
	void setReady(bool ready);

	void setVideoClip(GLVideoClip *videoClip);
	GLVideoClip *videoClip() const;

Q_SIGNALS:
	void frameUpdate();

protected:
	bool needsSwizzling(const QVideoSurfaceFormat &format) const;

private:
	GLTextureBitmap::Ptr m_videoTextureBitmap;

	int m_brightness;
	int m_contrast;
	int m_hue;
	int m_saturation;
    ivec2 m_size;

	QVideoFrame::PixelFormat m_pixelFormat;
	QSize m_frameSize;
	QRect m_sourceRect;
	bool m_colorsDirty;
	bool m_ready;

	GLVideoClip *m_videoClip;
};

class VideoCustomRequest : public QObject
{
    Q_OBJECT

public:
    VideoCustomRequest(QWidget *parent = nullptr);
    ~VideoCustomRequest();

    void setMediaFromCustomRequest(QUrl qUrl, GLVideoClip* video_clip, QMediaPlayer* player, std::function<void (QString)> onError);

private:
    QNetworkAccessManager* manager = nullptr;
    QNetworkRequest request;
    QBuffer* customHeadersRequestBuffer = nullptr;

    void resetMediaBuffer();
    QBuffer* setMediaBuffer(QByteArray qData);
};

#endif // VIDEO_SURFACE_H
