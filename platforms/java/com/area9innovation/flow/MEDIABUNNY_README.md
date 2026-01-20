# MediaBunny Java Backend

Java implementation of MediaBunny for server-side media processing using jcodec.
This provides an alternative to the browser-based WebCodecs implementation for server-side scenarios.

## Architecture

```
Flow Application → lib/mediabunny/mediabunny.flow → platforms/java/Mediabunny.java → jcodec/javax.sound
```

## Dependencies

### Option 1: Download JARs to flow9/platforms/java/lib/

Download these JARs and place them in `flow9/platforms/java/lib/`:

1. **jcodec-0.2.5.jar** - Core jcodec library
   - URL: https://repo1.maven.org/maven2/org/jcodec/jcodec/0.2.5/jcodec-0.2.5.jar

2. **jcodec-javase-0.2.5.jar** - Java SE extensions (AWT support)
   - URL: https://repo1.maven.org/maven2/org/jcodec/jcodec-javase/0.2.5/jcodec-javase-0.2.5.jar

```bash
# Quick download commands:
cd flow9/platforms/java/lib/
curl -O https://repo1.maven.org/maven2/org/jcodec/jcodec/0.2.5/jcodec-0.2.5.jar
curl -O https://repo1.maven.org/maven2/org/jcodec/jcodec-javase/0.2.5/jcodec-javase-0.2.5.jar
```

### Option 2: Add to your `pom.xml` (for Maven projects):

```xml
<dependencies>
    <!-- jcodec for video processing -->
    <dependency>
        <groupId>org.jcodec</groupId>
        <artifactId>jcodec</artifactId>
        <version>0.2.5</version>
    </dependency>
    <dependency>
        <groupId>org.jcodec</groupId>
        <artifactId>jcodec-javase</artifactId>
        <version>0.2.5</version>
    </dependency>

    <!-- Optional: For MP3 encoding (requires LAME) -->
    <!--
    <dependency>
        <groupId>net.sourceforge.lame</groupId>
        <artifactId>lame4j</artifactId>
        <version>1.0</version>
    </dependency>
    -->
</dependencies>
```

Or for Gradle (`build.gradle`):

```groovy
dependencies {
    implementation 'org.jcodec:jcodec:0.2.5'
    implementation 'org.jcodec:jcodec-javase:0.2.5'

    // Optional: For MP3 encoding
    // implementation 'net.sourceforge.lame:lame4j:1.0'
}
```

## API Reference

### Java-Specific Functions (File Path Based)

These functions work with file paths instead of native blobs, making them suitable for server-side processing:

| Function | Parameters | Description |
|----------|------------|-------------|
| `mbGetMediaDurationJava` | `(filePath: string, cb: (double) -> void)` | Get media duration in seconds |
| `mbGetMediaDurationFromBase64Java` | `(base64str: string, cb: (double) -> void)` | Get duration from base64 data |
| `mbGetMediaDurationFromUrlJava` | `(url: string, cb: (double) -> void)` | Get duration from URL |
| `mbGetVideoInfoJava` | `(filePath: string, cb: (int, int, int) -> void)` | Get video width, height, bitrate |
| `mbConversionJava` | `(inputPath: string, format: string, params: [MBStyle], cb: (string) -> void, onError: (string) -> void)` | Convert media |
| `mbConcatMediaJava` | `(inputPaths: [string], outputName: string, cb: (string) -> void, onError: (string) -> void)` | Concatenate media files |
| `mbGetFileInfoJava` | `(filePath: string, cb: (int, string, double) -> void)` | Get file size, MIME type, last modified |

### High-Level Conversion

Use `mbConversionJavaPath` for a convenient wrapper that handles MBFormat:

```flow
mbConversionJavaPath(
    "/path/to/input.mp4",
    MBVideoMP4(),
    [MBTrim(10, 20), MBCrop(100, 50, 640, 480)],
    \outputPath -> println("Converted: " + outputPath),
    \error -> println("Error: " + error)
);
```

## Supported Formats

### Input Formats
- **Video**: MP4, MOV, MKV, WebM, AVI
- **Audio**: WAV, MP3, M4A, OGG, FLAC

### Output Formats
- **Video**: MP4 (H.264)
- **Audio**: WAV (PCM)
- **Note**: MP3 output requires LAME library; WebM output falls back to MP4

## Usage Examples

### Get Video Duration

```flow
import mediabunny/mediabunny;

main() {
    mbGetMediaDurationJava("/path/to/video.mp4", \duration -> {
        println("Duration: " + d2s(duration) + " seconds");
    });
}
```

### Convert Video to Different Format

```flow
import mediabunny/mediabunny;

main() {
    mbConversionJavaPath(
        "/path/to/input.mp4",
        MBVideoMP4(),
        [
            MBTrim(10, 30),           // Trim from 10s to 30s
            MBCrop(0, 0, 1280, 720)   // Crop to 720p
        ],
        \outputPath -> println("Output: " + outputPath),
        \error -> println("Error: " + error)
    );
}
```

### Extract Audio from Video

```flow
import mediabunny/mediabunny;

main() {
    mbConversionJavaPath(
        "/path/to/video.mp4",
        MBAudioWAV(),
        [MBSampleRate(44100), MBAudioNumberOfChannels(2)],
        \outputPath -> println("Audio extracted: " + outputPath),
        \error -> println("Error: " + error)
    );
}
```

### Concatenate Videos

```flow
import mediabunny/mediabunny;

main() {
    mbConcatMediaJava(
        ["/path/to/video1.mp4", "/path/to/video2.mp4", "/path/to/video3.mp4"],
        "concatenated_output",
        \outputPath -> println("Concatenated: " + outputPath),
        \error -> println("Error: " + error)
    );
}
```

## Comparison: JS vs Java Implementation

| Feature | JS (WebCodecs) | Java (jcodec) |
|---------|----------------|---------------|
| Environment | Browser | Server |
| Hardware Acceleration | Yes (GPU) | No (CPU only) |
| File Handling | Blob/File objects | File paths |
| MP3 Encoding | Built-in | Requires LAME |
| WebM Output | Native | Falls back to MP4 |
| Max File Size | ~256 MB (browser memory) | Limited by disk/heap |
| Concurrency | Single-threaded | Multi-threaded |

## Limitations

1. **WebM Output**: jcodec doesn't support WebM muxing; falls back to MP4
2. **MP3 Encoding**: Requires external LAME library
3. **Audio from Video**: Audio extraction from video containers is limited
4. **No Hardware Acceleration**: All processing is CPU-based

## For Production Use

For production scenarios requiring full codec support, consider:

1. **FFmpeg via ProcessBuilder**: Most complete solution
   ```java
   ProcessBuilder pb = new ProcessBuilder("ffmpeg", "-i", input, "-c:v", "libx264", output);
   ```

2. **JavaCV (FFmpeg bindings)**: Native FFmpeg with Java API
   ```xml
   <dependency>
       <groupId>org.bytedeco</groupId>
       <artifactId>javacv-platform</artifactId>
       <version>1.5.9</version>
   </dependency>
   ```

3. **Xuggler**: Older but stable FFmpeg wrapper (deprecated)

## Thread Safety

The Mediabunny Java implementation uses a fixed thread pool (4 threads) for async operations.
All callbacks are invoked on the Flow runtime's deferred execution queue.

## Error Handling

Errors are reported through the `onError` callback with descriptive messages.
Check server logs for detailed stack traces when debugging.
