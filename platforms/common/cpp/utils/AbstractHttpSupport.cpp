#include "AbstractHttpSupport.h"

#include "core/RunnerMacros.h"

#include <stdlib.h>
#include <fstream>
#include <sstream>

// 
ResponseEncoding defaultResponseEncoding = ResponseEncodingAuto;

AbstractHttpSupport::AbstractHttpSupport(ByteCodeRunner *owner) : NativeMethodHost(owner)
{
    next_http_request = 1;
}

HttpRequest *AbstractHttpSupport::getRequestById(int id)
{
    T_active_requests::iterator it = active_requests.find(id);
    return (it != active_requests.end() ? &it->second : NULL);
}

void AbstractHttpSupport::cancelRequest(int id)
{
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
        return unicode_string((unicode_char*)(pdata+2), (count-2)/FLOW_CHAR_SIZE);
    else
        return parseUtf8((const char*)buffer, count);
}

void AbstractHttpSupport::deliverDataBytes(int id, const void *buffer, unsigned count)
{
    HttpRequest *rq = getRequestById(id);

    if (rq->response_enc != ResponseEncodingByte)
        deliverData(id, parseDataBytes(buffer, count));
    else
        deliverData(id, unicode_string((unicode_char*)buffer, count/FLOW_CHAR_SIZE));
}

void AbstractHttpSupport::deliverData(int id, const unicode_char *data, unsigned count)
{
    WITH_RUNNER_LOCK_DEFERRED(getFlowRunner());

    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->data_cb.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER_DefSlots1(msg);

        msg = RUNNER->AllocateString(data, count);
        RUNNER->EvalFunction(rq->data_cb, 1, msg);
    }
}

void AbstractHttpSupport::deliverPartialData(int id, const void *buffer, unsigned count, bool last)
{
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
        if (rq->is_utf && rq->response_enc != ResponseEncodingByte)
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
    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);
    
    HttpRequest *rq = getRequestById(id);

    if (rq && !rq->status_cb.IsVoid()) {
        RUNNER->EvalFunction(rq->status_cb, 1, StackSlot::MakeInt(status));
    }

    getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
}

void AbstractHttpSupport::deliverResponse(int id, int status, HeadersMap headers)
{
    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);
    
    HttpRequest *rq = getRequestById(id);

    if (rq && rq->result_filename != "") {
        std::vector<char> tmp_buffer;

        if (rq->tmp_filename != "") {
            FILE* tmp_file = fopen(rq->tmp_filename.c_str(), "rb");

            fseek(tmp_file, 0, SEEK_END);
            tmp_buffer.resize(ftell(tmp_file));
            rewind(tmp_file);

            fread(tmp_buffer.data(), 1, tmp_buffer.size(), tmp_file);
            fclose(tmp_file);
        } else {
            tmp_buffer = rq->tmp_buffer;
        }

        FILE* result_file = fopen(rq->result_filename.c_str(), "wb");

        fwrite(tmp_buffer.data(), 1, tmp_buffer.size(), result_file);

        fclose(result_file);
        tmp_buffer.clear();
    }

    if (rq && !rq->response_cb.IsVoid()) {
        RUNNER_DefSlots1(data);

        if (rq->tmp_filename != "") {
            data = RUNNER->LoadFileAsString(rq->tmp_filename, true);
        } else {
            const unsigned char* pdata = (const unsigned char*)rq->tmp_buffer.data();
            size_t count = rq->tmp_buffer.size();

            if (count >= 2 && pdata[0] == 0xFF && pdata[1] == 0xFE) { // UTF-16 BOM
                data = RUNNER->AllocateString((unicode_char*)(pdata+2), (count-2)/FLOW_CHAR_SIZE);
            } else {
                switch (rq->response_enc)
                {
                    case ResponseEncodingUTF8:
                        data = RUNNER->AllocateString(parseUtf8Base((const char*)pdata, count, false));
                        break;
                    case ResponseEncodingUTF8js:
                        data = RUNNER->AllocateString(parseUtf8Base((const char*)pdata, count, true));
                        break;
                    case ResponseEncodingByte:
                        data = RUNNER->AllocateString((unicode_char*)pdata, count/FLOW_CHAR_SIZE+count%FLOW_CHAR_SIZE);
                        break;
                    default: /* ResponseEncodingAuto */
                        data = RUNNER->AllocateString(parseUtf8((const char*)pdata, count));
                }
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

    if (rq && !rq->done_cb.IsVoid()) {
        getFlowRunner()->EvalFunction(rq->done_cb, 0);

        active_requests.erase(id);
        getFlowRunner()->NotifyHostEvent(HostEventNetworkIO);
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

void AbstractHttpSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    active_requests.clear();
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
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, uploadNativeFile, 8);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, downloadFile, 4);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, downloadFileBinary, 4);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, downloadFileBinaryWithHeaders, 5);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, removeUrlFromCache, 1);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, clearUrlCache, 0);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, getAvailableCacheSpaceMb, 0);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, systemDownloadFile, 1);
    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, sendHttpRequestWithAttachments, 6);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, httpCustomRequestNative, 8);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, deleteAppCookies, 0);

    TRY_USE_NATIVE_METHOD(AbstractHttpSupport, setDefaultResponseEncoding, 1);

    return NULL;
}

void AbstractHttpSupport::decodeMap(RUNNER_VAR, HttpRequest::T_SMap *pmap, const StackSlot &smap)
{
    for (unsigned int i = 0; i < RUNNER->GetArraySize(smap); i++) {
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
    for (HttpRequest::T_FileMap::iterator it = rq.attachments.begin(); it != rq.attachments.end(); ++it)
    {
        FlowFile *flowFile = it->second;
        if(!flowFile->open())
            continue;
        std::vector<uint8_t> fileContent = flowFile->readBytes();
        flowFile->close();

        body << boundaryDataLine;
        body << "Content-Disposition: form-data; name=\"" << encodeUtf8(it->first) << "\";filename=\"" << flowFile->getFilepath() << "\"\r\n\r\n";
        body << std::string(fileContent.begin(), fileContent.end()) << "\r\n";
    }

    body << "--" + boundary + "--\r\n";

    std::string body_str = body.str();
    rq.payload = std::vector<uint8_t>(body_str.begin(), body_str.end());
}

unicode_string AbstractHttpSupport::urlencode(const unicode_string &url)
{
    static const char lookup[]= "0123456789ABCDEF";
    std::stringstream e;
    const std::string &s = encodeUtf8(url);
    for(size_t i = 0, ix = s.length(); i < ix; i++)
    {
        const char& c = s[i];

        if ( (48 <= c && c <= 57) ||//0-9
             (65 <= c && c <= 90) ||//abc...xyz
             (97 <= c && c <= 122) || //ABC...XYZ
             (c=='-' || c=='_' || c=='.' || c=='~')
        ) {
            e << c;
        } else {
            e << '%';
            e << lookup[ (c&0xF0)>>4 ];
            e << lookup[ (c&0x0F) ];
        }
    }
    return parseUtf8(e.str());
}

void AbstractHttpSupport::processRequest(HttpRequest &rq) {
    std::map<unicode_string,unicode_string>::iterator found = rq.headers.find(parseUtf8("Content-Type"));
    bool useMultipart = found != rq.headers.end() && encodeUtf8(found->second).find("multipart/form-data") == 0;
    if ((!rq.attachments.empty() || useMultipart) && rq.payload.empty()) {
        processAttachmentsAsMultipart(rq);
    } else {
        std::string url = encodeUtf8(rq.url);

        HttpRequest::T_SMap paramsEncoded;
        for (HttpRequest::T_SMap::iterator it = rq.params.begin(); it != rq.params.end(); ++it) {
            paramsEncoded[urlencode(it->first)] = urlencode(it->second);
        }

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
                paramsEncoded[key] = value;

                pos = ampPos != std::string::npos ? ampPos + 1 : querySize;
            }
        }

        unicode_string params;
        for (HttpRequest::T_SMap::iterator it = paramsEncoded.begin(); it != paramsEncoded.end(); ++it) {
            if (it != paramsEncoded.begin())
                params += unicode_string(1, '&');

            params += it->first + unicode_string(1, '=') + it->second;
        }

        if (encodeUtf8(rq.method) == "GET") {
			if (params.empty()) {
				// Avoid adding the ? on requests without parameters
				rq.url = parseUtf8(url);
			} else {
				std::string dash = dashPos != std::string::npos ? url.substr(dashPos, url.size() - dashPos) : "";
				rq.url = parseUtf8(url.substr(0, queryPos)) + unicode_char('?') + params + parseUtf8(dash);
			}
        } else if (rq.payload.empty()) {
            std::string params_str = encodeUtf8(params);
            rq.payload = std::vector<uint8_t>(params_str.begin(), params_str.end());
            rq.headers[parseUtf8("Content-Type")] = parseUtf8("application/x-www-form-urlencoded");
        }
    }

    if (!rq.payload.empty()) {
        std::ostringstream contentlength;
        contentlength << rq.payload.size();
        rq.headers[parseUtf8("Content-Length")] = parseUtf8(contentlength.str());
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
    RUNNER_PopArgs8(url, method, headers, params, data, responseEncoding, onResponse, async);
    RUNNER_CheckTag4(TString, url, method, data, responseEncoding);
    RUNNER_CheckTag2(TArray, headers, params);
    RUNNER_CheckTag1(TBool, async);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = RUNNER->GetString(method);
    rq.response_enc = GetResponseEncodingFromString(encodeUtf8(RUNNER->GetString(responseEncoding)));
    rq.response_enc = (rq.response_enc == ResponseEncodingAuto ? defaultResponseEncoding : rq.response_enc);
    std::string payload_string = encodeUtf8(RUNNER->GetString(data));
    rq.payload = std::vector<uint8_t>(payload_string.begin(), payload_string.end());
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



StackSlot AbstractHttpSupport::downloadFileBinary(RUNNER_ARGS)
{
    RUNNER_PopArgs4(url, pathToSave, onDone, onError);
    RUNNER_CheckTag2(TString, url, pathToSave);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.method = parseUtf8("GET");
    rq.response_enc = ResponseEncodingByte;
    rq.url = RUNNER->GetString(url);
    rq.result_filename = encodeUtf8(RUNNER->GetString(pathToSave));
    rq.done_cb = onDone;
    rq.error_cb = onError;

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}



StackSlot AbstractHttpSupport::downloadFileBinaryWithHeaders(RUNNER_ARGS)
{
    RUNNER_PopArgs5(url, headers, pathToSave, onDone, onError);
    RUNNER_CheckTag2(TString, url, pathToSave);
	RUNNER_CheckTag(TArray, headers);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.method = parseUtf8("GET");
    rq.response_enc = ResponseEncodingByte;
    rq.url = RUNNER->GetString(url);
    rq.result_filename = encodeUtf8(RUNNER->GetString(pathToSave));
    rq.done_cb = onDone;
    rq.error_cb = onError;
	
    decodeMap(RUNNER, &rq.headers, headers);

    processRequest(rq);
    doRequest(rq);

    RETVOID;
}

StackSlot AbstractHttpSupport::uploadNativeFile(RUNNER_ARGS)
{
    RUNNER_PopArgs8(file, url, params, headers, onOpen, onDataFn, onErrorFn, onProgressFn);
    RUNNER_CheckTag(TNative, file);
    RUNNER_CheckTag(TString, url);
    RUNNER_CheckTag2(TArray, headers, params);

    FlowFile *flowFile = RUNNER->GetNative<FlowFile*>(file);
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);

    int id = next_http_request++;

    HttpRequest &rq = active_requests[id];
    rq.req_id = id;
    rq.url = RUNNER->GetString(url);
    rq.method = parseUtf8("POST");

    rq.open_cb = onOpen;
    rq.data_cb = onDataFn;
    rq.error_cb = onErrorFn;
    rq.progress_cb = onProgressFn;

    decodeMap(RUNNER, &rq.headers, headers);
    decodeMap(RUNNER, &rq.params, params);

    unicode_string filename = parseUtf8(flowFile->getFilename());

    HttpRequest::T_SMap::iterator customNameField = rq.params.find(parseUtf8("uploadDataFieldName"));
    if(customNameField != rq.params.end()) {
        filename = customNameField->second;
        rq.params.erase(customNameField);
    }

    rq.attachments[filename] = flowFile;

    processRequest(rq);
    doRequest(rq);

    return RUNNER->AllocateNativeClosure(cbCancel, "uploadNativeFile$cancel", 0, this, 1, StackSlot::MakeInt(id));
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

    HttpRequest::T_SMap attachments_buffer;
    decodeMap(RUNNER, &attachments_buffer, attachments);
    for (HttpRequest::T_SMap::iterator it = attachments_buffer.begin(); it != attachments_buffer.end(); ++it)
    {
        rq.attachments[it->first] = new FlowFile(RUNNER, encodeUtf8(it->second));
    }

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

ResponseEncoding AbstractHttpSupport::GetResponseEncodingFromString(std::string str)
{
    if (str == "utf8_js")
        return ResponseEncodingUTF8js;
    else if (str == "utf8") {
        return ResponseEncodingUTF8;
    } else if (str == "byte")
        return ResponseEncodingByte;
    else if (str == "auto")
        return ResponseEncodingAuto;
    else {
        cout << "Invalid encoding '" << str << "'. Switched to 'auto'." << endl;
        return ResponseEncodingAuto;
    }
}

StackSlot AbstractHttpSupport::setDefaultResponseEncoding(RUNNER_ARGS)
{
    RUNNER_PopArgs1(tmp_value);
    RUNNER_CheckTag1(TString, tmp_value);

    defaultResponseEncoding = GetResponseEncodingFromString(encodeUtf8(RUNNER->GetString(tmp_value)));

    static const char lookup[] = "Default response encoding switched to ";

    switch (defaultResponseEncoding) {
        case ResponseEncodingUTF8:
            setUtf8JsStyleGlobalFlag(false);
            cout << lookup << "'" << "utf8 without surrogate pairs" << "'." << endl;
            break;
        case ResponseEncodingUTF8js:
            setUtf8JsStyleGlobalFlag(true);
            cout << lookup << "'" << "utf8 with surrogate pairs" << "'." << endl;
            break;
        case ResponseEncodingByte:
            setUtf8JsStyleGlobalFlag(false);
            cout << lookup << "'" << "raw byte" << "'." << endl;
            break;
        case ResponseEncodingAuto:
            setUtf8JsStyleGlobalFlag(false);
            cout << lookup << "'" << "auto" << "'." << endl;
            break;
        default:
            setUtf8JsStyleGlobalFlag(false);
            cout << "Invalid encoding '" << encodeUtf8(RUNNER->GetString(tmp_value)) << "'. Switched to 'auto'." << endl;
    }

    RETVOID;  
}
