#import <AVFoundation/AVFoundation.h>
#include "AbstractSoundSupport.h"

class iosSoundChannel;
class iosSoundSupport;

@interface AVAudioPlayerDelegate : NSObject {
    iosSoundChannel * Owner;
}
- (id) initWithOwner: (iosSoundChannel*) owner;
- (void) audioPlayerDidFinishPlaying: (AVAudioPlayer*) player successfully: (BOOL) success;
@end

@interface DeviceAudioLevelObserver : NSObject {
@private
    iosSoundSupport * owner;
}
- (id) initWithOwner: (iosSoundSupport *) ownr;
@end

class iosSound : public AbstractSound
{
protected:
    friend class iosSoundChannel;
    NSString * SoundPath;
    NSURL * SoundURL;
    std::vector<int> waitingSoundChannels;
    
public:
    iosSound(AbstractSoundSupport *owner);
    ~iosSound() { [SoundURL autorelease]; [SoundPath release]; }
    
    void addWaitingChannel(AbstractSoundChannel * c) {
        waitingSoundChannels.push_back(getFlowRunner()->RegisterRoot(c->getFlowValue()));
    }
    
    void startAllWaitingChannels();
    
    NSURL * getSoundURL() { return SoundURL; }
    
    virtual void beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady);    
    DEFINE_FLOW_NATIVE_OBJECT(iosSound, AbstractSound);
};

class iosSoundChannel : public AbstractSoundChannel
{
protected:    
    virtual void setVolume(float value);
    virtual void stopSound();
    virtual float getSoundPosition();
    void releaseAudioPlayer();
    
    AVAudioPlayer * AudioPlayer;
    AVAudioPlayerDelegate * AudioPlayerDelegate;
    
public:
    iosSoundChannel(AbstractSoundSupport *owner, AbstractSound *snd) : AbstractSoundChannel(owner, snd), AudioPlayer(nil)
    {
        AudioPlayer = nil;
        AudioPlayerDelegate = [[AVAudioPlayerDelegate alloc] initWithOwner: this];
    }
    
    ~iosSoundChannel() 
    { 
        [AudioPlayerDelegate release];
        [AudioPlayer release];
    }
    
    virtual void beginPlay(float start_pos, bool loop, StackSlot onDone);
    void playSoundWithAudioPlayer(float start_pos);
    void finished();
    
    DEFINE_FLOW_NATIVE_OBJECT(iosSoundChannel, AbstractSoundChannel);
};

class iosSoundSupport : public AbstractSoundSupport
{
    friend class iosSound;
public:
    iosSoundSupport(ByteCodeRunner *Runner);
    ~iosSoundSupport();
    
protected:
    virtual AbstractSound *makeSound() { return new iosSound(this); }
    virtual AbstractSoundChannel *makeSoundChannel(AbstractSound *sound) { return new iosSoundChannel(this, sound); }
    virtual float doComputeSoundLength(AbstractSound *sound);
    
    virtual void doSetAudioSessionCategory(unicode_string category);
    virtual unicode_string doGetAudioSessionCategory();
    
private:
    NSString *getAudioSessionCategoryNative(NSString *category);
    NSString *getAudioSessionCategoryFlow(NSString *category);
    
    DeviceAudioLevelObserver *volumeObserver;
};
