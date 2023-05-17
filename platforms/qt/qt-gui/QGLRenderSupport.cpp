#include "QGLRenderSupport.h"
#include "QGLTextEdit.h"
#include "QGLLineEdit.h"

#include "gl-gui/GLRenderer.h"
#include "gl-gui/GLTextClip.h"
#include "gl-gui/GLVideoClip.h"
#include "gl-gui/GLWebClip.h"

#include "swfloader.h"

#include "qt-gui/mainwindow.h"

#include <QProcess>
#include <QNetworkRequest>
#include <QNetworkReply>

#include <QApplication>
#include <QMessageBox>
#include <QGLFramebufferObject>
#include <QLabel>
#include <QWebEngineSettings>
#include <QWebEngineProfile>
#include <QVideoSurfaceFormat>

#include <sstream>

#include "QGLWebPage.h"

#include "core/RunnerMacros.h"
#include "utils/flowfilestruct.h"

#include "VideoWidget.h"

#ifdef FLOW_MEDIARECORDER
#include "QMediaStreamSupport.h"
#include "QMediaRecorderSupport.h"
#endif

QGLRenderSupport::QGLRenderSupport(QWidget *parent, ByteCodeRunner *owner, bool fake_touch, bool transparent) :
    QOpenGLWidget(parent),
    GLRenderSupport(owner),
    request_manager(new QNetworkAccessManager(this)),
	gl_fake_touch(fake_touch)
{
    QOpenGLWidget::setAcceptDrops(true);
    setMouseTracking(true);
    setFocusPolicy(Qt::StrongFocus);
    setUpdateBehavior(QOpenGLWidget::NoPartialUpdate);

    gl_transparent = transparent;

    if (gl_transparent) {
        setAttribute(Qt::WA_TranslucentBackground);
        setAttribute(Qt::WA_NoSystemBackground, true);
    }

    bc_download_progress = NULL;
    bc_reply = NULL;

    if (gl_fake_touch)
        NoHoverMouse = DrawMouseRect = true;

    no_qglfb = false;

    EmulatePanGesture = false;

    connect(request_manager, SIGNAL(finished(QNetworkReply*)), this, SLOT(handleFinished(QNetworkReply*)));
}

void QGLRenderSupport::loadFontsFromFolder(QString base) {
    QDirIterator fontsIterator(base + "fonts", QDirIterator::Subdirectories);
    while (fontsIterator.hasNext()) {
        QString font = fontsIterator.next();

        if (font.endsWith("ttf") || font.endsWith("otf"))
            QFontDatabase::addApplicationFont(font);
    }

    QDirIterator recourcesIterator(base + "resources/fonts", QDirIterator::Subdirectories);
    while (recourcesIterator.hasNext()) {
        QString font = recourcesIterator.next();

        if (font.endsWith("ttf") || font.endsWith("otf"))
            QFontDatabase::addApplicationFont(font);
    }
}

static QFont::Weight qFontWeightByTextWeight(TextWeight weight) {
    switch (weight) {
    case TextWeight::Thin: return QFont::Thin;
    case TextWeight::UltraLight: return QFont::ExtraLight;
    case TextWeight::Light: return QFont::Light;
    case TextWeight::Regular: return QFont::Normal;
    case TextWeight::Medium: return QFont::Medium;
    case TextWeight::SemiBold: return QFont::DemiBold;
    case TextWeight::Bold: return QFont::Bold;
    case TextWeight::ExtraBold: return QFont::ExtraBold;
    case TextWeight::Black: return QFont::Black;
    default: return QFont::Normal;
    }
}

static QFont::Style qFontStyleByTextStyle(TextStyle style) {
    switch (style) {
    case TextStyle::Normal: return QFont::StyleNormal;
    case TextStyle::Italic: return QFont::StyleItalic;
    case TextStyle::Oblique: return QFont::StyleOblique;
    default: return QFont::StyleNormal;
    }
}

bool QGLRenderSupport::loadSystemFont(FontHeader *header, TextFont textFont)
{
    QString family(textFont.family.c_str());
    QFont::Weight weight = qFontWeightByTextWeight(textFont.weight);
    QFont::Style style = qFontStyleByTextStyle(textFont.style);

    QFont font(family, -1, weight, false);
    font.setStyle(style);

    if (!font.exactMatch()) {
        font = QFont(family + " " + QString(textFont.suffix().c_str()), weight, false);
        font.setStyle(style);
    }

    if (!font.exactMatch())
        return false;

    header->tile_size = 64;
    header->grid_size = 4;
    header->render_em_size = 56; //header->tile_size/2;
    header->active_tile_size = (header->tile_size-2)/header->render_em_size;

    font.setPixelSize(header->render_em_size);

    QFontMetrics metrics(font);

    float coeff = 1.0f / header->render_em_size;

    header->dist_scale = 1.0f / 16.0f;

    header->ascender = metrics.ascent() * coeff;
    header->descender = -metrics.descent() * coeff;
    header->line_height = metrics.lineSpacing() * coeff;
    header->max_advance = metrics.maxWidth() * coeff;

    header->underline_position = metrics.underlinePos() * coeff;
    header->underline_thickness = coeff;

    FontsMap[textFont] = new QFont(font);
    return true;
}

bool QGLRenderSupport::loadSystemGlyph(const FontHeader *header, GlyphHeader *info, StaticBuffer *pixels, TextFont textFont, ucs4_char code)
{
    QFont *pfont = FontsMap[textFont];
    QFontMetrics metrics(*pfont);

    QString qchar = QString::fromUcs4(&code, 1);
    if (!metrics.inFontUcs4(code))
        return false;

    ushort scale = 3;
    unsigned render_size = header->tile_size * scale;

    QRect rect = metrics.boundingRect(qchar[0]);

    float coeff = 1.0f / header->render_em_size;
    int xoff = (header->tile_size - rect.width()) / 2;
    int yoff = (header->tile_size - rect.height()) / 2;

    info->unicode_char = code;
    info->advance = metrics.horizontalAdvance(qchar) * coeff;
    info->bearing_x = rect.left() * coeff;
    info->bearing_y = rect.top() * coeff;
    info->size_x = rect.width() * coeff;
    info->size_y = rect.height() * coeff;
    info->field_bearing_x = (rect.left() - xoff + 1) * coeff;
    info->field_bearing_y = (rect.top() - yoff + 1) * coeff;

    QFont render_font(*pfont);
    render_font.setPixelSize(header->render_em_size * scale);

    QImage img = QImage(render_size, render_size, QImage::Format_ARGB32_Premultiplied);

    img.fill(0);

    QPainter painter(&img);
    painter.setPen(QPen(QColor(255,255,255)));
    painter.setFont(render_font);
    painter.drawText(QPoint((xoff - rect.left()) * scale, (yoff - rect.top())*scale), qchar);

    bool isGreyGlyph = true;
    const uint8_t* bytes = img.bits();
    for (long i = 0; i < img.sizeInBytes(); i += 4) {
        isGreyGlyph = isGreyGlyph && bytes[i] == bytes[i + 1] && bytes[i + 1] == bytes[i + 2] && bytes[i + 2] == bytes[i + 3];
    }

    // Font engine detects if colored by condition unicode_char > 0xFFFF.
    // We have to define it here to avoid font mismatches
    info->unicode_char = isGreyGlyph ? 0xD800 : 0x10000;

    if (!isGreyGlyph) {
        pixels->allocate(img.sizeInBytes(), false);
        memcpy(pixels->writable_data(), img.bits(), img.sizeInBytes());
    } else {
        std::vector<uint8_t> bitmap(render_size * render_size, 0);
        uint8_t* buf = bitmap.data();

        for (unsigned y = 0; y < render_size; y++)
        {
            for (unsigned x = 0; x < render_size; x++)
            {
                QRgb data = img.pixel(x, y);
                *buf++ = (data&255) == 255 ? 255 : 0;
            }
        }

        smoothFontBitmap(header, pixels, bitmap.data(), scale);
    }

    return true;
}


void QGLRenderSupport::setDPI(int dpi)
{
    GLRenderSupport::setDPI(dpi);

    if (NoHoverMouse)
        MouseRadius = 0.07f * PixelsPerCm;
}

void QGLRenderSupport::StartBytecodeDownload(QUrl url)
{
    bc_download_progress = new QProgressDialog(QString("Downloading program code..."), QString(), 0, 100, this);
    bc_download_progress->setWindowModality(Qt::WindowModal);

    QUrl rq_url = url.resolved(QUrl(QUrlQuery(url.query()).queryItemValue("name")+".bytecode"));
    QNetworkRequest request(rq_url);

    bc_reply = request_manager->get(request);
    connect(bc_reply, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(bytecodeDownloadProgress(qint64,qint64)));
    connect(bc_reply, SIGNAL(finished()), this, SLOT(bytecodeDownloadFinished()));
}

void QGLRenderSupport::bytecodeDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    if (!bc_download_progress)
        return;
    bc_download_progress->setMaximum(bytesTotal);
    bc_download_progress->setValue(bytesReceived);
}

void QGLRenderSupport::bytecodeDownloadFinished()
{
    bc_download_progress->deleteLater();
    bc_download_progress = NULL;

    QNetworkReply *reply = bc_reply;
    bc_reply->deleteLater();
    bc_reply = NULL;

    if (reply->error() == QNetworkReply::NoError) {
        QByteArray data = reply->readAll();

        getFlowRunner()->flow_err << "Loading retrieved bytecode." << endl;
        getFlowRunner()->Init(data.data(), data.size());
        getFlowRunner()->RunMain();
    } else {
        QString message = QString::number(reply->error()) + " " + reply->errorString();
        QMessageBox::critical(this, "Bytecode download failed", message);
        QApplication::quit();
    }
}

void QGLRenderSupport::LoadFont(std::string code, QString name)
{
    std::vector<unicode_string> aliases;
    aliases.push_back(parseUtf8(code));
    loadFont(encodeUtf8(qt2unicode(name)), aliases);
}

bool QGLRenderSupport::loadAssetData(StaticBuffer *buffer, std::string name, size_t size)
{
    return GLRenderSupport::loadAssetData(buffer, encodeUtf8(qt2unicode(getFullResourcePath(QString::fromStdString(name)))), size);
}

void QGLRenderSupport::OnRunnerReset(bool inDestructor)
{
    GLRenderSupport::OnRunnerReset(inDestructor);

    for (std::map<GLClip*,QWidget*>::iterator it = NativeWidgets.begin(); it != NativeWidgets.end(); ++it)
        if (it->second != Q_NULLPTR)
            it->second->deleteLater();

    NativeWidgets.clear();
    NativeWidgetClips.clear();
    fullScreenConnections.clear();
    quitConnections.clear();

    emit runnerReset(inDestructor);
}

#ifdef FLOW_DEBUGGER
void QGLRenderSupport::onClipDataChanged(GLClip *clip)
{
    if (clip->isAttachedToStage())
        emit clipDataChanged(clip);
}

void QGLRenderSupport::onClipBeginSetParent(GLClip *child, GLClip *parent, GLClip *oldparent)
{
    if (parent && !parent->isAttachedToStage())
        parent = NULL;
    if (oldparent && !oldparent->isAttachedToStage())
        oldparent = NULL;

    if (parent || oldparent)
        emit clipAboutToChangeParent(child, parent, oldparent);
}

void QGLRenderSupport::onClipEndSetParent(GLClip *child, GLClip *parent, GLClip *oldparent)
{
    if (parent && !parent->isAttachedToStage())
        parent = NULL;
    if (oldparent && !oldparent->isAttachedToStage())
        oldparent = NULL;

    if (parent || oldparent)
        emit clipChangedParent(child, parent, oldparent);
}
#endif

bool QGLRenderSupport::doCreateNativeWidget(GLClip* clip, bool neww)
{
    QWidget* &widget = NativeWidgets[clip];
    QRect rect;
    bool visible = false, ok = false;

    if (widget) {
        NativeWidgetClips.erase(widget);

        if (neww) {
            delete widget;
            widget = NULL;
        } else {
            rect = widget->geometry();
            visible = widget->isVisible();
        }
    }

    if (GLTextClip* text_clip = flow_native_cast<GLTextClip>(clip))
        ok = doCreateTextWidget(widget, text_clip);
    else if (GLVideoClip* video_clip = flow_native_cast<GLVideoClip>(clip)) {
        ok = doCreateVideoWidget(widget, video_clip);
    } else if (GLWebClip* web_clip = flow_native_cast<GLWebClip>(clip))
        ok = doCreateWebWidget(widget, web_clip);

    if (widget) {
        NativeWidgetClips[widget] = clip;

        if (visible)
            widget->setGeometry(rect);
        widget->setVisible(visible);
    }

    return ok;
}

void QGLRenderSupport::doDestroyNativeWidget(GLClip *clip)
{
    QWidget *widget = NativeWidgets[clip];
    widget->hide();
    widget->deleteLater();
    NativeWidgetClips.erase(widget);
    NativeWidgets.erase(clip);

    // Clean VideoWidget reference from VideoPlayerMap
    VideoWidget *videoWidget = qobject_cast<VideoWidget*>(widget);
    if (videoWidget) {
        videoWidget->videoSurface()->setVideoClip(NULL);
        VideoPlayerMap.remove(videoWidget->mediaPlayer());
    }
}

void QGLRenderSupport::doReshapeNativeWidget(GLClip* clip, const GLBoundingBox &bbox, float scale, float alpha)
{
    QWidget* widget = NativeWidgets[clip];

    if (widget) {
        bool wasVisible = widget->isVisible();

        if (bbox.isEmpty || alpha <= 0.0f || (bbox.size().x == 0 && bbox.size().y == 0))
            widget->setVisible(false);
        else {
            GLBoundingBox box = bbox;
            box.roundOut();

            vec2 size = box.size();

            widget->setGeometry(bbox.min_pt.x, bbox.min_pt.y, size.x, size.y);
            widget->setVisible(true);

            if (GLTextClip* text_clip = flow_native_cast<GLTextClip>(clip)) {
                QGLTextEdit* edit = qobject_cast<QGLTextEdit*>(widget);
                TextFont textFont = text_clip->getTextFont();

                QFont font = FontsMap[textFont] ? QFont(*FontsMap[textFont]) : QFont(QString(textFont.family.c_str()));
                int pixelSize = (int)(scale * text_clip->getFontSize());
                font.setPixelSize(pixelSize == 0 ? 1 : pixelSize);

                edit->setFont(font);

                vec2 flowSize = text_clip->getExplicitSize();

                if (flowSize.x != 0.0f) {
                    edit->setFixedWidth(scale * (flowSize.x + 8));
                }
                if (flowSize.y != 0.0f) {
                    edit->setFixedHeight(scale * (flowSize.y + 8));
                }

                if (!wasVisible)
                    edit->setFocus();

                edit->ensureCursorVisible();
            } else if (GLVideoClip *video_clip = flow_native_cast<GLVideoClip>(clip)) {
                video_clip->updateSubtitlesPosition();
            } else if (GLWebClip *web_clip = flow_native_cast<GLWebClip>(clip)) {
                // setGeometry invariably causes an "OpenGL error 1282" from inside Qt, so we
                // consume the error here since it doesn't seem to affect the result.
                // TODO: Figure out what's actually going on inside Qt. Probably related to rebuilding their FBO.
            	UNUSED(web_clip);
                glGetError();
            }
        }
    }
}

double getLightness(vec4 color)
{
    double min = std::min(color.x, std::min(color.y, color.z));
    double max = std::max(color.x, std::max(color.y, color.z));

    return (min + max) / 2;
}

std::string flowColorToRGBAStr(vec4 color)
{
    return stl_sprintf("rgba(%s, %s, %s, %s)",
                       QString::number(color.x * 255.f).toUtf8().constData(),
                       QString::number(color.y * 255.f).toUtf8().constData(),
                       QString::number(color.z * 255.f).toUtf8().constData(),
                       QString::number(color.a).toUtf8().constData());
}

bool QGLRenderSupport::doCreateTextWidget(QWidget* &widget, GLTextClip* text_clip)
{
   QGLTextEdit* edit = qobject_cast<QGLTextEdit*>(widget);

    if (!edit) {
        delete widget;
        widget = edit = new QGLTextEdit(this, this, text_clip);

        edit->setAcceptRichText(false);
    } else {
        edit->disconnect(this, SLOT(textFieldChanged()));
    }

    connect(edit, SIGNAL(textChanged()), SLOT(textFieldChanged()));
    connect(edit, SIGNAL(cursorPositionChanged()), SLOT(textFieldChanged()));
    connect(edit, SIGNAL(selectionChanged()), SLOT(textFieldChanged()));

    return true;
}

void QGLRenderSupport::onTextClipStateChanged(GLTextClip* clip) {
    QGLTextEdit* edit = qobject_cast<QGLTextEdit*>(NativeWidgets[clip]);
    if (edit)
        edit->onStateChange();
}

void QGLRenderSupport::textFieldChanged()
{
    GLClip* owner = NativeWidgetClips[(QWidget*)sender()];
    QGLTextEdit *edit = qobject_cast<QGLTextEdit*>(sender());
    QTextCursor cursor = edit->textCursor();

    dispatchEditStateUpdate(owner, cursor.position(), cursor.selectionStart(), cursor.selectionEnd(), true, qt2unicode(edit->toPlainText()));
    edit->resetCursorBlink();
}

bool QGLRenderSupport::doCreateVideoWidget(QWidget* &widget, GLVideoClip* video_clip)
{
    // Delete the old widget, if any, and the associated media player object
    VideoWidget* videoWidget = qobject_cast<VideoWidget*>(NativeWidgets[video_clip]);
    if (videoWidget) {
        QMediaPlayer* player = videoWidget->mediaPlayer();
        if (player) {
            VideoPlayerMap.remove(player);
            delete player;
        }
        delete videoWidget;
    }
    if (video_clip->useMediaStream()) {
#ifdef FLOW_MEDIARECORDER
        QMediaStreamSupport::FlowNativeMediaStream *mediaStream = getFlowRunner()->GetNative<QMediaStreamSupport::FlowNativeMediaStream*>(getFlowRunner()->LookupRoot(video_clip->getMediaStreamId()));

        widget = videoWidget = new VideoWidget(this);
        mediaStream->videoSurface = videoWidget->videoSurface();

        video_clip->notify(GLVideoClip::SizeChange, mediaStream->width, mediaStream->height);

        GLTextureBitmap::Ptr texture_bitmap(new GLTextureBitmap(video_clip->getSize(), GL_RGBA));
        video_clip->setVideoTextureImage(texture_bitmap);
        videoWidget->setTargetVideoTexture(texture_bitmap);
        videoWidget->setVideoClip(video_clip);

        connect(videoWidget->videoSurface(), &VideoSurface::frameUpdate, this, [this, videoWidget, video_clip](){
            video_clip->notifyEvent(GLVideoClip::PlayStart);
            disconnect(videoWidget->videoSurface(), &VideoSurface::frameUpdate, 0, 0);
            connect(videoWidget->videoSurface(), &VideoSurface::frameUpdate, this, &QGLRenderSupport::doRequestRedraw);
        });
#endif
    } else {
        // Media player does the video decoding and hands us new frames
        QMediaPlayer* player = new QMediaPlayer(nullptr, QMediaPlayer::VideoSurface);

        connect(player, &QMediaPlayer::stateChanged, this, &QGLRenderSupport::videoStateChanged);
        connect(player, &QMediaPlayer::mediaStatusChanged, this, &QGLRenderSupport::mediaStatusChanged);
        connect(player, &QMediaPlayer::positionChanged, this, &QGLRenderSupport::videoPositionChanged);
        connect(player, SIGNAL(error(QMediaPlayer::Error)), this, SLOT(handleVideoError()));

        widget = videoWidget = new VideoWidget(this);
        VideoPlayerMap[player] = videoWidget;

        videoWidget->hide();
        player->setVideoOutput(videoWidget->videoSurface());
        player->setNotifyInterval(10);
        videoWidget->setMediaPlayer(player);

        // We pass the frames from Qt to our OpenGL video renderer through a texture
        GLTextureBitmap::Ptr texture_bitmap(new GLTextureBitmap(video_clip->getSize(), GL_RGBA));
        video_clip->setVideoTextureImage(texture_bitmap);
        videoWidget->setTargetVideoTexture(texture_bitmap);
        videoWidget->setVideoClip(video_clip);

        // Load the video file and start playing the video

        QString name = unicode2qt(video_clip->getName());
        QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
        QString full_path = getFullResourcePath(name);
        QUrl rq_url = base.resolved(QUrl(name));

        if (QFile::exists(full_path))
            player->setMedia(QUrl::fromLocalFile(full_path));
        else if (QFile::exists(name))
            player->setMedia(QUrl::fromLocalFile(name));
        else if (video_clip->isHeadersSet()) {
            QNetworkRequest request = QNetworkRequest(rq_url);
            video_clip->applyHeaders(&request);

            QNetworkAccessManager * manager = new QNetworkAccessManager(this);
            connect(manager, &QNetworkAccessManager::finished, this, [player, video_clip, this](QNetworkReply* reply)
            {
                if (reply->error() == QNetworkReply::NoError) {
                    player->setMedia(QMediaContent(), video_clip->setMediaBuffer(reply->readAll()));

                    if (video_clip->isPlaying()) {
                        player->play();
                    } else {
                        player->pause();
                    }
                } else {
                    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

                    getFlowRunner()->flow_err << "Video error: " << encodeUtf8(qt2unicode(reply->errorString())) << endl;
                    dispatchVideoNotFound(video_clip);
                }
            });

            manager->get(request);
        } else {
            player->setMedia(rq_url);
        }

        if (!video_clip->isHeadersSet())
        {
            if (video_clip->isPlaying()) {
                player->play();
            } else {
                player->pause();
            }
        }
    }
    return true;
}

void QGLRenderSupport::doUpdateVideoFocus(GLVideoClip *video_clip, bool focus)
{
    VideoWidget *videoWidget = qobject_cast<VideoWidget*>(NativeWidgets[video_clip]);
    if (!videoWidget) return;

    if (focus)
    {
        videoWidget->activateWindow();
        videoWidget->setFocus();
    }
}

void QGLRenderSupport::doUpdateVideoPlay(GLVideoClip *video_clip)
{
    VideoWidget *videoWidget = qobject_cast<VideoWidget*>(NativeWidgets[video_clip]);
    if (!videoWidget) return;

    QMediaPlayer *player = videoWidget->mediaPlayer();
    if (!player) return;

    if (video_clip->isPlaying()) {
        player->play();
    } else {
        player->pause();
    }
}

void QGLRenderSupport::doUpdateVideoPosition(GLVideoClip *video_clip)
{
    VideoWidget *videoWidget = qobject_cast<VideoWidget*>(NativeWidgets[video_clip]);
    if (!videoWidget) return;

    QMediaPlayer *player = videoWidget->mediaPlayer();
    if (!player) return;

    player->setPosition(video_clip->getPosition());
}

void QGLRenderSupport::doUpdateVideoVolume(GLVideoClip *video_clip)
{
    VideoWidget *videoWidget = qobject_cast<VideoWidget*>(NativeWidgets[video_clip]);
    if (!videoWidget) return;

    QMediaPlayer *player = videoWidget->mediaPlayer();
    if (!player) return;

    player->setVolume(video_clip->getVolume() * 100);
}

void QGLRenderSupport::doUpdateVideoPlaybackRate(GLVideoClip *video_clip)
{
    VideoWidget *videoWidget = qobject_cast<VideoWidget*>(NativeWidgets[video_clip]);
    if (!videoWidget) return;

    QMediaPlayer *player = videoWidget->mediaPlayer();
    if (!player) return;

    player->setPlaybackRate(video_clip->getPlaybackRate());
}

void QGLRenderSupport::handleVideoError()
{
    QMediaPlayer *player = qobject_cast<QMediaPlayer*>(sender());
    if (!player) return;

    VideoWidget *videoWidget = VideoPlayerMap[player];
    if (!videoWidget) return;

    GLClip *owner = NativeWidgetClips[videoWidget];
    if (!owner) return;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    getFlowRunner()->flow_err << "Video error: " << encodeUtf8(qt2unicode(player->errorString())) << endl;
    dispatchVideoNotFound(owner);
}

void QGLRenderSupport::mediaStatusChanged(QMediaPlayer::MediaStatus status)
{
    QMediaPlayer *player = qobject_cast<QMediaPlayer*>(sender());
    if (!player) return;

    VideoWidget *videoWidget = VideoPlayerMap[player];
    if (!videoWidget) return;

    GLClip *owner = NativeWidgetClips[videoWidget];
    if (!owner) return;

    switch (status) {
        case QMediaPlayer::BufferedMedia:
        case QMediaPlayer::LoadedMedia: {
            dispatchVideoDuration(owner, player->duration());
            dispatchVideoPlayStatus(owner, GLVideoClip::PlayStart);
            break;
        }
        case QMediaPlayer::EndOfMedia: {
            dispatchVideoPlayStatus(owner, GLVideoClip::PlayEnd);
            break;
        }
        default: break;
    }
}

void QGLRenderSupport::videoStateChanged(QMediaPlayer::State state)
{
    QMediaPlayer *player = qobject_cast<QMediaPlayer*>(sender());
    if (!player) return;

    VideoWidget *videoWidget = VideoPlayerMap[player];
    if (!videoWidget) return;

    GLClip *owner = NativeWidgetClips[videoWidget];
    if (!owner) return;

    switch (state) {
        case QMediaPlayer::PlayingState: {
            dispatchVideoPlayStatus(owner, GLVideoClip::UserResume);
            break;
        }
        case QMediaPlayer::PausedState: {
            dispatchVideoPlayStatus(owner, GLVideoClip::UserPause);
            break;
        }
        case QMediaPlayer::StoppedState: {
            dispatchVideoPlayStatus(owner, GLVideoClip::PlayEnd);
            break;
        }
    }
}

void QGLRenderSupport::videoPositionChanged(int64_t position)
{
    QMediaPlayer *player = qobject_cast<QMediaPlayer*>(sender());
    if (!player) return;

    VideoWidget *videoWidget = VideoPlayerMap[player];
    if (!videoWidget) return;

    GLClip *owner = NativeWidgetClips[videoWidget];
    if (!owner) return;

    doRequestRedraw();
    updateLastUserAction();

    dispatchVideoPosition(owner, position);
}

bool QGLRenderSupport::doCreateWebWidget(QWidget *&widget, GLWebClip *web_clip) {
    QWebEngineView *web_view = qobject_cast<QWebEngineView*>(widget);
    if (!web_view) {
        widget = web_view = new QWebEngineView(this);
        web_view->setPage(new QGLWebPage(this, web_view));
    }

    if (!web_clip->getUseCache())
    {
        web_view->page()->profile()->setPersistentCookiesPolicy(QWebEngineProfile::NoPersistentCookies);
        web_view->page()->profile()->setHttpCacheType(QWebEngineProfile::MemoryHttpCache);
    }

    QString path = unicode2qt(web_clip->getUrl());
    QString full_path = getFullResourcePath(path);

    web_view->setGeometry(0, 0, Width, Height);

    if (QFile::exists(full_path)) {
        web_view->load(QUrl::fromLocalFile(full_path));
    } else {
        QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
        QUrl rq_url = base.resolved(QUrl(path));
        if (getFlowRunner()->NotifyStubs)
            getFlowRunner()->flow_err << "HTML URL: " << encodeUtf8(qt2unicode(rq_url.toString())) << std::endl;
        web_view->load(rq_url);
    }

    web_view->setFocusPolicy(Qt::NoFocus);

    connect(web_view, SIGNAL(loadFinished(bool)), SLOT(webPageLoaded(bool)));

    return true;
}

void QGLRenderSupport::webPageLoaded(bool ok) {
    QWebEngineView * web_view = qobject_cast<QWebEngineView*>(sender());
    GLClip *nester = NativeWidgetClips[web_view];

    if (ok) {
        web_view->findText("404 Not Found", QWebEnginePage::FindFlags(), [this, nester](bool found) {
            if (found) {
                dispatchPageError(nester, "404 Page Not Found");
            } else {
                dispatchPageLoaded(nester);
            }
        });
    } else {
        dispatchPageError(nester, "Failed");
    }

    web_view->disconnect(this, SLOT(webPageLoaded(bool)));
}

void QGLRenderSupport::callflow(QWebEngineView * web_view, QVariantList args) {
    GLClip *owner = NativeWidgetClips[web_view];

    if (owner) {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlots1(arg);
        arg = RUNNER->AllocateArray(args.length());
        for (int i = 0; i < args.length(); i++) {
            RUNNER->SetArraySlot(arg, i, variant2slot(args[i]));
        }

        dispatchPageCall(owner, arg);
    }
}

StackSlot QGLRenderSupport::webClipHostCall(GLWebClip * clip, const unicode_string &name, const StackSlot & args) {
    QWidget *widget = NativeWidgets[clip];
    QWebEngineView *web_view = qobject_cast<QWebEngineView*>(widget);

    if (web_view) {
        QWebEnginePage * page = web_view->page();
        QString fn = unicode2qt(name);
        std::stringstream ss;
        getFlowRunner()->PrintData(ss, args);
        QString args_str = QString::fromStdString(ss.str());
        page->runJavaScript(fn + "(" + args_str.mid(1,args_str.length()-2) + ")", [this](const QVariant &var) {
            return variant2slot(var);
        });
    }

    return getFlowRunner()->AllocateString("");
}

StackSlot QGLRenderSupport::webClipEvalJS(GLWebClip * clip, const unicode_string &code, StackSlot& cb) {
    QWidget *widget = NativeWidgets[clip];
    QWebEngineView *web_view = qobject_cast<QWebEngineView*>(widget);

    if (web_view) {
        QWebEnginePage * page = web_view->page();
        QString js = unicode2qt(code);

        page->runJavaScript(js, [this, cb](const QVariant &var) {
            RUNNER_VAR = getFlowRunner();
            WITH_RUNNER_LOCK_DEFERRED(RUNNER);
            RUNNER->EvalFunction(cb, 1, variant2slot(var));
        });
    }

    RETVOID;
}

StackSlot QGLRenderSupport::variant2slot(QVariant var) {
    return getFlowRunner()->AllocateString(var.toString());
}

void QGLRenderSupport::initializeGL()
{
    if (!initGLContext(defaultFramebufferObject())) {
        //QMessageBox::critical(this, "OpenGL Init Failed", "Could not initialize the graphics subsystem.");
        cerr << "Could not initialize the graphics subsystem." << endl;
        cerr << GLRenderer::getOpenGLInfo() << endl;
        exit(1);
    }
}

void QGLRenderSupport::resizeGL(int w, int h)
{
    resizeGLContext(w,h);

    if (windowTitle.size() == 0)
        window()->setWindowTitle(stl_sprintf("Qt Flow Runner - [%dx%d]", w, h).c_str());
}

void QGLRenderSupport::paintGL()
{
    // Qt uses a framebuffer object to render on QOpenGLWidgets, so the framebuffer id is not 0.
    // Therefore, we need to let the core graphics module know which FBO to restore to for the root FBO
    // since it uses and switches to other FBO's.
    // Moreover, we set the root FBO id here to make sure Qt's FBO has been initialized, since it
    // doesn't seem to have been by the time initializeGL is called.
    getRenderer()->setRootFramebufferId(defaultFramebufferObject());

    // Could have changed if window was moved between screens
    getRenderer()->setDevicePixelRatio(devicePixelRatio());

    paintGLContext();
}

bool QGLRenderSupport::loadPicture(unicode_string url, bool c /*cache*/)
{
    HttpRequest::T_SMap headers;
    return loadPicture(url, headers, c);
}

bool QGLRenderSupport::loadPicture(unicode_string url, HttpRequest::T_SMap& headers, bool /*cache*/)
{
    QString name = unicode2qt(url);
    QString full_path = getFullResourcePath(name);

    if (name.toLower().endsWith(".swf")) {
        QString png_name = name.left(name.length()-4) + ".png";
        QString png_path = getFullResourcePath(png_name);
#if 0 && defined(WIN32)
        if (!QFile::exists(png_path)) {
            // Code to automatically create missing PNGs for vector SWFs
            QProcess p;
            p.setWorkingDirectory("c:\\flow9");
            QString target = unicode2qt(url);
            target = target.replace(".swf", ".png");
            QString cmd = "c:\\flow9\\resources\\swfrender.exe " + unicode2qt(url) + " -o " + target;
            qDebug() << cmd;
            p.start(cmd);
            bool r = p.waitForFinished(-1);
            qDebug() << p.readAllStandardOutput();
            if (!r) {
                qDebug() << p.readAllStandardError();
            }
        }
#endif

        if (!QFile::exists(png_path))
            png_path = png_name;

        if (QFile::exists(png_path)) {
            resolvePicture(url, encodeUtf8(qt2unicode(png_path)));
            return true;
        }
    }

    if (!QFile::exists(full_path))
        full_path = name;

    if (QFile::exists(full_path)) {
        resolvePicture(url, encodeUtf8(qt2unicode(full_path)));
        return true;
    }

    QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
    QUrl rq_url = base.resolved(QUrl(unicode2qt(url)));
    QNetworkRequest request(rq_url);

    // Set headers for HTTP request
    if (headers.size() > 0) {
        for (HttpRequest::T_SMap::iterator it = headers.begin(); it != headers.end(); ++it)
        {
            request.setRawHeader(
                        unicode2qt(it->first).toLatin1(),
                        unicode2qt(it->second).toUtf8()
            );
        }
    }

    request_map[request_manager->get(request)] = url;

    return true;
}

void QGLRenderSupport::abortPictureLoading(unicode_string url){
    foreach (QNetworkReply *reply, request_map.keys()) {
        if (request_map.value(reply) == url) {
            reply->abort();
            if (getFlowRunner()->NotifyStubs)
                getFlowRunner()->flow_err << "Aborted download of image: " << encodeUtf8(url) << endl;
            break;
        }
    }
}

void QGLRenderSupport::handleFinished(QNetworkReply *reply) {
    unicode_string id = request_map[reply];
    request_map.remove(reply);

    reply->deleteLater();

    if (!id.empty()) {
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray data = reply->readAll();
            if (getFlowRunner()->NotifyStubs)
                getFlowRunner()->flow_err << "Downloaded image: " << encodeUtf8(id) << endl;
            resolvePicture(id, (uint8_t*)data.data(), data.size());
        } else {
            QString message = QString::number(reply->error()) + " " + reply->errorString() + " in " + unicode2qt(id);
            resolvePictureError(id, qt2unicode(message));
        }
    }
}

void QGLRenderSupport::dispatchMouseEvent(FlowEvent event, int x, int y)
{
    // Randomize mouse position in fake touch mode to simulate sensor imprecision
    if (NoHoverMouse)
    {
        // Use the default value of radius, ignoring setHitboxRadius
        float MouseRadius = 0.07f * PixelsPerCm;
        float r = MouseRadius * 0.7f;

        x += int((rand()*r*2.0f)/RAND_MAX - r);
        y += int((rand()*r*2.0f)/RAND_MAX - r*0.1);
    }

    GLRenderSupport::dispatchMouseEvent(event, x, y);
}

void QGLRenderSupport::dispatchMouseEventFromWidget(QWidget *widget, FlowEvent e, QMouseEvent* qe)
{
    if (qe->isAccepted() == 1) {
        QPoint flow_pos = widget->mapToParent( qe->pos() );
        dispatchMouseEvent(e, flow_pos.x(), flow_pos.y());
    }
}

void QGLRenderSupport::mouseMoveEvent(QMouseEvent *event)
{
    if (EmulatePanGesture && (event->buttons() & Qt::LeftButton))
        dispatchGestureEvent(FlowPanEvent, FlowGestureStateProgress, event->x(), event->y(), event->x() - MouseX, event->y() - MouseY);

    // No mouse tracking in fake touch mode
    if (NoHoverMouse && !event->buttons())
        return;

    updateLastUserAction();

    dispatchMouseEvent(FlowMouseMove, event->x(), event->y());
}

void QGLRenderSupport::mousePressEvent(QMouseEvent *event)
{
    if (EmulatePanGesture)
        dispatchGestureEvent(FlowPanEvent, FlowGestureStateBegin, event->x(), event->y(), 0.0f, 0.0f);

    if (event->button() == Qt::LeftButton)
        dispatchMouseEvent(FlowMouseDown, event->x(), event->y());
    else if (event->button() == Qt::RightButton)
        dispatchMouseEvent(FlowMouseRightDown, event->x(), event->y());
    else if (event->button() == Qt::MiddleButton)
        dispatchMouseEvent(FlowMouseMiddleDown, event->x(), event->y());
}

void QGLRenderSupport::mouseReleaseEvent(QMouseEvent *event)
{
    if (EmulatePanGesture)
        dispatchGestureEvent(FlowPanEvent, FlowGestureStateEnd, event->x(), event->y(), event->x() - MouseX, event->y() - MouseY);

    if (event->button() == Qt::LeftButton)
        dispatchMouseEvent(FlowMouseUp, event->x(), event->y());
    else if (event->button() == Qt::RightButton)
        dispatchMouseEvent(FlowMouseRightUp, event->x(), event->y());
    else if (event->button() == Qt::MiddleButton)
        dispatchMouseEvent(FlowMouseMiddleUp, event->x(), event->y());
}

// On OSX, we have pixelDelta (and angleDelta seems to be in
// pixels as well, with twice the scale, possibly because of retina)
void QGLRenderSupport::wheelEvent(QWheelEvent *event)
{
    QPoint numPixels = event->pixelDelta();
    QPoint numAngle = event->angleDelta();

    double deltaX = 0;
    double deltaY = 0;
    if (!numPixels.isNull()) {
        deltaX = numPixels.x();
        deltaY = numPixels.y();
    } else {
        deltaX = numAngle.x() / 120;
        deltaY = numAngle.y() / 120;
    }

    GLRenderSupport::dispatchWheelEvent(deltaY);
    GLRenderSupport::dispatchFineGrainWheelEvent(deltaX, deltaY);

    event->accept();
}

void QGLRenderSupport::OnHostEvent(HostEvent event)
{
    GLRenderSupport::OnHostEvent(event);
}

void QGLRenderSupport::doSetCursor(std::string type)
{
    if (type == "finger")
        QWidget::setCursor(QCursor(Qt::PointingHandCursor));
#if QT_VERSION >= QT_VERSION_CHECK(4,7,0)
    else if (type == "move")
        QWidget::setCursor(QCursor(Qt::OpenHandCursor));
#endif
    else if (type == "text")
        QWidget::setCursor(QCursor(Qt::IBeamCursor));
    else if (type == "none")
        QWidget::setCursor(QCursor(Qt::BlankCursor));
    else if (type == "crosshair")
        QWidget::setCursor(QCursor(Qt::CrossCursor));
    else if (type == "help")
        QWidget::setCursor(QCursor(Qt::WhatsThisCursor));
    else if (type == "wait")
        QWidget::setCursor(QCursor(Qt::WaitCursor));
    else if (type == "progress")
        QWidget::setCursor(QCursor(Qt::BusyCursor));
    else if (type == "not-allowed")
        QWidget::setCursor(QCursor(Qt::ForbiddenCursor));
    else if (type == "col-resize")
        QWidget::setCursor(QCursor(Qt::SplitHCursor));
    else if (type == "row-resize")
        QWidget::setCursor(QCursor(Qt::SplitVCursor ));
    else if (type == "n-resize")
        QWidget::setCursor(QCursor(Qt::UpArrowCursor));
    else if (type == "ew-resize")
        QWidget::setCursor(QCursor(Qt::SizeHorCursor));
    else if (type == "ns-resize")
        QWidget::setCursor(QCursor(Qt::SizeVerCursor));
    else if (type == "nesw-resize")
        QWidget::setCursor(QCursor(Qt::SizeBDiagCursor));
    else if (type == "nwse-resize")
        QWidget::setCursor(QCursor(Qt::SizeFDiagCursor));
    else if (type == "grab")
        QWidget::setCursor(QCursor(Qt::OpenHandCursor));
    else if (type == "grabbing")
        QWidget::setCursor(QCursor(Qt::ClosedHandCursor));
    else
        QWidget::setCursor(QCursor(Qt::ArrowCursor));
}

void QGLRenderSupport::doOpenUrl(unicode_string url, unicode_string)
{
    QDesktopServices::openUrl(QUrl(unicode2qt(url)));
}

void QGLRenderSupport::keyPressEvent(QKeyEvent *event)
{
#ifdef __APPLE__
    // On Windows, a kewReleaseEvent seems to be sent after each continuous key press, but
    // not on the Mac. We send the key up event explicitly as well for uniform behavior
    // on the flow side
    if (event->isAutoRepeat()) translateKeyEvent(FlowKeyUp, event);
#endif
    translateKeyEvent(FlowKeyDown, event);
}

void QGLRenderSupport::keyReleaseEvent(QKeyEvent *event)
{
    translateKeyEvent(FlowKeyUp, event);
}

inline bool isAlpha(int key)
{
    return key >= Qt::Key_A && key <= Qt::Key_Z;
}

inline bool isNum(int key)
{
    return key >= Qt::Key_0 && key <= Qt::Key_9;
}

inline bool isFlowAlpha(int key)
{
    return key >= FlowKey_A && key <= FlowKey_Z;
}

inline bool isFlowNum(int key)
{
    return key >= FlowKey_0 && key <= FlowKey_9;
}

inline bool isPrintableASCII(int key)
{
    return key >= Qt::Key_Space && key <= Qt::Key_AsciiTilde;
}

bool isControlChar(QKeyEvent *info)
{
    bool ctrl = info->modifiers().testFlag(Qt::ControlModifier);
    if (!ctrl || info->key() == Qt::Key_Return)
        return false;

#ifdef __APPLE__
    // key is empty string on osx when command is pressed, so the test below doesn't work
    // TODO: This test might also work on windows and linux, but hasn't been tested
    return info->key() != Qt::Key_Control && info->key() > Qt::Key_Space;
#else
    return info->text().length() > 0 && info->text().compare(" ") < 0;
#endif
}

// translates the Qt key into the corresponding flow key code (see lib/keycode.flow)
FlowKeyCode QtToFlowKeyCode(int qt_key)
{
    switch (qt_key) {
#define CASE(qtv, flowv) case qtv: return flowv; break;
    CASE(Qt::Key_Backspace, FlowKey_Backspace);
    CASE(Qt::Key_Tab, FlowKey_Tab);
    CASE(Qt::Key_Backtab, FlowKey_BackTab);
    CASE(Qt::Key_Enter, FlowKey_Enter);
    CASE(Qt::Key_Return, FlowKey_Enter);
    CASE(Qt::Key_Shift, FlowKey_Shift);
    CASE(Qt::Key_Control, FlowKey_Ctrl);
    CASE(Qt::Key_Alt, FlowKey_Alt);
    CASE(Qt::Key_Meta, FlowKey_Meta);
    CASE(Qt::Key_Escape, FlowKey_Escape);
    CASE(Qt::Key_Space, FlowKey_Space);
    CASE(Qt::Key_PageUp, FlowKey_PageUp);
    CASE(Qt::Key_PageDown, FlowKey_PageDown);
    CASE(Qt::Key_End, FlowKey_End);
    CASE(Qt::Key_Home, FlowKey_Home);
    CASE(Qt::Key_Left, FlowKey_Left);
    CASE(Qt::Key_Right, FlowKey_Right);
    CASE(Qt::Key_Up, FlowKey_Up);
    CASE(Qt::Key_Down, FlowKey_Down);
    CASE(Qt::Key_Insert, FlowKey_Insert);
    CASE(Qt::Key_Delete, FlowKey_Delete);
    CASE(Qt::Key_BracketLeft, FlowKey_BracketLeft);
    CASE(Qt::Key_BracketRight, FlowKey_BracketRight);
    CASE(Qt::Key_F1, FlowKey_F1);
    CASE(Qt::Key_F2, FlowKey_F2);
    CASE(Qt::Key_F3, FlowKey_F3);
    CASE(Qt::Key_F4, FlowKey_F4);
    CASE(Qt::Key_F5, FlowKey_F5);
    CASE(Qt::Key_F6, FlowKey_F6);
    CASE(Qt::Key_F7, FlowKey_F7);
    CASE(Qt::Key_F8, FlowKey_F8);
    CASE(Qt::Key_F9, FlowKey_F9);
    CASE(Qt::Key_F10, FlowKey_F10);
    CASE(Qt::Key_F11, FlowKey_F11);
    CASE(Qt::Key_F12, FlowKey_F12);
#undef CASE
    default: {
        if (isAlpha(qt_key))
            return (FlowKeyCode)(FlowKey_A + (qt_key - Qt::Key_A));
        else if (isNum(qt_key))
            return (FlowKeyCode)(FlowKey_0 + (qt_key - Qt::Key_0));
        else
            return FlowKey_Null;
    }
    }
}

// translates the Qt key into the corresponding flow key code (see lib/keycode.flow)
Qt::Key FlowKeyCodeToQt(int flow_key)
{
    switch (flow_key) {
#define CASE(qtv, flowv) case qtv: return flowv; break;
    CASE(FlowKey_Backspace, Qt::Key_Backspace);
    CASE(FlowKey_Tab, Qt::Key_Tab);
    CASE(FlowKey_BackTab, Qt::Key_Backtab);
    CASE(FlowKey_Enter, Qt::Key_Enter);
    CASE(FlowKey_Shift, Qt::Key_Shift);
    CASE(FlowKey_Ctrl, Qt::Key_Control);
    CASE(FlowKey_Alt, Qt::Key_Alt);
    CASE(FlowKey_Meta, Qt::Key_Meta);
    CASE(FlowKey_Escape, Qt::Key_Escape);
    CASE(FlowKey_Space, Qt::Key_Space);
    CASE(FlowKey_PageUp, Qt::Key_PageUp);
    CASE(FlowKey_PageDown, Qt::Key_PageDown);
    CASE(FlowKey_End, Qt::Key_End);
    CASE(FlowKey_Home, Qt::Key_Home);
    CASE(FlowKey_Left, Qt::Key_Left);
    CASE(FlowKey_Right, Qt::Key_Right);
    CASE(FlowKey_Up, Qt::Key_Up);
    CASE(FlowKey_Down, Qt::Key_Down);
    CASE(FlowKey_Insert, Qt::Key_Insert);
    CASE(FlowKey_Delete, Qt::Key_Delete);
    CASE(FlowKey_BracketLeft, Qt::Key_BracketLeft);
    CASE(FlowKey_BracketRight, Qt::Key_BracketRight);
    CASE(FlowKey_F1, Qt::Key_F1);
    CASE(FlowKey_F2, Qt::Key_F2);
    CASE(FlowKey_F3, Qt::Key_F3);
    CASE(FlowKey_F4, Qt::Key_F4);
    CASE(FlowKey_F5, Qt::Key_F5);
    CASE(FlowKey_F6, Qt::Key_F6);
    CASE(FlowKey_F7, Qt::Key_F7);
    CASE(FlowKey_F8, Qt::Key_F8);
    CASE(FlowKey_F9, Qt::Key_F9);
    CASE(FlowKey_F10, Qt::Key_F10);
    CASE(FlowKey_F11, Qt::Key_F11);
    CASE(FlowKey_F12, Qt::Key_F12);
#undef CASE
    default: {
        if (isFlowAlpha(flow_key))
            return (Qt::Key)(Qt::Key_A + (flow_key - FlowKey_A));
        else if (isFlowNum(flow_key))
            return (Qt::Key)(Qt::Key_0 + (flow_key - FlowKey_0));
        else
            return Qt::Key_unknown ;
    }
    }
}

GLClip* tabDownClipFocused = NULL;

FlowKeyEvent QGLRenderSupport::keyEventToFlowKeyEvent(FlowEvent event, QKeyEvent *info)
{
    QString text = info->text();
    unicode_string key = qt2unicode(text);
    FlowKeyCode code = QtToFlowKeyCode(info->key());

    // debug hack
    if (info->key() == Qt::Key_F12 && event == FlowKeyDown && gl_fake_touch)
        setScreenRotation(FlowScreenRotation((getScreenRotation()+1)&3));

    bool ctrl = info->modifiers().testFlag(Qt::ControlModifier);
    bool shift = info->modifiers().testFlag(Qt::ShiftModifier);
    bool alt = info->modifiers().testFlag(Qt::AltModifier);
    bool meta = info->modifiers().testFlag(Qt::MetaModifier);

    // emulate swipe & pan
    if (ctrl && shift && event == FlowKeyDown) {
        static bool pinch_in_progress = false;
        static float pinch_scale = 1.0f;

#define CASE(key, dx, dy) case key: dispatchGestureEvent(FlowSwipeEvent,FlowGestureStateEnd, MouseX, MouseY, dx, dy); \
    cout << "Emulate swipe at " << MouseX << "," << MouseY << endl; break;
        switch (code) {
        CASE(FlowKey_Left, -1.0, 0.0);
        CASE(FlowKey_Right, 1.0, 0.0);
        CASE(FlowKey_Up, 0.0, -1.0);
        CASE(FlowKey_Down, 0.0, 1.0);
        case FlowKey_F11:
            EmulatePanGesture = !EmulatePanGesture;
            cout << "Emulate Pan gesture: " << (EmulatePanGesture ? "On" : "Off") << endl;
            break;
        case FlowKey_F8: // Zoom im
            cout << "Emulate Pinch Zoom in" << endl;
            dispatchGestureEvent(FlowPinchEvent, !pinch_in_progress ? FlowGestureStateBegin : FlowGestureStateProgress, MouseX, MouseY, pinch_scale *= 1.1f, 0.0f);
            pinch_in_progress = true;
            break;
        case FlowKey_F9: // Zoom out
            cout << "Emulate Pinch Zoom out" << endl;
            dispatchGestureEvent(FlowPinchEvent, !pinch_in_progress ? FlowGestureStateBegin : FlowGestureStateProgress, MouseX, MouseY, pinch_scale /= 1.1f, 0.0f);
            pinch_in_progress = true;
            break;
        case FlowKey_F10:
            if (pinch_in_progress) {
                cout << "Emulate Pinch Endt" << endl;
                dispatchGestureEvent(FlowPinchEvent, FlowGestureStateEnd, MouseX, MouseY, pinch_scale, 0.0f);
                pinch_in_progress = false;
                pinch_scale = 1.0f;
            }
            break;
        default:
            break;
        }
#undef CASE
    }

    if (info->key() == Qt::Key_Tab && event == FlowKeyDown)
    {
        tabDownClipFocused = GLRenderSupport::getCurrentFocus();
    }

    if (info->key() == Qt::Key_Tab && event == FlowKeyUp && TabOrderingEnabled)
    {
        GLRenderSupport::tryFocusNextClip(tabDownClipFocused, true);
    }

    if (info->key() == Qt::Key_Escape) {
        if (MainWindow *mWindow = qobject_cast<MainWindow*>(this->parent()))
            if (mWindow->windowState() == Qt::WindowFullScreen)
                hideFullScreen();
    }

    if (event == FlowKeyUp && (info->key() == Qt::Key_Enter || info->key() == Qt::Key_Return || info->key() == Qt::Key_Space)) {
        if (GLRenderSupport::getCurrentFocus()) {
            GLRenderSupport::getCurrentFocus()->dispatchAccessCallback();
        }
    }

    if (ctrl || meta) {
        // If ctrl or meta keys are pressed, info->text() returns empty string,
        // so we need to set the key name as well based on their ASCII values
        if (isAlpha(info->key())) {
            // Ascii codes 0-31: We add 32 to make it lowercase
            key = info->key() + 32;
        } else if (isPrintableASCII(info->key())) {
            key = info->key();
        }
    }

    // Adjust strings to match codes
    switch (code) {
#define SSTR(str) { static const unicode_string v = parseUtf8(str); key = v; }
#define CASE(name, str) case name: SSTR(str); break;
    CASE(FlowKey_Backspace, "backspace");
    CASE(FlowKey_Tab, "tab");
    CASE(FlowKey_Enter, "enter");
    case FlowKey_Shift:
        shift = true; SSTR("shift"); break;
    case FlowKey_Ctrl:
        ctrl = true; SSTR("ctrl"); break;
    case FlowKey_Alt:
        alt = true; SSTR("alt"); break;
    case FlowKey_Meta:
        meta = true; SSTR("meta"); break;
    CASE(FlowKey_Escape, "esc");
    CASE(FlowKey_Space, " ");
    CASE(FlowKey_PageUp, "page up");
    CASE(FlowKey_PageDown, "page down");
    CASE(FlowKey_End, "end");
    CASE(FlowKey_Home, "home");
    CASE(FlowKey_Left, "left");
    CASE(FlowKey_Up, "up");
    CASE(FlowKey_Right, "right");
    CASE(FlowKey_Down, "down");
    CASE(FlowKey_Insert, "insert");
    CASE(FlowKey_Delete, "delete");
    CASE(FlowKey_Numpad_Multiply, "*");
    CASE(FlowKey_Numpad_Add, "+");
    CASE(FlowKey_Numpad_Subtract, "-");
    CASE(FlowKey_Numpad_Decimal, ".");
    CASE(FlowKey_Numpad_Divide, "/");
    case FlowKey_F1: case FlowKey_F2: case FlowKey_F3:
    case FlowKey_F4: case FlowKey_F5: case FlowKey_F6:
    case FlowKey_F7: case FlowKey_F8: case FlowKey_F9:
    case FlowKey_F10: case FlowKey_F11: case FlowKey_F12:
    case FlowKey_F13: case FlowKey_F14: case FlowKey_F15:
        {
            char tmp[16];
            int sz = sprintf(tmp, "F%d", code-FlowKey_F1+1);
            key = parseUtf8(tmp, sz);
            break;
        }
    case FlowKey_Null:
    case FlowKey_Numpad_0:;
#undef SSTR
#undef CASE
    default: break; // do nothing
    }

    return FlowKeyEvent(
        event, key, ctrl, shift, alt, meta, code
    );
}


void QGLRenderSupport::translateKeyEvent(FlowEvent event, QKeyEvent *info)
{
    translateFlowKeyEvent(keyEventToFlowKeyEvent(event, info));
}

void QGLRenderSupport::translateFlowKeyEvent(FlowKeyEvent event)
{
    dispatchFlowKeyEvent(event);
}

StackSlot QGLRenderSupport::setFocus(RUNNER_ARGS)
{
    RUNNER_PopArgs2(nclip, focus);
    RUNNER_CheckTag1(TNative, nclip);
    RUNNER_CheckTag1(TBool, focus);

    GLClip *clip = RUNNER->GetNative<GLClip*>(nclip);
    if (clip->isVisible())
    {
        if (GLRenderSupport::getCurrentFocus() && focus.GetBool())
            GLRenderSupport::getCurrentFocus()->setFocus(false);

        clip->setFocus(focus.GetBool());
    }

    RETVOID;
}

StackSlot QGLRenderSupport::getFocus(RUNNER_ARGS)
{
    RUNNER_PopArgs1(clip);
    RUNNER_CheckTag1(TNative, clip);

    return StackSlot::MakeBool(RUNNER->GetNative<GLClip*>(clip) == GLRenderSupport::getCurrentFocus());
}

GLClip* draggingOver;
void QGLRenderSupport::dragEnterEvent(QDragEnterEvent *event)
{
    draggingOver = NULL;
    if (event->mimeData()->hasUrls()) {
        QList<QUrl> urls = event->mimeData()->urls();

        for (QList<QUrl>::Iterator it = urls.begin(); it != urls.end(); ++it) {
            QString path = (*it).toLocalFile();

            QDir dir(path);
            if (!dir.exists()) {
                event->accept();
                break;
            }
        }
    }
}

void QGLRenderSupport::dragMoveEvent(QDragMoveEvent *event)
{
    draggingOver = NULL;
    for (T_FileDropClips::iterator it = FileDropClips.begin(); it != FileDropClips.end(); ++it)
    {
        GLClip* clip = (*it);
        GLBoundingBox box = clip->getGlobalBBox();
        vec2 pos = box.min_pt;
        vec2 size = box.size();
        vec2 mpos = vec2(event->pos().x() - pos.x, event->pos().y() - pos.y);
        if (mpos.x >= 0 && mpos.y >= 0 && mpos.x <= size.x && mpos.y <= size.y)
        {
            draggingOver = clip;
            break;
        }
    }

    if (draggingOver)
        event->acceptProposedAction();
    else
        event->ignore();
}
/*
#define FILE_DROP_CHUNK_SIZE 30*1024*1024 // 30MB

FileReaderAsync::FileReaderAsync(ByteCodeRunner *owner, QUrl url, QMimeType type, QRegExp *mimeRegExp) : NativeMethodHost(owner), owner(owner), url(url), type(type), mimeRegExp(mimeRegExp) {
    offset = 0;
    mimeTypes = new QMimeDatabase();
    file = new QFile(url.toLocalFile());
}

void FileReaderAsync::readFile() {
    RUNNER_VAR = owner;

    if (file->open(QIODevice::ReadOnly))
    {
        readChunk();
    } else {
        RUNNER_DefSlots1(error);
        WITH_RUNNER_LOCK_DEFERRED(RUNNER);

        error = RUNNER->AllocateString("Cannot open file " + url.fileName());

        RUNNER->EvalFunction(draggingOver->getFileDropErrorCallback(), 1, error);

        file->close();

        emit loadDone();
    }
}

void FileReaderAsync::readChunk() {
    if (file->pos() == file->size()) {
        emit loadDone();
        return;
    }

    offset += FILE_DROP_CHUNK_SIZE;

    if (offset > file->size())
        offset = file->size();

    RUNNER_VAR = owner;
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    QByteArray blob = file->read(FILE_DROP_CHUNK_SIZE);
    file->seek(offset);

    if (!type.isValid())
        type = mimeTypes->mimeTypeForFileNameAndData(url.toLocalFile(), blob);

    if (mimeRegExp->indexIn(type.name(), 0) != -1) {
        QString dataUrl = "data:" + type.name() + ";base64," + blob.toBase64(QByteArray::Base64Encoding);

        RUNNER_DefSlots2(slot1, slot2);

        slot1 = RUNNER->AllocateString(url.fileName());
        slot2 = RUNNER->AllocateString(dataUrl);

        RUNNER->EvalFunction(draggingOver->getFileDropDataCallback(), 3, slot1, slot2,
                             RUNNER->AllocateNativeClosure(readChunk_native, "readChunk_native", 0, this, 0));
    }
}

StackSlot FileReaderAsync::readChunk_native(RUNNER_ARGS, void* data) {
    FileReaderAsync *reader = static_cast<FileReaderAsync*>(data);

    // Run readChunk asynchroniusly to prevent recursive call of readChunk and memory overloading
    QMetaObject::invokeMethod(reader, "readChunk", Qt::QueuedConnection);

    RETVOID;
}*/

void QGLRenderSupport::dropEvent(QDropEvent *event)
{
    if (draggingOver) {
        event->acceptProposedAction();

        const QMimeData *data = event->mimeData();

        if (data->hasUrls()) {
            QList<QUrl> urlList = data->urls();

            int filesLimit = min(draggingOver->getFilesCountDroppable(), urlList.length());

            if (filesLimit < 0)
                filesLimit = urlList.length();

            RUNNER_VAR = getFlowRunner();
            WITH_RUNNER_LOCK_DEFERRED(RUNNER);

            RUNNER_DefSlots1(fileArray);
            fileArray = RUNNER->AllocateArray(filesLimit);

            for (int i = 0; i < filesLimit; ++i) {
                QString path = urlList.at(i).toLocalFile();

                FlowFile *file = new FlowFile(RUNNER, path.toStdString());

                RUNNER->SetArraySlot(fileArray, i, RUNNER->AllocNative(file));
            }

            RUNNER->EvalFunction(draggingOver->getFileDropDoneCallback(), 1, fileArray);
        }
    } else {
        event ->ignore();
    }
}

void QGLRenderSupport::addFileDropClip(GLClip *clip)
{
    FileDropClips.insert(clip);
}

void QGLRenderSupport::eraseFileDropClip(GLClip *clip)
{
    FileDropClips.erase(clip);
}

void QGLRenderSupport::showFullScreen()
{
    qobject_cast<MainWindow*>(this->parent())->showFullScreen();
}

void QGLRenderSupport::hideFullScreen()
{
    qobject_cast<MainWindow*>(this->parent())->showNormal();
}

void QGLRenderSupport::focusInEvent (QFocusEvent * event )
{
   QWidget::focusInEvent(event);

   updateLastUserAction();
   getFlowRunner()->NotifyPlatformEvent(PlatformApplicationResumed);
}

void QGLRenderSupport::focusOutEvent (QFocusEvent * event )
{
   QWidget::focusInEvent(event);

   updateLastUserAction();
   getFlowRunner()->NotifyPlatformEvent(PlatformApplicationSuspended);
}

NativeFunction *QGLRenderSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "Native."

    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getApplicationPath, 0)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, setClipboard, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getClipboard, 0)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getClipboardToCB, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getClipboardFormat, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, setCurrentDirectory, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getCurrentDirectory, 0)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, quit, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, onQuit, 1)

#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "RenderSupport."

    TRY_USE_NATIVE_METHOD_NAME(QGLRenderSupport, setWindowTitleNative,"setWindowTitle", 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, setFavIcon, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, takeSnapshot, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, takeSnapshotBox, 5)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getSnapshot, 0)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getSnapshotBox, 4)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getScreenPixelColor, 2)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, setNativeTabEnabled, 1)

    TRY_USE_NATIVE_METHOD(QGLRenderSupport, setFocus, 2)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, getFocus, 1)

    TRY_USE_NATIVE_METHOD(QGLRenderSupport, onFullScreen, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, toggleFullScreen, 1)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, isFullScreen, 0)
    TRY_USE_NATIVE_METHOD(QGLRenderSupport, emitKeyEvent, 8)

    //QT only GLClip functionalities
    TRY_USE_OBJECT_METHOD(GLClip, addFileDropListener, 4)

    return GLRenderSupport::MakeNativeFunction(name, num_args);
}

StackSlot QGLRenderSupport::removeQuitListener_native(RUNNER_ARGS, void *data)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_id = slot[0].GetInt();

    if (QGLRenderSupport *rs = static_cast<QGLRenderSupport*>(data)) {
        QMetaObject::Connection c = rs->quitConnections[cb_id];

        RUNNER->ReleaseRoot(cb_id);
        disconnect(c);

        rs->quitConnections.erase(cb_id);
    }

    RETVOID;
}

StackSlot QGLRenderSupport::onQuit(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_id = RUNNER->RegisterRoot(cb);

    auto c = connect(qApp, &QCoreApplication::aboutToQuit, [cb_id, RUNNER]() {
        WITH_RUNNER_LOCK_DEFERRED(RUNNER);

        RUNNER->EvalFunction(RUNNER->LookupRoot(cb_id), 0, NULL);
    });

    quitConnections[cb_id] = c;

    return RUNNER->AllocateNativeClosure(removeQuitListener_native, "onQuit$disposer", 1, this, 1, StackSlot::MakeInt(cb_id));
}

StackSlot QGLRenderSupport::removeFullScreenChangeListener_native(RUNNER_ARGS, void *data)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_id = slot[0].GetInt();

    if (QGLRenderSupport *rs = static_cast<QGLRenderSupport*>(data)) {
        QMetaObject::Connection c = rs->fullScreenConnections[cb_id];

        RUNNER->ReleaseRoot(cb_id);
        disconnect(c);

        rs->fullScreenConnections.erase(cb_id);
    }

    RETVOID;
}

StackSlot QGLRenderSupport::toggleFullScreen(RUNNER_ARGS)
{
    RUNNER_PopArgs1(fs);
    RUNNER_CheckTag(TBool, fs);

    if (fs.GetBool()) {
        showFullScreen();
    } else {
        hideFullScreen();
    }

    RETVOID;
}

StackSlot QGLRenderSupport::onFullScreen(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);

    int cb_id = RUNNER->RegisterRoot(cb);
    auto c = connect(qobject_cast<MainWindow*>(this->parent()), &MainWindow::windowStateChanged, [cb_id, RUNNER](Qt::WindowStates windowState) {
        WITH_RUNNER_LOCK_DEFERRED(RUNNER);

        RUNNER->EvalFunction(RUNNER->LookupRoot(cb_id), 1, StackSlot::MakeBool(windowState & Qt::WindowFullScreen));
    });

    fullScreenConnections[cb_id] = c;

    return RUNNER->AllocateNativeClosure(removeFullScreenChangeListener_native, "onFullScreen$disposer", 1, this, 1, StackSlot::MakeInt(cb_id));
}

StackSlot QGLRenderSupport::isFullScreen(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS

    return StackSlot::MakeBool(qobject_cast<MainWindow*>(this->parent())->windowState() == Qt::WindowFullScreen);
}

StackSlot QGLRenderSupport::emitKeyEvent(RUNNER_ARGS)
{
    RUNNER_PopArgs8(clip, event_name, key, ctrl, shift, alt, meta, key_code);
    RUNNER_CheckTag(TString, event_name);
    RUNNER_CheckTag(TString, key);
    RUNNER_CheckTag(TBool, ctrl);
    RUNNER_CheckTag(TBool, shift);
    RUNNER_CheckTag(TBool, alt);
    RUNNER_CheckTag(TBool, meta);
    RUNNER_CheckTag(TInt, key_code);
    UNUSED(clip);

    std::string event = encodeUtf8(RUNNER->GetString(event_name));
    QEvent::Type type = QEvent::KeyPress;
    Qt::Key qt_key = FlowKeyCodeToQt(key_code.GetInt());

    if (qt_key != Qt::Key_Control && qt_key != Qt::Key_Shift && qt_key != Qt::Key_Alt && qt_key != Qt::Key_Meta) {
        int modifier = Qt::NoModifier;

        if (ctrl.GetBool()) {
            modifier += Qt::CTRL;
        }

        if (shift.GetBool()) {
            modifier += Qt::SHIFT;
        }

        if (alt.GetBool()) {
            modifier += Qt::ALT;
        }

        if (meta.GetBool()) {
            modifier += Qt::META;
        }

        if (event == "keydown")
            type = QEvent::KeyPress;
        else if (event == "keyup")
            type = QEvent::KeyRelease;

        QWidget* target = this;

        for (std::map<GLClip*, QWidget*>::iterator it = NativeWidgets.begin(); it != NativeWidgets.end(); it++ ) {
            if (it->second->hasFocus()) {
                target = it->second;
            }
        }

        QKeyEvent* key_event = new QKeyEvent(type, qt_key, (Qt::KeyboardModifier) modifier, unicode2qt(RUNNER->GetString(key)));
        QCoreApplication::postEvent(target, key_event);
    }

    RETVOID;
}

StackSlot QGLRenderSupport::getApplicationPath(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    return RUNNER->AllocateString(QCoreApplication::applicationFilePath());
}

StackSlot QGLRenderSupport::setClipboard(RUNNER_ARGS)
{
    RUNNER_PopArgs1(string);
    QString arg = unicode2qt(RUNNER->GetString(string));

    QApplication::clipboard()->setText(arg, QClipboard::Clipboard);

    RETVOID;
}

StackSlot QGLRenderSupport::getClipboard(RUNNER_ARGS)
{
	IGNORE_RUNNER_ARGS
    return RUNNER->AllocateString(QApplication::clipboard()->text(QClipboard::Clipboard));
}

StackSlot QGLRenderSupport::getClipboardToCB(RUNNER_ARGS)
{
    StackSlot &callback = RUNNER_ARG(0);
    RUNNER->EvalFunction(callback, 1, getClipboard(RUNNER, NULL));
    RETVOID;
}

StackSlot QGLRenderSupport::getClipboardFormat(RUNNER_ARGS)
{
    RUNNER_PopArgs1(mimetype);
    RUNNER_CheckTag1(TString, mimetype);

    QString type = RUNNER->GetQString(mimetype);

    if (type == "text")
        type = "text/plain";
    else if (type == "image")
        type = "image/*";
    else if (type == "html")
        type = "text/html";
    else if (type == "urls")
        type = "text/uri-list";

    const QMimeData *data = QApplication::clipboard()->mimeData(QClipboard::Clipboard);

    if (type.startsWith("image") && data->hasImage())
    {
        QImage image = data->imageData().value<QImage>();

        QBuffer *image_buffer = new QBuffer();
        image_buffer->open(QIODevice::ReadWrite);
        QImageWriter *writer = new QImageWriter(image_buffer, "PNG");
        writer->write(image);

        QByteArray bytes_arr = image_buffer->buffer();

        int n = bytes_arr.size();
        unicode_char * unicode = new unicode_char[n];
        for (int i = 0; i != n; ++i) {
            unicode[i] = bytes_arr[i];
        }

        image_buffer->close();
        delete writer;
        delete image_buffer;

        return RUNNER->AllocateString(unicode, n);
    }

    QByteArray byte_data = data->data(type);

    int n = byte_data.size();
    unicode_char * unicode = new unicode_char[n];
    for (int i = 0; i != n; ++i) {
        unicode[i] = byte_data[i];
    }

    return RUNNER->AllocateString(unicode, n);
}

StackSlot QGLRenderSupport::setCurrentDirectory(RUNNER_ARGS)
{
    RUNNER_PopArgs1(_path);
    RUNNER_CheckTag1(TString, _path);

    QString path = unicode2qt(RUNNER->GetString(_path));
    QDir::setCurrent(path);

    RETVOID;
}

StackSlot QGLRenderSupport::getCurrentDirectory(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    QString path = QDir::currentPath();

    return RUNNER->AllocateString(path);
}

StackSlot QGLRenderSupport::setWindowTitleNative(RUNNER_ARGS)
{
    RUNNER_PopArgs1(string);
    RUNNER_CheckTag1(TString, string);

    QString arg = unicode2qt(RUNNER->GetString(string));

    windowTitle = arg.toStdString();
    window()->setWindowTitle(windowTitle.c_str());

    RETVOID;
}

StackSlot QGLRenderSupport::setFavIcon(RUNNER_ARGS)
{
	IGNORE_RUNNER_ARGS;
    RETVOID;
}

StackSlot QGLRenderSupport::quit(RUNNER_ARGS) {
    RUNNER_PopArgs1(rawcode);
    RUNNER_CheckTag(TInt, rawcode);

    // Unless there is an event handler in action, quit does not work
    exitCode = rawcode.GetInt();
    QTimer::singleShot(1, this, SLOT(doQuit()));

    RETVOID;
}

void QGLRenderSupport::doQuit() {
    QCoreApplication::exit(exitCode);
}

StackSlot QGLRenderSupport::takeSnapshot(RUNNER_ARGS) {
    RUNNER_PopArgs1(path)
    RUNNER_CheckTag(TString, path)

    QImage screen = grab().toImage();
    QString full_path = getFullResourcePath(unicode2qt(RUNNER->GetString(path)));

    // Make sure the full directory path exists
    QDir d = QFileInfo(full_path).absoluteDir();
    if (!d.exists(d.absolutePath())) {
        d.mkpath(d.absolutePath());
    }
    screen.save(full_path);
    RETVOID;
}

StackSlot QGLRenderSupport::takeSnapshotBox(RUNNER_ARGS) {
    RUNNER_PopArgs5(path, x, y, w, h)
    RUNNER_CheckTag(TString, path)
    RUNNER_CheckTag(TInt, x)
    RUNNER_CheckTag(TInt, y)
    RUNNER_CheckTag(TInt, w)
    RUNNER_CheckTag(TInt, h)

    QImage screen = grab().toImage().copy(QRect(x.GetInt(), y.GetInt(), w.GetInt(), h.GetInt()));
    QString full_path = getFullResourcePath(unicode2qt(RUNNER->GetString(path)));

    // Make sure the full directory path exists
    QDir d = QFileInfo(full_path).absoluteDir();
    if (!d.exists(d.absolutePath())) {
        d.mkpath(d.absolutePath());
    }
    screen.save(full_path);
    RETVOID;
}


StackSlot QGLRenderSupport::getSnapshot(RUNNER_ARGS) {

    IGNORE_RUNNER_ARGS;

    QImage image = grab().toImage();
    QByteArray byteArray;
    QBuffer buffer(&byteArray);
    image.save(&buffer, "PNG");
    QString imgBase64 = "data:image/png;base64," + QString::fromLatin1(byteArray.toBase64().data());

    return RUNNER->AllocateString(imgBase64);
}

StackSlot QGLRenderSupport::getSnapshotBox(RUNNER_ARGS) {
    RUNNER_PopArgs4(x, y, w, h)
    RUNNER_CheckTag(TInt, x)
    RUNNER_CheckTag(TInt, y)
    RUNNER_CheckTag(TInt, w)
    RUNNER_CheckTag(TInt, h)

    QImage image = grab().toImage().copy(QRect(x.GetInt(), y.GetInt(), w.GetInt(), h.GetInt()));
    QByteArray byteArray;
    QBuffer buffer(&byteArray);
    image.save(&buffer, "PNG");
    QString imgBase64 = "data:image/png;base64," + QString::fromLatin1(byteArray.toBase64().data());

    return RUNNER->AllocateString(imgBase64);
}

StackSlot QGLRenderSupport::getScreenPixelColor(RUNNER_ARGS) {
    RUNNER_PopArgs2(x,y);
    RUNNER_CheckTag2(TInt, x, y);

    QImage screen = grab().toImage();

    if (x.GetInt() < 0 || x.GetInt() >= screen.width() || y.GetInt() < 0 || y.GetInt() >= screen.height())
        return StackSlot::MakeInt(0);

    QRgb color = screen.pixel(x.GetInt(), y.GetInt());

    return StackSlot::MakeInt(color & 0xFFFFFF);
}

StackSlot QGLRenderSupport::setNativeTabEnabled(RUNNER_ARGS)
{
    RUNNER_PopArgs1(enabled);
    RUNNER_CheckTag1(TBool, enabled);

    TabOrderingEnabled = enabled.GetBool();

    RETVOID;
}

const QString QGLRenderSupport::getFullResourcePath(QString path)
{
    if(!QDir::isAbsolutePath(path)) {
        if (QDir(ResourceBase).exists(path)) {
            path = ResourceBase + path;
        } else {
            path = FlowBase + path;
        }
    }

    return path;
}
