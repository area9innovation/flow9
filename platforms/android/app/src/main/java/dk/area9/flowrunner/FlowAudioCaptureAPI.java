package dk.area9.flowrunner;

import java.io.File;
import android.annotation.TargetApi;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.DialogInterface.OnClickListener;
import android.media.MediaMetadataRetriever;
import android.media.MediaRecorder;
import android.media.MediaRecorder.OnInfoListener;
import android.net.Uri;
import android.os.Build;
import androidx.annotation.Nullable;
import android.util.Log;

@TargetApi(Build.VERSION_CODES.GINGERBREAD_MR1)
public class FlowAudioCaptureAPI {

    public static final String AUDIO_APP_CALLBACK_ADDITIONAL_INFO = "FLOW_AUDIO_APP_CALLBACK_ADDITIONAL_INFO";
    public static final String AUDIO_APP_DESIRED_FILENAME = "FLOW_AUDIO_APP_DESIRED_FILENAME";
    public static final String AUDIO_APP_DURATION = "FLOW_AUDIO_APP_DURATION";

    @Nullable
    public static String audioAppCallbackAdditionalInfo = "";
    @Nullable
    public static String audioAppDesiredFilename = "";
    public static int audioAppDuration = -1;

    private Context context;
    private FlowRunnerWrapper wrapper;
    @Nullable
    private MediaRecorder mediaRecorder = null;
    @Nullable
    private File audioFile = null;
    private volatile static FlowAudioCaptureAPI uniqueInstance;
    private boolean isRecording = false;

    private FlowAudioCaptureAPI() {
       
    }
    
    private FlowAudioCaptureAPI(FlowRunnerWrapper wrapper) {
        this.wrapper = wrapper;
    }
    
    private void mediaRecorderRelease() {
        isRecording = false;
        audioFile = null;
        mediaRecorder.release();
    }
    
    public void setContext(Context context) {
        this.context = context;
    }
    

    public static FlowAudioCaptureAPI getInstance() {
        return uniqueInstance;
    }
    
    public static FlowAudioCaptureAPI getInstance(FlowRunnerWrapper wrapper) {
        if (uniqueInstance == null) {
            uniqueInstance = new FlowAudioCaptureAPI(wrapper);
        }
        return uniqueInstance;
    }
    
    public void startRecordAudio(String additionalInfo, String fileName, int duration) {
        if (!isRecording) {
            audioAppCallbackAdditionalInfo = additionalInfo;
            audioAppDesiredFilename = fileName;
            audioAppDuration = duration*1000;
            String audioFileName = fileName + ".mp4";
            File newAudioFile = new File(context.getApplicationInfo().dataDir, audioFileName);

            mediaRecorder = new MediaRecorder();
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
            mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
            mediaRecorder.setAudioChannels(2);
            mediaRecorder.setOutputFile(newAudioFile.getAbsolutePath());
            if (audioAppDuration > 0) {
                mediaRecorder.setMaxDuration(audioAppDuration);
            
                mediaRecorder.setOnInfoListener(new OnInfoListener() {
                    @Override
                    public void onInfo(MediaRecorder mr, int what, int extra) {
                        AlertDialog.Builder builder = new AlertDialog.Builder(context);
                        builder.setTitle("Audio recording stopped");
                        builder.setCancelable(false);
                        builder.setPositiveButton("OK", new OnClickListener() {
    
                            @Override
                            public void onClick(DialogInterface dialog, int which) {
                                
                            }
                            
                        });
                        if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                            builder.setMessage("The maximum length for this audio has been reached.");
                            AlertDialog alert = builder.create();
                            alert.show();
                        }
                    }
                });
            }
            
            try {
                mediaRecorder.prepare();
            } catch (IllegalStateException e) {
                Log.e(Utils.LOG_TAG, "MediaRecorder is busy by another application");
                e.printStackTrace();
                mediaRecorderRelease();
            } catch (Exception e) {
                Log.e(Utils.LOG_TAG, "Can't prepare MediaRecorder for some reason");
                e.printStackTrace();
                mediaRecorderRelease();
            }
            
            try {
                mediaRecorder.start();
                isRecording = true;
                audioFile = newAudioFile;
            } catch (Exception e){
                Log.e(Utils.LOG_TAG, "Can't start record audio for some reason");
                e.printStackTrace();
                mediaRecorderRelease();
            }
        }
        
    }

    public void stopRecordAudio() {
        if (mediaRecorder != null && isRecording) {
            try {
                isRecording = false;
                mediaRecorder.stop();
            } catch (IllegalStateException e) {
                Log.e(Utils.LOG_TAG, "MediaRecorder is busy by another application");
                e.printStackTrace();
                mediaRecorderRelease();
            }
        }
    }

    public void takeAudioRecord() {
        stopRecordAudio();
        if (audioFile != null) {
            MediaMetadataRetriever retriever = new MediaMetadataRetriever();
            retriever.setDataSource(context, Uri.fromFile(audioFile));
            if (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) != null) {

                String time = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);
                int timeInSec = Integer.parseInt(time) / 1000;
                int size = (int) audioFile.length();
                // Notify flow about Audio capture event
                retriever.release();
                wrapper.NotifyCameraEventAudio(0, Uri.fromFile(audioFile).toString(), audioAppCallbackAdditionalInfo, timeInSec, size);
            } else {
                retriever.release();
                wrapper.NotifyCameraEventAudio(1, "ERROR: Audio file corrupted", audioAppCallbackAdditionalInfo, -1, -1);
            }
            mediaRecorderRelease();
        } else {
            wrapper.NotifyCameraEventAudio(2, "ERROR: Nothing to save yet", audioAppCallbackAdditionalInfo, -1, -1);
        }
    }
}
