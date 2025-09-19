# MediaBunny Flow Library

A Flow implementation of [MediaBunny](https://mediabunny.dev/) for browser-native media conversion using hardware-accelerated WebCodecs. Eliminates the need for server-side FFmpeg processing.

## Architecture

```
Flow Application → lib/mediabunny.flow → platforms/js/Mediabunny.hx → www/js/mediabunny/*.mjs → Browser WebCodecs API
```

**Key Features:**
- ✅ Client-side processing with hardware acceleration
- ✅ No server infrastructure required
- ✅ Better security (files stay on client)
- ✅ FFmpeg-equivalent operations
- ✅ Lazy loading (libraries load on first use)

## API Reference

### Functions

| Function | Parameters | Description |
|----------|------------|-------------|
| `mbGetMediaDuration` | `(file: native, cb: (int) -> void)` | Get media duration in seconds |
| `mbConversion` | `(file: native, format: MBFormat, params: [MBStyle], cb: (native) -> void, onError: (string) -> void)` | Convert media with options |

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

## FFmpeg Equivalents

| Flow Operation | FFmpeg Command |
|----------------|----------------|
| `mbConversion(file, MBAudioMP3(), [], cb, onError)` | `ffmpeg -i input -c:a mp3 output.mp3` |
| `mbConversion(file, MBAudioWAV(), [MBSampleRate(16000)], cb, onError)` | `ffmpeg -i input -ar 16000 -c:a pcm_s16le output.wav` |
| `mbConversion(file, MBVideoMP4(), [MBCrop(x,y,w,h)], cb, onError)` | `ffmpeg -i input -filter:v "crop=w:h:x:y" output.mp4` |
| `mbGetMediaDuration(file, cb)` | `ffprobe -show_entries format=duration input` |

## Usage Example

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
		}, \err -> println("Load error: " + err))
}
```

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

1. Download latest `mediabunny.min.mjs` and `mediabunny-mp3-encoder.mjs` from [releases](https://github.com/Vanilagy/mediabunny/releases)
2. Replace files in `flow9/www/js/mediabunny/`
3. Fix import in `mediabunny-mp3-encoder.mjs`:
	 ```javascript
	 // Change this:
	 import { CustomAudioEncoder, EncodedPacket, registerEncoder } from "mediabunny";
	 // To this:
	 import { CustomAudioEncoder, EncodedPacket, registerEncoder } from "./mediabunny.min.mjs";
	 ```
4. Test with unit tests: `http://localhost:3000/mediabunny_unittests.html`

## License

MediaBunny: MPL-2.0 (commercial use allowed)
Flow bindings: Follow Flow9 project license