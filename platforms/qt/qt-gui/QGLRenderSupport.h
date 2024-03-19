#ifndef QGLRENDERSUPPORT_H
#define QGLRENDERSUPPORT_H

#include "gl-gui/GLRenderSupport.h"
#include "font/Headers.h"
#include "qt-backend/HttpSupport.h"

#include <qmediaplayer.h>

#include <QOpenGLWidget>
#include <QNetworkAccessManager>
#include <QProgressDialog>
#include <QWebEngineView>
#include <QApplication>
#include <QVideoWidget>
#include <QMimeDatabase>
#include <QMimeType>

class QWebViewDelegate;
class VideoWidget;

/*
That is not necessary currently but we can keep the functionality for future.
class FileReaderAsync : public QObject, public NativeMethodHost {
    Q_OBJECT
private:
    ByteCodeRunner *owner;

    uint64_t offset;
    QMimeDatabase *mimeTypes;

    QFile *file;
    QUrl url;
    QMimeType type;
    QRegExp *mimeRegExp;

Q_SIGNALS:
    void loadDone();

public:
    FileReaderAsync(ByteCodeRunner *owner, QUrl url, QMimeType type, QRegExp *mimeRegExp);
    void readFile();
    Q_INVOKABLE void readChunk();

    static StackSlot readChunk_native(ByteCodeRunner*, StackSlot*, void*);
};
*/

class QGLRenderSupport : public QOpenGLWidget, public GLRenderSupport
{
    Q_OBJECT

    QString ResourceBase;
    QString FlowBase;

    typedef  std::set<GLClip*> T_FileDropClips;
    T_FileDropClips FileDropClips;

    std::map<int, QMetaObject::Connection> fullScreenConnections, quitConnections;
    std::map<GLClip*, QWidget*> NativeWidgets;
    std::map<QWidget*, GLClip*> NativeWidgetClips;

    QNetworkAccessManager *request_manager;
    QHash<QNetworkReply*, unicode_string> request_map;

    QProgressDialog *bc_download_progress;
    QNetworkReply *bc_reply;

    STL_HASH_MAP<TextFont, QFont*> FontsMap;

    // We can't get the QVideoWidget from the QVideoPlayer, so keep track of the mappings
    // QHash<QMediaPlayer*, QVideoWidget*> VideoPlayerMap;
    QHash<QMediaPlayer*, VideoWidget*> VideoPlayerMap;

    bool EmulatePanGesture;

    void addFileDropClip(GLClip *clip);
    void eraseFileDropClip(GLClip *clip);

    void showFullScreen();
    void hideFullScreen();

public:
    QGLRenderSupport(QWidget *parent, ByteCodeRunner *owner, bool fake_touch = false, bool transparent = false);

    bool no_qglfb;

    void setDPI(int dpi);

    void SetResourceBase(QString path) { ResourceBase = path; loadFontsFromFolder(path); }
    void SetFlowBase(QString path) { FlowBase = path; loadFontsFromFolder(path); }
    void LoadFont(std::string code, QString name);

    void StartBytecodeDownload(QUrl url);

    virtual bool loadAssetData(StaticBuffer *buffer, std::string name, size_t size);

    virtual bool loadSystemFont(FontHeader *header, TextFont textFont);
    virtual bool loadSystemGlyph(const FontHeader *header, GlyphHeader *info, StaticBuffer *pixels, TextFont textFont, ucs4_char code);

    FlowKeyEvent keyEventToFlowKeyEvent(FlowEvent event, QKeyEvent *info);
    void translateKeyEvent(FlowEvent event, QKeyEvent *info);
    void translateFlowKeyEvent(FlowKeyEvent event);

    void dispatchMouseEvent(FlowEvent, int x, int y);
    void dispatchMouseEventFromWidget(QWidget *widget, FlowEvent e, QMouseEvent* qe);
    void dragEnterEvent(QDragEnterEvent *);
    void dragMoveEvent(QDragMoveEvent *);
    void dropEvent(QDropEvent *);
    void mouseMoveEvent(QMouseEvent *);
    void mousePressEvent(QMouseEvent *);
    void mouseReleaseEvent(QMouseEvent *);
    void wheelEvent(QWheelEvent *event);

signals:
    void runnerReset(bool destructor);

#ifdef FLOW_DEBUGGER
    void clipDataChanged(GLClip *clip);
    void clipAboutToChangeParent(GLClip *clip, GLClip *newparent, GLClip *oldparent);
    void clipChangedParent(GLClip *clip, GLClip *newparent, GLClip *oldparent);
#endif

public slots:
    void debugHighlightClip(GLClip *clip) { setDebugHighlight(clip); }

private slots:
    void textFieldChanged();

    void handleFinished(QNetworkReply* reply);

    void videoStateChanged(QMediaPlayer::State state);
    void mediaStatusChanged(QMediaPlayer::MediaStatus status);
    void videoPositionChanged(int64_t position);
    void handleVideoError();

    void bytecodeDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void bytecodeDownloadFinished();

    void webPageLoaded(bool ok);
    void doQuit();

protected:
    std::string windowTitle;
    bool TabOrderingEnabled = false;
    int exitCode;
    bool gl_fake_touch;

    void initializeGL();
    void resizeGL(int w, int h);
    void paintGL();

    void loadFontsFromFolder(QString dir);

    bool loadPicture(unicode_string url, bool cache);
    bool loadPicture(unicode_string url, HttpRequest::T_SMap& headers, bool cache);

    void abortPictureLoading(unicode_string url);

    void keyPressEvent(QKeyEvent *);
    void keyReleaseEvent(QKeyEvent *);

    QImage paintSnapshot();

    void OnRunnerReset(bool inDestructor);
    void OnHostEvent(HostEvent);
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    bool doCreateNativeWidget(GLClip *clip, bool neww);
    void doDestroyNativeWidget(GLClip *clip);
    void doReshapeNativeWidget(GLClip *clip, const GLBoundingBox &bbox, float scale, float alpha);

    bool doCreateTextWidget(QWidget *&widget, GLTextClip *text_clip);
    bool doCreateVideoWidget(QWidget *&widget, GLVideoClip *video_clip);
    bool doCreateWebWidget(QWidget *&widget, GLWebClip *video_clip);
    StackSlot webClipHostCall(GLWebClip * clip, const unicode_string &name, const StackSlot & args);
    StackSlot webClipEvalJS(GLWebClip * clip, const unicode_string &code, StackSlot& cb);
    StackSlot variant2slot(QVariant var);
    void callflow(QWebEngineView * web_view, QVariantList args);
    friend class QWebViewDelegate;

    void onTextClipStateChanged(GLTextClip* clip);

    void doUpdateVideoPlay(GLVideoClip *clip);
    void doUpdateVideoPosition(GLVideoClip *clip);
    void doUpdateVideoVolume(GLVideoClip *clip);
    void doUpdateVideoPlaybackRate(GLVideoClip *clip);
    void doUpdateVideoFocus(GLVideoClip *clip, bool focus);

    void doRequestRedraw() { update(); }
    bool hasCursorSupport() { return true; }
    void doSetCursor(std::string name);
    void doOpenUrl(unicode_string, unicode_string);

    static StackSlot removeQuitListener_native(ByteCodeRunner*,StackSlot*,void*);
    static StackSlot removeFullScreenChangeListener_native(ByteCodeRunner*,StackSlot*, void *);
    static void readFile_native(ByteCodeRunner* runner, StackSlot*, QFile *file, QUrl url, QMimeDatabase *mimeTypes, QMimeType type, QRegExp *mimeRegExp, uint16_t offset);

    void setFocus(GLClip *clip, bool focus);
    void focusInEvent(QFocusEvent *event);
    void focusOutEvent(QFocusEvent *event);

    const QString getFullResourcePath(QString path);

#ifdef FLOW_DEBUGGER
    virtual void onClipDataChanged(GLClip *clip);
    virtual void onClipBeginSetParent(GLClip *child, GLClip *parent, GLClip *oldparent);
    virtual void onClipEndSetParent(GLClip *child, GLClip *parent, GLClip *oldparent);
#endif

private:
    DECLARE_NATIVE_METHOD(setClipboard)
    DECLARE_NATIVE_METHOD(getClipboard)
    DECLARE_NATIVE_METHOD(getClipboardToCB)
    DECLARE_NATIVE_METHOD(getClipboardFormat)
    DECLARE_NATIVE_METHOD(setWindowTitleNative)
    DECLARE_NATIVE_METHOD(setFavIcon)
    DECLARE_NATIVE_METHOD(quit)
    DECLARE_NATIVE_METHOD(takeSnapshot)
    DECLARE_NATIVE_METHOD(takeSnapshotBox)
    DECLARE_NATIVE_METHOD(getSnapshot)
    DECLARE_NATIVE_METHOD(getSnapshotBox)
    DECLARE_NATIVE_METHOD(getScreenPixelColor)
    DECLARE_NATIVE_METHOD(setNativeTabEnabled)

    DECLARE_NATIVE_METHOD(setFocus)
    DECLARE_NATIVE_METHOD(getFocus)

    DECLARE_NATIVE_METHOD(addFileDropListener)

    DECLARE_NATIVE_METHOD(setCurrentDirectory)
    DECLARE_NATIVE_METHOD(getCurrentDirectory)

    DECLARE_NATIVE_METHOD(getApplicationPath)
    DECLARE_NATIVE_METHOD(getApplicationArguments)

    DECLARE_NATIVE_METHOD(toggleFullScreen)
    DECLARE_NATIVE_METHOD(onFullScreen)
    DECLARE_NATIVE_METHOD(isFullScreen)
    DECLARE_NATIVE_METHOD(emitKeyEvent)

    DECLARE_NATIVE_METHOD(onQuit)
};

#endif // QGLRENDERSUPPORT_H
