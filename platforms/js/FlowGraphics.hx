import js.Browser;

import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;
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

	private var pen = new Point(0.0, 0.0);
	private var localBounds = new Bounds();

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
		pen.x = x;
		pen.y = y;
		localBounds.addPoint(pen);

		return newGraphics;
	}

	public override function lineTo(x : Float, y : Float) : Graphics {
		var newGraphics = super.lineTo(x, y);
		pen.x = x;
		pen.y = y;
		localBounds.addPoint(pen);

		return newGraphics;
	}

	public override function quadraticCurveTo(cx : Float, cy : Float, x : Float, y : Float) : Graphics {
		var dx = x - pen.x;
		var dy = y - pen.y;

		var newGraphics = super.quadraticCurveTo(cx, cy, x, y);
		pen.x = x;
		pen.y = y;
		localBounds.addPoint(pen);

		return newGraphics;
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

		if (parent != null) {
			invalidateStage();
		}

		return newGraphics;
	}

	public override function drawRect(x : Float, y : Float, width : Float, height : Float) : Graphics {
		if (width < 0) {
			x = x + width;
			width = Math.abs(width);
		}

		if (height < 0) {
			y = y + height;
			height = Math.abs(height);
		}

		if (width > 0 && height > 0) {
			var newGraphics = super.drawRect(x, y, width, height);

			localBounds.addPoint(new Point(x, y));
			localBounds.addPoint(new Point(x + width, y + height));

			endFill();

			return newGraphics;
		} else {
			return this;
		}
	}

	public override function drawRoundedRect(x : Float, y : Float, width : Float, height : Float, radius : Float) : Graphics {
		if (width < 0) {
			x = x + width;
			width = Math.abs(width);
		}

		if (height < 0) {
			y = y + height;
			height = Math.abs(height);
		}

		if (width > 0 && height > 0) {
			radius = Math.abs(radius);

			if (radius > 0) {
				var newGraphics = super.drawRoundedRect(x, y, width, height, radius);

				localBounds.addPoint(new Point(x, y));
				localBounds.addPoint(new Point(x + width, y + height));

				endFill();

				return newGraphics;
			} else {
				return drawRect(x, y, width, height);
			}
		} else {
			return this;
		}
	}

	public override function drawEllipse(x : Float, y : Float, width : Float, height : Float) : Graphics {
		width = Math.abs(width);
		height = Math.abs(height);

		if (width > 0 && height > 0) {
			var newGraphics = super.drawEllipse(x, y, width, height);

			localBounds.addPoint(new Point(x - width, y - height));
			localBounds.addPoint(new Point(x + width, y + height));

			endFill();

			return newGraphics;
		} else {
			return this;
		}
	}

	public override function drawCircle(x : Float, y : Float, radius : Float) : Graphics {
		radius = Math.abs(radius);

		if (radius > 0) {
			var newGraphics = super.drawCircle(x, y, radius);

			localBounds.addPoint(new Point(x - radius, y - radius));
			localBounds.addPoint(new Point(x + radius, y + radius));

			endFill();

			return newGraphics;
		} else {
			return this;
		}
	}

	#if (pixijs < "4.7.0")
		public override function getLocalBounds() : Rectangle {
			return localBounds.getRectangle(new Rectangle());
		}
	#else
		public override function getLocalBounds(?rect : Rectangle) : Rectangle {
			return localBounds.getRectangle(rect);
		}
	#end

	public override function getBounds(?skipUpdate : Bool, ?rect : Rectangle) : Rectangle {
		var bounds = new Bounds();

		bounds.minX = localBounds.minX * worldTransform.a + localBounds.minY * worldTransform.c + worldTransform.tx;
		bounds.minY = localBounds.minX * worldTransform.b + localBounds.minY * worldTransform.d + worldTransform.ty;
		bounds.maxX = localBounds.maxX * worldTransform.a + localBounds.maxY * worldTransform.c + worldTransform.tx;
		bounds.maxY = localBounds.maxX * worldTransform.b + localBounds.maxY * worldTransform.d + worldTransform.ty;

		return bounds.getRectangle(rect);
	}

	public override function clear() : Graphics {
		pen = new Point();
		localBounds = new Bounds();
		var newGraphics = super.clear();

		if (parent != null) {
			invalidateStage();
		}

		return newGraphics;
	};
}