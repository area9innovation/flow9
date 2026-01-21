package com.area9innovation.flow;

import org.jcodec.api.FrameGrab;
import org.jcodec.api.JCodecException;
import org.jcodec.api.awt.AWTSequenceEncoder;
import org.jcodec.common.Demuxer;
import org.jcodec.common.DemuxerTrack;
import org.jcodec.common.DemuxerTrackMeta;
import org.jcodec.common.Format;
import org.jcodec.common.JCodecUtil;
import org.jcodec.common.io.FileChannelWrapper;
import org.jcodec.common.io.NIOUtils;
import org.jcodec.common.io.SeekableByteChannel;
import org.jcodec.common.model.ColorSpace;
import org.jcodec.common.model.Picture;
import org.jcodec.common.model.Rational;
import org.jcodec.common.model.Size;
import org.jcodec.containers.mp4.demuxer.MP4Demuxer;
import org.jcodec.containers.mkv.demuxer.MKVDemuxer;
import org.jcodec.scale.AWTUtil;
import org.jcodec.scale.ColorUtil;
import org.jcodec.scale.Transform;
import org.jcodec.codecs.aac.AACDecoder;
import org.jcodec.common.AudioCodecMeta;
import org.jcodec.common.model.AudioBuffer;
import org.jcodec.common.model.Packet;

import javax.sound.sampled.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.net.URL;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.nio.channels.FileChannel;
import java.nio.channels.ReadableByteChannel;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Base64;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Java implementation of MediaBunny for server-side media processing.
 * Uses jcodec for video operations and javax.sound for audio operations.
 *
 * This provides an alternative to the browser-based WebCodecs implementation
 * for server-side processing scenarios.
 *
 * The Java API uses file paths (String) instead of browser blobs (native),
 * so it has separate native bindings with "Path" suffix:
 *   - mbGetMediaDurationPath, mbGetVideoInfoPath, mbConversionPath, etc.
 *
 * Dependencies required in pom.xml or build.gradle:
 *   - org.jcodec:jcodec:0.2.5
 *   - org.jcodec:jcodec-javase:0.2.5
 *
 * For MP3 encoding, additionally add:
 *   - com.github.trilarion:java-vorbis-support:1.2.1 (for OGG)
 *   - javazoom:jlayer:1.0.1 (for MP3 decoding)
 *   - net.sourceforge.lame:lame4j:1.0 (for MP3 encoding, optional)
 */
public class Mediabunny extends NativeHost {

    private static final ExecutorService executor = Executors.newFixedThreadPool(4);

    public Mediabunny() {}

    /**
     * Get media duration from a file path.
     * Native binding: Mediabunny.getMediaDurationPath
     *
     * @param filePath Path to the media file
     * @param cb Callback receiving duration in seconds (as double)
     */
    public static Object getMediaDurationPath(String filePath, Func1<Object, Double> cb) {
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Callbacks.Callback callback = callbacks.make(cb);

        executor.submit(() -> {
            try {
                double duration = getMediaDurationSync(filePath);
                callback.setReady(duration);
            } catch (Exception e) {
                System.err.println("[Mediabunny] getMediaDurationPath error: " + e.getMessage());
                callback.setReady(0.0);
            }
        });
        return null;
    }

    /**
     * Get media duration from base64 encoded content.
     * Native binding: Mediabunny.getMediaDurationFromBase64Path
     *
     * @param base64str Base64 encoded media data (can include data URL prefix)
     * @param cb Callback receiving duration in seconds
     */
    public static Object getMediaDurationFromBase64Path(String base64str, Func1<Object, Double> cb) {
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Callbacks.Callback callback = callbacks.make(cb);

        executor.submit(() -> {
            Path tempFile = null;
            try {
                byte[] data = decodeBase64(base64str);
                tempFile = Files.createTempFile("mediabunny_", ".tmp");
                Files.write(tempFile, data);
                double duration = getMediaDurationSync(tempFile.toString());
                callback.setReady(duration);
            } catch (Exception e) {
                System.err.println("[Mediabunny] getMediaDurationFromBase64Path error: " + e.getMessage());
                callback.setReady(0.0);
            } finally {
                deleteTempFile(tempFile);
            }
        });
        return null;
    }

    /**
     * Get media duration from a URL.
     * Native binding: Mediabunny.getMediaDurationFromUrlPath
     *
     * @param mediaUrl URL to the media file
     * @param cb Callback receiving duration in seconds
     */
    public static Object getMediaDurationFromUrlPath(String mediaUrl, Func1<Object, Double> cb) {
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Callbacks.Callback callback = callbacks.make(cb);

        executor.submit(() -> {
            Path tempFile = null;
            try {
                tempFile = downloadToTempFile(mediaUrl);
                double duration = getMediaDurationSync(tempFile.toString());
                callback.setReady(duration);
            } catch (Exception e) {
                System.err.println("[Mediabunny] getMediaDurationFromUrlPath error: " + e.getMessage());
                callback.setReady(0.0);
            } finally {
                deleteTempFile(tempFile);
            }
        });
        return null;
    }

    /**
     * Get video information (width, height, bitrate).
     * Native binding: Mediabunny.getVideoInfoPath
     *
     * @param filePath Path to the video file
     * @param cb Callback receiving (width, height, bitrate)
     */
    public static Object getVideoInfoPath(String filePath, Func3<Object, Integer, Integer, Integer> cb) {
        // For Func3, we need a wrapper since Callbacks.make expects Func1
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Func1<Object, Object> wrapper = (Object args) -> {
            int[] arr = (int[]) args;
            return cb.invoke(arr[0], arr[1], arr[2]);
        };
        Callbacks.Callback callback = callbacks.make(wrapper);

        executor.submit(() -> {
            try {
                int[] info = getVideoInfoSync(filePath);
                callback.setReady(info);
            } catch (Exception e) {
                System.err.println("[Mediabunny] getVideoInfoPath error: " + e.getMessage());
                callback.setReady(new int[]{0, 0, 0});
            }
        });
        return null;
    }

    /**
     * Get video information from base64 encoded content.
     * Native binding: Mediabunny.getVideoInfoFromBase64Path
     */
    public static Object getVideoInfoFromBase64Path(String base64str, Func3<Object, Integer, Integer, Integer> cb) {
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Func1<Object, Object> wrapper = (Object args) -> {
            int[] arr = (int[]) args;
            return cb.invoke(arr[0], arr[1], arr[2]);
        };
        Callbacks.Callback callback = callbacks.make(wrapper);

        executor.submit(() -> {
            Path tempFile = null;
            try {
                byte[] data = decodeBase64(base64str);
                tempFile = Files.createTempFile("mediabunny_", ".tmp");
                Files.write(tempFile, data);
                int[] info = getVideoInfoSync(tempFile.toString());
                callback.setReady(info);
            } catch (Exception e) {
                System.err.println("[Mediabunny] getVideoInfoFromBase64Path error: " + e.getMessage());
                callback.setReady(new int[]{0, 0, 0});
            } finally {
                deleteTempFile(tempFile);
            }
        });
        return null;
    }

    /**
     * Get video information from a URL.
     * Native binding: Mediabunny.getVideoInfoFromUrlPath
     */
    public static Object getVideoInfoFromUrlPath(String mediaUrl, Func3<Object, Integer, Integer, Integer> cb) {
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Func1<Object, Object> wrapper = (Object args) -> {
            int[] arr = (int[]) args;
            return cb.invoke(arr[0], arr[1], arr[2]);
        };
        Callbacks.Callback callback = callbacks.make(wrapper);

        executor.submit(() -> {
            Path tempFile = null;
            try {
                tempFile = downloadToTempFile(mediaUrl);
                int[] info = getVideoInfoSync(tempFile.toString());
                callback.setReady(info);
            } catch (Exception e) {
                System.err.println("[Mediabunny] getVideoInfoFromUrlPath error: " + e.getMessage());
                callback.setReady(new int[]{0, 0, 0});
            } finally {
                deleteTempFile(tempFile);
            }
        });
        return null;
    }

    /**
     * Convert media to a different format.
     * Native binding: Mediabunny.conversionPath
     *
     * @param inputPath Path to input file
     * @param format Output format: "mp3", "wav", "mp4", "webm"
     * @param params Array of MBStyle structs: [MBSampleRate, MBCrop, MBTrim, MBAudioNumberOfChannels]
     * @param cb Success callback receiving output file path
     * @param onError Error callback
     */
    public static Object conversionPath(String inputPath, String format, Object[] params,
                                        Func1<Object, String> cb, Func1<Object, String> onError) {
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Callbacks.Callback successCallback = callbacks.make(cb);
        Callbacks.Callback errorCallback = callbacks.make(onError);
        successCallback.alternativeCallbackIds = new Integer[]{errorCallback.id};
        errorCallback.alternativeCallbackIds = new Integer[]{successCallback.id};

        executor.submit(() -> {
            try {
                // Extract parameters from MBStyle structs
                int sampleRate = extractSampleRate(params);
                int[] crop = extractCrop(params);
                int[] trim = extractTrim(params);
                int numberOfChannels = extractNumberOfChannels(params);

                String outputPath = convertMedia(inputPath, format, sampleRate, crop, trim, numberOfChannels);
                successCallback.setReady(outputPath);
            } catch (Exception e) {
                String errorMsg = "Conversion failed: " + e.getMessage();
                System.err.println("[Mediabunny] " + errorMsg);
                e.printStackTrace();
                errorCallback.setReady(errorMsg);
            }
        });
        return null;
    }

    /**
     * Concatenate multiple media files.
     * Native binding: Mediabunny.concatMediaPath
     *
     * @param inputPaths Array of input file paths
     * @param outputName Base name for output file
     * @param cb Success callback receiving output file path
     * @param onError Error callback
     */
    public static Object concatMediaPath(Object[] inputPaths, String outputName,
                                         Func1<Object, String> cb, Func1<Object, String> onError) {
        Callbacks callbacks = FlowRuntime.getCallbacks();
        Callbacks.Callback successCallback = callbacks.make(cb);
        Callbacks.Callback errorCallback = callbacks.make(onError);
        successCallback.alternativeCallbackIds = new Integer[]{errorCallback.id};
        errorCallback.alternativeCallbackIds = new Integer[]{successCallback.id};

        executor.submit(() -> {
            try {
                if (inputPaths == null || inputPaths.length == 0) {
                    errorCallback.setReady("No files provided for concatenation");
                    return;
                }

                if (inputPaths.length == 1) {
                    successCallback.setReady((String) inputPaths[0]);
                    return;
                }

                String[] paths = new String[inputPaths.length];
                for (int i = 0; i < inputPaths.length; i++) {
                    paths[i] = (String) inputPaths[i];
                }

                String outputPath = concatenateMedia(paths, outputName);
                successCallback.setReady(outputPath);
            } catch (Exception e) {
                String errorMsg = "Concatenation failed: " + e.getMessage();
                System.err.println("[Mediabunny] " + errorMsg);
                e.printStackTrace();
                errorCallback.setReady(errorMsg);
            }
        });
        return null;
    }

    /**
     * Get file info (size, type, lastModified).
     * Native binding: Mediabunny.getFileInfoPath
     */
    public static Object getFileInfoPath(String filePath, Func3<Object, Integer, String, Double> cb) {
        try {
            File file = new File(filePath);
            int size = (int) file.length();
            String type = detectMimeType(filePath);
            double lastModified = file.lastModified();
            cb.invoke(size, type, lastModified);
        } catch (Exception e) {
            System.err.println("[Mediabunny] getFileInfoPath error: " + e.getMessage());
            cb.invoke(0, "error", 0.0);
        }
        return null;
    }

    // ==================== Synchronous Implementation Methods ====================

    private static double getMediaDurationSync(String filePath) throws Exception {
        File file = new File(filePath);
        String ext = getFileExtension(filePath).toLowerCase();

        // Try video duration first
        if (isVideoFile(ext)) {
            try (SeekableByteChannel channel = NIOUtils.readableChannel(file)) {
                Demuxer demuxer = createDemuxer(file, channel, ext);
                if (demuxer != null) {
                    DemuxerTrack videoTrack = demuxer.getVideoTracks().isEmpty() ? null : demuxer.getVideoTracks().get(0);
                    if (videoTrack != null) {
                        DemuxerTrackMeta meta = videoTrack.getMeta();
                        if (meta != null && meta.getTotalDuration() > 0) {
                            return meta.getTotalDuration();
                        }
                    }
                    // Try audio track for duration
                    DemuxerTrack audioTrack = demuxer.getAudioTracks().isEmpty() ? null : demuxer.getAudioTracks().get(0);
                    if (audioTrack != null) {
                        DemuxerTrackMeta meta = audioTrack.getMeta();
                        if (meta != null && meta.getTotalDuration() > 0) {
                            return meta.getTotalDuration();
                        }
                    }
                }
            }
        }

        // Try audio duration for audio files
        if (isAudioFile(ext)) {
            return getAudioDuration(filePath);
        }

        return 0.0;
    }

    private static int[] getVideoInfoSync(String filePath) throws Exception {
        File file = new File(filePath);
        String ext = getFileExtension(filePath).toLowerCase();

        int width = 0, height = 0, bitrate = 0;

        // Use FrameGrab to get video dimensions - more reliable than demuxer metadata
        try {
            FrameGrab grab = FrameGrab.createFrameGrab(NIOUtils.readableChannel(file));
            Picture picture = grab.getNativeFrame();
            if (picture != null) {
                width = picture.getWidth();
                height = picture.getHeight();
            }
        } catch (Exception e) {
            // Fall back to demuxer approach
        }

        // Get duration for bitrate calculation
        try (SeekableByteChannel channel = NIOUtils.readableChannel(file)) {
            Demuxer demuxer = createDemuxer(file, channel, ext);
            if (demuxer != null && !demuxer.getVideoTracks().isEmpty()) {
                DemuxerTrack videoTrack = demuxer.getVideoTracks().get(0);
                DemuxerTrackMeta meta = videoTrack.getMeta();
                if (meta != null) {
                    // Estimate bitrate from file size and duration
                    double duration = meta.getTotalDuration();
                    if (duration > 0) {
                        bitrate = (int) ((file.length() * 8) / duration);
                    }
                }
            }
        }

        return new int[]{width, height, bitrate};
    }

    private static String convertMedia(String inputPath, String format, int sampleRate,
                                       int[] crop, int[] trim, int numberOfChannels) throws Exception {
        String ext = format.toLowerCase();

        switch (ext) {
            case "wav":
                return convertToWav(inputPath, sampleRate, trim, numberOfChannels);
            case "mp3":
                return convertToMp3(inputPath, sampleRate, trim, numberOfChannels);
            case "mp4":
                return convertToMp4(inputPath, crop, trim);
            case "webm":
                // jcodec doesn't support WebM output natively, fall back to MP4
                System.err.println("[Mediabunny] WebM output not supported by jcodec, using MP4 instead");
                return convertToMp4(inputPath, crop, trim);
            default:
                throw new UnsupportedOperationException("Unsupported output format: " + format);
        }
    }

    private static String convertToWav(String inputPath, int sampleRate, int[] trim, int numberOfChannels) throws Exception {
        String outputPath = generateOutputPath(inputPath, "wav");
        System.out.println("[Mediabunny] convertToWav: inputPath=" + inputPath);
        System.out.println("[Mediabunny] convertToWav: outputPath=" + outputPath);
        System.out.println("[Mediabunny] convertToWav: extension=" + getFileExtension(inputPath));
        System.out.println("[Mediabunny] convertToWav: isVideoFile=" + isVideoFile(getFileExtension(inputPath)));

        // For video files, extract audio first
        String audioSource = inputPath;
        if (isVideoFile(getFileExtension(inputPath))) {
            System.out.println("[Mediabunny] convertToWav: extracting audio from video...");
            audioSource = extractAudioFromVideo(inputPath);
            System.out.println("[Mediabunny] convertToWav: extracted to " + audioSource);
        }

        // Read input audio
        File audioSourceFile = new File(audioSource);
        System.out.println("[Mediabunny] convertToWav: reading audio from " + audioSource);
        System.out.println("[Mediabunny] convertToWav: audioSource exists=" + audioSourceFile.exists() + ", size=" + audioSourceFile.length());

        AudioInputStream audioStream = AudioSystem.getAudioInputStream(audioSourceFile);
        AudioFormat sourceFormat = audioStream.getFormat();
        System.out.println("[Mediabunny] convertToWav: sourceFormat=" + sourceFormat);

        // Determine target format
        int targetSampleRate = sampleRate > 0 ? sampleRate : (int) sourceFormat.getSampleRate();
        int targetChannels = numberOfChannels > 0 ? numberOfChannels : sourceFormat.getChannels();
        System.out.println("[Mediabunny] convertToWav: targetSampleRate=" + targetSampleRate + ", targetChannels=" + targetChannels);

        AudioFormat targetFormat = new AudioFormat(
            AudioFormat.Encoding.PCM_SIGNED,
            targetSampleRate,
            16,  // 16-bit
            targetChannels,
            targetChannels * 2,  // frame size
            targetSampleRate,
            false  // little endian
        );

        // Convert if necessary
        AudioInputStream convertedStream;
        System.out.println("[Mediabunny] convertToWav: checking if format conversion needed");
        System.out.println("[Mediabunny] convertToWav: sourceFormat.matches(targetFormat)=" + sourceFormat.matches(targetFormat));

        if (!sourceFormat.matches(targetFormat)) {
            System.out.println("[Mediabunny] convertToWav: format conversion needed");

            // First convert to PCM if needed
            if (sourceFormat.getEncoding() != AudioFormat.Encoding.PCM_SIGNED &&
                sourceFormat.getEncoding() != AudioFormat.Encoding.PCM_UNSIGNED) {
                System.out.println("[Mediabunny] convertToWav: converting encoding to PCM_SIGNED");
                AudioFormat pcmFormat = new AudioFormat(
                    AudioFormat.Encoding.PCM_SIGNED,
                    sourceFormat.getSampleRate(),
                    16,
                    sourceFormat.getChannels(),
                    sourceFormat.getChannels() * 2,
                    sourceFormat.getSampleRate(),
                    false
                );
                audioStream = AudioSystem.getAudioInputStream(pcmFormat, audioStream);
                sourceFormat = audioStream.getFormat();
                System.out.println("[Mediabunny] convertToWav: after PCM conversion, sourceFormat=" + sourceFormat);
            }

            // Java's AudioSystem CANNOT do sample rate conversion properly
            // It claims to support it but produces garbage output
            // Only do channel conversion, keep original sample rate
            boolean needsSampleRateChange = (int) sourceFormat.getSampleRate() != targetSampleRate;
            boolean needsChannelChange = sourceFormat.getChannels() != targetChannels;

            System.out.println("[Mediabunny] convertToWav: needsSampleRateChange=" + needsSampleRateChange +
                " (" + (int)sourceFormat.getSampleRate() + " vs " + targetSampleRate + ")");
            System.out.println("[Mediabunny] convertToWav: needsChannelChange=" + needsChannelChange +
                " (" + sourceFormat.getChannels() + " vs " + targetChannels + ")");

            if (needsSampleRateChange) {
                System.out.println("[Mediabunny] convertToWav: WARNING - sample rate conversion requested (" +
                    (int)sourceFormat.getSampleRate() + " -> " + targetSampleRate +
                    ") but Java AudioSystem cannot resample - keeping original sample rate");
            }

            if (needsChannelChange) {
                // Try converting just channels at source sample rate
                AudioFormat monoFormat = new AudioFormat(
                    AudioFormat.Encoding.PCM_SIGNED,
                    sourceFormat.getSampleRate(),  // Keep source sample rate
                    16,
                    targetChannels,
                    targetChannels * 2,
                    sourceFormat.getSampleRate(),
                    false
                );

                System.out.println("[Mediabunny] convertToWav: converting channels " +
                    sourceFormat.getChannels() + " -> " + targetChannels);
                System.out.println("[Mediabunny] convertToWav: target monoFormat=" + monoFormat);

                try {
                    convertedStream = AudioSystem.getAudioInputStream(monoFormat, audioStream);
                    System.out.println("[Mediabunny] convertToWav: channel conversion successful");
                    System.out.println("[Mediabunny] convertToWav: convertedStream format=" + convertedStream.getFormat());
                    System.out.println("[Mediabunny] convertToWav: convertedStream frameLength=" + convertedStream.getFrameLength());
                } catch (Exception e) {
                    System.out.println("[Mediabunny] convertToWav: channel conversion FAILED: " + e.getMessage());
                    System.out.println("[Mediabunny] convertToWav: using original stream without conversion");
                    convertedStream = audioStream;
                }
            } else {
                System.out.println("[Mediabunny] convertToWav: no channel conversion needed, using source stream");
                convertedStream = audioStream;
            }
        } else {
            System.out.println("[Mediabunny] convertToWav: no format conversion needed");
            convertedStream = audioStream;
        }

        System.out.println("[Mediabunny] convertToWav: final convertedStream format=" + convertedStream.getFormat());

        // Apply trimming if specified
        if (trim[0] > 0 || trim[1] > 0) {
            System.out.println("[Mediabunny] convertToWav: applying trim [" + trim[0] + ", " + trim[1] + "]");
            convertedStream = trimAudioStream(convertedStream, trim[0], trim[1]);
        }

        // If audioSource is already the target (from extractAudioFromVideo),
        // and no conversion/trimming needed, just return it
        if (audioSource.equals(outputPath) && convertedStream == audioStream && trim[0] == 0 && trim[1] == 0) {
            System.out.println("[Mediabunny] convertToWav: no changes needed, returning " + audioSource);
            audioStream.close();
            return audioSource;
        }

        // Write output using our own writeWavFile to ensure correct WAV header
        // (AudioSystem.write can produce corrupted headers in some cases)
        System.out.println("[Mediabunny] convertToWav: writing to " + outputPath);
        AudioFormat finalFormat = convertedStream.getFormat();
        byte[] pcmData = convertedStream.readAllBytes();
        System.out.println("[Mediabunny] convertToWav: read " + pcmData.length + " bytes from stream");
        System.out.println("[Mediabunny] convertToWav: finalFormat sampleRate=" + (int)finalFormat.getSampleRate() +
            ", channels=" + finalFormat.getChannels() + ", bitsPerSample=" + finalFormat.getSampleSizeInBits());

        writeWavFile(outputPath, pcmData, (int)finalFormat.getSampleRate(),
            finalFormat.getChannels(), finalFormat.getSampleSizeInBits());
        System.out.println("[Mediabunny] convertToWav: wrote " + pcmData.length + " bytes");

        audioStream.close();
        if (convertedStream != audioStream) {
            convertedStream.close();
        }

        // Cleanup temp file if we extracted audio and output is different
        if (!audioSource.equals(inputPath) && !audioSource.equals(outputPath)) {
            System.out.println("[Mediabunny] convertToWav: cleaning up temp file " + audioSource);
            // TODO: REMOVE DEBUG - don't delete for debugging
            if (!DEBUG_SAVE_FILES) {
                new File(audioSource).delete();
            } else {
                System.out.println("[Mediabunny] DEBUG: keeping temp file for inspection: " + audioSource);
            }
        }

        File outputFile = new File(outputPath);
        System.out.println("[Mediabunny] convertToWav: final output exists=" + outputFile.exists() + ", size=" + outputFile.length());

        // TODO: REMOVE DEBUG - save copy of final converted audio
        if (DEBUG_SAVE_FILES) {
            try {
                String debugPath = DEBUG_OUTPUT_DIR + "2_final_converted.wav";
                Files.copy(outputFile.toPath(), new File(debugPath).toPath(), java.nio.file.StandardCopyOption.REPLACE_EXISTING);
                System.out.println("[Mediabunny] DEBUG: saved final output to " + debugPath);
            } catch (Exception e) {
                System.out.println("[Mediabunny] DEBUG: failed to save debug copy: " + e.getMessage());
            }
        }

        return outputPath;
    }

    private static String convertToMp3(String inputPath, int sampleRate, int[] trim, int numberOfChannels) throws Exception {
        // MP3 encoding requires external library (LAME)
        // For now, convert to WAV and note that MP3 encoding needs additional setup
        System.err.println("[Mediabunny] MP3 encoding requires LAME library. Converting to WAV instead.");
        System.err.println("[Mediabunny] To enable MP3: add net.sourceforge.lame:lame4j dependency");
        return convertToWav(inputPath, sampleRate, trim, numberOfChannels);
    }

    private static String convertToMp4(String inputPath, int[] crop, int[] trim) throws Exception {
        String outputPath = generateOutputPath(inputPath, "mp4");
        File inputFile = new File(inputPath);
        File outputFile = new File(outputPath);

        // Use jcodec's FrameGrab and AWTSequenceEncoder
        FrameGrab grab = FrameGrab.createFrameGrab(NIOUtils.readableChannel(inputFile));

        // Get video info
        int[] info = getVideoInfoSync(inputPath);
        int width = info[0];
        int height = info[1];

        // Apply crop if specified
        int cropLeft = crop[0], cropTop = crop[1], cropWidth = crop[2], cropHeight = crop[3];
        boolean doCrop = cropWidth > 0 && cropHeight > 0;

        int outputWidth = doCrop ? cropWidth : width;
        int outputHeight = doCrop ? cropHeight : height;

        // Create encoder
        AWTSequenceEncoder encoder = AWTSequenceEncoder.createSequenceEncoder(outputFile, 25);

        // Apply trim if specified
        double startTime = trim[0];
        double endTime = trim[1];
        if (startTime > 0) {
            grab.seekToSecondPrecise(startTime);
        }

        Picture picture;
        double currentTime = startTime;
        double frameDuration = 1.0 / 25.0;  // Assuming 25 fps

        while ((picture = grab.getNativeFrame()) != null) {
            if (endTime > 0 && currentTime >= endTime) {
                break;
            }

            BufferedImage img = AWTUtil.toBufferedImage(picture);

            // Apply crop if needed
            if (doCrop) {
                img = img.getSubimage(cropLeft, cropTop, cropWidth, cropHeight);
            }

            encoder.encodeImage(img);
            currentTime += frameDuration;
        }

        encoder.finish();
        return outputPath;
    }

    private static String concatenateMedia(String[] inputPaths, String outputName) throws Exception {
        if (inputPaths.length == 0) {
            throw new IllegalArgumentException("No input files provided");
        }

        String ext = getFileExtension(inputPaths[0]).toLowerCase();
        String outputPath = outputName + "." + ext;

        if (isAudioFile(ext)) {
            return concatenateAudio(inputPaths, outputPath);
        } else {
            return concatenateVideo(inputPaths, outputPath);
        }
    }

    private static String concatenateAudio(String[] inputPaths, String outputPath) throws Exception {
        // Get format from first file
        AudioInputStream firstStream = AudioSystem.getAudioInputStream(new File(inputPaths[0]));
        AudioFormat format = firstStream.getFormat();
        firstStream.close();

        // Concatenate all streams
        ByteArrayOutputStream baos = new ByteArrayOutputStream();

        for (String path : inputPaths) {
            AudioInputStream stream = AudioSystem.getAudioInputStream(new File(path));

            // Convert to same format if needed
            if (!stream.getFormat().matches(format)) {
                stream = AudioSystem.getAudioInputStream(format, stream);
            }

            byte[] buffer = new byte[4096];
            int bytesRead;
            while ((bytesRead = stream.read(buffer)) != -1) {
                baos.write(buffer, 0, bytesRead);
            }
            stream.close();
        }

        // Write combined audio
        byte[] audioData = baos.toByteArray();
        ByteArrayInputStream bais = new ByteArrayInputStream(audioData);
        AudioInputStream combinedStream = new AudioInputStream(bais, format, audioData.length / format.getFrameSize());

        AudioSystem.write(combinedStream, AudioFileFormat.Type.WAVE, new File(outputPath));
        combinedStream.close();

        return outputPath;
    }

    private static String concatenateVideo(String[] inputPaths, String outputPath) throws Exception {
        File outputFile = new File(outputPath);
        AWTSequenceEncoder encoder = AWTSequenceEncoder.createSequenceEncoder(outputFile, 25);

        for (String inputPath : inputPaths) {
            File inputFile = new File(inputPath);
            FrameGrab grab = FrameGrab.createFrameGrab(NIOUtils.readableChannel(inputFile));

            Picture picture;
            while ((picture = grab.getNativeFrame()) != null) {
                BufferedImage img = AWTUtil.toBufferedImage(picture);
                encoder.encodeImage(img);
            }
        }

        encoder.finish();
        return outputPath;
    }

    // ==================== Helper Methods ====================

    private static Demuxer createDemuxer(File file, SeekableByteChannel channel, String ext) throws Exception {
        switch (ext) {
            case "mp4":
            case "m4v":
            case "m4a":
            case "mov":
                return MP4Demuxer.createMP4Demuxer(channel);
            case "mkv":
            case "webm":
                // MKVDemuxer needs FileChannelWrapper
                FileChannelWrapper fcw = NIOUtils.readableChannel(file);
                return new MKVDemuxer(fcw);
            default:
                // Try to detect format using File
                Format format = JCodecUtil.detectFormat(file);
                if (format == Format.MOV) {
                    channel.setPosition(0);
                    return MP4Demuxer.createMP4Demuxer(channel);
                } else if (format == Format.MKV) {
                    FileChannelWrapper fcw2 = NIOUtils.readableChannel(file);
                    return new MKVDemuxer(fcw2);
                }
                return null;
        }
    }

    private static double getAudioDuration(String filePath) throws Exception {
        AudioInputStream audioStream = AudioSystem.getAudioInputStream(new File(filePath));
        AudioFormat format = audioStream.getFormat();
        long frames = audioStream.getFrameLength();
        double duration = frames / format.getFrameRate();
        audioStream.close();
        return duration;
    }

    // TODO: REMOVE DEBUG FLAG - set to false for production
    private static final boolean DEBUG_SAVE_FILES = true;
    // Use Java temp dir which works on both Windows and Linux
    private static final String DEBUG_OUTPUT_DIR = System.getProperty("java.io.tmpdir") + File.separator + "mediabunny_debug" + File.separator;

    /**
     * Extract audio from video file using jcodec's AAC decoder.
     * Demuxes MP4, decodes AAC audio frames to PCM, writes as WAV.
     */
    private static String extractAudioFromVideo(String videoPath) throws Exception {
        File videoFile = new File(videoPath);
        // Use _extracted suffix to avoid collision with final _converted output
        String outputPath = generateOutputPath(videoPath, "extracted.wav");
        System.out.println("[Mediabunny] extractAudioFromVideo: videoPath=" + videoPath);
        System.out.println("[Mediabunny] extractAudioFromVideo: outputPath=" + outputPath);

        // TODO: REMOVE DEBUG - save copy to permanent location
        if (DEBUG_SAVE_FILES) {
            File debugDir = new File(DEBUG_OUTPUT_DIR);
            debugDir.mkdirs();
            System.out.println("[Mediabunny] DEBUG: will save copies to " + debugDir.getAbsolutePath());
        }
        System.out.println("[Mediabunny] extractAudioFromVideo: file exists=" + videoFile.exists() + ", size=" + videoFile.length());

        try (SeekableByteChannel channel = NIOUtils.readableChannel(videoFile)) {
            System.out.println("[Mediabunny] extractAudioFromVideo: creating MP4Demuxer...");
            MP4Demuxer demuxer = MP4Demuxer.createMP4Demuxer(channel);

            System.out.println("[Mediabunny] extractAudioFromVideo: audioTracks=" + demuxer.getAudioTracks().size());
            if (demuxer.getAudioTracks().isEmpty()) {
                throw new Exception("No audio track found in video file");
            }

            DemuxerTrack audioTrack = demuxer.getAudioTracks().get(0);
            DemuxerTrackMeta trackMeta = audioTrack.getMeta();
            System.out.println("[Mediabunny] extractAudioFromVideo: trackMeta=" + trackMeta);
            System.out.println("[Mediabunny] extractAudioFromVideo: codec=" + (trackMeta != null ? trackMeta.getCodec() : "null"));

            // Get decoder-specific info from track metadata
            ByteBuffer codecPrivate = trackMeta.getCodecPrivate();
            System.out.println("[Mediabunny] extractAudioFromVideo: codecPrivate=" + (codecPrivate != null ? codecPrivate.remaining() + " bytes" : "null"));
            if (codecPrivate == null) {
                throw new Exception("No codec private data (decoder config) found in audio track");
            }

            // Initialize AAC decoder with codec private data
            System.out.println("[Mediabunny] extractAudioFromVideo: initializing AACDecoder...");
            AACDecoder decoder = new AACDecoder(codecPrivate.duplicate());
            AudioCodecMeta audioMeta = trackMeta.getAudioCodecMeta();
            System.out.println("[Mediabunny] extractAudioFromVideo: audioMeta=" + audioMeta);
            if (audioMeta != null) {
                System.out.println("[Mediabunny] extractAudioFromVideo: sampleRate=" + audioMeta.getSampleRate() + ", channels=" + audioMeta.getChannelCount());
            }

            // Collect all decoded PCM data
            ByteArrayOutputStream pcmData = new ByteArrayOutputStream();
            int frameCount = 0;
            int decodedFrames = 0;

            Packet packet;
            while ((packet = audioTrack.nextFrame()) != null) {
                frameCount++;
                ByteBuffer frameData = packet.getData();
                if (frameData == null || frameData.remaining() == 0) {
                    continue;
                }

                try {
                    // Allocate buffer for decoded PCM (AAC frame can decode to ~8KB PCM)
                    ByteBuffer decodedBuffer = ByteBuffer.allocate(1 << 16);

                    AudioBuffer audioBuffer = decoder.decodeFrame(frameData, decodedBuffer);
                    if (audioBuffer != null) {
                        decodedFrames++;
                        ByteBuffer data = audioBuffer.getData();
                        byte[] pcmBytes = new byte[data.remaining()];
                        data.get(pcmBytes);
                        pcmData.write(pcmBytes);
                    }
                } catch (Exception e) {
                    // Skip corrupted frames
                    if (frameCount <= 5) {
                        System.err.println("[Mediabunny] Skipping audio frame " + frameCount + ": " + e.getMessage());
                    }
                }
            }

            System.out.println("[Mediabunny] extractAudioFromVideo: processed " + frameCount + " frames, decoded " + decodedFrames);
            System.out.println("[Mediabunny] extractAudioFromVideo: pcmData size=" + pcmData.size() + " bytes");

            if (pcmData.size() == 0) {
                throw new Exception("Failed to decode any audio data from video");
            }

            // Get audio format from track metadata or use defaults
            int sampleRate = 44100;
            int channels = 2;
            int bitsPerSample = 16;

            if (audioMeta != null) {
                sampleRate = audioMeta.getSampleRate();
                channels = audioMeta.getChannelCount();
            }

            // Write WAV file
            byte[] pcmBytes = pcmData.toByteArray();
            System.out.println("[Mediabunny] extractAudioFromVideo: writing WAV file: sampleRate=" + sampleRate + ", channels=" + channels + ", size=" + pcmBytes.length);
            writeWavFile(outputPath, pcmBytes, sampleRate, channels, bitsPerSample);
            System.out.println("[Mediabunny] extractAudioFromVideo: done, output=" + outputPath);

            // TODO: REMOVE DEBUG - save copy of extracted audio
            if (DEBUG_SAVE_FILES) {
                String debugPath = DEBUG_OUTPUT_DIR + "1_extracted_from_video.wav";
                writeWavFile(debugPath, pcmBytes, sampleRate, channels, bitsPerSample);
                System.out.println("[Mediabunny] DEBUG: saved extracted audio to " + debugPath);
            }

            return outputPath;
        }
    }

    /**
     * Write PCM data to a WAV file with proper RIFF header.
     */
    private static void writeWavFile(String outputPath, byte[] pcmData, int sampleRate, int channels, int bitsPerSample) throws Exception {
        int byteRate = sampleRate * channels * bitsPerSample / 8;
        int blockAlign = channels * bitsPerSample / 8;
        int dataSize = pcmData.length;
        int chunkSize = 36 + dataSize;

        try (FileOutputStream fos = new FileOutputStream(outputPath);
             DataOutputStream dos = new DataOutputStream(fos)) {

            // RIFF header
            dos.writeBytes("RIFF");
            dos.writeInt(Integer.reverseBytes(chunkSize));
            dos.writeBytes("WAVE");

            // fmt subchunk
            dos.writeBytes("fmt ");
            dos.writeInt(Integer.reverseBytes(16)); // Subchunk1Size for PCM
            dos.writeShort(Short.reverseBytes((short) 1)); // AudioFormat: PCM = 1
            dos.writeShort(Short.reverseBytes((short) channels));
            dos.writeInt(Integer.reverseBytes(sampleRate));
            dos.writeInt(Integer.reverseBytes(byteRate));
            dos.writeShort(Short.reverseBytes((short) blockAlign));
            dos.writeShort(Short.reverseBytes((short) bitsPerSample));

            // data subchunk
            dos.writeBytes("data");
            dos.writeInt(Integer.reverseBytes(dataSize));
            dos.write(pcmData);
        }
    }

    private static AudioInputStream trimAudioStream(AudioInputStream stream, double startSec, double endSec) throws Exception {
        AudioFormat format = stream.getFormat();
        float frameRate = format.getFrameRate();
        int frameSize = format.getFrameSize();

        long startFrame = (long) (startSec * frameRate);
        long endFrame = endSec > 0 ? (long) (endSec * frameRate) : stream.getFrameLength();
        long framesToRead = endFrame - startFrame;

        // Skip to start
        long bytesToSkip = startFrame * frameSize;
        stream.skip(bytesToSkip);

        // Read the trimmed portion
        long bytesToRead = framesToRead * frameSize;
        byte[] data = new byte[(int) bytesToRead];
        int bytesRead = 0;
        int totalRead = 0;

        while (totalRead < bytesToRead && (bytesRead = stream.read(data, totalRead, (int) (bytesToRead - totalRead))) != -1) {
            totalRead += bytesRead;
        }

        ByteArrayInputStream bais = new ByteArrayInputStream(data, 0, totalRead);
        return new AudioInputStream(bais, format, totalRead / frameSize);
    }

    private static int extractSampleRate(Object[] params) {
        if (params != null && params.length > 0 && params[0] instanceof Struct) {
            Object[] fields = ((Struct) params[0]).getFields();
            if (fields.length > 0 && fields[0] instanceof Integer) {
                return (Integer) fields[0];
            }
        }
        return 16000; // Default
    }

    private static int[] extractCrop(Object[] params) {
        if (params != null && params.length > 1 && params[1] instanceof Struct) {
            Object[] fields = ((Struct) params[1]).getFields();
            if (fields.length >= 4) {
                return new int[]{
                    fields[0] instanceof Integer ? (Integer) fields[0] : 0,
                    fields[1] instanceof Integer ? (Integer) fields[1] : 0,
                    fields[2] instanceof Integer ? (Integer) fields[2] : 0,
                    fields[3] instanceof Integer ? (Integer) fields[3] : 0
                };
            }
        }
        return new int[]{0, 0, 0, 0};
    }

    private static int[] extractTrim(Object[] params) {
        if (params != null && params.length > 2 && params[2] instanceof Struct) {
            Object[] fields = ((Struct) params[2]).getFields();
            if (fields.length >= 2) {
                return new int[]{
                    fields[0] instanceof Integer ? (Integer) fields[0] : 0,
                    fields[1] instanceof Integer ? (Integer) fields[1] : 0
                };
            }
        }
        return new int[]{0, 0};
    }

    private static int extractNumberOfChannels(Object[] params) {
        if (params != null && params.length > 3 && params[3] instanceof Struct) {
            Object[] fields = ((Struct) params[3]).getFields();
            if (fields.length > 0 && fields[0] instanceof Integer) {
                return (Integer) fields[0];
            }
        }
        return 0; // Default: keep original
    }

    private static byte[] decodeBase64(String base64str) {
        String data = base64str;
        // Handle data URL format
        int commaIndex = base64str.indexOf(',');
        if (commaIndex >= 0) {
            data = base64str.substring(commaIndex + 1);
        }
        return Base64.getDecoder().decode(data);
    }

    private static Path downloadToTempFile(String url) throws Exception {
        Path tempFile = Files.createTempFile("mediabunny_", ".tmp");
        try (InputStream in = new URL(url).openStream();
             OutputStream out = Files.newOutputStream(tempFile)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = in.read(buffer)) != -1) {
                out.write(buffer, 0, bytesRead);
            }
        }
        return tempFile;
    }

    private static void deleteTempFile(Path path) {
        if (path != null) {
            try {
                Files.deleteIfExists(path);
            } catch (Exception e) {
                // Ignore
            }
        }
    }

    private static String getFileExtension(String path) {
        int lastDot = path.lastIndexOf('.');
        return lastDot > 0 ? path.substring(lastDot + 1) : "";
    }

    private static String generateOutputPath(String inputPath, String newExtension) {
        int lastDot = inputPath.lastIndexOf('.');
        String baseName = lastDot > 0 ? inputPath.substring(0, lastDot) : inputPath;
        return baseName + "_converted." + newExtension;
    }

    private static boolean isVideoFile(String ext) {
        return ext.equals("mp4") || ext.equals("m4v") || ext.equals("mov") ||
               ext.equals("mkv") || ext.equals("webm") || ext.equals("avi");
    }

    private static boolean isAudioFile(String ext) {
        return ext.equals("mp3") || ext.equals("wav") || ext.equals("m4a") ||
               ext.equals("ogg") || ext.equals("flac") || ext.equals("aac");
    }

    private static String detectMimeType(String path) {
        String ext = getFileExtension(path).toLowerCase();
        switch (ext) {
            case "mp4": return "video/mp4";
            case "webm": return "video/webm";
            case "mkv": return "video/x-matroska";
            case "mov": return "video/quicktime";
            case "avi": return "video/x-msvideo";
            case "mp3": return "audio/mpeg";
            case "wav": return "audio/wav";
            case "ogg": return "audio/ogg";
            case "m4a": return "audio/mp4";
            case "flac": return "audio/flac";
            default: return "application/octet-stream";
        }
    }
}
