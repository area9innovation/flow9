import js.html.MediaStream;
import pixi.interaction.EventEmitter;

class FlowMediaStream extends EventEmitter {
    public var mediaStream : MediaStream;
    public var videoClip : VideoClip;

    public function new(mediaStream : MediaStream) {
        super();
        this.mediaStream = mediaStream;
    }
}