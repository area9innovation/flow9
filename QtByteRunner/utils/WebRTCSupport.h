#ifndef WEBRTCSUPPORT_H
#define WEBRTCSUPPORT_H

#include "core/ByteCodeRunner.h"

#include <vector>

class WebRTCSupport : public NativeMethodHost
{
public:
    WebRTCSupport(ByteCodeRunner *Runner);
protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);
private:

    virtual void makeSenderFromStream(unicode_string serverUrl, unicode_string roomId, std::vector<unicode_string> stunUrls, std::vector<std::vector<unicode_string> > turnServers,
                                           StackSlot stream, int onMediaSenderReadyRoot, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot) {}
    virtual void stopSender(StackSlot sender) {}

    DECLARE_NATIVE_METHOD(makeMediaSenderFromStream)
    DECLARE_NATIVE_METHOD(stopMediaSender)
};

#endif // WEBRTCSUPPORT_H

