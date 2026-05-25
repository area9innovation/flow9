#ifndef VIDEO_SURFACE_H
#define VIDEO_SURFACE_H

#include <QMediaPlayer>
#include <QVideoSink>
#include <QVideoFrame>
#include <QVideoFrameFormat>
#include <QWidget>
#include "gl-gui/GLRenderer.h"
#include "gl-gui/GLVideoClip.h"
#include "QBuffer"
#include "QNetworkAccessManager"

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

	// Returns the QVideoSink for use with QMediaPlayer::setVideoOutput()
	QVideoSink *videoSink() const;

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

// Qt6 replacement for QAbstractVideoSurface using QVideoSink
class VideoSurface : public QObject
{
	Q_OBJECT

public:
	VideoSurface(QObject *parent = 0);
	~VideoSurface();

	void setTargetVideoTexture(GLTextureBitmap::Ptr video_texture);

	QVideoSink *sink() const { return m_sink; }

	bool isReady() const;
	void setReady(bool ready);

	void setVideoClip(GLVideoClip *videoClip);
	GLVideoClip *videoClip() const;

Q_SIGNALS:
	void frameUpdate();

private slots:
	void onVideoFrameChanged(const QVideoFrame &frame);

private:
	GLTextureBitmap::Ptr m_videoTextureBitmap;       // RGBA bitmap for non-YUV formats
	GLTextureBitmap::Ptr m_videoTextureBitmapY;      // Y plane (GL_LUMINANCE) for GPU NV12/YUV420P
	GLTextureBitmap::Ptr m_videoTextureBitmapUV;     // UV plane (GL_LUMINANCE_ALPHA) for GPU NV12/YUV420P
	QVideoSink *m_sink;

    ivec2 m_size;
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
