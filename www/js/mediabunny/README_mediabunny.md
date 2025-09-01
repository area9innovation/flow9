# MediaBunny Flow Library

A Flow implementation of [MediaBunny](https://mediabunny.dev/) for browser-native media conversion. This library provides comprehensive media processing capabilities directly in the browser using WebCodecs, eliminating the need for server-side FFmpeg processing.

## 🎯 Purpose

The MediaBunny Flow library provides:

- ✅ **Client-side media processing** using hardware-accelerated WebCodecs
- ✅ **Eliminates server infrastructure** requirements for media conversion
- ✅ **Improved performance** with browser-native optimizations
- ✅ **Better security** by keeping files on the client
- ✅ **Comprehensive FFmpeg-equivalent operations**

## 📁 Implementation

The MediaBunny functionality is implemented in:
- `platforms/js/Mediabunny.hx` - Main Haxe implementation
- Flow bindings for seamless integration

## 🔄 Media Operations

### Supported Operations

| Operation | Flow Function | Description |
|-----------|---------------|-------------|
| Audio Extraction | `extractAudioHighQuality` | Extract MP3 from video files |
| Video Compression | `reduceBitrate` | Reduce video file size |
| Speech Format | `convertToSpeechFormat` | 16kHz mono WAV for speech recognition |
| Thumbnail Generation | `extractThumbnail` | Extract video frames as images |
| Media Info | `getMediaInfo` | Get detailed file information |
| Media Duration | `getMediaDuration` | Get media duration |
| Format Conversion | `convertMedia` | General format conversion |

## 🔧 Basic Usage

```flow
import mediabunny;
import runtime;
import net/http;

main() {
	url = "./images/material_test/big_buck_bunny.mp4";

	makeFileByBlobUrl(url, "big_buck_bunny", \file -> {
		getMediaDuration(file, \duration -> {
			println(duration)
		})},
		\err -> println("[ERROR]: " + err)
	)
}
```

## 🌐 Browser Compatibility

MediaBunny requires browsers with WebCodecs support:

- ✅ **Chrome 94+** (Full support)
- ✅ **Firefox 90+** (Good support)
- ✅ **Safari 16+** (Good support)
- ✅ **Edge 94+** (Full support)

## 🚧 File Size & Performance

### Limits
- **Maximum file size:** 256 MB
- **Recommended:** < 100 MB for optimal performance

### Performance Characteristics
- **MP3 conversion:** ~0.1 seconds per MB
- **Video compression:** ~1 second per MB
- **Thumbnail extraction:** ~1 second regardless of file size
- Hardware acceleration provides significant performance improvements

## 🔒 Security Benefits

1. **Browser sandboxing** - All processing happens in secure browser context
2. **No file uploads** for processing - Files remain on client
3. **No server vulnerabilities** - Eliminates server-side attack surface
4. **Memory isolation** - Browser manages memory securely
5. **User consent** - Explicit file access through browser APIs

## 📈 Performance Benefits

1. **Client-side processing** - Offloads work from servers
2. **Hardware acceleration** - Uses device GPU when available
3. **Reduced bandwidth** - No need to upload/download for processing
4. **Parallel processing** - Multiple files can be processed simultaneously
5. **Instant feedback** - Real-time progress updates

## 📄 License

MediaBunny itself is licensed under MPL-2.0, which allows commercial use.