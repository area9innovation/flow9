#include "GLVideoClip.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

IMPLEMENT_FLOW_NATIVE_OBJECT(GLVideoClip, GLClip)

GLVideoClip::GLVideoClip(GLRenderSupport *owner, const StackSlot &size_cb, const StackSlot &play_cb, const StackSlot &dur_cb, const StackSlot &pos_cb) :
    GLClip(owner)
{
    if (!size_cb.IsVoid())
        addEventCallback(FlowVideoSizeNotify, size_cb);
    if (!play_cb.IsVoid())
        addEventCallback(FlowVideoPlayNotify, play_cb);
    if (!dur_cb.IsVoid())
        addEventCallback(FlowVideoDurationNotify, dur_cb);
    if (!pos_cb.IsVoid())
        addEventCallback(FlowVideoPositionNotify, pos_cb);

    use_media_stream = false;
    start = end = duration = 0;
    failed = looping = loaded = playing = false;
    subtitle = new GLTextClip(owner);
    addChild(subtitle);

    updateVolume(1.0f);
    updatePlaybackRate(1.0f);
    updatePosition(0.0f, true);
}

void GLVideoClip::computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform)
{
    GLClip::computeBBoxSelf(bbox, transform);

    bbox |= transform * GLBoundingBox(vec2(0,0), vec2(size));
}

void GLVideoClip::renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box)
{
    if (failed) {
        surface->makeCurrent();
        renderer->beginDrawSimple(vec4(1,0,0,1)*global_alpha);
        renderer->drawRect(vec2(0,0), vec2(size));
    } else if (texture_image) {
        surface->makeCurrent();
        if (texture_image->isTexture2D())
            renderer->beginDrawFancy(vec4(0,0,0,0), true, texture_image->swizzleRB());
        else
            renderer->beginDrawFancyExternalTexture(vec4(0,0,0,0));

        glVertexAttrib4f(GLRenderer::AttrVertexColor, global_alpha, global_alpha, global_alpha, global_alpha);

        if ((int)local_transform_raw.angle % 180) {
            texture_image->drawRect(renderer, vec2(0,0), vec2(size.y, size.x));
        } else {
            texture_image->drawRect(renderer, vec2(0,0), vec2(size));
        }

    }

    GLClip::renderInner(renderer, surface, clip_box);
}

const GLTransform &GLVideoClip::getLocalTransform()
{
    if (!checkFlag(LocalTransformReady)) {
        setFlags(LocalTransformReady);
        local_transform = local_transform_raw.toMatrixForm();
    }

    return local_transform;
}

void GLVideoClip::notify(GLVideoClip::StateChangeEvent event, int64_t value, int64_t secondary_value)
{
//    cout << "notify" << endl;
//    cout << event << endl;
//    cout << value << endl;
//    cout << secondary_value << endl;

    switch (event) {
        case PlayChange: {
            if (state_stack.empty() || !loaded) {
                if (value == 0) { // play
                    updatePlay(false, true);
                } else if (value == 1) { // pause
                    updatePlay(true, true);
                } else if (value == 2) { // stop
                    updatePlay(false, true);
                }
            } else {
                filterStateEvents(event);
                nextStateEvent();
            }

            break;
        }
        case PositionChange: {
            if (state_stack.empty() || !loaded) {
                checkTimeRange(value, true);
            } else {
                filterStateEvents(event);
                nextStateEvent();
            }

            break;
        }
        case SizeChange: {
            notifySize(value, secondary_value);

            if (duration > 0) {
                loaded = true;
                update();
            }

            break;
        }
        case DurationChange: {
            notifyDuration(value);

            loaded = true;
            update();

            break;
        }
        default: break; // do nothing
    }
}

void GLVideoClip::pushStateEvent(GLVideoClip::StateChangeEvent event, int64_t value, int64_t secondary_value)
{
//    cout << "pushStateEvent" << endl;
//    cout << event << endl;
//    cout << value << endl;
//    cout << secondary_value << endl;

    StateChange new_event(event, value, secondary_value);

    filterStateEvents(event);
    state_stack.push_back(new_event);

    if (state_stack.size() == 1) {
        nextStateEvent();
    }
}

struct FilterStatePredicate {
    const GLVideoClip::StateChangeEvent event;
    const int64_t value;

    FilterStatePredicate(GLVideoClip::StateChangeEvent _event, int64_t _value) : event(_event), value(_value) { }

    bool operator() (GLVideoClip::StateChange stack_event) {
        bool b = stack_event.event == event;

       if (b && value >= 0) {
           b = stack_event.value == value;
       }

       return b;
    }
};

void GLVideoClip::filterStateEvents(GLVideoClip::StateChangeEvent event, int64_t value)
{
//    cout << "filterStateEvents" << endl;
//    cout << event << endl;
//    cout << value << endl;

//    cout << "before" << endl;
//    cout << "[" << endl;
//    for (std::vector<StateChange>::const_iterator i = state_stack.begin(); i != state_stack.end(); ++i) {
//        cout << (*i).event << ' ' << (*i).value << endl;
//    }
//    cout << "]" << endl;

    state_stack.erase(std::remove_if(
        state_stack.begin(),
        state_stack.end(),
        FilterStatePredicate(event, value)
    ), state_stack.end());

//    cout << "after" << endl;
//    cout << "[" << endl;
//    for (std::vector<StateChange>::const_iterator i = state_stack.begin(); i != state_stack.end(); ++i) {
//        cout << (*i).event << ' ' << (*i).value << endl;
//    }
//    cout << "]" << endl;
}

void GLVideoClip::nextStateEvent()
{
    if (state_stack.empty() || !loaded  || !checkFlag(HasNativeWidget))
       return;

    current_event = StateChange(state_stack.front().event, state_stack.front().value, state_stack.front().secondary_value);

//    cout << "nextStateEvent" << endl;
//    cout << current_event.event << endl;
//    cout << current_event.value << endl;

    switch (current_event.event) {
        case PlayChange: {
            owner->doUpdateVideoPlay(this);

            break;
        }
        case PositionChange: {
            owner->doUpdateVideoPosition(this);

            break;
        }
        default: break; // do nothing
    }
}

void GLVideoClip::notifyNotFound()
{
    failed = true;
    owner->destroyNativeWidget(this);

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    args[0] = RUNNER->AllocateString("NetStream.Play.StreamNotFound");
    invokeEventCallbacks(FlowVideoStreamEvent, 1, args);
}

void GLVideoClip::notifyEvent(GLVideoClip::Event ev)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    const char *tag = "";

    switch (ev) {
        case PlayStart: {
            update();
            tag = "NetStream.Play.Start";
            break;
        }
        case PlayEnd: {
            tag = "NetStream.Play.Stop";
            update();
            break;
        }
        case UserPause: {
            tag = "FlowGL.User.Pause";
            break;
        }
        case UserResume: {
            tag = "FlowGL.User.Resume";
            break;
        }
        case UserStop: {
            tag = "FlowGL.User.Stop";
            break;
        }
        case UserSeek: {
            tag = "FlowGL.User.Seek";
            break;
        }
    }

    args[0] = RUNNER->AllocateString(tag);
    invokeEventCallbacks(FlowVideoStreamEvent, 1, args);
}

void GLVideoClip::notifySize(int w, int h)
{
    if (w < 0 || h < 0 || (w == size.x && h == size.y))
        return;

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 2);

    size = ivec2(w,h);
    wipeFlags(WipeGraphicsChanged);

    args[0] = StackSlot::MakeDouble(w);
    args[1] = StackSlot::MakeDouble(h);
    invokeEventCallbacks(FlowVideoSizeNotify, 2, args);
}

void GLVideoClip::notifyDuration(int64_t duration)
{
    if (duration < 0)
        return;

    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    this->duration = duration;
    if (end == 0) {
        end = duration;
    }

    args[0] = StackSlot::MakeDouble(duration / 1000.0);
    invokeEventCallbacks(FlowVideoDurationNotify, 1, args);
}

void GLVideoClip::notifyPlay(bool playing)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    this->playing = playing;

    args[0] = StackSlot::MakeBool(playing);
    invokeEventCallbacks(FlowVideoPlayNotify, 1, args);
}

void GLVideoClip::notifyPosition(int64_t position)
{
    RUNNER_VAR = getFlowRunner();
    RUNNER_DefSlotArray(args, 1);

    this->position = position;

    args[0] = StackSlot::MakeDouble(position / 1000.0);
    invokeEventCallbacks(FlowVideoPositionNotify, 1, args);
}

void GLVideoClip::checkTimeRange(int64_t position, bool video_response)
{
    if (position < start) {
        updatePosition(start, false);
    } else if (end > start && position >= end) {
        if (playing) {
            updatePlay(looping, false);
            if (looping) {
                updatePosition(start, false);
            } else {
                updatePosition(start, false, false);
                notifyEvent(GLVideoClip::PlayEnd);
            }
        } else {
            updatePosition(end, false);
        }
    } else {
        updatePosition(position, video_response);
    }
}

void GLVideoClip::update()
{
    state_stack.clear();

    if (!checkFlag(HasNativeWidget))
        return;

    owner->doUpdateVideoPosition(this);
    owner->doUpdateVideoPlay(this);
    owner->doUpdateVideoVolume(this);
    owner->doUpdateVideoPlaybackRate(this);
}

void GLVideoClip::updatePlay(bool playing, bool video_response, bool notify)
{
    if (this->playing != playing) {
        this->playing = playing;
        if (notify) {
            notifyPlay(playing);
        }

        if (!video_response && loaded) {
            if (playing) {
                pushStateEvent(PlayChange, 1);
            } else {
                pushStateEvent(PlayChange, 0);
            }
        }
    }
}

void GLVideoClip::updatePosition(int64_t position, bool video_response, bool notify)
{
    if (this->position != position) {
        this->position = position;
        if (notify) {
            notifyPosition(position);
        }

        if (!video_response && loaded) {
            pushStateEvent(PositionChange, position);
        }
    }
}

void GLVideoClip::updateVolume(float volume)
{
    if (this->volume != volume) {
        this->volume = volume;

        if (loaded) {
           owner->doUpdateVideoVolume(this);
        }
    }
}

void GLVideoClip::updatePlaybackRate(double playbackRate)
{
    if (this->playbackRate != playbackRate) {
        this->playbackRate = playbackRate;

        if (loaded) {
           owner->doUpdateVideoPlaybackRate(this);
        }
    }
}

void GLVideoClip::updateTimeRange(int64_t start, int64_t end)
{
    this->start = start;
    this->end = end;

    if (this->start < 0) {
        this->start = 0;
    }

    if (this->end <= this->start) {
        this->end = duration;
    }

    checkTimeRange(position, false);
}

void GLVideoClip::setFocus(bool focus)
{
    if (checkFlag(HasNativeWidget))
        owner->doUpdateVideoFocus(this, focus);

    GLClip::setFocus(focus);
}

StackSlot GLVideoClip::playVideo2(RUNNER_ARGS)
{
    RUNNER_CopyArgArray(newargs, 1, 2);
    newargs[1] = StackSlot::MakeBool(false);
    newargs[2] = StackSlot::MakeEmptyArray();
    return playVideo(RUNNER, newargs);
}

StackSlot GLVideoClip::playVideo(RUNNER_ARGS)
{
    RUNNER_PopArgs3(name_str, start_paused, headers);
    RUNNER_CheckTag1(TString, name_str);
    RUNNER_CheckTag1(TBool, start_paused);
    RUNNER_CheckTag1(TArray, headers)

    name = RUNNER->GetString(name_str);
    failed = false;
    playing = !start_paused.GetBool();

    for (unsigned i = 0; i < RUNNER->GetArraySize(headers); i++) {
       const StackSlot &header_slot = RUNNER->GetArraySlot(headers, i);
       RUNNER_CheckTag(TArray, header_slot);

       unicode_string name     = RUNNER->GetString(RUNNER->GetArraySlot(header_slot, 0));
       unicode_string value    = RUNNER->GetString(RUNNER->GetArraySlot(header_slot, 1));

       req_headers[name] = value;
   }

    if (!owner->createNativeWidget(this))
        notifyNotFound();

    RETVOID;
}

StackSlot GLVideoClip::playVideoFromMediaStream(RUNNER_ARGS)
{
    RUNNER_PopArgs2(mediaStream, start_paused);
    RUNNER_CheckTag1(TNative, mediaStream);
    RUNNER_CheckTag1(TBool, start_paused);

    use_media_stream = true;
    media_stream_id = RUNNER->RegisterRoot(mediaStream);
    failed = false;
    playing = !start_paused.GetBool();
    if (!owner->createNativeWidget(this))
        notifyNotFound();

    RETVOID;
}

StackSlot GLVideoClip::pauseVideo(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    updatePlay(false, false);

    RETVOID;
}

StackSlot GLVideoClip::resumeVideo(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    updatePlay(true, false);

    RETVOID;
}

StackSlot GLVideoClip::closeVideo(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    owner->destroyNativeWidget(this);

    RETVOID;
}

StackSlot GLVideoClip::getVideoPosition(RUNNER_ARGS)
{
    IGNORE_RUNNER_ARGS;

    return StackSlot::MakeDouble(position / 1000.0);
}

StackSlot GLVideoClip::seekVideo(RUNNER_ARGS)
{
    RUNNER_PopArgs1(position);
    RUNNER_CheckTag1(TDouble, position);

    checkTimeRange(int64_t(position.GetDouble() * 1000), false);

    RETVOID;
}

StackSlot GLVideoClip::setVideoVolume(RUNNER_ARGS)
{
    RUNNER_PopArgs1(volume);
    RUNNER_CheckTag1(TDouble, volume);

    updateVolume(volume.GetDouble());

    RETVOID;
}

StackSlot GLVideoClip::setVideoPlaybackRate(RUNNER_ARGS)
{
    RUNNER_PopArgs1(playbackRate);
    RUNNER_CheckTag1(TDouble, playbackRate);

    updatePlaybackRate(playbackRate.GetDouble());

    RETVOID;
}

StackSlot GLVideoClip::setVideoTimeRange(RUNNER_ARGS)
{
    RUNNER_PopArgs2(start, end);
    RUNNER_CheckTag1(TDouble, start);
    RUNNER_CheckTag1(TDouble, end);

    updateTimeRange(int64_t(start.GetDouble() * 1000), int64_t(end.GetDouble() * 1000));

    RETVOID;
}

StackSlot GLVideoClip::setVideoLooping(RUNNER_ARGS)
{
    RUNNER_PopArgs1(looping);
    RUNNER_CheckTag1(TBool, looping);

    this->looping = looping.GetBool();

    RETVOID;
}

StackSlot GLVideoClip::setVideoControls(RUNNER_ARGS)
{
    RUNNER_PopArgs1(ctls);
    RUNNER_CheckTag1(TArray, ctls);

    controls = 0;

    for (unsigned int i = 0; i < RUNNER->GetArraySize(ctls); i++)
    {
        const StackSlot &obj = RUNNER->GetArraySlot(ctls, i);
        RUNNER_CheckTag1(TStruct, obj);

        const std::string &name = RUNNER->GetStructName(obj);
        if (name == "PauseResume")
            controls |= CtlPauseResume;
        else if (name == "VolumeControl")
            controls |= CtlVolume;
        else if (name == "FullScreenPlayer")
            controls |= CtlFullScreen;
        else if (name == "Scrubber")
            controls |= CtlScrubber;
    }

    RETVOID;
}

void GLVideoClip::setVideoTextureImage(GLTextureImage::Ptr image) {
    texture_image = image;
}

StackSlot GLVideoClip::setVideoSubtitle(RUNNER_ARGS)
{
    RUNNER_PopArgs1(subtitle);
    RUNNER_CheckTag1(TString, subtitle);

    if (!RUNNER->GetString(subtitle).empty()) {
        RUNNER_CopyArgArray(newargs, 10, 0);
        this->subtitle->setTextAndStyle(RUNNER, newargs);

        updateSubtitlesPosition();
        this->subtitle->setVisible(true);
    } else {
        this->subtitle->setVisible(false);
    }

    RETVOID;
}

void GLVideoClip::updateSubtitlesPosition()
{
    RUNNER_VAR = getFlowRunner();

    RUNNER_DefSlotArray(clipX, 1);
    clipX[0] = StackSlot::MakeDouble((size.x - this->subtitle->getLocalBBoxSelf().size().x) / 2);
    this->subtitle->setClipX(RUNNER, clipX);

    RUNNER_DefSlotArray(clipY, 1);
    clipY[0] = StackSlot::MakeDouble((size.y - this->subtitle->getLocalBBoxSelf().size().y) - 2);
    this->subtitle->setClipY(RUNNER, clipY);
}

StackSlot GLVideoClip::addStreamStatusListener(RUNNER_ARGS)
{
    RUNNER_PopArgs1(callback);

    return addEventCallback(RUNNER, FlowVideoStreamEvent, callback, "addStreamStatusListener$dispose");
}

void GLVideoClip::applyHeaders(QNetworkRequest *request) {
    // Set headers for HTTP request
    for (HttpRequest::T_SMap::iterator it = req_headers.begin(); it != req_headers.end(); ++it)
    {
        request->setRawHeader(
                    unicode2qt(it->first).toLatin1(),
                    unicode2qt(it->second).toUtf8()
        );
    }
}
