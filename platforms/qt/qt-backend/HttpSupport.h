#ifndef HTTPSUPPORT_H
#define HTTPSUPPORT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QList>

#include "core/ByteCodeRunner.h"
#include "utils/AbstractHttpSupport.h"

class QtHttpSupport : public QObject, public AbstractHttpSupport
{
    Q_OBJECT

    QNetworkAccessManager *manager;
    QHash<QNetworkReply*, int> request_map;

    void setRequestHeaders(QNetworkRequest& request, HttpRequest::T_SMap& headers);
public:
    QtHttpSupport(ByteCodeRunner* runner);
    ~QtHttpSupport();

protected:
    virtual void doRequest(HttpRequest &rq);
    virtual void doCancelRequest(HttpRequest &rq);

private slots:
    void handleFinished(QNetworkReply* reply);
    void downloadProgress(qint64 bytesReceived, qint64 bytesTotal);
};

#endif // HTTPSUPPORT_H
