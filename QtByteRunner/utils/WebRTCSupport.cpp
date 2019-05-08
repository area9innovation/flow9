#include "WebRTCSupport.h"

#include "core/RunnerMacros.h"


WebRTCSupport::WebRTCSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{

}

NativeFunction *WebRTCSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "WebRTCSupport."

    TRY_USE_NATIVE_METHOD(WebRTCSupport, makeMediaSenderFromStream, 9);
    TRY_USE_NATIVE_METHOD(WebRTCSupport, stopMediaSender, 1);

    return NULL;
}


StackSlot WebRTCSupport::makeMediaSenderFromStream(RUNNER_ARGS)
{
    RUNNER_PopArgs5(serverUrl, roomId, stunUrls, turnServers, stream);
    RUNNER_CheckTag2(TString, serverUrl, roomId);
    RUNNER_CheckTag2(TArray, stunUrls, turnServers);
    RUNNER_CheckTag1(TNative, stream);

    RUNNER_DefSlots2(slotvalue1, slotvalue2)

    int onMediaSenderReadyRoot = RUNNER->RegisterRoot(RUNNER_ARG(5));
    int onNewParticipantRoot = RUNNER->RegisterRoot(RUNNER_ARG(6));
    int onParticipantLeaveRoot = RUNNER->RegisterRoot(RUNNER_ARG(7));
    int onErrorRoot = RUNNER->RegisterRoot(RUNNER_ARG(8));

    int stunLength = RUNNER->GetArraySize(stunUrls);
    std::vector<unicode_string> stun(stunLength);
    for (int i = 0; i < stunLength; i++)
    {
        slotvalue1 = RUNNER->GetArraySlot(stunUrls, i);
        RUNNER_CheckTag1(TString, slotvalue1);
        stun.push_back(RUNNER->GetString(slotvalue1));
    }

    int turnLength = RUNNER->GetArraySize(turnServers);
    std::vector<std::vector<unicode_string> > turn(turnLength);
    for (int i = 0; i < turnLength; i++)
    {
        slotvalue1 = RUNNER->GetArraySlot(turnServers, i);
        RUNNER_CheckTag1(TArray, slotvalue1);
        for (int j = 0; j < RUNNER->GetArraySize(slotvalue1); j++) {
            slotvalue2 = RUNNER->GetArraySlot(slotvalue1, j);
            RUNNER_CheckTag1(TString, slotvalue2);
            turn[i].push_back(RUNNER->GetString(slotvalue2));
        }
    }

    makeSenderFromStream(RUNNER->GetString(serverUrl), RUNNER->GetString(roomId), stun, turn, stream, onMediaSenderReadyRoot, onNewParticipantRoot, onParticipantLeaveRoot, onErrorRoot);

    RETVOID;
}

StackSlot WebRTCSupport::stopMediaSender(RUNNER_ARGS)
{
    StackSlot &mediaSender = RUNNER_ARG(0);
    RUNNER_CheckTag1(TNative, mediaSender);
    stopSender(mediaSender);

    RETVOID;
}
