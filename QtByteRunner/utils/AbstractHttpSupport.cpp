#include "AbstractHttpSupport.h"

#include "core/RunnerMacros.h"

#include <stdlib.h>
#include <fstream>
#include <sstream>

AbstractHttpSupport::AbstractHttpSupport(ByteCodeRunner *owner) : NativeMethodHost(owner)
{
    next_http_request = 1;
    active_file_selection = -1;
}

HttpRequest *AbstractHttpSupport::getRequestById(int id)
{
    T_active_requests::iterator it = active_requests.find(id);
    return (it != active_requests.end() ? &it->second : NULL);
}

void AbstractHttpSupport::cancelRequest(int id)
{
    if (active_file_selection == id) {
        doCancelSelect();
        active_file_selection = -1;
    }

    HttpRequest *rq = getRequestById(id);
    if (rq) {
        doCancelRequest(*rq);
        active_requests.erase(id);
    }
}

unicode_string AbstractHttpSupport::parseDataBytes(const void * buffer, size_t count)
{
    const unsigned char *pdata = (const unsigned char*)buffer;

    if (count >= 2 && pdata[0] == 0xFF && pdata[1] == 0xFE) // UTF-16 BOM
        return unicode_string((unicode_char*)(pdata+2), (count-2)/2);
    else
        return parseUtf8((const char*)buffer, count);
}

void AbstractHttpSupport::deliverDataBytes(int id, const void *buffer, unsigned count)
{
    deliverData(id, parseDataBytes(buffer, count));
}

void AbstractHttpSupport::deliverData(int id, const unicode_char *data, unsigned count)
{
    assert(id != active_file_selection);

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->data_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlots1(msg);

        msg = RUNNER->AllocateString(data, count);
        RUNNER->EvalFunction(rq->data_cb, 1, msg);
    }

    if (rq && !rq->done_cb.IsVoid()) {
        getFlowRunner()->EvalFunction(rq->done_cb, 0);

        active_requests.erase(id);
        getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
    }
}

void AbstractHttpSupport::deliverPartialData(int id, const void *buffer, unsigned count, bool last)
{
    assert(id != active_file_selection);

    HttpRequest *rq = getRequestById(id);
    if (!rq) return;

    if (rq->is_media_preload)
    {
        if (last)
            deliverData(id, (unicode_char*)NULL, 0);
        return;
    }

    if (!rq->tmp_file)
    {
        size_t pos = rq->tmp_buffer.size();
        rq->tmp_buffer.resize(pos+count);
        memcpy(rq->tmp_buffer.data()+pos, buffer, count);

        if (rq->tmp_buffer.size() >= MIN_MMAP_SIZE)
        {
            char fnbuf[1024];
#if defined(WIN32)
            rq->tmp_filename = tmpnam(fnbuf);
#else
            rq->tmp_filename = mkstemp(fnbuf);
#endif
            rq->tmp_file = MakeTemporaryFile(&rq->tmp_filename);

            if (!rq->tmp_file)
            {
                unicode_string errorMessage = parseUtf8("Could not open temporary file: " + rq->tmp_filename);
                deliverError(id, errorMessage.data(), errorMessage.size());
                return;
            }

            rq->is_utf = !(rq->tmp_buffer[0] == char(0xFF) && rq->tmp_buffer[1] == char(0xFE));
            int skip = (rq->is_utf ? 0 : 2);
            buffer = rq->tmp_buffer.data()+skip;
            count = rq->tmp_buffer.size()-skip;
        }
    }

    if (rq->tmp_file)
    {
        if (rq->is_utf)
        {
            unicode_string tmp;
            rq->tmp_parser.parse(tmp, (const char*)buffer, count);
            fwrite(tmp.data(), sizeof(unicode_char), tmp.size(), rq->tmp_file);
        }
        else
            fwrite(buffer, 1, count, rq->tmp_file);

        rq->tmp_buffer.clear();
    }

    if (last)
    {
        if (!rq->tmp_file)
        {
            deliverDataBytes(id, rq->tmp_buffer.data(), rq->tmp_buffer.size());
            return;
        }

        if (rq->is_utf && !rq->tmp_parser.is_complete())
            fwrite("?\0", 1, 2, rq->tmp_file);

        fclose(rq->tmp_file);
        rq->tmp_file = NULL;

        if (!rq->data_cb.IsVoid()) {
            WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

            RUNNER_VAR = getFlowRunner();
            RUNNER_DefSlots1(msg);

            msg = RUNNER->LoadFileAsString(rq->tmp_filename, true);

            RUNNER->EvalFunction(rq->data_cb, 1, msg);

            active_requests.erase(id);
            getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
        }
    }
}

void AbstractHttpSupport::deliverError(int id, const void * buffer, size_t count)
{
    assert(id != active_file_selection);

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->error_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlots1(msg);

        msg = RUNNER->AllocateString(parseDataBytes(buffer, count));
        RUNNER->EvalFunction(rq->error_cb, 1, msg);

        active_requests.erase(id);
        getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
    } else {
        rq->tmp_buffer.resize(count);
        memcpy(rq->tmp_buffer.data(), buffer, count);
    }
}

void AbstractHttpSupport::deliverStatus(int id, int status)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->status_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(rq->status_cb, 1, StackSlot::MakeInt(status));
    }

    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

void AbstractHttpSupport::deliverResponse(int id, int status, HeadersMap headers)
{
    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->response_cb.IsVoid()) {
        RUNNER_DefSlots1(data);

        if (rq->tmp_filename != "") {
            data = RUNNER->LoadFileAsString(rq->tmp_filename, true);
        } else {
            const unsigned char* pdata = (const unsigned char*)rq->tmp_buffer.data();
            size_t count = rq->tmp_buffer.size();

            if (count >= 2 && pdata[0] == 0xFF && pdata[1] == 0xFE) { // UTF-16 BOM
                data = RUNNER->AllocateString((unicode_char*)(pdata+2), (count-2)/2);
            } else {
                data = RUNNER->AllocateString(parseUtf8((const char*)pdata, count));
            }
        }

        int i = 0;
        StackSlot headersArray = RUNNER->AllocateArray(headers.size());
        for (std::map<unicode_string, unicode_string>::iterator it = headers.begin(); it != headers.end(); ++it) {
            StackSlot headerPair = RUNNER->AllocateArray(2);

            RUNNER->SetArraySlot(headerPair, 0, RUNNER->AllocateString(it->first));
            RUNNER->SetArraySlot(headerPair, 1, RUNNER->AllocateString(it->second));

            RUNNER->SetArraySlot(headersArray, i++, headerPair);
        }

        RUNNER->EvalFunction(rq->response_cb, 3, StackSlot::MakeInt(status), data, headersArray);
    }
}

void AbstractHttpSupport::deliverTransferStarted(int id)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->open_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(rq->open_cb, 0);
    }

    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

void AbstractHttpSupport::deliverProgress(int id, FlowDouble pos, FlowDouble total)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->progress_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(rq->progress_cb, 2, StackSlot::MakeDouble(pos), StackSlot::MakeDouble(total));
    }

    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

void AbstractHttpSupport::deliverSelectCancel(int id)
{
    assert(id == active_file_selection);
    active_file_selection = -1;

    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->cancel_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(rq->cancel_cb, 0);
    }

    active_requests.erase(id);
    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

bool AbstractHttpSupport::deliverSelectOK(int id, unicode_string name, int size)
{
    bool continueUploading = false;
    assert(id == active_file_selection);
    active_file_selection = -1;

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->select_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        StackSlot result = RUNNER->EvalFunction(rq->select_cb, 2,
            RUNNER->AllocateString(name), StackSlot::MakeInt(size));
        continueUploading = (result.IsBool() && result.GetBool());
    }
    return continueUploading;
}

void AbstractHttpSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    active_requests.clear();

    if (active_file_selection > 0)
        doCancelSelect();
    active_file_selection = -1;
}

void AbstractHttpSupport::flowGCObject(GarbageCollectorFn ref)
{
    ref << active_requests;
}

NativeFunction *AbstractHttpSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "HttpSupport."

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, httpRequest, 7);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, preloadMediaUrl, 3);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, uploadFile, 10);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, downloadFile, 4);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, removeUrlFromCache, 1);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, clearUrlCache, 0);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, getAvailableCacheSpaceMb, 0);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, systemDownloadFile, 1);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, sendHttpRequestWithAttachments, 6);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, httpCustomRequestNative, 7);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, deleteAppCookies, 0);

    return NULL;
}

void AbstractHttpSupport::decodeMap(RUNNER_VAR, HttpRequest::T_SMap *pmap, const StackSlot &smap)
{
    for (int i = 0; i < RUNNER->GetArraySize(smap); i++) {
        const StackSlot &map_item = RUNNER->GetArraySlot(smap,i);
        RUNNER_CheckTagVoid(TArray, map_item);

        unicode_string key = RUNNER->GetString(RUNNER->GetArraySlot(map_item,0));
        unicode_string value = RUNNER->GetString(RUNNER->GetArraySlot(map_item,1));
        (*pmap)[key] = value;
    }
}

void AbstractHttpSupport::processAttachmentsAsMultipart(HttpRequest& rq) {
    std::ostringstream body;

    // based on this code: https://gist.github.com/mombrea/8467128
    std::string boundary("*****");
    std::string boundaryDataLine = "--" + boundary + "\r\n";

    rq.headers[parseUtf8("Content-Type")] = parseUtf8("multipart/form-data; boundary=" + boundary);
    rq.headers[parseUtf8("Connection")] = parseUtf8("Keep-Alive");

    // loop for params
    for (HttpRequest::T_SMap::iterator it = rq.params.begin(); it != rq.params.end(); ++it)
    {
        body << boundaryDataLine;
        body << "Content-Disposition: form-data; name=\"" << encodeUtf8(it->first)
             << "\"\r\n\r\n" << encodeUtf8(it->second) << "\r\n";
    }

    // loop for attachments
    for (HttpRequest::T_SMap::iterator it = rq.attachments.begin(); it != rq.attachments.end(); ++it)
    {
        std::ifstream t(encodeUtf8(it->second).c_str());
        std::string fileData;

        if (t.peek() == std::ifstream::traits_type::eof())
            continue;

        t.seekg(0, std::ios::end);
        fileData.reserve(t.tellg());
        t.seekg(0, std::ios::beg);

        fileData.assign((std::istreambuf_iterator<char>(t)),
                   std::istreambuf_iterator<char>());

        body << boundaryDataLine;
        body << "Content-Disposition: form-data; name=\"" << encodeUtf8(it->first) << "\";filename=\"" << encodeUtf8(it->second) << "\"\r\n\r\n";
        body << fileData << "\r\n";
    }

    body << boundaryDataLine;

    body.seekp(0, std::ios::end);
    std::ostringstream sslength;
    sslength << body.tellp();
    rq.headers[parseUtf8("Content-Length")] = parseUtf8(sslength.str());

    rq.payload = parseUtf8(body.str());
}

void AbstractHttpSupport::processRequest(HttpRequest &rq) {
    if (!rq.attachments.empty() && rq.payload.empty()) {
        processAttachmentsAsMultipart(rq);
    } else {
        std::string url = encodeUtf8(rq.url);

        // Map url query parameters to rq.params
        size_t queryPos = url.find_first_of('?');
        size_t dashPos = url.find_first_of('#');

        if (queryPos != std::string::npos) {
            size_t querySize = dashPos == std::string::npos ? dashPos : dashPos - queryPos - 1;

            std::string query = url.substr(queryPos + 1, querySize);

            size_t pos = 0;
            while(pos < querySize) {
                size_t equalPos = query.find_first_of('=', pos);
                size_t ampPos = query.find_first_of('&', pos);

                unicode_string key = parseUtf8(query.substr(pos, equalPos - pos));
                unicode_string value = parseUtf8(query.substr(equalPos + 1, ampPos - equalPos - 1));
                rq.params[key] = value;

                pos = ampPos != std::string::npos ? ampPos + 1 : querySize;
            }
        }

        unicode_string params;
        for (HttpRequest::T_SMap::iterator it = rq.params.begin(); it != rq.params.end(); ++it) {
            if (it != rq.params.begin())
                params += unicode_string(1, '&');

            params += it->first + unicode_string(1, '=') + it->second;
        }

        if (encodeUtf8(rq.method) == "GET") {
            std::string dash = dashPos != std::string::npos ? url.substr(dashPos, url.size() - dashPos) : "";

            rq.url = parseUtf8(url.substr(0, queryPos)) + unicode_char('?') + params + parseUtf8(dash);
        } else if (rq.payload.empty()) {
            rq.payload = params;
            rq.headers[parseUtf8("Content-Type")] = parseUtf8("application/x-www-form-urlencoded");
        }
    }
}

StackSlot AbstractHttpSupport::httpRequest(RUNNER_ARGS)
{
    RUNNER_PopArgs7(url, postMethod, headers, params, onData, onError, onStatus);
    RUNNER_CheckTag1(TString, url);
    RUNNER_CheckTag1(TBool, postMethod);
    RUNNER_CheckTag2(TArray, headers, params);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);

    if (postMethod.GetBool()) {
        rq.method = parseUtf8("POST");
    } else {
        rq.method = parseUtf8("GET");
    }

    rq.data_cb = onData;
    rq.error_cb = onError;
    rq.status_cb = onStatus;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::httpCustomRequestNative(RUNNER_ARGS)
{
    RUNNER_PopArgs7(url, method, headers, params, data, onResponse, async);
    RUNNER_CheckTag3(TString, url, method, data);
    RUNNER_CheckTag2(TArray, headers, params);
    RUNNER_CheckTag1(TBool, async);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = RUNNER->GetString(method);
    rq.payload = RUNNER->GetString(data);
    rq.response_cb = onResponse;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::preloadMediaUrl(RUNNER_ARGS)
{
    RUNNER_PopArgs3(url, onDone, onError);
    RUNNER_CheckTag1(TString, url);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = parseUtf8("GET");
    rq.is_media_preload = true;
    rq.done_cb = onDone;
    rq.error_cb = onError;

    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::downloadFile(RUNNER_ARGS)
{
    RUNNER_PopArgs4(url, onData, onError, onProgress);
    RUNNER_CheckTag1(TString, url);
	
    int id = next_http_request++;
	
    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.method = parseUtf8("GET");
    rq.url = RUNNER->GetString(url);
    rq.data_cb = onData;
    rq.error_cb = onError;
    rq.progress_cb = onProgress;

    processRequest(rq);
    doRequest(rq);
	
    RETVOID;
}

StackSlot AbstractHttpSupport::uploadFile(RUNNER_ARGS)
{
    RUNNER_PopArgs10(url, params, headers, fileTypes, onOpen, onSelect, onData, onError, onProgress, onCancel);
    RUNNER_CheckTag1(TString, url);
    RUNNER_CheckTag3(TArray, params, headers, fileTypes);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;

    rq.url = RUNNER->GetString(url);
    rq.method = parseUtf8("POST");

    rq.open_cb = onOpen;
    rq.select_cb = onSelect;
    rq.data_cb = onData;
    rq.error_cb = onError;
    rq.progress_cb = onProgress;
    rq.cancel_cb = onCancel;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    for (int i = 0; i < RUNNER->GetArraySize(fileTypes); i++) {
        const StackSlot &item = RUNNER->GetArraySlot(fileTypes,i);
        rq.file_types.push_back(RUNNER->GetString(item));
    }

    if (active_file_selection > 0) {
        doCancelSelect();
        deliverSelectCancel(active_file_selection);
    }

    active_file_selection = id;
    if (!doSelectFile(rq))
        deliverSelectCancel(id);

    return RUNNER->AllocateNativeClosure(cbCancel, "uploadFile$cancel", 0, this, 1, StackSlot::MakeInt(id));
}

StackSlot AbstractHttpSupport::cbCancel(RUNNER_ARGS, void *ptr) {
    AbstractHttpSupport *self = static_cast<AbstractHttpSupport*>(ptr);
    self->cancelRequest(RUNNER->GetClosureSlot(RUNNER_CLOSURE,0).GetInt());
    RETVOID;
}

StackSlot AbstractHttpSupport::removeUrlFromCache(RUNNER_ARGS) {
    RUNNER_PopArgs1(url);
    RUNNER_CheckTag1(TString, url);
    doRemoveUrlFromCache(RUNNER->GetString(url));
    RETVOID;
}

StackSlot AbstractHttpSupport::clearUrlCache(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    doClearUrlCache();
    RETVOID;
}

StackSlot AbstractHttpSupport::getAvailableCacheSpaceMb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeInt(doGetAvailableCacheSpaceMb());
}

StackSlot AbstractHttpSupport::systemDownloadFile(RUNNER_ARGS) {
    RUNNER_PopArgs1(url);
    RUNNER_CheckTag1(TString, url);
    doSystemDownloadFile(RUNNER->GetString(url));
    RETVOID;
}

StackSlot AbstractHttpSupport::sendHttpRequestWithAttachments(RUNNER_ARGS) {
    RUNNER_PopArgs6(url, headers, params, attachments, onData, onError);
    RUNNER_CheckTag1(TString, url);
    RUNNER_CheckTag3(TArray, headers, params, attachments);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = parseUtf8("POST");
    rq.data_cb = onData;
    rq.error_cb = onError;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);
    decodeMap(RUNNER, &rq.attachments, attachments);

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::deleteAppCookies(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    doDeleteAppCookies();

    RETVOID;
}
