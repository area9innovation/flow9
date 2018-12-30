#ifndef HTTPSUPPORT_H
#define HTTPSUPPORT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QList>
#include <QUrlQuery>
#include <QHttpMultiPart>

#ifdef QT_GUI_LIB
#include <QFileDialog>
#endif

#include "ByteCodeRunner.h"
#include "utils/flowfilestruct.h"
#include "utils/AbstractHttpSupport.h"

class QFileSystemInterface;

class QtHttpSupport : public QObject, public AbstractHttpSupport
{
    Q_OBJECT

    friend class QFileSystemInterface;

#ifdef QT_GUI_LIB
    QWidget *window;
    QFileDialog *dialog;
    QString dialog_dir;
#endif

    QNetworkAccessManager *manager;
    QHash<QNetworkReply*, int> request_map;

    void removeDialog(bool now = false);

    void setRequestHeaders(QNetworkRequest& request, HttpRequest::T_SMap& headers);
    void setQueryParameters(QUrlQuery& query,HttpRequest::T_SMap& parameters);

    void setHttpParametersPart(QHttpMultiPart* multiPart, HttpRequest::T_SMap& parameters);
    void setHttpAttachmentsPart(QHttpMultiPart* multiPart, HttpRequest::T_SMap& attachments);

    void setHttpFlowFilePart(QHttpMultiPart* multiPart, FlowFile* flowFile);

public:
#ifdef QT_GUI_LIB
    QtHttpSupport(ByteCodeRunner* runner, QWidget *window = NULL);
#else
    QtHttpSupport(ByteCodeRunner* runner, QObject *parent = NULL);
#endif
    ~QtHttpSupport();

protected:
    virtual void doRequest(HttpRequest &rq);
    void doUploadFlowFile(HttpRequest &rq, FlowFile* flowFile);

    virtual bool doSelectFile(HttpRequest &rq);

    virtual void doCancelSelect();
    virtual void doCancelRequest(HttpRequest &rq);


private slots:
    void handleFinished(QNetworkReply* reply);
    void downloadProgress(qint64 bytesReceived, qint64 bytesTotal);

#ifdef QT_GUI_LIB
    void selectAccepted();
    void selectRejected();
#endif
};

#endif // HTTPSUPPORT_H
