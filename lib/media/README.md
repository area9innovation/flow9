# Table of contents

1. [Supported platforms](#supported-platforms)
2. [Usage](#usage)
   1. [mediastream.flow](#mediastreamflow)
   2. [mediarecorder.flow](#mediarecorderflow)
   3. [webrtc.flow](#webrtcflow)
3. [Building with QT](#building-with-qt)

## Supported platforms

|            | MediaStream | MediaRecorder | WebRTC |
|------------|:-----------:|:-------------:|:------:|
| Chrome     |52+          |47+            |51+     |
| Firefox    |36+          |25+            |22+     |
| Safari     |11+          |-              |11+     |
| Edge       |12+          |-              |15+     |
| Android    |+            |+              |+       |
| iOS        |+            |+              |+       |
| QT Windows |+            |+              |-       |
| QT MacOS   |+            |+              |-       |
| QT Linux   |-            |-              |-       |

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

### webrtc.flow

`initWebRTC : io(OnReady: () -> void) -> void`  
 Load libraries which are needed for JS

`makeMediaSenderFromStream(serverUrl : string, roomId : string, stream : MediaStream, onReady : (stop : () -> void) -> void, onError : (string) -> void, onNewParticipant : (id : string, stream : MediaStream) -> void, onParticipantLeave: (id : string) -> void, styles : [WebRTCStyle]) -> void`  
Join socket.io room and start WebRTC chat
>`serverUrl : string` url of socket.io server  
>`roomId : string` socket.io room id  
>`stream : MediaStream` stream which will be sent to other room participants  
>`onReady : (stop : () -> void) -> void` invoked once MediaSender is ready  
>`onError : (string) -> void` invoked when error is thrown  
>`onNewParticipant : (id : string, stream : MediaStream) -> void` invoked when new participant joins room  
>`onParticipantLeave: (id : string) -> void` invoked when chat participant leaves room  
>`styles : [WebRTCStyle]` Array of STUN/TURN servers

## Building with QT

1. Install runtime and developer versions of [GStreamer](https://gstreamer.freedesktop.org/data/pkg/)
2. Enable MediaRecorder in QtByteRunner.pro (<https://github.com/area9innovation/flow9/blob/master/platforms/qt/QtByteRunner.pro#L315>)

```
# MediaRecorder
if(false) { # true to put MediaRecorder on
```
