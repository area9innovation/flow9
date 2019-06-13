#ifndef iosWebRTCSupport_h
#define iosWebRTCSupport_h

#ifdef FLOW_MEDIASTREAM

#include "ByteCodeRunner.h"
#include "WebRTCSupport.h"
#include "iosMediaStreamSupport.h"

#import "WebRTC/WebRTC.h"
#import "SocketIO-Swift.h"

class iosWebRTCSupport;

@interface RTCPeerConnectionManager : NSObject<RTCPeerConnectionDelegate> {
    ByteCodeRunner *runner;
    NativeMethodHost* host;
}
@property(retain) NSMutableDictionary<NSString*, RTCPeerConnection*> *peerConnections;

@property(retain) RTCPeerConnectionFactory* peerConnectionFactory;
@property(retain) RTCConfiguration *configuration;
@property(retain) RTCMediaStream* localStream;
@property(retain) RTCMediaConstraints* mediaConstraints;
@property(retain) SocketIOClient* serverSocket;

@property int onNewParticipantRoot;
@property int onParticipantLeaveRoot;
@property int onErrorRoot;

- (id) initWithOwner:(iosWebRTCSupport*) owner peerConnectionFactory:(RTCPeerConnectionFactory*) peerConnectionFactory configuration:(RTCConfiguration*) configuration localStream:(RTCMediaStream*) localStream serverSocket:(SocketIOClient*) serverSocket onNewParticipantRoot:(int) onNewParticipantRoot onParticipantLeaveRoot:(int) onParticipantLeaveRoot onErrorRoot:(int) onErrorRoot;
- (void) createPeerConnection:(NSString*) clientId;
- (void) setRemoteDescription:(NSString*) clientId sessionDescription:(RTCSessionDescription*) sessionDescription;
- (void) createOffer:(NSString*) clientId;
- (void) createAnswer:(NSString*) clientId;
- (void) addIceCandidate:(NSString*) clientId iceCandidate:(RTCIceCandidate*)iceCandidate;
- (void) close:(NSString*) clientId;
- (void) close;
@end

class FlowNativeMediaSender : public FlowNativeObject
{
public:
    
    FlowNativeMediaSender(iosWebRTCSupport* owner);
    ~FlowNativeMediaSender();
    
    int onMediaSenderReadyRoot;
    int onNewParticipantRoot;
    int onParticipantLeaveRoot;
    int onErrorRoot;

    RTCPeerConnectionManager *peerConnectionManager;
    SocketManager* socketManager;
    SocketIOClient* socket;
    
    void retain();
    void release();
    
    DEFINE_FLOW_NATIVE_OBJECT(FlowNativeMediaSender, FlowNativeObject)
};

class iosWebRTCSupport : public WebRTCSupport
{
    ByteCodeRunner *owner;
    
public:
    iosWebRTCSupport(ByteCodeRunner *runner);
    ~iosWebRTCSupport();
protected:
    void makeSenderFromStream(unicode_string serverUrl, unicode_string roomId, std::vector<unicode_string> stunUrls, std::vector<std::vector<unicode_string> > turnServers,
                              StackSlot stream, int onMediaSenderReadyRoot, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot);
    void stopSender(StackSlot sender);
private:
    RTCConfiguration* createRTCConfiguration(std::vector<unicode_string> stunUrls, std::vector<std::vector<unicode_string> > turnServers);
};

#endif /* FLOW_MEDIASTREAM */

#endif /* iosWebRTCSupport_h */
