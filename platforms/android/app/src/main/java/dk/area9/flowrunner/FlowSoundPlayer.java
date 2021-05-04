package dk.area9.flowrunner;

import java.io.File;
import java.io.IOException;
import java.net.URI;
import java.util.HashMap;

import android.content.Context;
import android.media.MediaPlayer;
import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

class FlowSoundPlayer implements FlowRunnerWrapper.SoundPlayer {
    private Context context;
    private URI loader_uri;
    private FlowRunnerWrapper wrapper;

    public FlowSoundPlayer(Context context, FlowRunnerWrapper wrapper) {
        this.context = context;
        this.wrapper = wrapper;
        
        wrapper.setSoundPlayer(this);

        wrapper.addListener(new FlowRunnerWrapper.ListenerAdapter() {
            public void onFlowReset(boolean post_destroy) {
                reset();
            }
        });
    }

    public void setLoaderURI(URI uri) {
        loader_uri = uri;
    }

    /* Cache preloading */
    @NonNull
    private HashMap<String, String> uri_cache = new HashMap<String,String>();
    @NonNull
    private HashMap<String, Integer> soundUrlDurations = new HashMap<String, Integer>();
    
    public void preloadSound(@NonNull final String url, @NonNull final FlowRunnerWrapper.SoundLoadResolver rsv) throws IOException {
        if (uri_cache.get(url) != null) {
            rsv.resolveReady();
            return;
        }

        ResourceCache.getInstance(context).getCachedResource(loader_uri, url, new ResourceCache.Resolver() {
            public void resolveFile(@NonNull String filename) {
                uri_cache.put(url, filename);
                MediaPlayer mp = MediaPlayer.create(context, Uri.fromFile(new File(filename))); 
                soundUrlDurations.put(url, mp.getDuration());
                mp.reset(); // hint to dispose it

                rsv.resolveReady();
            }
            public void resolveError(String message) {
                rsv.resolveError(message);                
            }
        });        
    }

    @Override
    public int getUrlDuration(String url) {
        Integer duration = soundUrlDurations.get(url);
        return duration != null ? duration.intValue() : 0;
    }

    /* Playback */
    private class Channel {
        final long id;
        @Nullable
        MediaPlayer player;
        
        Channel(long id) {
            this.id = id;
        }
        
        void notifyDone() {
            wrapper.deliverSoundPlayDone(id);
            destroy();
        }

        void beginPlay(File file, float start, boolean loop) {
            if (player != null)
                destroy();
                
            try {
                player = MediaPlayer.create(context, Uri.fromFile(file));
    
                player.seekTo((int)start);
                player.setLooping(loop);
    
                player.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
                    public void onCompletion(MediaPlayer mp) {
                        notifyDone();
                    }
                });
                
                player.setOnErrorListener(new MediaPlayer.OnErrorListener() {
                    public boolean onError(MediaPlayer mp, int what, int extra) {
                        notifyDone();
                        return false;
                    }
                });
                
                player.start();
            } catch (RuntimeException e) {
                destroy();
                throw e;
            }
        }
        
        void stopPlay() {
            destroy();
        }
        
        void destroy() {
            if (player != null) {
                player.release();
                player = null;
            }
        }
        
        void setVolume(float volume) {
            if (player != null)
                player.setVolume(volume, volume);
        }
        
        float getPosition() {
            if (player != null)
                return player.getCurrentPosition();
            else
                return 0;
        }

        float getDuration() {
            if (player != null)
                return player.getDuration();
            else
                return 0;
        }
}
    
    @NonNull
    private HashMap<Long,Channel> channels = new HashMap<Long,Channel>();
    
    public void reset() {
        for (Channel channel : channels.values())
            channel.destroy();
        channels.clear();
    }

    private Channel getChannel(long id, boolean create) {
        Channel cur = channels.get(id);
        if (cur == null && create) {
            channels.put(id, cur = new Channel(id));
        }
        return cur;
    }

    public void beginPlay(long channel_id, String url, float start_pos, boolean loop) {
        String filename;
        filename = uri_cache.get(url);
        if (filename == null)
            throw new IllegalStateException("Sound " + url + " wasn't preloaded.");

        File file = new File(filename);
        if (!file.exists())
            throw new IllegalStateException("Preloaded sound file doesn't exist.");
       
        Channel channel = getChannel(channel_id, true);
        channel.beginPlay(file, start_pos, loop);
    }

    public void stopPlay(long channel_id) {
        Channel channel = getChannel(channel_id, false);
        if (channel != null)
            channel.stopPlay();
    }

    public void setVolume(long channel_id, float value) {
        Channel channel = getChannel(channel_id, false);
        if (channel != null)
            channel.setVolume(value);        
    }

    public float getPosition(long channel_id) {
        Channel channel = getChannel(channel_id, false);
        if (channel != null)
            return channel.getPosition();
        else
            return 0;
    }

    public float getLength(long channel_id) {
        Channel channel = getChannel(channel_id, false);
        if (channel != null)
            return channel.getDuration();
        else
            return 0;
    }
}
