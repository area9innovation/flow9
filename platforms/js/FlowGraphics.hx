import js.Browser;
import js.html.Element;

import pixi.core.display.Bounds;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;
import pixi.core.graphics.Graphics;
import pixi.core.sprites.Sprite;
import pixi.core.textures.Texture;

using DisplayObjectHelper;

class FlowGraphics extends Graphics {
	private var scrollRect : FlowGraphics;
	private var _visible : Bool = true;
	private var clipVisible : Bool = false;

	private var pen = new Point(0.0, 0.0);
	private var localBounds = new Bounds();
	private var widgetBounds = new Bounds();
	private var _bounds = new Bounds();
	public var filterPadding = 0.0;
	private var graphicsBounds = new Bounds();

	private var fillGradient : Dynamic;
	private var strokeGradient : Dynamic;

	public var transformChanged : Bool = false;
	private var worldTransformChanged : Bool = false;
	private var graphicsChanged : Bool = false;

	private var nativeWidget : Element;
	private var accessWidget : AccessWidget;
	public var tagName : String;
	public var className : String;

	public var isEmpty : Bool = true;
	public var isCanvas : Bool = false;
	public var isSvg : Bool = false;
	public var isNativeWidget : Bool = false;
	public var keepNativeWidget : Bool = false;
	public var keepNativeWidgetChildren : Bool = false;
	public var hasMask : Bool = false;

	public var left = null;
	public var top = null;

	private static inline function trimFloat(f : Float, min : Float, max : Float) : Float {
		return f < min ? min : (f > max ? max : f);
	}

	public function new() {
		super();

		visible = false;
		interactiveChildren = false;
		isNativeWidget = false;
	}

	public function useSvg() {
		isSvg = true;
	}

	public function beginGradientFill(colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic, type : String) : Void {
		fillGradient = { colors : colors, alphas : alphas, offsets : offsets, matrix : matrix, type : type };

		beginFill(0x000000, 1.0); // This will be used as a mask graphics
	}

	public function lineGradientStroke(colors : Array<Int>, alphas : Array<Float>, offsets: Array<Float>, matrix : Dynamic) : Void {
		strokeGradient = { colors : colors, alphas : alphas, offsets : offsets, matrix : matrix };

		isSvg = true;

		lineStyle(lineWidth, RenderSupport.removeAlphaChannel(colors[0]), alphas[0]);
	}

	public override function moveTo(x : Float, y : Float) : Graphics {
		var newGraphics = super.moveTo(x, y);
		pen.x = x;
		pen.y = y;

		return newGraphics;
	}

	public override function lineTo(x : Float, y : Float) : Graphics {
		if (untyped !this.currentPath) {
			moveTo(0.0, 0.0);
		}

		var newGraphics = super.lineTo(x, y);
		pen.x = x;
		pen.y = y;

		isSvg = true;

		return newGraphics;
	}

	public override function quadraticCurveTo(cx : Float, cy : Float, x : Float, y : Float) : Graphics {
		var dx = x - pen.x;
		var dy = y - pen.y;

		var newGraphics = super.quadraticCurveTo(cx, cy, x, y);
		pen.x = x;
		pen.y = y;

		isSvg = true;

		return newGraphics;
	}

	public override function endFill() : Graphics {
		if (untyped (this.fillColor != null && fillAlpha > 0) || (lineWidth > 0 && this.lineAlpha > 0) || fillGradient != null) {
			if (!isEmpty) {
				isSvg = true;
			}

			isEmpty = false;
		}

		var newGraphics = super.endFill();

		for (data in graphicsData) {
			if (data.lineWidth != null && lineWidth == 0) {
				data.lineWidth = null;
			}
		}

		calculateGraphicsBounds();

		if (strokeGradient != null && this.isHTMLRenderer()) {
			untyped data.gradient = strokeGradient;
			untyped data.strokeGradient = strokeGradient.type == 'radial' ?
				"radial-gradient(" :
				"linear-gradient(" + (strokeGradient.matrix.rotation + 90.0) + 'deg, ';

			for (i in 0...strokeGradient.colors.length) {
				untyped data.strokeGradient += RenderSupport.makeCSSColor(strokeGradient.colors[i], strokeGradient.alphas[i]) + ' ' +
					trimFloat(strokeGradient.offsets[i], 0.0, 1.0) * (strokeGradient.type == 'radial' ? 70.0 : 100.0) + '%' +
					(i != strokeGradient.colors.length - 1 ? ', ' : '');
			}

			untyped data.strokeGradient += ")";
		}

		if (fillGradient != null) {
			if (this.isHTMLRenderer()) {
				untyped data.gradient = fillGradient;
				untyped data.fillGradient = fillGradient.type == 'radial' ?
					"radial-gradient(" :
					"linear-gradient(" + (fillGradient.matrix.rotation + 90.0) + 'deg, ';

				for (i in 0...fillGradient.colors.length) {
					untyped data.fillGradient += RenderSupport.makeCSSColor(fillGradient.colors[i], fillGradient.alphas[i]) + ' ' +
						trimFloat(fillGradient.offsets[i], 0.0, 1.0) * (fillGradient.type == 'radial' ? 70.0 : 100.0) + '%' +
						(i != fillGradient.colors.length - 1 ? ', ' : '');
				}

				untyped data.fillGradient += ")";
			} else {
				// Only linear gradient is supported
				var canvas : js.html.CanvasElement = Browser.document.createCanvasElement();
				canvas.width = Math.ceil(graphicsBounds.maxX);
				canvas.height = Math.ceil(graphicsBounds.maxY);

				var ctx = canvas.getContext2d();
				var matrix = fillGradient.matrix;
				var gradient = fillGradient.type == "radial"
					? ctx.createRadialGradient(
						matrix.xOffset + matrix.width / 2.0,
						matrix.yOffset + matrix.height / 2.0,
						0.0,
						matrix.xOffset + matrix.width / 2.0,
						matrix.yOffset + matrix.height / 2.0,
						Math.max(matrix.width / 2.0, matrix.height / 2.0)
					)
					: ctx.createLinearGradient(
						matrix.xOffset + (matrix.width / 2.0 - Math.sin((matrix.rotation + 90.0) * 0.0174532925) * matrix.width / 2.0),
						matrix.yOffset + (matrix.height / 2.0 + Math.cos((matrix.rotation + 90.0) * 0.0174532925) * matrix.height / 2.0),
						matrix.xOffset + (matrix.width / 2.0 - Math.sin((matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * matrix.width / 2.0),
						matrix.yOffset + (matrix.height / 2.0 + Math.cos((matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * matrix.height / 2.0)
					);

				for (i in 0...fillGradient.colors.length) {
					gradient.addColorStop(
						trimFloat(fillGradient.offsets[i], 0.0, 1.0),
						RenderSupport.makeCSSColor(fillGradient.colors[i], fillGradient.alphas[i])
					);
				}

				ctx.fillStyle = gradient;
				ctx.fillRect(0.0, 0.0, canvas.width, canvas.height);

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

				sprite.invalidateTransform('endFill Gradient');
			}
		}

		graphicsChanged = true;
		this.invalidateTransform('endFill');

		if (this.isMask || this.isCanvas) {
			if (isNativeWidget) {
				this.deleteNativeWidget();
			}
		} else if (!isEmpty) {
			this.initNativeWidget();
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
			radius = Math.abs(Math.min(radius, Math.min(width / 2.0, height / 2.0)));

			if (radius > 0) {
				var newGraphics = super.drawRoundedRect(x, y, width, height, radius);

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

			endFill();

			return newGraphics;
		} else {
			return this;
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		rect = localBounds.getRectangle(rect);

		if (this.filterPadding != 0.0) {
			rect.x -= this.filterPadding;
			rect.y -= this.filterPadding;
			rect.width += this.filterPadding * 2.0;
			rect.height += this.filterPadding * 2.0;
		}

		return rect;
	}

	public override function getBounds(?skipUpdate : Bool, ?rect : Rectangle) : Rectangle {
		if (!skipUpdate) {
			updateTransform();
		}

		getLocalBounds();
		calculateBounds();

		return _bounds.getRectangle(rect);
	}

	public function calculateBounds() : Void {
		_bounds.minX = localBounds.minX * worldTransform.a + localBounds.minY * worldTransform.c + worldTransform.tx;
		_bounds.minY = localBounds.minX * worldTransform.b + localBounds.minY * worldTransform.d + worldTransform.ty;
		_bounds.maxX = localBounds.maxX * worldTransform.a + localBounds.maxY * worldTransform.c + worldTransform.tx;
		_bounds.maxY = localBounds.maxX * worldTransform.b + localBounds.maxY * worldTransform.d + worldTransform.ty;
	}

	public function calculateGraphicsBounds() : Void {
		updateLocalBounds();

		if (untyped Math.isFinite(this._localBounds.minX) && Math.isFinite(this._localBounds.minY)) {
			var shouldFixBound = lineWidth != null && graphicsData != null && graphicsData.length > 0 && graphicsData[0].lineAlpha == 0;
			graphicsBounds.minX = untyped this._localBounds.minX - (shouldFixBound ? lineWidth / 2.0 : 0.0);
			graphicsBounds.minY = untyped this._localBounds.minY - (shouldFixBound ? lineWidth / 2.0 : 0.0);
			graphicsBounds.maxX = untyped this._localBounds.maxX + (shouldFixBound ? lineWidth / 2.0 : 0.0);
			graphicsBounds.maxY = untyped this._localBounds.maxY + (shouldFixBound ? lineWidth / 2.0 : 0.0);
		} else {
			graphicsBounds.minX = pen.x - (lineWidth != null ? lineWidth / 2.0 : 0.0);
			graphicsBounds.minY = pen.y - (lineWidth != null ? lineWidth / 2.0 : 0.0);
			graphicsBounds.maxX = pen.x + (lineWidth != null ? lineWidth / 2.0 : 0.0);
			graphicsBounds.maxY = pen.y + (lineWidth != null ? lineWidth / 2.0 : 0.0);
		}

		if (graphicsBounds.minX > graphicsBounds.maxX) {
			var temp = graphicsBounds.maxX;
			graphicsBounds.maxX = graphicsBounds.minX;
			graphicsBounds.minX = temp;
		}

		if (graphicsBounds.minY > graphicsBounds.maxY) {
			var temp = graphicsBounds.maxY;
			graphicsBounds.maxY = graphicsBounds.minY;
			graphicsBounds.minY = temp;
		}

		widgetBounds.minX = graphicsBounds.minX + (lineWidth != null && lineWidth > 0 && !isSvg ? (lineWidth < 2.0 ? lineWidth + 0.25 : lineWidth) : 0.0);
		widgetBounds.minY = graphicsBounds.minY + (lineWidth != null && lineWidth > 0 && !isSvg ? (lineWidth < 2.0 ? lineWidth + 0.25 : lineWidth) : 0.0);
		widgetBounds.maxX = graphicsBounds.maxX - (lineWidth != null && lineWidth > 0 && !isSvg ? (lineWidth < 2.0 ? lineWidth + 0.25 : lineWidth) : 0.0);
		widgetBounds.maxY = graphicsBounds.maxY - (lineWidth != null && lineWidth > 0 && !isSvg ? (lineWidth < 2.0 ? lineWidth + 0.25 : lineWidth) : 0.0);

		if (isSvg) {
			widgetBounds.maxX = Math.max(widgetBounds.minX + 4.0, widgetBounds.maxX);
			widgetBounds.maxY = Math.max(widgetBounds.minY + 4.0, widgetBounds.maxY);
		}
	}

	public override function clear() : Graphics {
		if (graphicsData != []) {
			pen = new Point();
			localBounds = new Bounds();
			graphicsBounds = new Bounds();
			widgetBounds = new Bounds();
			var newGraphics = super.clear();
			untyped this.fillAlpha = null;

			isEmpty = true;
			isSvg = false;

			if (parent != null) {
				this.invalidateStage();
			}

			return newGraphics;
		} else {
			return this;
		}
	};

	private function updateNativeWidgetGraphicsData() : Void {
		if (this.isMask || this.isCanvas || this.isEmpty) {
			if (isNativeWidget) {
				this.deleteNativeWidget();
			}

			return;
		}

		this.initNativeWidget();

		if (!graphicsChanged) {
			return;
		}

		if (nativeWidget != null) {
			if (graphicsData.length == 0) {
				while (nativeWidget.lastElementChild != null) {
					nativeWidget.removeChild(nativeWidget.lastElementChild);
				}

				nativeWidget.style.background = null;
				nativeWidget.style.border = null;
				nativeWidget.style.borderRadius = null;
				nativeWidget.style.borderImage = null;
			} else if (graphicsData.length != 1 || isSvg || this.hasMask) {
				nativeWidget.style.borderRadius = null;
				if (Platform.isIE) {
					nativeWidget.style.background = '';
				} else {
					nativeWidget.style.background = null;
				}

				var svg : js.html.Element = nativeWidget.addElementNS('svg');

				svg.style.position = 'absolute';
				svg.style.left = "0";
				svg.style.top = "0";

				if (graphicsData.length == 1) {
					for (child in svg.childNodes) {
						if (untyped child.tagName != null && child.tagName.toLowerCase() == 'g') {
							svg.removeChild(child);
						}
					}
				} else {
					while (svg.lastElementChild != null && svg.lastElementChild.tagName.toLowerCase() != 'g' && svg.lastElementChild.tagName.toLowerCase() != 'defs') {
						svg.removeChild(svg.lastElementChild);
					}

					svg = svg.addElementNS('g');

					while (svg.lastElementChild != null) {
						svg.removeChild(svg.lastElementChild);
					}
				}

				for (data in graphicsData) {
					var element : js.html.Element = null;

					if (untyped data.fillGradient != null || data.strokeGradient != null) {
						var gradient : Dynamic = untyped data.gradient;
						var defs = svg.addElementNS('defs');
						var linearGradient = defs.addElementNS(gradient.type == 'radial' ? 'radialGradient' : 'linearGradient');

						if (gradient.type == 'radial') {
							for (child in defs.getElementsByTagName('linearGradient')) {
								svg.removeChild(child);
							}
						} else {
							for (child in defs.getElementsByTagName('radialGradient')) {
								svg.removeChild(child);
							}
						}

						linearGradient.setAttribute('id', nativeWidget.getAttribute('id') + "gradient");

						linearGradient.setAttribute('x1', '' + (50.0 - Math.sin((gradient.matrix.rotation + 90.0) * 0.0174532925) * 50.0) + '%');
						linearGradient.setAttribute('y1', '' + (50.0 + Math.cos((gradient.matrix.rotation + 90.0) * 0.0174532925) * 50.0) + '%');
						linearGradient.setAttribute('x2', '' + (50.0 - Math.sin((gradient.matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * 50.0) + '%');
						linearGradient.setAttribute('y2', '' + (50.0 + Math.cos((gradient.matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * 50.0) + '%');

						while (linearGradient.lastElementChild != null) {
							linearGradient.removeChild(linearGradient.lastElementChild);
						}

						for (i in 0...gradient.colors.length) {
							var stop = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'stop');

							stop.setAttribute("offset", '' + trimFloat(gradient.offsets[i], 0.0, 1.0) * 100.0 + '%');
							stop.setAttribute("style", 'stop-color:' + RenderSupport.makeCSSColor(gradient.colors[i], gradient.alphas[i]));

							linearGradient.appendChild(stop);
						}
					}

					var createSvgElement = function(tagName) {
						if (graphicsData.length == 1) {
							while (svg.lastElementChild != null && svg.lastElementChild.tagName.toLowerCase() != tagName && svg.lastElementChild.tagName.toLowerCase() != 'defs') {
								svg.removeChild(svg.lastElementChild);
							}

							element = svg.addElementNS(tagName);
						} else {
							element = Browser.document.createElementNS("http://www.w3.org/2000/svg", tagName);
							svg.appendChild(element);
						}

						if (untyped data.fillGradient != null) {
							element.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						} else if (data.fill != null && data.fillAlpha > 0) {
							element.setAttribute("fill", RenderSupport.makeCSSColor(data.fillColor, data.fillAlpha));
						} else {
							element.setAttribute("fill", "none");
						}

						if (untyped data.strokeGradient != null) {
							element.setAttribute("stroke", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
							element.setAttribute("stroke-width", Std.string(data.lineWidth));
						} else if (data.lineWidth != null && data.lineWidth > 0 && data.lineAlpha > 0) {
							element.setAttribute("stroke", RenderSupport.makeCSSColor(data.lineColor, data.lineAlpha));
							element.setAttribute("stroke-width", Std.string(data.lineWidth));
						} else {
							element.setAttribute("stroke", "none");
							element.removeAttribute("stroke-width");
						}
					};

					/*
					// HOT FIX FOR https://trello.com/c/EeDgmRL3/21766-slideshow-editor-major-slowdowns
					Browser.window.addEventListener('beforeprint', function () {
						try {
							nativeWidget.style.position = 'fixed';
							svg.style.position = '';
						} catch (e : Dynamic) {}
					}, false);

					Browser.window.addEventListener('afterprint', function () {
						try {
							nativeWidget.style.position = '';
							svg.style.position = 'absolute';
						} catch (e : Dynamic) {}
					}, false);
					*/
					if (data.shape.type == 0) {
						createSvgElement('path');

						var d : String = untyped __js__("data[0].shape.points.map(function(p, i) {
							return i % 2 == 0 ? (i == 0 ? 'M' : 'L') + p + ' ' : '' + p + ' ';
						}).join('')");

						if (untyped data.shape.points.length > 2 &&
							data.shape.points[0] == data.shape.points[data.shape.points.length - 2] &&
							data.shape.points[1] == data.shape.points[data.shape.points.length - 1]) {
							d = d + ' Z';
						}

						element.setAttribute("d", d);
					} else if (data.shape.type == 1) {
						createSvgElement('rect');

						element.setAttribute("x", Std.string(data.shape.x));
						element.setAttribute("y", Std.string(data.shape.y));
						element.setAttribute("width", Std.string(data.shape.width));
						element.setAttribute("height", Std.string(data.shape.height));
						element.removeAttribute("rx");
						element.removeAttribute("ry");
					} else if (data.shape.type == 2) {
						createSvgElement('circle');

						element.setAttribute("cx", Std.string(data.shape.x));
						element.setAttribute("cy", Std.string(data.shape.y));
						element.setAttribute("r", Std.string(data.shape.radius));
					} else if (data.shape.type == 4) {
						createSvgElement('rect');

						element.setAttribute("x", Std.string(data.shape.x));
						element.setAttribute("y", Std.string(data.shape.y));
						element.setAttribute("width", Std.string(data.shape.width));
						element.setAttribute("height", Std.string(data.shape.height));
						element.setAttribute("rx", Std.string(data.shape.radius));
						element.setAttribute("ry", Std.string(data.shape.radius));
					} else {
						trace("updateNativeWidgetGraphicsData: Unknown shape type");
						trace(data);
					}
				}
			} else {
				while (nativeWidget.lastElementChild != null) {
					nativeWidget.removeChild(nativeWidget.lastElementChild);
				}

				var data = graphicsData[0];

				if (data.fillAlpha > 0 || data.lineAlpha > 0) {
					if (data.lineWidth != null && data.lineWidth > 0 && data.lineAlpha > 0) {
						nativeWidget.style.border = '${data.lineWidth}px solid ' + (untyped data.strokeGradient != null ? '' : RenderSupport.makeCSSColor(data.lineColor, data.lineAlpha));
					} else {
						nativeWidget.style.border = null;
					}

					if (data.fill != null && data.fillAlpha > 0) {
						if (widgetBounds.getBoundsWidth() <= 2.0) {
							nativeWidget.style.border = null;
							nativeWidget.style.borderLeft = '${widgetBounds.getBoundsWidth()}px solid ' + RenderSupport.makeCSSColor(data.fillColor, data.fillAlpha);
							nativeWidget.style.background = null;
						} else if (widgetBounds.getBoundsHeight() <= 2.0) {
							nativeWidget.style.border = null;
							nativeWidget.style.borderTop = '${widgetBounds.getBoundsHeight()}px solid ' + RenderSupport.makeCSSColor(data.fillColor, data.fillAlpha);
							nativeWidget.style.background = null;
						} else {
							nativeWidget.style.background = RenderSupport.makeCSSColor(data.fillColor, data.fillAlpha);
						}
					} else {
						nativeWidget.style.background = null;
					}

					if (untyped data.fillGradient != null) {
						nativeWidget.style.background = untyped data.fillGradient;
					} else if (untyped data.strokeGradient != null) {
						trace(untyped data.strokeGradient);
						nativeWidget.style.borderImage = untyped data.strokeGradient;
					}

					var lineWidth = data.lineWidth != null && data.lineAlpha > 0 ? data.lineWidth : 0.0;
					if (data.shape.type == 1) {
						left = data.shape.x - lineWidth / 2.0;
						top = data.shape.y - lineWidth / 2.0;

						nativeWidget.style.borderRadius = null;
					} else if (data.shape.type == 2) {
						left = data.shape.x - DisplayObjectHelper.round(data.shape.radius) - lineWidth / 2.0;
						top = data.shape.y - DisplayObjectHelper.round(data.shape.radius) - lineWidth / 2.0;

						nativeWidget.style.borderRadius = '${DisplayObjectHelper.round(data.shape.radius + lineWidth)}px';
					} else if (data.shape.type == 3) {
						left = data.shape.x - DisplayObjectHelper.round(data.shape.width - lineWidth) - lineWidth / 2.0;
						top = data.shape.y - DisplayObjectHelper.round(data.shape.height - lineWidth) - lineWidth / 2.0;

						nativeWidget.style.borderRadius = '${DisplayObjectHelper.round(data.shape.width + lineWidth)}px /
							${DisplayObjectHelper.round(data.shape.height + lineWidth)}px';
					} else if (data.shape.type == 4) {
						left = data.shape.x - lineWidth / 2.0;
						top = data.shape.y - lineWidth / 2.0;

						nativeWidget.style.borderRadius = '${DisplayObjectHelper.round(data.shape.radius)}px';
					} else {
						trace('updateNativeWidgetGraphicsData: Unknown shape type');
						trace(data);
					}
				}
			}

			graphicsChanged = false;
		}
	}

	private function createNativeWidget(?tagName : String = "div") : Void {
		if (!isNativeWidget) {
			return;
		}

		this.deleteNativeWidget();

		nativeWidget = Browser.document.createElement(this.tagName != null && this.tagName != '' ? this.tagName : tagName);
		this.updateClipID();
		nativeWidget.className = 'nativeWidget';
		if (this.className != null && this.className != '') {
			nativeWidget.classList.add(this.className);
		}
		nativeWidget.setAttribute('role', 'presentation');

		isNativeWidget = true;
	}
}