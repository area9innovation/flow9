# Table of contents

1. [Supported platforms](#supported-platforms)
2. [Usage](#usage)
   1. [mediastream.flow](#mediastreamflow)
   2. [mediarecorder.flow](#mediarecorderflow)
3. [Building with QT](#building-with-qt)

## Supported platforms

|            | MediaStream | MediaRecorder |
|------------|:-----------:|:-------------:|
| Chrome     |52+          |47+            |
| Firefox    |36+          |25+            |
| Safari     |11+          |-              |
| Edge       |12+          |-              |
| Android    |+            |+              |
| iOS        |+            |+              |
| QT Windows |+            |+              |
| QT MacOS   |+            |+              |
| QT Linux   |-            |-              |

## Usage
Example of media lib usage can be found [here](https://github.com/area9innovation/flow9/blob/master/lib/material/tests/test_mediastream.flow)

### mediastream.flow

`initDeviceInfo : io(onDeviceInfoReady : () -> void) -> void`  
 Update list of available audio and video devices.

`requestAudioInputDevices(onDevicesReady : ([MediaStreamInputDevice]) -> void) -> void`  
 Returns list of available audio devices in onDevicesReady callback.

`requestVideoInputDevices(onDevicesReady : ([MediaStreamInputDevice]) -> void) -> void`  
 Returns list of available video devices in onDevicesReady callback.

`makeMediaStream(onReady : (stream : MediaStream, stop : () -> void) -> void, onError : (string) -> void, styles : [MediaStreamStyle]) -> void`  
Create MediaStream using MediaStreamStyles.
Uses default audio/video device if MediaStreamAudioDevice/MediaStreamVideoDevice wasn't specified.

---

To use MediaStream as source for video, add it to video styles

```
mediaStream : MediaStream;
MVideoPlayer(
    "",
    make(WidthHeight(640., 360.)),
    [
        mediaStream
    ]
)
```

### mediarecorder.flow

`makeMediaRecorderFromStream(destination : [MediaRecorderDestination], stream : MediaStream, onReady : (MediaRecorderControls) -> void, onError: (string) -> void, styles : [MediaRecorderStyle]) -> void`  
Record MediaStream to file and/or send it to websocket server

```
filepath : string;
mediaStream : MediaStream;
makeMediaRecorderFromStream(
    [
        MediaRecorderFilePath(filepath)
    ],
    mediaStream,
    \controls -> {
        controls.start();
        timer(3000, \-> controls.stop());
    },
    \error -> {},
    []
);
```

## Building with QT

1. Install runtime and developer versions of [GStreamer](https://gstreamer.freedesktop.org/data/pkg/)
2. Enable MediaRecorder in QtByteRunner.pro (<https://github.com/area9innovation/flow9/blob/master/platforms/qt/QtByteRunner.pro#L315>)

```
# MediaRecorder
if(false) { # true to put MediaRecorder on
```
