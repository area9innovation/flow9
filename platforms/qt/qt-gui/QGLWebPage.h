#ifndef QGLWEBPAGE_H
#define QGLWEBPAGE_H

#include <QList>
#include <QObject>
#include <QWebEnginePage>
#include <QWebChannel>
#include <QNetworkCookie>
#include <QNetworkCookieJar>

#include "QGLRenderSupport.h"


class QWebViewDelegate : public QObject
{
    Q_OBJECT
    QGLRenderSupport * rs;
    QWebEngineView * web_view;
public:
    QWebViewDelegate(QObject *owner, QGLRenderSupport *rs, QWebEngineView * web_view) : QObject(owner), rs(rs), web_view(web_view) {}
    Q_INVOKABLE void callflow(QVariantList args) { rs->callflow(web_view, args); }
};

class QGLWebPage : public QWebEnginePage
{
    Q_OBJECT
public:
    QGLWebPage(QGLRenderSupport *rs, QWebEngineView *parent = Q_NULLPTR);

private:
    QGLRenderSupport *owner;
    QWebViewDelegate *delegate;
    QWebChannel *channel;

protected:
    void javaScriptConsoleMessage(JavaScriptConsoleMessageLevel level, const QString & message, int lineNumber, const QString & sourceID);
};

#endif // QGLWEBPAGE_H
