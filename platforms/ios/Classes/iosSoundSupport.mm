#include "iosSoundSupport.h"
#import "utils.h"
#import "URLLoader.h"

@implementation AVAudioPlayerDelegate
- (id) initWithOwner: (iosSoundChannel*) owner
{
    self = [super init];
    Owner = owner;
    return self;
}

- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer*) player successfully: (BOOL) success {
    if (!success) LogW(@"Failed to play sound %@", player.url);
    Owner->finished();
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    LogW(@"Audio decoding error for %@ : %@",  player.url, [error localizedDescription]);
    //Owner->finished(); audioPlayerDidFinishPlaying is called too
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [super dealloc];
}
@end

@implementation DeviceAudioLevelObserver

-(id) initWithOwner:(iosSoundSupport *)ownr
{
    self = [super init];
    owner = ownr;
    
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:nil];
    
    return self;
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                         change:(NSDictionary *)change context:(void *)context {
    owner->NotifyDeviceVolumeEvent([[AVAudioSession sharedInstance] outputVolume]);
}

@end

IMPLEMENT_FLOW_NATIVE_OBJECT(iosSound, AbstractSound);

iosSound::iosSound(AbstractSoundSupport *owner) : AbstractSound(owner), SoundURL(nil)
{
    // Set session to playback to avoide muting by ringer switch
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error: nil];
}

void iosSound::beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady)
{
    AbstractSound::beginLoad(url, onFail, onReady);
    
    NSString * ns_url = UNICODE2NS(url);
    SoundPath = [ns_url retain];
    NSString * file_path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: ns_url];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: file_path] ) {
        SoundURL = [[NSURL fileURLWithPath: file_path isDirectory: NO] retain];
        LogI(@"loadSound: Resolved %@ as bundled file", ns_url);
        resolveReady();
    } else if ([URLLoader isCached: ns_url]) {
        SoundURL = [[NSURL fileURLWithPath: [URLLoader cachePathForURL: ns_url ] isDirectory: NO] retain];
        LogI(@"loadSound: Resolved %@ as cached file", ns_url);
        getFlowRunner()->NotifyHostEvent(NativeMethodHost::HostEventResourceLoad);
        resolveReady();
    } else {
        void (^on_success)(NSData * data) = ^void(NSData * data) {
            LogI(@"loadSound: Sound %@ downloaded from network", ns_url);
            SoundURL = [[NSURL fileURLWithPath: [URLLoader cachePathForURL: ns_url ] isDirectory: NO] retain];
            
            resolveReady();
            getFlowRunner()->NotifyHostEvent(NativeMethodHost::HostEventResourceLoad);
            startAllWaitingChannels();
        };
        
        void (^on_error)(void) = ^void(void) {
            LogI(@"loadSound: Cannot download sound %@", ns_url);
            resolveError(NS2UNICODE(@"Cannot download"));
            getFlowRunner()->NotifyHostEvent(NativeMethodHost::HostEventResourceLoad);
        };
        
        LogI(@"loadSound: Start downloading sound %@", ns_url);

        SoundURL = nil;
        URLLoader * loader = [[URLLoader alloc] initWithURL: ns_url onSuccess: on_success onError: on_error onProgress: ^void(float p){} onlyCache: YES];
        [loader start];
    }
}

void iosSound::startAllWaitingChannels()
{
    for (std::vector<int>::iterator it = waitingSoundChannels.begin(); it != waitingSoundChannels.end(); ++it) {
        ByteCodeRunner * rnr = getFlowRunner();
        iosSoundChannel * c = rnr->GetNative<iosSoundChannel*>(rnr->LookupRoot(*it));
        c->playSoundWithAudioPlayer(0.0f);
        rnr->ReleaseRoot(*it);
    }
    
    waitingSoundChannels.clear();
}

IMPLEMENT_FLOW_NATIVE_OBJECT(iosSoundChannel, AbstractSoundChannel);

void iosSoundChannel::beginPlay(float start_pos, bool loop, StackSlot onDone)
{
    AbstractSoundChannel::beginPlay(start_pos, loop, onDone);
    
    iosSound * snd = ((iosSound *)sound);
    NSURL * sound_url = snd->SoundURL;
    
    LogI(@"beginPlay: %@", snd->SoundPath);
    
    if (sound_url == nil) { // Is not downloaded yet
        LogI(@"Sound %@ is not loaded yet. Add to the queue", snd->SoundPath);
        snd->addWaitingChannel(this);
        return;
    } else {
        playSoundWithAudioPlayer(start_pos);
    }
}

void iosSoundChannel::playSoundWithAudioPlayer(float start_pos)
{
    iosSound * snd = ((iosSound *)sound);
    NSURL * sound_url = snd->SoundURL;
    
    NSError * error = nil;
    
    AudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: sound_url error: &error];
    LogI(@"playSoundWithAudioPlayer : %@", sound_url);
    
    if (!AudioPlayer)
    {
        LogE(@"Cannot create player for sound: %@", sound_url);
        LogE(@"%@", [error localizedDescription]);
        DELAY(500, ^{ finished(); }); // flow code may not expect immediate call of ondone
    }
    else
    {
        [AudioPlayer setCurrentTime: start_pos / 1000.0f];
        if (![AudioPlayer play]) {
            LogI(@"Cannot play sound %@", sound_url);
            DELAY(500, ^{ finished(); });
        } else {
            AudioPlayer.delegate = AudioPlayerDelegate;
        }
    }
}

void iosSoundChannel::releaseAudioPlayer() {
    [AudioPlayer stop];
    [AudioPlayer release];
    AudioPlayer = nil;
}

void iosSoundChannel::finished()
{
    notifyDone();
    releaseAudioPlayer();
}

void iosSoundChannel::setVolume(float value)
{
}

void iosSoundChannel::stopSound()
{
    AbstractSoundChannel::stopSound();
    releaseAudioPlayer();
}

float iosSoundChannel::getSoundPosition()
{
    if (AudioPlayer)
        return AudioPlayer.currentTime * 1000.0f; // ms
    else
        return 0.0f;
}

iosSoundSupport::iosSoundSupport(ByteCodeRunner *Runner) : AbstractSoundSupport(Runner)
{
    volumeObserver = [[DeviceAudioLevelObserver alloc] initWithOwner:this];
}

iosSoundSupport::~iosSoundSupport()
{
    [volumeObserver release];
}

float iosSoundSupport::doComputeSoundLength(AbstractSound *sound)
{
    iosSound * snd = (iosSound*) sound;
    NSURL * sound_url = snd->getSoundURL();
    if (sound_url != nil) {
        AVURLAsset* audioAsset = [AVURLAsset URLAssetWithURL: sound_url options:nil];
        CMTime audioDuration = audioAsset.duration;
        float audioDurationSeconds = CMTimeGetSeconds(audioDuration);
        return audioDurationSeconds * 1000.0f; // ms
    } else {
        LogW(@"Attempt to get duration of not loaded sound");
        return 1.0f;
    }
}

NSString *iosSoundSupport::getAudioSessionCategoryNative(NSString *category) {
    if ([category isEqualToString:@"ambient"]) {
        return AVAudioSessionCategoryAmbient;
    } else if ([category isEqualToString:@"playback"]) {
        return AVAudioSessionCategoryPlayback;
    } else if ([category isEqualToString:@"record"]) {
        return AVAudioSessionCategoryRecord;
    } else if ([category isEqualToString:@"playandrecord"]) {
        return AVAudioSessionCategoryPlayAndRecord;
    } else if ([category isEqualToString:@"multiroute"]) {
        return AVAudioSessionCategoryMultiRoute;
    } else {
        // default category
        return AVAudioSessionCategorySoloAmbient;
    }
}

NSString *iosSoundSupport::getAudioSessionCategoryFlow(NSString *category) {
    if ([category isEqualToString:AVAudioSessionCategoryAmbient]) {
        return @"ambient";
    } else if ([category isEqualToString:AVAudioSessionCategoryPlayback]) {
        return @"playback";
    } else if ([category isEqualToString:AVAudioSessionCategoryRecord]) {
        return @"record";
    } else if ([category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        return @"playandrecord";
    } else if ([category isEqualToString:AVAudioSessionCategoryMultiRoute]) {
        return @"multiroute";
    } else {
        // default category
        return @"soloambient";
    }
}

unicode_string iosSoundSupport::doGetAudioSessionCategory() {
    NSString *category = [[AVAudioSession sharedInstance] category];
    
    return NS2UNICODE(getAudioSessionCategoryFlow(category));
}

void iosSoundSupport::doSetAudioSessionCategory(unicode_string category) {
    [[AVAudioSession sharedInstance] setCategory:getAudioSessionCategoryNative(UNICODE2NS(category)) error:nil];
}
