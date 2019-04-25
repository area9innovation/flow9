#ifndef ABSTRACTSOUNDSUPPORT_H
#define ABSTRACTSOUNDSUPPORT_H

#include "core/ByteCodeRunner.h"

class AbstractSoundSupport;

class AbstractSound : public FlowNativeObject
{
protected:
    AbstractSoundSupport *owner;

    unicode_string url;
    bool done, auto_play;

    bool length_ready;
    float length;

    // ROOT
    StackSlot onFail, onReady;

    void flowGCObject(GarbageCollectorFn);
    virtual float computeSoundLength();

public:
    AbstractSound(AbstractSoundSupport *owner);

    const unicode_string &getUrl() { return url; }
    void setAutoPlay() { auto_play = true; }

    virtual void beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady);

    void resolveReady();
    void resolveError(unicode_string error);

    DEFINE_FLOW_NATIVE_OBJECT(AbstractSound, FlowNativeObject);

public:
    DECLARE_NATIVE_METHOD(playSound);
    DECLARE_NATIVE_METHOD(playSoundFrom);
    DECLARE_NATIVE_METHOD(getSoundLength);
};

class AbstractSoundChannel : public FlowNativeObject
{
protected:
    AbstractSoundSupport *owner;
    bool isActive;
    float position;
    float length;

    // ROOT
    AbstractSound *sound;
    StackSlot onDone;

    void flowGCObject(GarbageCollectorFn);

    virtual void setVolume(float value);
    virtual void stopSound();
    virtual float getSoundPosition();

public:
    AbstractSoundChannel(AbstractSoundSupport *owner, AbstractSound *sound);

    AbstractSound *getSound() { return sound; }

    virtual void beginPlay(float start_pos, bool loop, StackSlot onDone);

    void notifyDone();

    DEFINE_FLOW_NATIVE_OBJECT(AbstractSoundChannel, FlowNativeObject);

public:
    DECLARE_NATIVE_METHOD(setVolume);
    DECLARE_NATIVE_METHOD(stopSound);
    DECLARE_NATIVE_METHOD(getSoundPosition);
};

class AbstractSoundSupport : public NativeMethodHost {
    friend class AbstractSound;
    friend class AbstractSoundChannel;

    // ROOT
    std::set<AbstractSound*> pending_sounds;
    std::set<AbstractSoundChannel*> active_channels;

public:
    AbstractSoundSupport(ByteCodeRunner *owner);
    
    void NotifyDeviceVolumeEvent(float level);

protected:
    void OnRunnerReset(bool inDestructor);
    void flowGCObject(GarbageCollectorFn ref);

    bool isPendingSound(AbstractSound *sound) { return pending_sounds.count(sound) != 0; }
    bool isActiveChannel(AbstractSoundChannel *channel) { return active_channels.count(channel) != 0; }

    virtual AbstractSound *makeSound();
    virtual AbstractSoundChannel *makeSoundChannel(AbstractSound *sound);

    virtual void doBeginLoad(AbstractSound *sound);

    void resolveReady(AbstractSound *sound);
    void resolveError(AbstractSound *sound, unicode_string error);

    virtual float doComputeSoundLength(AbstractSound *sound);

    virtual void doBeginPlay(AbstractSoundChannel *channel, float start_pos, bool loop);

    virtual void doSetVolume(AbstractSoundChannel *channel, float value);
    virtual void doStopSound(AbstractSoundChannel *channel);
    virtual float doGetSoundPosition(AbstractSoundChannel *channel);
    
    virtual void doSetAudioSessionCategory(unicode_string category) {}
    virtual unicode_string doGetAudioSessionCategory() { return parseUtf8("soloambient"); }

    void notifyDone(AbstractSoundChannel *channel);

    NativeFunction *MakeNativeFunction(const char *name, int num_args);

private:
    DECLARE_NATIVE_METHOD(loadSound);
    DECLARE_NATIVE_METHOD(noSound);
    DECLARE_NATIVE_METHOD(play);
    DECLARE_NATIVE_METHOD(setAudioSessionCategory);
    DECLARE_NATIVE_METHOD(getAudioSessionCategory);
    DECLARE_NATIVE_METHOD(addDeviceVolumeEventListener);
    
    
    typedef std::vector<int> T_DeviceVolumeEventListeners;
    T_DeviceVolumeEventListeners DeviceVolumeEventListeners;
    static StackSlot removeDeviceVolumeEventListener(ByteCodeRunner*, StackSlot*, void*);
};

#endif // ABSTRACTSOUNDSUPPORT_H
