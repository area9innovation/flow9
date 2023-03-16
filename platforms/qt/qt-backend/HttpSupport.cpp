#include "HttpSupport.h"
#include "core/RunnerMacros.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>

QtHttpSupport::QtHttpSupport(ByteCodeRunner *runner)
    : AbstractHttpSupport(runner), manager(new QNetworkAccessManager(this))
{
    connect(manager, SIGNAL(finished(QNetworkReply*)), this, SLOT(handleFinished(QNetworkReply*)));
}

QtHttpSupport::~QtHttpSupport()
{
    delete manager;
}

void QtHttpSupport::setRequestHeaders(QNetworkRequest& request, HttpRequest::T_SMap& headers)
{
    for (HttpRequest::T_SMap::iterator it = headers.begin(); it != headers.end(); ++it) {
        request.setRawHeader(unicode2qt(it->first).toLatin1(), unicode2qt(it->second).toUtf8());
    }
}

void QtHttpSupport::doRequest(HttpRequest &rq)
{
    QUrl base(unicode2qt(getFlowRunner()->getUrlString()));
    QUrl url = base.resolved(QUrl(unicode2qt(rq.url)));

    QString method = unicode2qt(rq.method);

    QNetworkRequest request(url);

    // Set headers for HTTP request
    setRequestHeaders(request, rq.headers);

    // Replies only. It indicates that the server is redirecting the request to a different URL.
    request.setAttribute(QNetworkRequest::RedirectionTargetAttribute, true);
    // Indicates whether the Network Access API should automatically follow a HTTP redirect response or not.
    // Currently redirects that are insecure, that is redirecting from "https" to "http" protocol, are not allowed.
    // In QT 6 this attribute is removed.
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    if (getFlowRunner()->NotifyStubs)
        getFlowRunner()->flow_err << "Requesting URL: " << url.toString().toUtf8().data() << std::endl;

    QNetworkReply *reply = manager->sendCustomRequest(request, method.toLatin1(), QByteArray(reinterpret_cast<const char*>(rq.payload.data()), rq.payload.size()));

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

void QtHttpSupport::doCancelRequest(HttpRequest &rq)
{
    QNetworkReply *reply = (QNetworkReply*)rq.aux_data;

    if (request_map.contains(reply)) {
        reply->abort();
        reply->deleteLater();
        request_map.remove(reply);
    }
}
