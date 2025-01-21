#include "AbstractSoundSupport.h"

#include "core/RunnerMacros.h"

/* SOUND */

IMPLEMENT_FLOW_NATIVE_OBJECT(AbstractSound, FlowNativeObject);

void AbstractSound::flowGCObject(GarbageCollectorFn ref)
{
    ref << onFail << onReady;
}

AbstractSound::AbstractSound(AbstractSoundSupport *owner)
    : FlowNativeObject(owner->getFlowRunner()), owner(owner)
{
    onFail = onReady = StackSlot::MakeVoid();
    done = auto_play = length_ready = false;
    length = 0.0f;
}

void AbstractSound::beginLoad(unicode_string url, StackSlot onFail, StackSlot onReady)
{
    this->url = url;
    this->onFail = onFail;
    this->onReady = onReady;

    owner->doBeginLoad(this);
}

float AbstractSound::computeSoundLength()
{
    return owner->doComputeSoundLength(this);
}

void AbstractSound::resolveReady()
{
    owner->pending_sounds.erase(this);

    done = true;

    if (!onReady.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(onReady, 0);
        onFail = onReady = StackSlot::MakeVoid();
    }

    if (auto_play) {
        AbstractSoundChannel *channel = owner->makeSoundChannel(this);
        channel->getFlowValue();
        channel->beginPlay(0.0f, false, StackSlot::MakeVoid());
    }
}

void AbstractSound::resolveError(unicode_string error)
{
    owner->pending_sounds.erase(this);

    if (!onFail.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(onFail, 1, RUNNER->AllocateString(error));
        onFail = onReady = StackSlot::MakeVoid();
    } else {
        getFlowRunner()->flow_err << encodeUtf8(error) << endl;
    }
}

StackSlot AbstractSound::playSound(RUNNER_ARGS)
{
    RUNNER_PopArgs2(loop, onDone);
    RUNNER_CheckTag(TBool, loop);
    RUNNER_DefSlots1(retval);

    AbstractSoundChannel *channel = owner->makeSoundChannel(this);
    retval = RUNNER->AllocNative(channel);

    channel->beginPlay(0.0f, loop.GetBool(), onDone);

    return retval;
}

StackSlot AbstractSound::playSoundFrom(RUNNER_ARGS)
{
    RUNNER_PopArgs2(start, onDone);
    RUNNER_CheckTag(TDouble, start);
    RUNNER_DefSlots1(retval);

    AbstractSoundChannel *channel = owner->makeSoundChannel(this);
    retval = RUNNER->AllocNative(channel);

    channel->beginPlay(float(start.GetDouble()), false, onDone);

    return retval;
}

StackSlot AbstractSound::getSoundLength(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    if (done && !length_ready)
    {
        length = computeSoundLength();
        length_ready = true;
    }

    return StackSlot::MakeDouble(length);
}

/* CHANNEL */

IMPLEMENT_FLOW_NATIVE_OBJECT(AbstractSoundChannel, FlowNativeObject);

void AbstractSoundChannel::flowGCObject(GarbageCollectorFn ref)
{
    ref << sound << onDone;
}

AbstractSoundChannel::AbstractSoundChannel(AbstractSoundSupport *owner, AbstractSound *sound)
    : FlowNativeObject(owner->getFlowRunner()), owner(owner), sound(sound)
{
    isActive = false;
    onDone = StackSlot::MakeVoid();
    position = 0.0f;
}

void AbstractSoundChannel::beginPlay(float start_pos, bool loop, StackSlot onDone)
{
    this->onDone = onDone;
    isActive = true;

    owner->doBeginPlay(this, start_pos, loop);
}

void AbstractSoundChannel::notifyDone()
{
    owner->active_channels.erase(this);
    isActive = false;

    if (!onDone.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(onDone, 0);
        onDone = StackSlot::MakeVoid();
    }
}

void AbstractSoundChannel::setVolume(float value)
{
    if (isActive)
        owner->doSetVolume(this, value);
}

void AbstractSoundChannel::stopSound()
{
    if (isActive) {
        isActive = false;
        onDone = StackSlot::MakeVoid();
        owner->doStopSound(this);
    }
}

float AbstractSoundChannel::getSoundPosition()
{
    return owner->doGetSoundPosition(this);
}

StackSlot AbstractSoundChannel::setVolume(RUNNER_ARGS)
{
    RUNNER_PopArgs1(volume);
    RUNNER_CheckTag(TDouble, volume);

    setVolume(float(volume.GetDouble()));

    RETVOID;
}

StackSlot AbstractSoundChannel::stopSound(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    stopSound();

    RETVOID;
}

StackSlot AbstractSoundChannel::getSoundPosition(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    if (isActive)
        position = getSoundPosition();

    return StackSlot::MakeDouble(position);
}

/* HOST */

AbstractSoundSupport::AbstractSoundSupport(ByteCodeRunner *owner)
    : NativeMethodHost(owner)
{
}

void AbstractSoundSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    pending_sounds.clear();
    active_channels.clear();
}

void AbstractSoundSupport::flowGCObject(GarbageCollectorFn ref)
{
    ref << pending_sounds << active_channels;
}

AbstractSound *AbstractSoundSupport::makeSound()
{
    return new AbstractSound(this);
}

AbstractSoundChannel *AbstractSoundSupport::makeSoundChannel(AbstractSound *sound)
{
    return new AbstractSoundChannel(this, sound);
}

void AbstractSoundSupport::doBeginLoad(AbstractSound *sound)
{
    pending_sounds.insert(sound);
}

float AbstractSoundSupport::doComputeSoundLength(AbstractSound* /*sound*/)
{
    return 0.0f;
}

void AbstractSoundSupport::resolveReady(AbstractSound *sound)
{
    if (!isPendingSound(sound)) return;

    sound->resolveReady();
}

void AbstractSoundSupport::resolveError(AbstractSound *sound, unicode_string error)
{
    if (!isPendingSound(sound)) return;

    sound->resolveError(error);
}

void AbstractSoundSupport::doBeginPlay(AbstractSoundChannel *channel, float, bool)
{
    active_channels.insert(channel);
}

void AbstractSoundSupport::doStopSound(AbstractSoundChannel *channel)
{
    active_channels.erase(channel);
}

void AbstractSoundSupport::doSetVolume(AbstractSoundChannel *, float) {}

float AbstractSoundSupport::doGetSoundPosition(AbstractSoundChannel* /*channel*/)
{
    return 0.0f;
}

void AbstractSoundSupport::notifyDone(AbstractSoundChannel *channel)
{
    if (!isActiveChannel(channel)) return;

    channel->notifyDone();
}

NativeFunction *AbstractSoundSupport::MakeNativeFunction(const char *name, int num_args)
{
#undef NATIVE_NAME_PREFIX
#define NATIVE_NAME_PREFIX "SoundSupport."

    TRY_USE_NATIVE_METHOD(AbstractSoundSupport, loadSound, 4);
    TRY_USE_NATIVE_METHOD(AbstractSoundSupport, noSound, 0);
    TRY_USE_NATIVE_METHOD(AbstractSoundSupport, play, 1);
    
    TRY_USE_NATIVE_METHOD(AbstractSoundSupport, getAudioSessionCategory, 0);
    TRY_USE_NATIVE_METHOD(AbstractSoundSupport, setAudioSessionCategory, 1);
    TRY_USE_NATIVE_METHOD(AbstractSoundSupport, addDeviceVolumeEventListener, 1);

    TRY_USE_OBJECT_METHOD(AbstractSound, playSound, 3);
    TRY_USE_OBJECT_METHOD(AbstractSound, playSoundFrom, 3);
    TRY_USE_OBJECT_METHOD(AbstractSound, getSoundLength, 1);

    TRY_USE_OBJECT_METHOD(AbstractSoundChannel, setVolume, 2);
    TRY_USE_OBJECT_METHOD(AbstractSoundChannel, stopSound, 1);
    TRY_USE_OBJECT_METHOD(AbstractSoundChannel, getSoundPosition, 1);

    return NULL;
}

StackSlot AbstractSoundSupport::loadSound(RUNNER_ARGS) {
    RUNNER_PopArgs4(url, headers, onFail, onDone);
    RUNNER_CheckTag(TString, url);
    RUNNER_DefSlots1(retval);

    AbstractSound *sound = makeSound();
    retval = RUNNER->AllocNative(sound);

    sound->beginLoad(RUNNER->GetString(url), onFail, onDone);

    return retval;
}

StackSlot AbstractSoundSupport::noSound(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;

    return RUNNER->AllocNative(makeSoundChannel(NULL));
}

StackSlot AbstractSoundSupport::play(RUNNER_ARGS) {
    RUNNER_PopArgs1(url);
    RUNNER_CheckTag(TString, url);

    AbstractSound *sound = makeSound();
    sound->getFlowValue();
    sound->setAutoPlay();
    sound->beginLoad(RUNNER->GetString(url), StackSlot::MakeVoid(), StackSlot::MakeVoid());

    RETVOID;
}

StackSlot AbstractSoundSupport::getAudioSessionCategory(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    
    return RUNNER->AllocateString(doGetAudioSessionCategory());
}

StackSlot AbstractSoundSupport::setAudioSessionCategory(RUNNER_ARGS) {
    RUNNER_PopArgs1(category_str);
    RUNNER_CheckTag1(TString, category_str);
    
    doSetAudioSessionCategory(RUNNER->GetString(category_str));
    
    RETVOID;
}

StackSlot AbstractSoundSupport::addDeviceVolumeEventListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(cb);
    
    int cb_root = RUNNER->RegisterRoot(cb);
    DeviceVolumeEventListeners.push_back(cb_root);
    
    return RUNNER->AllocateNativeClosure(removeDeviceVolumeEventListener, "addDeviceVolumeEventListener$disposer", 0, &DeviceVolumeEventListeners,
                                         1, StackSlot::MakeInt(cb_root));
}

void AbstractSoundSupport::NotifyDeviceVolumeEvent(float level) {
    RUNNER_VAR = getFlowRunner();
    WITH_RUNNER_LOCK_DEFERRED(RUNNER);
    
    const StackSlot &level_slot = StackSlot::MakeDouble(level);
    
    for (T_DeviceVolumeEventListeners::iterator it = DeviceVolumeEventListeners.begin(); it != DeviceVolumeEventListeners.end(); ++it) {
        RUNNER->EvalFunction(RUNNER->LookupRoot(*it), 1, level_slot);
    }
}

StackSlot AbstractSoundSupport::removeDeviceVolumeEventListener(RUNNER_ARGS, void * data)
{
    const StackSlot *slot = RUNNER->GetClosureSlotPtr(RUNNER_CLOSURE, 1);
    int cb_root = slot[0].GetInt();
    
    T_DeviceVolumeEventListeners *VolumeListeners = (T_DeviceVolumeEventListeners*)data;
    
    T_DeviceVolumeEventListeners::iterator itListeners = std::find(VolumeListeners->begin(), VolumeListeners->end(), cb_root);
    if(itListeners !=  VolumeListeners->end()) {
        VolumeListeners->erase(itListeners);
    }
    
    RUNNER->ReleaseRoot(cb_root);
    
    RETVOID;
}
