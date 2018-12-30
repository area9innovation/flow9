#include "QGLWebPage.h"


QGLWebPage::QGLWebPage(QGLRenderSupport *rs, QWebEngineView *parent) : QWebEnginePage(parent), owner(rs)
{
    channel = new QWebChannel(this);
    delegate = new QWebViewDelegate(this, rs, parent);
    channel->registerObject(QStringLiteral("flow"), delegate);

    setWebChannel(channel);
}

void QGLWebPage::javaScriptConsoleMessage(JavaScriptConsoleMessageLevel level, const QString & message, int lineNumber, const QString & sourceID)
{
    QString level_str = "";
    switch(level)
    {
        case QWebEnginePage::InfoMessageLevel: level_str = "info"; break;
        case QWebEnginePage::ErrorMessageLevel: level_str = "error"; break;
        case QWebEnginePage::WarningMessageLevel: level_str = "warning"; break;
    }

    QString source = sourceID.isEmpty() ? "?" : sourceID;
    owner->getFlowRunner()->flow_err << "JS " << encodeUtf8(qt2unicode(level_str)) << " " << encodeUtf8(qt2unicode(source)) << ": " << lineNumber << ": " << encodeUtf8(qt2unicode(message)) << std::endl;
}
