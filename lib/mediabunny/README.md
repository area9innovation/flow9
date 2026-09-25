# MediaBunny Flow Library

A Flow implementation of [MediaBunny](https://mediabunny.dev/) for media conversion.

## Dual Backend Support

MediaBunny supports two backends:

### 1. JavaScript (Browser) - WebCodecs
- Hardware-accelerated using WebCodecs API
- Client-side processing (files stay on client)
- Best for web applications

### 2. Java (Server) - jcodec
- Server-side processing using jcodec library
- Works with file paths instead of blobs
- Best for backend services and batch processing
- See `platforms/java/com/area9innovation/flow/MEDIABUNNY_README.md` for details

## Architecture

### JavaScript Backend
```
Flow Application → lib/mediabunny.flow → platforms/js/Mediabunny.hx → www/js/mediabunny/*.mjs → Browser WebCodecs API
```

### Java Backend
```
Flow Application → lib/mediabunny.flow → platforms/java/Mediabunny.java → jcodec/javax.sound
```

**Key Features:**
- ✅ Client-side processing with hardware acceleration (JS)
- ✅ Server-side processing for batch operations (Java)
- ✅ No FFmpeg dependency required
- ✅ FFmpeg-equivalent operations
- ✅ Lazy loading (libraries load on first use)

## API Reference

### Functions

| Function | Parameters | Description |
|----------|------------|-------------|
| `mbGetMediaDuration` | `(file: native, cb: (int) -> void)` | Get media duration in seconds |
| `mbConversion` | `(file: native, format: MBFormat, params: [MBStyle], cb: (native) -> void, onError: (string) -> void)` | Convert media with options |
| `mbGetVideoInfo` | `(file: native, cb: (width: int, height: int, bitrate: int) -> void)` | Get info about video |
| `mbConcatMedia` | `(files: [native], cb: (native) -> void, onError: (string) -> void)` | Concatenate multiple videos into one |

### Formats (`MBFormat`)

| Format | Constructor | Type | Description |
|--------|-------------|------|-------------|
| MP3 | `MBAudioMP3()` | Audio | Compressed audio |
| WAV | `MBAudioWAV()` | Audio | Uncompressed audio |
| MP4 | `MBVideoMP4()` | Video | Standard video |
| WebM | `MBVideoWEBM()` | Video | Web-optimized video |

### Options (`MBStyle`)

| Option | Constructor | Description |
|--------|-------------|-------------|
| Sample Rate | `MBSampleRate(sampleRate: int)` | Audio sample rate (default: 16000) |
| Video Crop | `MBCrop(left: int, top: int, width: int, height: int)` | Crop video rectangle |
| Trim | `MBTrim(start: int, end: int)` | Keep only the given time range, in seconds |
| Audio Channels | `MBAudioNumberOfChannels(n: int)` | Up/downmix to `n` channels (1 mono, 2 stereo) |
| Video Bitrate | `MBVideoBitrate(bitrate: int)` | Target bitrate in bits per second when re-encoding |

### Video Bitrate

`MBVideoBitrate` only applies when the video is actually re-encoded — converting an
AVC source to WebM, or any conversion that crops. Where the source can be stream
copied (AVC into MP4), it is ignored and the original quality is preserved.

```flow
// Re-encode to WebM at 300 kbps
mbConversion(file, MBVideoWEBM(), [MBVideoBitrate(300000)], cb, onError);
```

Omitting it selects mediabunny's `high` quality resolved to a bitrate, which is the
default v1.17.3 used: `3_000_000 × (width×height / 1920×1080)^0.95 × codecFactor × 2`,
where `codecFactor` is 1 for AVC, 0.6 for VP9/HEVC, 1.2 for VP8 and 0.4 for AV1. For
320×180 VP9 that works out to 120 kbps.

This default has to be passed explicitly because v1.53.0 encodes at a constant
quantizer unless a bitrate is requested, which produced roughly 3.5x larger WebM
files. Note that any explicit quality forces a re-encode, so the binding only applies
it when the video cannot be stream copied.

`MBVideoBitrate` is JS-only; the Java backend ignores it.

## FFmpeg Equivalents

| Flow Operation | FFmpeg Command |
|----------------|----------------|
| `mbConversion(file, MBAudioMP3(), [], cb, onError)` | `ffmpeg -i input -c:a mp3 output.mp3` |
| `mbConversion(file, MBAudioWAV(), [MBSampleRate(16000)], cb, onError)` | `ffmpeg -i input -ar 16000 -c:a pcm_s16le output.wav` |
| `mbConversion(file, MBVideoMP4(), [MBCrop(x,y,w,h)], cb, onError)` | `ffmpeg -i input -filter:v "crop=w:h:x:y" output.mp4` |
| `mbGetMediaDuration(file, cb)` | `ffprobe -show_entries format=duration input` |
| `mbConcatMedia([file1, file2, ...], cb, onError)` | `ffmpeg -f concat -i filelist.txt -c copy output.mp4` |

## Java Backend API

For server-side processing, use the Java-specific functions that work with file paths.
These use the `Path` suffix to distinguish from the JS blob-based API:

| Function | Parameters | Description |
|----------|------------|-------------|
| `mbGetMediaDurationPath` | `(filePath: string, cb: (double) -> void)` | Get media duration |
| `mbGetVideoInfoPath` | `(filePath: string, cb: (int, int, int) -> void)` | Get video width, height, bitrate |
| `mbConversionPath` | `(inputPath: string, format: string, params: [MBStyle], cb: (string) -> void, onError: (string) -> void)` | Convert media (format as string) |
| `mbConversionFormatPath` | `(inputPath: string, format: MBFormat, params: [MBStyle], cb: (string) -> void, onError: (string) -> void)` | Convert media (format as MBFormat) |
| `mbConcatMediaPath` | `(inputPaths: [string], outputName: string, cb: (string) -> void, onError: (string) -> void)` | Concatenate media |
| `mbGetFileInfoPath` | `(filePath: string, cb: (size: int, mimeType: string, lastModified: double) -> void)` | Get file metadata |

### Java Usage Example

```flow
import mediabunny/mediabunny;

main() {
    // Get video duration
    mbGetMediaDurationPath("/path/to/video.mp4", \duration -> {
        println("Duration: " + d2s(duration) + " seconds");
    });

    // Convert video with trimming
    mbConversionFormatPath(
        "/path/to/input.mp4",
        MBVideoMP4(),
        [MBTrim(10, 30)],  // Trim from 10s to 30s
        \outputPath -> println("Output: " + outputPath),
        \error -> println("Error: " + error)
    );
}
```

### Java Backend Setup

1. Download jcodec JARs to `flow9/platforms/java/lib/`:
   ```bash
   curl -O https://repo1.maven.org/maven2/org/jcodec/jcodec/0.2.5/jcodec-0.2.5.jar
   curl -O https://repo1.maven.org/maven2/org/jcodec/jcodec-javase/0.2.5/jcodec-javase-0.2.5.jar
   ```

2. See `platforms/java/com/area9innovation/flow/MEDIABUNNY_README.md` for detailed documentation.

## Usage Examples

### Basic Usage

```flow
import mediabunny;
import runtime;
import net/http;

main() {
		makeFileByBlobUrl("./video.mp4", "video", \file -> {
				// Get duration
				mbGetMediaDuration(file, \duration ->
						println("Duration: " + i2s(duration) + "s"));

				// Convert to MP3
				mbConversion(file, MBAudioMP3(), [], \outputFile ->
						saveNativeFileClient("output", outputFile),
						\err -> println("Error: " + err));

				// Convert with custom sample rate
				mbConversion(file, MBAudioWAV(), [MBSampleRate(44100)], \outputFile ->
						saveNativeFileClient("hifi_output", outputFile),
						\err -> println("Error: " + err));

				// Get video info
				mbGetVideoInfo(file, \width, height, bitrate ->
						println("Video info: " + i2s(width) + "x" + i2s(height) + ":" + i2s(bitrate)));
		}, \err -> println("Load error: " + err))
}
```

### Media Concatenation

Perfect for joining multiple Amazon Chime recordings or any MP4 videos with consistent encoding:

```flow
import mediabunny;
import runtime;

main() {
	videoUrl = "./images/material_test/big_buck_bunny.mp4";

	makeFileByBlobUrl(videoUrl, "video1", \file1 -> {
		makeFileByBlobUrl(videoUrl, "video2", \file2 -> {
			makeFileByBlobUrl(videoUrl, "video3", \file3 -> {
				// Concatenate videos
				mbConcatMedia(
					[file1, file2, file3],
					\outputFile -> {
						println("✓ Videos concatenated successfully!");
						// Save the result
						saveNativeFileClient("concatenated", outputFile);
					},
					\error -> println("✗ Error: " + error)
				);
			}, \err -> println("Error loading file3: " + err));
		}, \err -> println("Error loading file2: " + err));
	}, \err -> println("Error loading file1: " + err));
}
```

**Concatenation Features:**
- ✅ Preserves video quality (stream copying when possible)
- ✅ Handles both video and audio tracks
- ✅ Automatic timestamp adjustment
- ✅ Client-side processing (no server upload needed)

**Requirements:**
- All media must be of the same type
- Recommended: Same resolution and frame rate for best results
- Media are joined in the order provided in the array

## Testing

### Unit Tests (`mediabunny/mediabunny_unittests.flow`)

**URL Control:**
- `mediabunny_unittests.html` - Run verification tests
- `mediabunny_unittests.html?generate=true` - Generate new baselines

**Test Coverage:**
- Duration detection (value comparison)
- Audio conversion (MD5 checksum verification)
- Video conversion (file size + MIME type)
- Cropping operations
- Error handling
- Video info extraction

### When Checksum Tests Fail

The baselines are recorded from one machine (mediabunny v1.53.0, Chrome 151 on
Linux). Encoded output is produced by the browser's own WebCodecs encoders, so a
MD5 or size mismatch does **not** by itself mean the conversion is broken — a
different browser, a different Chrome version, or a mediabunny update is enough
to shift the bytes. WAV is the exception: it is uncompressed PCM and stays
byte-identical.

When a test fails, verify the output is *semantically* correct instead of
chasing the checksum. Load mediabunny directly from the devtools console of the
test page and probe the produced file:

```javascript
const mb = await import('./js/mediabunny/mediabunny.min.mjs');
const input = new mb.Input({formats: mb.ALL_FORMATS, source: new mb.BlobSource(outputBlob)});
const videoTrack = await input.getPrimaryVideoTrack();
const audioTrack = await input.getPrimaryAudioTrack();
console.log({
    duration: await input.computeDuration(),
    video: videoTrack && {codec: videoTrack.codec, w: videoTrack.displayWidth, h: videoTrack.displayHeight},
    audio: audioTrack && {codec: audioTrack.codec, ch: audioTrack.numberOfChannels, sr: audioTrack.sampleRate},
});
```

Check that duration matches the source (or the requested trim), that dimensions
match the crop, that the sample rate matches `MBSampleRate`, and that both
tracks are present. If those hold, the conversion is fine and the baseline is
simply stale — regenerate it with `?generate=true`. Run generate mode twice and
compare before trusting a new value; if it differs between runs, that output is
genuinely non-deterministic on your machine and cannot be baselined at all.

### Concatenation Tests

`mbConcatMedia` is not covered by the unit test suite:

- `mediabunny/test_concatenate_verify.flow` — asserts the concatenated duration and
  video dimensions for MP4, WAV and the single-file passthrough. Results are printed
  to the console; no downloads.
- `mediabunny/test_concatenate_videos.flow` — downloads the concatenated output for
  manual inspection.

**Workflow:**
```flow
// 1. Generate baselines (first time)
// http://localhost:3000/mediabunny_unittests.html?generate=true

// 2. Run verification tests
main() // or visit mediabunny_unittests.html

// 3. Specific test categories
testAudioOnly()    // Audio tests only
testVideoOnly()    // Video tests only
testDurationOnly() // Quick duration check
```

## Browser Support & Performance

### Compatibility

| Browser | Version | Support | Notes |
|---------|---------|---------|--------|
| Chrome/Edge | 94+ | ✅ Full | Best performance |
| Firefox | 90+ | ⚠️ Good | Limited features |
| Safari | 16+ | ⚠️ Partial | WebCodecs varies |

### Performance Guidelines

- **Recommended max:** 256 MB files
- **Optimal performance:** < 100 MB
- **Memory usage:** ~3x file size during processing
- **Speed:** MP3 (~0.1s/MB), WAV (~0.05s/MB), Video (~1s/MB)

## Updating Library

Currently bundled: **v1.53.0**.

1. Download latest `mediabunny.min.mjs` and `mediabunny-mp3-encoder.mjs` from [releases](https://github.com/Vanilagy/mediabunny/releases)
2. Replace files in `flow9/www/js/mediabunny/`
3. Fix the bare import in `mediabunny-mp3-encoder.mjs` (the named imports vary by version, only the module specifier needs changing):
	 ```javascript
	 // Change this:
	 import { CustomAudioEncoder, EncodedPacket, Logging, registerEncoder } from "mediabunny";
	 // To this:
	 import { CustomAudioEncoder, EncodedPacket, Logging, registerEncoder } from "./mediabunny.min.mjs";
	 ```
4. Test with unit tests: `http://localhost:3000/mediabunny_unittests.html`

Note: default video encoding quality is chosen by mediabunny and changes between
releases, so re-encoded output (WebM) can differ in size after an update even
though the conversion itself is correct. Verify duration/dimensions/codecs rather
than checksums, and regenerate baselines with `?generate=true` when needed. See
[Video Bitrate](#video-bitrate) for how the default target bitrate is pinned.

## License

MediaBunny: MPL-2.0 (commercial use allowed)
Flow bindings: Follow Flow9 project license