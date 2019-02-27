import js.Browser;
import pixi.core.graphics.Graphics;
import pixi.core.graphics.GraphicsData;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;

using DisplayObjectHelper;

class FlowGraphics extends Graphics {
	private var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;
	private var transformChanged : Bool = true;
	private var skipRender : Bool = false;

	public var penX : Float = 0.0;
	public var penY : Float = 0.0;

	private var fillGradient : Dynamic;
	private var strokeGradient : Dynamic;

	private static inline function trimFloat(f : Float, min : Float, max : Float) : Float {
		return f < min ? min : (f > max ? max : f);
	}

	public function new() {
		super();

		visible = false;
		interactiveChildren = false;
		lineStyle(1.0, 0, 0.0);
	}

	public function beginGradientFill(colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) : Void {
		fillGradient = { colors : colors, alphas : alphas, offsets : offsets, matrix : matrix, type : type };

		beginFill(0x000000, 1.0); // This will be used as a mask graphics
	}

	public function lineGradientStroke(colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic) : Void {
		strokeGradient = { colors : colors, alphas : alphas, offsets : offsets, matrix : matrix };

		lineStyle(1.0, RenderSupportJSPixi.removeAlphaChannel(colors[0]), alphas[0]);
	}

	public override function moveTo(x : Float, y : Float) : Graphics {
		var newGraphics = super.moveTo(x, y);
		penX = x;
		penY = y;

		return newGraphics;
	}

	public override function lineTo(x : Float, y : Float) : Graphics {
		var newGraphics = super.lineTo(x, y);
		penX = x;
		penY = y;

		return super.lineTo(x, y);
	}

	public override function quadraticCurveTo(cx : Float, cy : Float, x : Float, y : Float) : Graphics {
		var dx = x - penX;
		var dy = y - penY;

		if (Math.sqrt(dx * dx + dy * dy) / lineWidth > 3) {
			var newGraphics = super.quadraticCurveTo(cx, cy, x, y);
			penX = x;
			penY = y;

			return newGraphics;
		} else {
			lineTo(cx, cy);
			return lineTo(x, y);
		}
	}

	public override function endFill() : Graphics {
		var newGraphics = super.endFill();

		if (fillGradient != null) {
			// Only linear gradient is supported
			var canvas : js.html.CanvasElement = Browser.document.createCanvasElement();
			var bounds = getLocalBounds();
			canvas.width = untyped bounds.width;
			canvas.height = untyped bounds.height;

			var ctx = canvas.getContext2d();
			var matrix = fillGradient.matrix;
			var gradient = fillGradient.type == "radial"
				? ctx.createRadialGradient(
					matrix.xOffset + matrix.width * Math.cos(matrix.rotation / 180.0 * Math.PI) / 2.0,
					matrix.yOffset + matrix.height * Math.sin(matrix.rotation / 180.0 * Math.PI) / 2.0,
					0.0,
					matrix.xOffset + matrix.width * Math.cos(matrix.rotation / 180.0 * Math.PI) / 2.0,
					matrix.yOffset + matrix.height * Math.sin(matrix.rotation / 180.0 * Math.PI) / 2.0,
					Math.max(matrix.width / 2.0, matrix.height / 2.0)
				)
				: ctx.createLinearGradient(
					matrix.xOffset,
					matrix.yOffset,
					matrix.width * Math.cos(matrix.rotation / 180.0 * Math.PI),
					matrix.height * Math.sin(matrix.rotation / 180.0 * Math.PI)
				);

			for (i in 0...fillGradient.colors.length) {
				gradient.addColorStop(
					trimFloat(fillGradient.offsets[i], 0.0, 1.0),
					RenderSupportJSPixi.makeCSSColor(fillGradient.colors[i], fillGradient.alphas[i])
				);
			}

			ctx.fillStyle = gradient;
			ctx.fillRect(0.0, 0.0, bounds.width, bounds.height);

			var sprite = new Sprite(Texture.fromCanvas(canvas));
			var mask = new FlowGraphics();

			mask.graphicsData = graphicsData.map(function (gd) { return gd.clone(); });
			sprite.mask = mask;
			untyped sprite._visible = true;
			untyped sprite.clipVisible = true;

			for (gd in graphicsData) {
				gd.fillAlpha = 0.0;
			}

			addChild(sprite.mask);
			addChild(sprite);
		}

		return newGraphics;
	}

	public override function drawRect(x : Float, y : Float, width : Float, height : Float) : Graphics {
		var newGraphics = super.drawRect(x, y, width, height);

		return newGraphics;
	};

	public override function clear() : Graphics {
		return super.clear();
	};
}