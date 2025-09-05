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

## 🔄 FFmpeg Operation Mappings

### Current FFmpeg Commands → MediaBunny Methods

| FFmpeg Command | MediaBunny Method | Description |
|----------------|-------------------|-------------|
| `ffmpeg -i input -vn -c:a mp3 output` | `extractAudioHighQuality(file)` | Audio extraction to MP3 |
| `ffmpeg -i input -q:a 0 -map a output` | `extractAudioHighQuality(file)` | High quality audio extraction |
| `ffmpeg -i input -b:v 1000K output` | `reduceBitrate(file, 1000)` | Video bitrate reduction |
| `ffmpeg -i input -ar 16000 -ac 1 -c:a pcm_s16le output` | `convertToSpeechFormat(file)` | Speech recognition format |
| `ffmpeg -ss 30 -i input -frames:v 1 output` | `extractThumbnail(file, 30)` | Video thumbnail extraction |
| `ffmpeg -f concat -i list.txt -c copy output` | `concatenateVideos(files)` | Video concatenation |

### Additional Operations

| Operation | Flow Function | Description |
|-----------|---------------|-------------|
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