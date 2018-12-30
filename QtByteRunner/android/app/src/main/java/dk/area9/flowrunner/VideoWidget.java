package dk.area9.flowrunner;

import java.io.IOException;

import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.SurfaceTexture;
import android.media.MediaPlayer;
import android.opengl.GLES20;
import android.os.Handler;
import android.os.Looper;
import android.preference.PreferenceManager;
import android.util.Log;
import android.view.MotionEvent;
import android.view.Surface;
import android.view.View;
import android.widget.MediaController;
import android.widget.RelativeLayout;
import android.widget.VideoView;
import android.graphics.SurfaceTexture.OnFrameAvailableListener;

class VideoWidget extends NativeWidget {
    private static Boolean useNativeVideo = null;

    static final int PlayStart = 0; // Loaded and/or start of video
    static final int PlayEnd = 1;   // End of video
    static final int UserPause = 2;
    static final int UserResume = 3;
    static final int UserSeek = 5;

    static final int CtlPauseResume = 1;
    static final int CtlFullScreen = 4;
    static final int CtlScrubber = 8;

    private String url, filename;
    private boolean playing, looping, mediaPlayerPrepared, PlayStartReported;
    int controls;
    float volume;
    boolean seek_pending;
    int seek_pos;
    private VideoView vview;
    private MediaController mediaController;
    private MediaPlayer mediaPlayer;
    private SurfaceTexture surfaceTexture;
    
    private final Handler handler = new Handler(Looper.getMainLooper());

    public VideoWidget(FlowWidgetGroup group, long id) { 
        super(group, id);
        if (useNativeVideo == null) {
            SharedPreferences prefs = PreferenceManager.getDefaultSharedPreferences(group.getContext());
            useNativeVideo = !prefs.getBoolean("opengl_video", true);
        }
    }
    
    protected View createView() {
        Context ctx = group.getContext();
        VideoView video = null;
        MediaPlayer player = null;
        
        if (useNativeVideo) {
            video = new VideoView(ctx);
        } else {
            player = new MediaPlayer();
        }

        mediaController = new MediaController(ctx) {
            public void setMediaPlayer(final MediaController.MediaPlayerControl player) {
                super.setMediaPlayer(new MediaController.MediaPlayerControl() {
                    // Delegate methods to the real interface:
                    public boolean canPause() { return player.canPause(); }
                    public boolean canSeekBackward() { return player.canSeekBackward(); }
                    public boolean canSeekForward() { return player.canSeekForward(); }
                    public int getBufferPercentage() { return player.getBufferPercentage(); }
                    public int getCurrentPosition() { return player.getCurrentPosition(); }
                    public int getDuration() { return player.getDuration(); }
                    public boolean isPlaying() { return player.isPlaying(); }
                    // But also note some events and report them to flow:
                    public void pause() {
                        player.pause();
                        reportStatusEvent(UserPause);
                    }
                    public void seekTo(int pos) {
                        player.seekTo(pos);
                        reportStatusEvent(UserSeek);
                    }
                    public void start() {
                        player.start();
                        reportStatusEvent(UserResume);
                    }
                    @Override
                    public int getAudioSessionId() {
                        // TODO Auto-generated method stub
                        return 0;
                    }
                });
            }

            public void setAnchorView(View view) {
                super.setAnchorView(group);
            }
        };

        if (video != null) {
            video.setOnTouchListener(new View.OnTouchListener() {
                public boolean onTouch(View v, MotionEvent event) {
                    if (event.getAction() == MotionEvent.ACTION_UP) {
                        if (event.getEventTime() - event.getDownTime() > 500 ) { // Long Tap
                            toggleFullscreen();
                        } else {
                            toggleMediaController();
                        }
                    }
    
                    return true;
                }
            });
            
            video.setZOrderMediaOverlay(true);
            vview = video;
        }
        if (player != null) {
            mediaPlayer = player;
            createVideoTexture();
        }
        
        mediaPlayerPrepared = false;
        
        int fill = RelativeLayout.LayoutParams.FILL_PARENT;
        final RelativeLayout grp = new RelativeLayout(ctx);

        RelativeLayout.LayoutParams vparams = new RelativeLayout.LayoutParams(fill,fill);
        vparams.addRule(RelativeLayout.ALIGN_PARENT_TOP,-1);
        vparams.addRule(RelativeLayout.ALIGN_PARENT_LEFT,-1);
        if (vview != null)
            grp.addView(vview, vparams);

        return grp;
    }

    public void destroy() {
        mediaPlayerPrepared = false;

        // Ensure the resources are immediately released
        if (vview != null)
            vview.stopPlayback();

        if (mediaPlayer != null) {
            mediaPlayer.stop();
            mediaPlayer.reset();
            mediaPlayer.release();
            mediaPlayer = null;
        }

        super.destroy();
    }

    private float linearVolume() {
        if (volume >= 1.0)
            return 1.0f;
        else if (volume <= 0.0)
            return 0.0f;
        else
            return volume;
    }

    private boolean isControllerEnabled() {
        return (controls & (CtlPauseResume | CtlScrubber)) != 0;
    }

    private void toggleMediaController() {
        if ( mediaController.isShown() ) {
            mediaController.hide();
        } else {
            if (!isControllerEnabled())
                return;

            mediaController.show();
        }
    }
    
    private boolean fullscreen = false;
    
    private void toggleFullscreen() {
        if ((controls & CtlFullScreen) == 0 && !fullscreen)
            return;

        fullscreen = !fullscreen;
        
        view.requestLayout();
    }

    protected void doRequestLayout() {
        if (vview != null)
            vview.setVisibility(visible ? FlowWidgetGroup.VISIBLE : FlowWidgetGroup.INVISIBLE);
     
        super.doRequestLayout();
    }

    public void layout() {
        super.layout();

        //Log.d(Utils.LOG_TAG, "VIDEO LAYOUT " + (maxx-minx) + "x" + (maxy-miny));

       if (fullscreen && view != null)
            view.layout(0, 0, group.getRight(), group.getBottom());
    }

    public void resize(boolean nvisible, int nminx, int nminy, int nmaxx, int nmaxy, float nscale, float nalpha) {
        // Must have at least 1x1 px, or it won't work at all.
        //
        // Also, due to an issue in SurfaceView.updateWindow, we
        // have to ensure that when we resize the video, we also
        // change the upper left corner coordinates, or it won't
        // update the window in the compositing manager.
        //
        // This bug is present in android 2.2.1, and may still be in 4.1.1.
        if (nmaxx <= nminx || nmaxy <= nminy)
        {
            nminx++; nminy++;
            nmaxx = Math.max(nminx+1,nmaxx);
            nmaxy = Math.max(nminy+1,nmaxy);
        }

        //Log.d(Utils.LOG_TAG, "VIDEO RESIZE " + (nmaxx-nminx) + "x" + (nmaxy-nminy));

        super.resize(nvisible, nminx, nminy, nmaxx, nmaxy, nscale, nalpha);
    }
    
    private boolean isKitKatOrLower() {
        return android.os.Build.VERSION.SDK_INT <= android.os.Build.VERSION_CODES.KITKAT;
    }

    private void updateStateFlags() {
        if (isControllerEnabled() && useNativeVideo) {
            vview.setMediaController(mediaController);
        } else if (vview != null) {
            mediaController.setVisibility(View.GONE);
            mediaController.setAnchorView(vview);
            vview.setMediaController(null);
        }

        if (mediaPlayer != null && mediaPlayerPrepared) {
            try {
                if (seek_pending) {
                    mediaPlayer.seekTo(seek_pos);
                    seek_pending = false;
                } else {
                    if (!playing && mediaPlayer.isPlaying()) {
                        reportStatusEvent(UserPause);
                        mediaPlayer.pause();
                    } else if (playing && !mediaPlayer.isPlaying()) {
                        if (isKitKatOrLower())
                            mediaPlayer.seekTo(mediaPlayer.getCurrentPosition());

                        reportStatusEvent(UserResume);
                        mediaPlayer.start();
                    }
                }

                mediaPlayer.setLooping(looping);
                float vv = linearVolume();
                mediaPlayer.setVolume(vv, vv);
            } catch (IllegalStateException e) {
                // There is rare and weird IllegalStateException on setLooping although 
                // MP is prepared.
                Log.e(Utils.LOG_TAG, "IllegalStateException for MediaPlayer updateStateFlags");
            }
        }
    }

    private MediaPlayer.OnErrorListener errorListener = new MediaPlayer.OnErrorListener() {
        public boolean onError(MediaPlayer mp, int what, int extra) {
            Log.e(Utils.LOG_TAG, "Video error: " + what + " " + extra);
            if (useNativeVideo || mediaPlayerPrepared) reportFailure(); // Weird error -38 event for
            // no video view on the stage case - when opengl texture used.
            // Before even source is set and player prepared.
            // Although all works fine after that.
            return true;
        }
    };

    private MediaPlayer.OnSeekCompleteListener seekListener = new MediaPlayer.OnSeekCompleteListener() {
        @Override
        public void onSeekComplete(MediaPlayer mp) {
            // Video seek is asynchronous
            reportStatusEvent(PlayStart);
            updateStateFlags();

            // Hack for displaying image when paused
            if (!mediaPlayer.isPlaying() && isKitKatOrLower()) {
                mediaPlayer.start();
            }

            reportPosition(mediaPlayer.getCurrentPosition());
        }
    };

    private boolean isMediaTypeAudio() {
        for (MediaPlayer.TrackInfo info : mediaPlayer.getTrackInfo()) {
            if (info.getTrackType() == MediaPlayer.TrackInfo.MEDIA_TRACK_TYPE_VIDEO)
                return false;
        }

        return true;
    }

    private void addCustomPositionListener() {
        final Handler posHandler = new Handler();
        group.getFlowRunnerView().queueEvent(new Runnable() {
            @Override
            public void run() {
                if (mediaPlayer != null && mediaPlayer.isPlaying())
                    reportPosition(mediaPlayer.getCurrentPosition());

                posHandler.postDelayed(this, 100);
            }
        });
    }

    private MediaPlayer.OnPreparedListener preparedListener = new MediaPlayer.OnPreparedListener() {
        public void onPrepared(MediaPlayer mp) {
            if (mediaPlayer == null)
                mediaPlayer = mp;

            mediaPlayerPrepared = true;

            reportSize(mediaPlayer.getVideoWidth(), mediaPlayer.getVideoHeight());
            reportDuration(mediaPlayer.getDuration());

            /*
             * For some reason the video sometimes fails to start
             * unless seeking and starting is done in this callback.
             * It might be not the most correct usage of the API,
             * but there you are.
             */

            mediaPlayer.setOnSeekCompleteListener(seekListener);

            if (!seek_pending) {
                seek_pos = 0;
                seek_pending = true;
            }

            updateStateFlags();

            if (isMediaTypeAudio())
                addCustomPositionListener();
        }
    };

    private MediaPlayer.OnCompletionListener completionListener = new MediaPlayer.OnCompletionListener() {
        public void onCompletion(MediaPlayer mp) {
            reportPosition(mediaPlayer.getDuration());
            reportStatusEvent(PlayEnd);
            if (looping) {
                mediaPlayer.seekTo(0);
            }
        }
    };

    private Runnable createCallback = new Runnable() {
        public void run() {
                if (id == 0) return;
                getOrCreateView();

            if (vview != null) {
                vview.setOnErrorListener(errorListener);
                vview.setOnPreparedListener(preparedListener);
                vview.setOnCompletionListener(completionListener);

                vview.setVideoPath(filename);
            } else if (mediaPlayer != null) {
                mediaPlayer.setOnErrorListener(errorListener);
                mediaPlayer.setOnPreparedListener(preparedListener);
                mediaPlayer.setOnCompletionListener(completionListener);
            }
        }
    };

    private Runnable updateCallback = new Runnable() {
        public void run() {
            if (id == 0 || (mediaPlayer == null && vview == null)) return;
            updateStateFlags();
        }
    };

    private long getReportId()
    {
        if (id == 0) return 0;
        if (group.getBlockEvents()) return 0;
        return id;
    }

    private void reportFailure()
    {
        long idv = getReportId();
        if (idv != 0)
            group.getWrapper().deliverVideoNotFound(idv);
    }

    private void reportSize(int width, int height)
    {
        Log.d(Utils.LOG_TAG, "VIDEO SIZE " + width + "x" + height);
        long idv = getReportId();
        if (idv != 0)
            group.getWrapper().deliverVideoSize(idv, width, height);
    }
    
    private void reportDuration(long duration)
    {
        Log.d(Utils.LOG_TAG, "VIDEO DURATION " + duration);
        long idv = getReportId();
        if (idv != 0)
            group.getWrapper().deliverVideoDuration(idv, duration);
    }

    private void reportPosition(long position) {
        long idv = getReportId();
        if (idv != 0)
            group.getWrapper().deliverVideoPosition(idv, position);
    }

    private void reportStatusEvent(final int event)
    {
        if (event == PlayStart)
            if (PlayStartReported)
                return;
            else
                PlayStartReported = true;
        final long idv = getReportId();

        handler.post(new Runnable() {
            @Override
            public void run() {
                if (idv != 0)
                    group.getWrapper().deliverVideoPlayStatus(idv, event);
            }
        });
    }

    public void init(final String url, boolean playing, boolean looping, int controls, float volume)
    {
        this.url = url;
        this.filename = null;
        this.playing = playing;
        this.looping = looping;
        this.controls = controls;
        this.volume = volume;
        this.seek_pos = 0;

        ResourceCache.Resolver resolver = new ResourceCache.Resolver() {
            public void resolveFile(String filename) {
                if (VideoWidget.this.url != url)
                    return;

                VideoWidget.this.filename = filename;
                handler.post(createCallback);
            }

            public void resolveError(String message) {
                Log.e(Utils.LOG_TAG, "Cannot load video: " + message);
                reportFailure();
            }
        };

        try {
            ResourceCache.getInstance(group.getContext()).getCachedResource(group.resource_uri, url, resolver);
        } catch (IOException e) {
            Log.e(Utils.LOG_TAG, "Cannot load video: " + e.getMessage());
            reportFailure();
        }
    }

    public void setPlaying(boolean playing)
    {
        this.playing = playing;

        handler.post(updateCallback);
    }

    public void setPosition(long position)
    {
        this.seek_pos = (int)position;
        this.seek_pending = true;

        handler.post(updateCallback);
    }

    public void setVolume(float volume)
    {
        this.volume = volume;

        handler.post(updateCallback);
    }
    
    public void destroySurface() {
        mediaPlayer.setSurface(null);
    }
    
    public void createSurface() {
        if (mediaPlayerPrepared) {
            createVideoTexture();
        }
    }

    private Runnable renderVideoImage = new Runnable() {
        @Override
        public void run() {
            try {
                if (isValidGLESFramebuffer()) {
                    surfaceTexture.updateTexImage();
                    group.getFlowRunnerView().requestRender();
                }
            } catch (Exception e) {
                Log.e(Utils.LOG_TAG, "ERROR ON UPDATE TEX IMAGE!");
            }
        }
    };

    private OnFrameAvailableListener frameAvailableListener = new OnFrameAvailableListener() {
        @Override
        public void onFrameAvailable(SurfaceTexture arg0) {
            if (!mediaPlayerPrepared)
                return;

            // Hack to have a initial image
            if (mediaPlayer != null && mediaPlayer.isPlaying() && !playing && isKitKatOrLower()) {
                updateStateFlags();
            }

            reportPosition(mediaPlayer.getCurrentPosition());

            group.getFlowRunnerView().queueEvent(renderVideoImage);
        }
    };
    
    // Should be called only from GL thread
    private boolean isValidGLESFramebuffer() {
        return GLES20.glCheckFramebufferStatus(GLES20.GL_FRAMEBUFFER) == GLES20.GL_FRAMEBUFFER_COMPLETE;
    }
    
    public void createVideoTexture() {
        group.getFlowRunnerView().queueEvent(new Runnable() {
            @Override
            public void run() {
                final int GL_TEXTURE_EXTERNAL_OES = 0x8D65;

                int[] textures = new int[1];
                GLES20.glGenTextures(1, textures, 0);
                final int texture_id = textures[0];

                GLES20.glBindTexture(GL_TEXTURE_EXTERNAL_OES, texture_id);
                GLES20.glTexParameterf(GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST);
                GLES20.glTexParameterf(GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR);

                surfaceTexture = new SurfaceTexture(texture_id);
                Surface surface = new Surface(surfaceTexture);

                try {
                    mediaPlayer.setSurface(surface);

                    if (!mediaPlayerPrepared) {
                        mediaPlayer.setDataSource(filename);
                        mediaPlayer.prepareAsync();
                    } else {
                        mediaPlayer.seekTo(mediaPlayer.getCurrentPosition());
                    }

                    surfaceTexture.setOnFrameAvailableListener(frameAvailableListener);

                    if (id != 0) // Widget may be already destroyed at this point
                        group.getWrapper().setVideoExternalTextureId(id, texture_id);

                } catch (Exception e1) {
                    e1.printStackTrace();
                    reportFailure();
                }
            }
        });
    }
}
