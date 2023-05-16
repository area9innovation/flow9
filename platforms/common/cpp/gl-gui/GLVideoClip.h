#ifndef GLVIDEOCLIP_H
#define GLVIDEOCLIP_H

#include "GLClip.h"
#include "GLRenderer.h"
#include "GLTextClip.h"

class GLVideoClip : public GLClip
{
public:
    enum StateChangeEvent {
        NoEvent = -1,
        PlayChange = 0, // 0 pause, 1 play, 2 stop
        PositionChange = 1,
        VolumeChange = 2,
        SizeChange = 3,
        DurationChange = 4
    };

    struct StateChange {
        GLVideoClip::StateChangeEvent event;
        int64_t value;
        int64_t secondary_value;

        StateChange() {
            event = GLVideoClip::NoEvent;
            value = -1;
            secondary_value = -1;
        }

        StateChange(GLVideoClip::StateChangeEvent event, int64_t value, int64_t secondary_value) {
            this->event = event;
            this->value = value;
            this->secondary_value = secondary_value;
        }
    };

protected:
    GLTextureImage::Ptr texture_image;

    ivec2 size;

    unicode_string name;
    int media_stream_id;
    bool use_media_stream;
    HttpRequest::T_SMap req_headers;

    int64_t position, lastPosition, duration, start, end;
    bool playing, failed, looping, loaded;
    int controls;
    float volume;
    double playbackRate;

    std::vector<StateChange> state_stack;
    StateChange current_event;

    GLTextClip *subtitle;

    void update();
    void updatePlay(bool playing, bool video_response, bool notify = true);
    void updatePosition(int64_t position, bool video_response, bool notify = true);
    void updateVolume(float volume);
    void updatePlaybackRate(double rate);
    void updateTimeRange(int64_t start, int64_t end);
    void checkTimeRange(int64_t position, bool video_response);

    void computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform);
    void renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box);

    void pushStateEvent(GLVideoClip::StateChangeEvent event, int64_t value, int64_t secondary_value = -1);
    void filterStateEvents(GLVideoClip::StateChangeEvent event, int64_t value = -1);
    void nextStateEvent();

    void notifySize(int w, int h);
    void notifyDuration(int64_t duration);
    void notifyPlay(bool playing);
    void notifyPosition(int64_t position);
public:
    GLVideoClip(GLRenderSupport *owner, const StackSlot &size_cb, const StackSlot &play_cb, const StackSlot &dur_cb, const StackSlot &pos_cb);

    enum Event {
        PlayStart = 0, // Loaded and/or start of video
        PlayEnd = 1,   // End of video (even when looping)
        // User actions:
        UserPause = 2,
        UserResume = 3,
        UserStop = 4,
        UserSeek = 5
    };

    enum Controls {
        CtlPauseResume = 1,
        CtlVolume = 2,
        CtlFullScreen = 4,
        CtlScrubber = 8
    };

    const GLTransform &getLocalTransform();
    bool useMediaStream() { return use_media_stream; }
    const unicode_string &getName() { return name; }
    int getMediaStreamId() { return media_stream_id; }
    bool isHeadersSet() { return req_headers.size() > 0; }
    void applyHeaders(QNetworkRequest *request);

    bool isPlaying() { return playing; }
    bool isLooping() { return looping; }
    int getControls() { return controls; }

    float getVolume() { return volume; }
    double getPlaybackRate() { return playbackRate; }
    int64_t getPosition() { return position; }

    void notifyNotFound();
    void notify(GLVideoClip::StateChangeEvent event, int64_t value, int64_t secondary_value = -1);
    void notifyEvent(Event ev);

    void updateSubtitlesPosition();

    ivec2 getSize() { return size; }
    void setVideoTextureImage(GLTextureImage::Ptr image);

    void setFocus(bool focus);

    DEFINE_FLOW_NATIVE_OBJECT(GLVideoClip, GLClip)

public:
    DECLARE_NATIVE_METHOD(playVideo)
    DECLARE_NATIVE_METHOD(playVideoFromMediaStream)
    DECLARE_NATIVE_METHOD(playVideo2)
    DECLARE_NATIVE_METHOD(seekVideo)
    DECLARE_NATIVE_METHOD(pauseVideo)
    DECLARE_NATIVE_METHOD(resumeVideo)
    DECLARE_NATIVE_METHOD(closeVideo)
    DECLARE_NATIVE_METHOD(getVideoPosition)
    DECLARE_NATIVE_METHOD(setVideoVolume)
    DECLARE_NATIVE_METHOD(setVideoPlaybackRate)
    DECLARE_NATIVE_METHOD(setVideoTimeRange)
    DECLARE_NATIVE_METHOD(setVideoLooping)
    DECLARE_NATIVE_METHOD(setVideoControls)
    DECLARE_NATIVE_METHOD(setVideoSubtitle)
    DECLARE_NATIVE_METHOD(addStreamStatusListener)
};

#endif // GLVIDEOCLIP_H
