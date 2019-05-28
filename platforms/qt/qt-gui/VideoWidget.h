#ifndef VIDEO_SURFACE_H
#define VIDEO_SURFACE_H

#include <QMediaPlayer>
#include <QAbstractVideoSurface>
#include <QWidget>
#include "gl-gui/GLRenderer.h"
#include "gl-gui/GLVideoClip.h"

class VideoSurface;

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

private:
	VideoSurface *m_videoSurface;
    QMediaPlayer *m_mediaObject;
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

#endif // VIDEO_SURFACE_H
