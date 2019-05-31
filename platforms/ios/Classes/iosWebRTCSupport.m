#include "iosWebRTCSupport.h"

#include "RunnerMacros.h"
#import "utils.h"

@implementation RTCPeerConnectionManager

- (id) initWithOwner:(iosWebRTCSupport*) owner peerConnectionFactory:(RTCPeerConnectionFactory *)peerConnectionFactory configuration:(RTCConfiguration *)configuration localStream:(RTCMediaStream *)localStream serverSocket:(SocketIOClient *)serverSocket onNewParticipantRoot:(int)onNewParticipantRoot onParticipantLeaveRoot:(int)onParticipantLeaveRoot onErrorRoot:(int)onErrorRoot {
    self = [super init];
    
    runner = owner->getFlowRunner();
    host = owner;
    self.peerConnections = [NSMutableDictionary dictionary];
    self.peerConnectionFactory = peerConnectionFactory;
    self.configuration = configuration;
    self.localStream = localStream;
    self.serverSocket = serverSocket;
    self.onNewParticipantRoot = onNewParticipantRoot;
    self.onParticipantLeaveRoot = onParticipantLeaveRoot;
    self.onErrorRoot = onErrorRoot;
    
    self.mediaConstraints = [[RTCMediaConstraints alloc]
                             initWithMandatoryConstraints:
                             @{
                               @"OfferToReceiveAudio" : ([[localStream audioTracks] count] > 0 ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse),
                               @"OfferToReceiveVideo" : ([[localStream videoTracks] count] > 0 ? kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse)
                               }
                             optionalConstraints: nil];
    
    return self;
}

- (void) createPeerConnection:(NSString*) clientId {
    RTCPeerConnection *peerConnection = [self.peerConnectionFactory peerConnectionWithConfiguration:self.configuration constraints:self.mediaConstraints delegate:self];
    [peerConnection addStream:self.localStream];
    [self.peerConnections setValue:peerConnection forKey:clientId];
}

- (void) sendMessageTo:(NSString*) clientId message:(NSDictionary*) message {
    [self.serverSocket emit:@"message" with:@[
                                              @{
                                                  @"clientId" : clientId,
                                                  @"content" : message
                                                  }
                                              ]];
}

- (void) setRemoteDescription:(NSString*) clientId sessionDescription:(RTCSessionDescription*) sessionDescription {
    [[self.peerConnections objectForKey:clientId] setRemoteDescription:sessionDescription completionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            runner->EvalFunction(runner->LookupRoot(self.onErrorRoot), 1, runner->AllocateString(NS2UNICODE(error.localizedDescription)));
        }
    }];
}

- (void) updateLocalDescription:(NSString*) clientId sessionDescription:(RTCSessionDescription*) sessionDescription error:(NSError*) error {
    if (error == nil && sessionDescription != nil) {
        [[self.peerConnections objectForKey:clientId] setLocalDescription:sessionDescription completionHandler:^(NSError * _Nullable error) {
            if (error != nil) {
                runner->EvalFunction(runner->LookupRoot(self.onErrorRoot), 1, runner->AllocateString(NS2UNICODE(error.localizedDescription)));
            }
        }];
        [self sendMessageTo:clientId message:@{
                                               @"type":[RTCSessionDescription stringForType:[sessionDescription type]],
                                               @"sdp":[sessionDescription sdp]
                                               }];
    } else {
        runner->EvalFunction(runner->LookupRoot(self.onErrorRoot), 1, runner->AllocateString(NS2UNICODE(error.localizedDescription)));
    }
}

- (void) createOffer:(NSString*) clientId {
    [[self.peerConnections objectForKey:clientId] offerForConstraints:self.mediaConstraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        [self updateLocalDescription:clientId sessionDescription:sdp error:error];
    }];
}

- (void) createAnswer:(NSString*) clientId {
    [[self.peerConnections objectForKey:clientId] answerForConstraints:self.mediaConstraints completionHandler:^(RTCSessionDescription * _Nullable sdp, NSError * _Nullable error) {
        [self updateLocalDescription:clientId sessionDescription:sdp error:error];
    }];
}

- (void) addIceCandidate:(NSString*) clientId iceCandidate:(RTCIceCandidate*)iceCandidate {
    [[self.peerConnections objectForKey:clientId] addIceCandidate:iceCandidate];
}

- (void) close:(NSString*) clientId {
    runner->EvalFunction(runner->LookupRoot(self.onParticipantLeaveRoot), 1, runner->AllocateString(NS2UNICODE(clientId)));
    RTCPeerConnection *peerConnection = [self.peerConnections objectForKey:clientId];
    [peerConnection close];
}

- (void) close {
    for(NSString *clientId in self.peerConnections) {
        [self close:clientId];
    }
}

- (void)dealloc {
    [self.peerConnections release];
    [self.peerConnectionFactory release];
    [self.configuration release];
    [self.localStream release];
    [self.mediaConstraints release];
    [self.serverSocket release];
    
    [super dealloc];
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didAddStream:(nonnull RTCMediaStream *)stream {
    FlowNativeMediaStream* mediaStream = new FlowNativeMediaStream(host);
    mediaStream->mediaStream = stream;
    mediaStream->retain();
    
    NSString *clientId = [[self.peerConnections allKeysForObject:peerConnection] firstObject];
    RUN_IN_MAIN_THREAD(^void{
        runner->EvalFunction(runner->LookupRoot(self.onNewParticipantRoot), 2, runner->AllocateString(NS2UNICODE(clientId)), mediaStream->getFlowValue());
        mediaStream->release();
    });
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didGenerateIceCandidate:(nonnull RTCIceCandidate *)candidate {
    NSString *clientId = [[self.peerConnections allKeysForObject:peerConnection] firstObject];
    [self sendMessageTo:clientId message:@{
                                           @"type":@"candidate",
                                           @"label":[NSNumber numberWithInteger:[candidate sdpMLineIndex]],
                                           @"id":[candidate sdpMid],
                                           @"candidate":[candidate sdp]
                                           }];
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didOpenDataChannel:(nonnull RTCDataChannel *)dataChannel {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveIceCandidates:(nonnull NSArray<RTCIceCandidate *> *)candidates {
    
}

- (void)peerConnection:(nonnull RTCPeerConnection *)peerConnection didRemoveStream:(nonnull RTCMediaStream *)stream {
    NSString *clientId = [[self.peerConnections allKeysForObject:peerConnection] firstObject];
    runner->EvalFunction(runner->LookupRoot(self.onParticipantLeaveRoot), 1, runner->AllocateString(NS2UNICODE(clientId)));
}

- (void)peerConnectionShouldNegotiate:(nonnull RTCPeerConnection *)peerConnection {
    
}

@end

IMPLEMENT_FLOW_NATIVE_OBJECT(FlowNativeMediaSender, FlowNativeObject)

FlowNativeMediaSender::FlowNativeMediaSender(iosWebRTCSupport *owner) : FlowNativeObject(owner->getFlowRunner())
{
    socketManager = nil;
    socket = nil;
}

void FlowNativeMediaSender::retain()
{
    [peerConnectionManager retain];
    [socketManager retain];
    [socket retain];
}

void FlowNativeMediaSender::release()
{
    [peerConnectionManager release];
    [socketManager release];
    [socket release];
}

FlowNativeMediaSender::~FlowNativeMediaSender()
{
    release();
}

iosWebRTCSupport::iosWebRTCSupport(ByteCodeRunner *runner) : WebRTCSupport(runner), owner(runner)
{
    RTCInitializeSSL();
}

iosWebRTCSupport::~iosWebRTCSupport()
{
    RTCCleanupSSL();
}

void iosWebRTCSupport::makeSenderFromStream(unicode_string serverUrl, unicode_string roomId, std::vector<unicode_string> stunUrls, std::vector<std::vector<unicode_string> > turnServers, StackSlot stream, int onMediaSenderReadyRoot, int onNewParticipantRoot, int onParticipantLeaveRoot, int onErrorRoot)
{
    RUNNER_VAR = owner;
    FlowNativeMediaSender* flowMediaSender = new FlowNativeMediaSender(this);
    FlowNativeMediaStream* flowMediaStream = RUNNER->GetNative<FlowNativeMediaStream*>(stream);
    
    NSURL *url = [[NSURL alloc] initWithString:UNICODE2NS(serverUrl)];
    SocketManager *manager = [[SocketManager alloc] initWithSocketURL:url config:@{@"log": @NO, @"compress": @YES}];
    SocketIOClient *socket = manager.defaultSocket;
    
    RTCPeerConnectionManager *peerConnectionManager = [[RTCPeerConnectionManager alloc]
                                                       initWithOwner:this
                                                       peerConnectionFactory:flowMediaStream->peerConnectionFactory
                                                       configuration:createRTCConfiguration(stunUrls, turnServers)
                                                       localStream:flowMediaStream->mediaStream
                                                       serverSocket:socket
                                                       onNewParticipantRoot:onNewParticipantRoot
                                                       onParticipantLeaveRoot:onParticipantLeaveRoot
                                                       onErrorRoot:onErrorRoot];
    
    [socket on:@"connect" callback:^(NSArray* data, SocketAckEmitter* ack) {
        flowMediaSender->retain();
        RUNNER->EvalFunction(RUNNER->LookupRoot(onMediaSenderReadyRoot), 1, flowMediaSender->getFlowValue());
        
        [socket emit:@"join" with:@[UNICODE2NS(roomId)]];
        [socket emit:@"message" with:@[@{@"content":@{@"type":@"new_user"}}]];
    }];
    
    [socket on:@"message" callback:^(NSArray* data, SocketAckEmitter* ack) {
        NSMutableDictionary *message = [data objectAtIndex:0];
        NSString *clientId = [message objectForKey:@"clientId"];
        NSMutableDictionary *content = [message objectForKey:@"content"];
        NSString *type = [content objectForKey:@"type"];
        
        if ([type isEqualToString:@"new_user"]) {
            [peerConnectionManager createPeerConnection:clientId];
            [peerConnectionManager createOffer:clientId];
        } else if ([type isEqualToString:@"offer"]) {
            [peerConnectionManager createPeerConnection:clientId];
            [peerConnectionManager setRemoteDescription:clientId sessionDescription:[[RTCSessionDescription alloc] initWithType:RTCSdpTypeOffer sdp:[content objectForKey:@"sdp"]]];
            [peerConnectionManager createAnswer:clientId];
        } else if ([type isEqualToString:@"answer"]) {
            [peerConnectionManager setRemoteDescription:clientId sessionDescription: [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:[content objectForKey:@"sdp"]]];
        } else if ([type isEqualToString:@"candidate"]) {
            RTCIceCandidate *iceCandidate = [[RTCIceCandidate alloc]
                                             initWithSdp:[content objectForKey:@"id"]
                                             sdpMLineIndex:[[content objectForKey:@"label"] intValue]
                                             sdpMid:[content objectForKey:@"candidate"]];
            [peerConnectionManager addIceCandidate:clientId iceCandidate:iceCandidate];
        } else if ([type isEqualToString:@"disconnect"]) {
            [peerConnectionManager close:clientId];
        }
    }];
    
    flowMediaSender->peerConnectionManager = peerConnectionManager;
    flowMediaSender->socketManager = manager;
    flowMediaSender->socket = socket;
    
    flowMediaSender->onMediaSenderReadyRoot = onMediaSenderReadyRoot;
    flowMediaSender->onNewParticipantRoot = onNewParticipantRoot;
    flowMediaSender->onParticipantLeaveRoot = onParticipantLeaveRoot;
    flowMediaSender->onErrorRoot = onErrorRoot;
    
    [socket connect];
}

void iosWebRTCSupport::stopSender(StackSlot sender)
{
    RUNNER_VAR = owner;
    FlowNativeMediaSender* flowMediaSender = RUNNER->GetNative<FlowNativeMediaSender*>(sender);
    
    [flowMediaSender->socket emit:@"message" with:@[@{
                                                        @"content":@{
                                                                @"type":@"disconnect"
                                                                }
                                                        }
                                                    ]];
    
    [flowMediaSender->peerConnectionManager close];
    [flowMediaSender->socket disconnect];
    [flowMediaSender->socketManager disconnect];
    
    RUNNER->ReleaseRoot(flowMediaSender->onMediaSenderReadyRoot);
    RUNNER->ReleaseRoot(flowMediaSender->onNewParticipantRoot);
    RUNNER->ReleaseRoot(flowMediaSender->onParticipantLeaveRoot);
    RUNNER->ReleaseRoot(flowMediaSender->onErrorRoot);
    flowMediaSender->release();
}

RTCConfiguration* iosWebRTCSupport::createRTCConfiguration(std::vector<unicode_string> stunUrls, std::vector<std::vector<unicode_string> > turnServers) {
    NSMutableArray* iceServers = [NSMutableArray array];
    for(unicode_string server_url : stunUrls) {
        [iceServers addObject:[[RTCIceServer alloc] initWithURLStrings:@[UNICODE2NS(server_url)]]];
    }
    
    for(std::vector<unicode_string> turnServer : turnServers) {
        [iceServers addObject:
         [[RTCIceServer alloc] initWithURLStrings:@[UNICODE2NS(turnServer[0])] username:UNICODE2NS(turnServer[1]) credential:UNICODE2NS(turnServer[2])]];
    }
    
    RTCConfiguration *configuration = [[RTCConfiguration alloc] init];
    [configuration setIceServers:iceServers];
    
    return configuration;
}
