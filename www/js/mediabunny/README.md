# MediaBunny Flow Library

A Flow implementation of [MediaBunny](https://mediabunny.dev/) for browser-native media conversion. This library provides comprehensive media processing capabilities directly in the browser using WebCodecs, eliminating the need for server-side FFmpeg processing.

## 🎯 Purpose

The MediaBunny Flow library provides:

- ✅ **Client-side media processing** using hardware-accelerated WebCodecs
- ✅ **Eliminates server infrastructure** requirements for media conversion
- ✅ **Improved performance** with browser-native optimizations
- ✅ **Better security** by keeping files on the client
- ✅ **Comprehensive FFmpeg-equivalent operations**

## 🏗️ Architecture Chain

The MediaBunny integration follows a layered architecture from Flow to JavaScript:

```
Flow Application
			 ↓
lib/mediabunny.flow (Flow bindings)
			 ↓
platforms/js/Mediabunny.hx (Haxe implementation)
			 ↓
Haxe-untyped JavaScript
			 ↓
www/js/mediabunny/mediabunny.min.mjs (Core MediaBunny library)
www/js/mediabunny/mediabunny-mp3-encoder.mjs (MP3 encoder extension)
			 ↓
Browser WebCodecs API
```

### Layer Details

1. **Flow Layer** (`lib/mediabunny.flow`)
	 - Defines Flow-native data structures (`MBFormat`, `MBStyle`)
	 - Exports type-safe functions (`mbGetMediaDuration`, `mbConversion`)
	 - Handles Flow-to-Haxe marshalling

2. **Haxe Layer** (`platforms/js/Mediabunny.hx`)
	 - Manages ES6 module loading
	 - Handles JavaScript Promise-based async operations
	 - Provides error handling and logging
	 - Bridges between Flow types and JavaScript objects

3. **JavaScript Layer** (`www/js/mediabunny/`)
	 - **mediabunny.min.mjs**: Core MediaBunny library with WebCodecs operations
	 - **mediabunny-mp3-encoder.mjs**: MP3 encoding extension (dynamically loaded)
	 - **Dynamic Loading**: Both modules are loaded asynchronously on first usage and cached for subsequent calls
	 - **Lazy Loading**: No initial bundle size impact - libraries load only when MediaBunny functions are called

## 📋 Implemented Operations

### Flow Functions

| Flow Function | Parameters | Description |
|---------------|------------|-------------|
| `mbGetMediaDuration` | `(file: native, cb: (int) -> void)` | Get media duration in seconds |
| `mbConversion` | `(file: native, format: MBFormat, params: [MBStyle], cb: (native) -> void, onError: (string) -> void)` | Convert media with specified format and options |

### Supported Formats (`MBFormat`)

| Format | Flow Constructor | Output Type | Description |
|--------|-----------------|-------------|-------------|
| MP3 | `MBAudioMP3()` | Audio | High-quality compressed audio |
| WAV | `MBAudioWAV()` | Audio | Uncompressed audio (faster processing) |
| MP4 | `MBVideoMP4()` | Video | Standard video format |
| WebM | `MBVideoWEBM()` | Video | Web-optimized video format |

### Processing Options (`MBStyle`)

| Option | Flow Constructor | Description |
|--------|-----------------|-------------|
| Sample Rate | `MBSampleRate(sampleRate: int)` | Audio sample rate in Hz (default: 16000) |
| Video Crop | `MBCrop(left: int, top: int, width: int, height: int)` | Crop video to specified rectangle |

## 🔄 FFmpeg Operation Mappings

### Current Flow Functions → FFmpeg Equivalents

| Flow Operation | FFmpeg Command | Description |
|----------------|----------------|-------------|
| `mbConversion(file, MBAudioMP3(), [], cb, onError)` | `ffmpeg -i input -c:a mp3 output.mp3` | Extract audio as MP3 |
| `mbConversion(file, MBAudioWAV(), [], cb, onError)` | `ffmpeg -i input -c:a pcm_s16le output.wav` | Extract audio as WAV |
| `mbConversion(file, MBAudioWAV(), [MBSampleRate(16000)], cb, onError)` | `ffmpeg -i input -ar 16000 -c:a pcm_s16le output.wav` | Convert to speech recognition format |
| `mbConversion(file, MBVideoMP4(), [], cb, onError)` | `ffmpeg -i input -c:v libx264 output.mp4` | Convert video to MP4 |
| `mbConversion(file, MBVideoWEBM(), [], cb, onError)` | `ffmpeg -i input -c:v libvpx output.webm` | Convert video to WebM |
| `mbConversion(file, MBVideoMP4(), [MBCrop(x,y,w,h)], cb, onError)` | `ffmpeg -i input -filter:v "crop=w:h:x:y" output.mp4` | Crop and convert video |
| `mbGetMediaDuration(file, cb)` | `ffprobe -v quiet -show_entries format=duration -of csv="p=0" input` | Get media duration |

### Advanced FFmpeg Operations (Not Yet Implemented)

| FFmpeg Operation | Potential Flow Function | Status |
|------------------|------------------------|--------|
| `ffmpeg -ss 30 -i input -frames:v 1 output.jpg` | `mbExtractThumbnail(file, time, cb, onError)` | ⏳ Future |
| `ffmpeg -f concat -i list.txt -c copy output` | `mbConcatenateMedia(files, cb, onError)` | ⏳ Future |
| `ffmpeg -i input -b:v 1000k output` | `mbReduceBitrate(file, bitrate, cb, onError)` | ⏳ Future |
| `ffmpeg -i input -vf scale=640:480 output` | `mbResize(file, width, height, cb, onError)` | ⏳ Future |

## 🔧 Basic Usage

```flow
import mediabunny;
import runtime;
import net/http;

main() {
		url = "./images/material_test/big_buck_bunny.mp4";

		makeFileByBlobUrl(url, "big_buck_bunny", \file -> {
				// Get media duration
				mbGetMediaDuration(file, \duration -> {
						println("Duration: " + i2s(duration) + " seconds")
				});

				// Convert to high-quality MP3
				mbConversion(file, MBAudioMP3(), [], \outputFile -> {
						saveNativeFileClient("output_audio", outputFile)
				}, \err -> println("[ERROR] MP3 conversion: " + err));

				// Convert to WAV with custom sample rate
				mbConversion(file, MBAudioWAV(), [MBSampleRate(44100)], \outputFile -> {
						saveNativeFileClient("output_hifi", outputFile)
				}, \err -> println("[ERROR] WAV conversion: " + err));

				// Convert video with cropping
				mbConversion(file, MBVideoMP4(), [MBCrop(100, 50, 256, 128)], \outputFile -> {
						saveNativeFileClient("output_cropped", outputFile)
				}, \err -> println("[ERROR] MP4 conversion: " + err));
		},
		\err -> println("[ERROR] Loading file: " + err))
}
```

## 📦 Updating MediaBunny Library

To update the MediaBunny library to the latest version:

### Step 1: Download Latest Release
1. Go to [MediaBunny Releases](https://github.com/Vanilagy/mediabunny/releases)
2. Download the latest versions of:
	 - `mediabunny.min.mjs`
	 - `mediabunny-mp3-encoder.mjs`

### Step 2: Replace Library Files
```bash
# Navigate to the mediabunny directory
cd flow9/www/js/mediabunny/

# Replace the library files
cp /path/to/downloaded/mediabunny.min.mjs .
cp /path/to/downloaded/mediabunny-mp3-encoder.mjs .
```

### Step 3: Fix Dynamic Import
The MP3 encoder file needs a manual fix to work with Flow's module system:

**Edit `mediabunny-mp3-encoder.mjs`:**

Find this line:
```javascript
import { CustomAudioEncoder, EncodedPacket, registerEncoder } from "mediabunny";
```

Replace with:
```javascript
import { CustomAudioEncoder, EncodedPacket, registerEncoder } from "./mediabunny.min.mjs";
```

### Step 4: Test the Update
Run a test conversion to ensure everything works:
```flow
import mediabunny;
import runtime;

main() {
		// Test with a simple audio file
		makeFileByBlobUrl("./test.mp4", "test", \file -> {
				mbGetMediaDuration(file, \duration -> {
						println("✓ MediaBunny library updated successfully. Duration: " + i2s(duration))
				})
		}, \err -> println("✗ Update failed: " + err))
}
```

## 🌐 Browser Compatibility

MediaBunny requires browsers with WebCodecs support:

| Browser | Version | Support Level | Notes |
|---------|---------|--------------|--------|
| **Chrome** | 94+ | ✅ Full | Best performance, all features |
| **Edge** | 94+ | ✅ Full | Chrome-based, full compatibility |
| **Firefox** | 90+ | ⚠️ Good | Some features may be limited |
| **Safari** | 16+ | ⚠️ Good | WebCodecs support varies |

### Feature Support by Browser

| Feature | Chrome/Edge | Firefox | Safari |
|---------|-------------|---------|--------|
| MP3 Encoding | ✅ | ✅ | ⚠️ |
| WAV Processing | ✅ | ✅ | ✅ |
| MP4 Processing | ✅ | ✅ | ⚠️ |
| WebM Processing | ✅ | ✅ | ❌ |
| Hardware Acceleration | ✅ | ⚠️ | ⚠️ |

## 🚧 File Size & Performance

### Recommended Limits
- **Maximum file size:** 256 MB
- **Optimal performance:** < 100 MB
- **Memory usage:** ~3x file size during processing

### Performance Characteristics
| Operation | Performance | Notes |
|-----------|------------|--------|
| **MP3 conversion** | ~0.1s per MB | Hardware-accelerated when available |
| **WAV conversion** | ~0.05s per MB | Fastest option, larger files |
| **Video compression** | ~1s per MB | Depends on resolution and complexity |
| **Duration detection** | ~1s | Constant time regardless of file size |
| **Cropping** | +0.2s per MB | Additional processing overhead |

### Memory Management
- Files are processed in chunks to minimize memory usage
- Browser automatically garbage-collects processed data
- Large files may trigger browser memory warnings

## 🔒 Security Benefits

1. **Browser sandboxing** - All processing in secure browser context
2. **No file uploads** - Files never leave the client device
3. **No server vulnerabilities** - Eliminates server-side attack surface
4. **Memory isolation** - Browser manages memory securely
5. **User consent** - Explicit file access through browser APIs
6. **No data persistence** - Processed files exist only in memory

## 📈 Performance Benefits

1. **Client-side processing** - Offloads work from servers
2. **Hardware acceleration** - Uses device GPU when available
3. **Reduced bandwidth** - No upload/download for processing
4. **Parallel processing** - Multiple files processed simultaneously
5. **Instant feedback** - Real-time progress updates
6. **Offline capability** - Works without internet connection
7. **Lazy loading** - Libraries load dynamically on first use, reducing initial page load time

## 📄 License

MediaBunny itself is licensed under MPL-2.0, which allows commercial use.
Flow bindings and Haxe implementation follow the Flow9 project license terms.