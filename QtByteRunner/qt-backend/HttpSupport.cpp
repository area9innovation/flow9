#include "HttpSupport.h"
#include "core/RunnerMacros.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QEventLoop>
#include <QFileInfo>
#include <QMimeDatabase>

#ifdef QT_GUI_LIB
QtHttpSupport::QtHttpSupport(ByteCodeRunner *runner, QWidget *window)
#else
QtHttpSupport::QtHttpSupport(ByteCodeRunner *runner, QObject *window)
#endif
    : QObject(window), AbstractHttpSupport(runner),
#ifdef QT_GUI_LIB
      window(window), dialog(NULL),
#endif
      manager(new QNetworkAccessManager(this))
{
    connect(manager, SIGNAL(finished(QNetworkReply*)), this, SLOT(handleFinished(QNetworkReply*)));
}

QtHttpSupport::~QtHttpSupport()
{
    delete manager;
#ifdef QT_GUI_LIB
    delete dialog;
#endif
}

void QtHttpSupport::setRequestHeaders(QNetworkRequest& request, HttpRequest::T_SMap& headers)
{
    for (HttpRequest::T_SMap::iterator it = headers.begin(); it != headers.end(); ++it) {
        request.setRawHeader(unicode2qt(it->first).toLatin1(), unicode2qt(it->second).toUtf8());
    }
}

void QtHttpSupport::setQueryParameters(QUrlQuery& query, HttpRequest::T_SMap& parameters)
{
    for (HttpRequest::T_SMap::iterator it = parameters.begin(); it != parameters.end(); ++it) {
        query.addQueryItem(unicode2qt(it->first), QUrl::toPercentEncoding(unicode2qt(it->second)));
    }
}

void QtHttpSupport::setHttpParametersPart(QHttpMultiPart* multiPart, HttpRequest::T_SMap& parameters)
{
    for (HttpRequest::T_SMap::iterator it = parameters.begin(); it != parameters.end(); ++it) {
        QHttpPart requestPart;

        requestPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"" + unicode2qt(it->first) + "\""));
        requestPart.setBody(QUrl::toPercentEncoding(unicode2qt(it->second).toUtf8()));

        multiPart->append(requestPart);
    }
}

void QtHttpSupport::setHttpAttachmentsPart(QHttpMultiPart* multiPart, HttpRequest::T_SMap& attachments)
{
    QMimeDatabase *mimeDatabase = new QMimeDatabase();
    for (HttpRequest::T_SMap::iterator it = attachments.begin(); it!= attachments.end(); ++it) {
        QHttpPart attachmentPart;

        QFile *file = new QFile(unicode2qt(it->second));
        QFileInfo info = QFileInfo(*file);
        QVariant mimeType = mimeDatabase->mimeTypeForFile(info).name();

        if (!file->open(QIODevice::ReadOnly)) {
            getFlowRunner()->flow_err << "Couldn't open file for uploading " + info.filePath().toStdString() << endl;
            continue;
        }

        attachmentPart.setHeader(QNetworkRequest::ContentTypeHeader, mimeType);
        attachmentPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"" + unicode2qt(it->first) + "\"; filename=\"" + info.fileName() + "\""));
        attachmentPart.setBodyDevice(file);
        file->setParent(multiPart);

        multiPart->append(attachmentPart);
    }

    delete mimeDatabase;
}

void QtHttpSupport::setHttpFlowFilePart(QHttpMultiPart *multiPart, FlowFile *flowFile)
{
    QMimeDatabase *mimeDatabase = new QMimeDatabase();
    QHttpPart attachmentPart;

    bool uploadWholeFile = flowFile->getOffset() <= 0 && flowFile->getEnd() >= flowFile->getFile()->size();

    QFile *file = flowFile->getFile();
    if (uploadWholeFile) {
        // We have to instantiate new QFile to close it only when QHttpPart read the QFile
        file = new QFile(flowFile->getFile()->fileName());
    }
    QFileInfo info = QFileInfo(*file);

    QString fileName = info.fileName();
    QString filePath = info.filePath();
    QVariant mimeType = mimeDatabase->mimeTypeForFile(info).name();

    if (!file->open(QIODevice::ReadOnly)) {
        getFlowRunner()->flow_err << "Couldn't open file for uploading " + info.filePath().toStdString() << endl;
        return;
    }

    attachmentPart.setHeader(QNetworkRequest::ContentTypeHeader, mimeType);
    attachmentPart.setHeader(QNetworkRequest::ContentDispositionHeader, QVariant("form-data; name=\"" + fileName + "\"; filename=\"" + fileName + "\""));

    if (uploadWholeFile) {
        attachmentPart.setBodyDevice(file);
        // Closes file when request is sent
        file->setParent(multiPart);
    } else {
        file->seek(flowFile->getOffset());
        QByteArray data = file->read(flowFile->getEnd() - flowFile->getOffset());
        attachmentPart.setBody(data);

        file->close();
    }

    multiPart->append(attachmentPart);

    delete mimeDatabase;
}

void QtHttpSupport::doUploadFlowFile(HttpRequest &rq, FlowFile *flowFile)
{
    QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
    QUrl url = base.resolved(QUrl(unicode2qt(rq.url)));

    QNetworkRequest request(url);

    QHttpMultiPart *multiPart = new QHttpMultiPart(QHttpMultiPart::FormDataType);

    // Set headers for HTTP request
    setRequestHeaders(request, rq.headers);

    // build parameters for request
    setHttpParametersPart(multiPart, rq.params);

    // Setup attachments for HTTP request
    setHttpFlowFilePart(multiPart, flowFile);

    if (getFlowRunner()->NotifyStubs)
        getFlowRunner()->flow_err << "Requesting URL: " << url.toString().toUtf8().data() << std::endl;

    QNetworkReply *reply;
#ifdef DEBUG_FLOW
    getFlowRunner()->flow_err << "Post data to " << url.toEncoded().data();
#endif
    reply = manager->post(request, multiPart);
    multiPart->setParent(reply);

    connect(reply, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(downloadProgress(qint64,qint64)));

    rq.aux_data = reply;
    request_map[reply] = rq.req_id;

    deliverTransferStarted(rq.req_id);
}

void QtHttpSupport::doRequest(HttpRequest &rq)
{
    QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
    QUrl url = base.resolved(QUrl(unicode2qt(rq.url)));

    QString method = unicode2qt(rq.method);
    QString payload = unicode2qt(rq.payload);

    QNetworkRequest request(url);

    // Set headers for HTTP request
    setRequestHeaders(request, rq.headers);

    if (getFlowRunner()->NotifyStubs)
        getFlowRunner()->flow_err << "Requesting URL: " << url.toString().toUtf8().data() << std::endl;

    QNetworkReply *reply = manager->sendCustomRequest(request, method.toLatin1(), QByteArray(payload.toStdString().c_str()));

    connect(reply, SIGNAL(downloadProgress(qint64,qint64)), this, SLOT(downloadProgress(qint64,qint64)));

    rq.aux_data = reply;
    request_map[reply] = rq.req_id;

    deliverTransferStarted(rq.req_id);
}

void QtHttpSupport::downloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    QNetworkReply * reply = (QNetworkReply*) sender();
    int id = request_map[reply];
    deliverProgress(id, bytesReceived, bytesTotal);
}

AbstractHttpSupport::HeadersMap parseQtResponseHeaders(QList<QNetworkReply::RawHeaderPair> headers)
{
    AbstractHttpSupport::HeadersMap headersMap = AbstractHttpSupport::HeadersMap();

    for (QList<QNetworkReply::RawHeaderPair>::iterator it = headers.begin(); it != headers.end(); ++it) {
        unicode_string name     = parseUtf8(it->first.toStdString());
        unicode_string header   = parseUtf8(it->second.toStdString());

        headersMap[name] = header;
    }

    return headersMap;
}

// handle HTTP response
void QtHttpSupport::handleFinished(QNetworkReply *reply)
{
    int id = request_map[reply];
    request_map.remove(reply);

    reply->deleteLater();

    if (id > 0) {
        // Handle HTTP redirects
        QUrl redirectUrl = reply->attribute(QNetworkRequest::RedirectionTargetAttribute).toUrl();
        if(reply->operation() == QNetworkAccessManager::GetOperation &&
                !redirectUrl.isEmpty() && redirectUrl != reply->request().url()) {
            QNetworkRequest new_request(reply->request());
            new_request.setUrl(redirectUrl);
            QNetworkReply * new_reply = manager->get(new_request);
            request_map[new_reply] = id;
            getRequestById(id)->aux_data = new_reply;

            return;
        }

        // handle status code first
        QVariant statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        int status = 0;
        if (statusCode.isValid()) {
            status = statusCode.toInt();
            deliverStatus(id, status);
        }

        QByteArray data = reply->readAll();
        // then check if there is an error and handle error or success
        if (reply->error() == QNetworkReply::NoError) {
            size_t half = data.size() / 2;

            deliverPartialData(id, data.data(), half, false);
            deliverPartialData(id, data.data() + half, data.size() - half, true);
        } else {
            if (status == 0) {
                status = reply->error();
                data   = reply->errorString().toUtf8();
            }

            deliverError(id, data.data(), data.size());
        }

        deliverResponse(id,
                        status,
                        parseQtResponseHeaders(reply->rawHeaderPairs()));
    }
}

bool QtHttpSupport::doSelectFile(HttpRequest &rq)
{
#ifdef QT_GUI_LIB
    if (!window)
        return false;

    QString filter = "";
    for (unsigned i = 0; i < rq.file_types.size(); i++)
        filter += (i ? " " : "") + unicode2qt(rq.file_types[i]);

    dialog = new QFileDialog(window, "Upload file", dialog_dir);
    dialog->setFileMode(QFileDialog::ExistingFile);
    dialog->setOption(QFileDialog::HideNameFilterDetails, false);
    if (!filter.isEmpty())
        dialog->setNameFilter("Specific files ("+filter+");;All files (*)");
    dialog->setWindowModality(Qt::WindowModal);

    connect(dialog, SIGNAL(accepted()), SLOT(selectAccepted()));
    connect(dialog, SIGNAL(rejected()), SLOT(selectRejected()));

/* Fix for drawing file dialog contents under Linux */
#ifdef __linux__
    connect(dialog, &QFileDialog::finished, [=](int v){window->setUpdatesEnabled(true);});
    window->setUpdatesEnabled(false);
#endif

    dialog->show();
    return true;
#else
    return false;
#endif
}

#ifdef QT_GUI_LIB
void QtHttpSupport::removeDialog(bool now)
{
    if (!dialog) return;

    dialog_dir = dialog->directory().absolutePath();

    if (now)
        delete dialog;
    else
        dialog->deleteLater();

    dialog = NULL;
}
#endif

void QtHttpSupport::doCancelSelect()
{
#ifdef QT_GUI_LIB
    removeDialog(true);
#endif
}

#ifdef QT_GUI_LIB
void QtHttpSupport::selectAccepted()
{
    QStringList files = dialog->selectedFiles();

    removeDialog();

    int id = getActiveFileSelection();
    HttpRequest *rq = getRequestById(id);

    if (files.count() != 1 || !rq) {
        deliverSelectCancel(id);
    } else {
        QFileInfo info(files[0]);
        QString name = info.fileName();
        qint64 size = info.size();

        if (deliverSelectOK(id, qt2unicode(name), int(size))) {
            rq->attachments[qt2unicode(info.fileName())] = qt2unicode(info.filePath());
            processRequest(*rq);
            doRequest(*rq);
        }
    }
}

void QtHttpSupport::selectRejected()
{
    removeDialog();

    deliverSelectCancel(getActiveFileSelection());
}
#endif

void QtHttpSupport::doCancelRequest(HttpRequest &rq)
{
    QNetworkReply *reply = (QNetworkReply*)rq.aux_data;

    if (request_map.contains(reply)) {
        reply->abort();
        reply->deleteLater();
        request_map.remove(reply);
    }
}
