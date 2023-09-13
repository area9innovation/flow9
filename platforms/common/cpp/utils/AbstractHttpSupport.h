#ifndef ABSTRACT_HTTP_SUPPORT_H
#define ABSTRACT_HTTP_SUPPORT_H

#include "core/ByteCodeRunner.h"

#include "utils/flowfilestruct.h"

enum ResponseEncoding {
    ResponseEncodingAuto,
    ResponseEncodingUTF8,
    ResponseEncodingUTF8js,
    ResponseEncodingByte
};

extern ResponseEncoding defaultResponseEncoding;

struct HttpRequest {
    typedef std::map<unicode_string,unicode_string> T_SMap;
    typedef std::map<unicode_string,FlowFile*> T_FileMap;

    int req_id;

    unicode_string url;
    unicode_string method;
    unicode_string tmp_value;
    ResponseEncoding response_enc;
    std::vector<uint8_t> payload;
    T_SMap headers, params;
    T_FileMap attachments;

    bool is_media_preload;
    StackSlot data_cb, error_cb, status_cb, done_cb, response_cb;

    StackSlot open_cb, progress_cb;

    bool is_utf;
    std::string tmp_filename;
    std::vector<char> tmp_buffer;
    IncrementalUtf8Parser tmp_parser;
    FILE *tmp_file;

    std::string result_filename;

    void *aux_data;

    HttpRequest() {
        req_id = 0;
        is_media_preload = false;
        data_cb = error_cb = status_cb = done_cb = response_cb = StackSlot::MakeVoid();
        open_cb = progress_cb = StackSlot::MakeVoid();
        tmp_file = NULL;
        aux_data = NULL;
    }

    ~HttpRequest() {
        if (tmp_file) {
            fclose(tmp_file);
            remove(tmp_filename.c_str());
        }
    }
};

inline GarbageCollectorFn operator<<(GarbageCollectorFn ref, HttpRequest &rq) {
    ref << rq.data_cb << rq.error_cb << rq.status_cb << rq.response_cb << rq.done_cb;
    ref << rq.open_cb << rq.progress_cb;
    return ref;
}

class AbstractHttpSupport : public NativeMethodHost {
    typedef STL_HASH_MAP<int, HttpRequest> T_active_requests;

    int next_http_request;
    T_active_requests active_requests; // ROOT

    void decodeMap(ByteCodeRunner*, HttpRequest::T_SMap*, const StackSlot &marr);
    void cancelRequest(int id);

    unicode_string parseDataBytes(const void * buffer, size_t count);
    unicode_string urlencode(const unicode_string &url);


public:
    typedef std::map<unicode_string, unicode_string> HeadersMap;

    AbstractHttpSupport(ByteCodeRunner *owner);

    void deliverData(int id, const unicode_string &data) { deliverData(id, data.data(), data.size()); }
    void deliverData(int id, const unicode_char *data, unsigned count);

    // Auto-selects between UTF-8 and UTF-16
    void deliverDataBytes(int id, const void *buffer, unsigned count);
    void deliverPartialData(int id, const void *buffer, unsigned count, bool last);

    void deliverError(int id, const void * buffer, size_t count);
    void deliverStatus(int id, int status);

    void deliverResponse(int id, int status, HeadersMap headers);

    void deliverTransferStarted(int id);
    void deliverProgress(int id, FlowDouble pos, FlowDouble total);

protected:
    void OnRunnerReset(bool inDestructor);
    void flowGCObject(GarbageCollectorFn ref);

    HttpRequest *getRequestById(int id);

    void processAttachmentsAsMultipart(HttpRequest& request);
    void processRequest(HttpRequest& request);

    virtual void doRequest(HttpRequest &rq) = 0;

    virtual void doCancelRequest(HttpRequest &) {}
    
    virtual void doRemoveUrlFromCache(const unicode_string &/*url*/) {}
    virtual void doClearUrlCache() {}
    
    virtual int doGetAvailableCacheSpaceMb() { return -1; }

    virtual void doSystemDownloadFile(const unicode_string &/*url*/) {}

    virtual void doDeleteAppCookies() {}

    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    ResponseEncoding GetResponseEncodingFromString(std::string str);

private:
    static StackSlot cbCancel(ByteCodeRunner*, StackSlot*, void*);

    DECLARE_NATIVE_METHOD(httpRequest)
    DECLARE_NATIVE_METHOD(preloadMediaUrl)
    DECLARE_NATIVE_METHOD(uploadNativeFile)
    DECLARE_NATIVE_METHOD(downloadFile)
    DECLARE_NATIVE_METHOD(downloadFileBinary)
    DECLARE_NATIVE_METHOD(removeUrlFromCache)
    DECLARE_NATIVE_METHOD(clearUrlCache)
    DECLARE_NATIVE_METHOD(getAvailableCacheSpaceMb)
    DECLARE_NATIVE_METHOD(systemDownloadFile)
    DECLARE_NATIVE_METHOD(sendHttpRequestWithAttachments)

    DECLARE_NATIVE_METHOD(httpCustomRequestNative)

    DECLARE_NATIVE_METHOD(deleteAppCookies)

    DECLARE_NATIVE_METHOD(setDefaultResponseEncoding)
};

#endif
