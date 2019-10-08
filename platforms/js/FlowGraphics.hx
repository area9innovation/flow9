import js.Browser;

import pixi.core.display.Bounds;
import pixi.core.display.DisplayObject;
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

	private var pen = new Point(0.0, 0.0);
	private var localBounds = new Bounds();
	private var graphicsBounds = new Bounds();
	private var _bounds = new Bounds();
	private var widgetBounds = new Bounds();

	private var fillGradient : Dynamic;
	private var strokeGradient : Dynamic;

	public var transformChanged : Bool = false;
	private var worldTransformChanged : Bool = false;

	private var nativeWidget : Dynamic;
	private var accessWidget : AccessWidget;

	public var isEmpty : Bool = true;
	public var isSvg : Bool = false;
	public var isNativeWidget : Bool;

	public var filterPadding = 0.0;

	private static inline function trimFloat(f : Float, min : Float, max : Float) : Float {
		return f < min ? min : (f > max ? max : f);
	}

	public function new() {
		super();

		visible = false;
		interactiveChildren = false;
		isNativeWidget = false;
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

		return newGraphics;
	}

	public override function lineTo(x : Float, y : Float) : Graphics {
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

		if (fillGradient != null) {
			if (RenderSupportJSPixi.RendererType == "html") {
				untyped data.gradient = fillGradient;
				untyped data.fillGradient = fillGradient.type == 'radial' ?
					"radial-gradient(" :
					"linear-gradient(" + (fillGradient.matrix.rotation + 90.0) + 'deg, ';

				for (i in 0...fillGradient.colors.length) {
					untyped data.fillGradient += RenderSupportJSPixi.makeCSSColor(fillGradient.colors[i], fillGradient.alphas[i]) + ' ' +
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
						RenderSupportJSPixi.makeCSSColor(fillGradient.colors[i], fillGradient.alphas[i])
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

		invalidateTransform('endFill');

		if (RenderSupportJSPixi.RendererType == "html" && !isEmpty) {
			updateNativeWidgetGraphicsData();
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
			radius = Math.abs(radius);

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

		var filterPadding = untyped this.filterPadding;

		rect.x -= filterPadding;
		rect.y -= filterPadding;
		rect.width += filterPadding * 2.0;
		rect.height += filterPadding * 2.0;

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
			graphicsBounds.minX = untyped this._localBounds.minX;
			graphicsBounds.minY = untyped this._localBounds.minY;
			graphicsBounds.maxX = untyped this._localBounds.maxX;
			graphicsBounds.maxY = untyped this._localBounds.maxY;
		} else {
			graphicsBounds.minX = pen.x - (lineWidth != null ? lineWidth / 2.0 : 0.0);
			graphicsBounds.minY = pen.y - (lineWidth != null ? lineWidth / 2.0 : 0.0);
			graphicsBounds.maxX = pen.x + (lineWidth != null ? lineWidth / 2.0 : 0.0);
			graphicsBounds.maxY = pen.y + (lineWidth != null ? lineWidth / 2.0 : 0.0);
		}

		widgetBounds.minX = graphicsBounds.minX + (lineWidth != null && !isSvg ? lineWidth : 0.0);
		widgetBounds.minY = graphicsBounds.minY + (lineWidth != null && !isSvg ? lineWidth : 0.0);
		widgetBounds.maxX = graphicsBounds.maxX - (lineWidth != null && !isSvg ? lineWidth : 0.0);
		widgetBounds.maxY = graphicsBounds.maxY - (lineWidth != null && !isSvg ? lineWidth : 0.0);
	}

	public override function clear() : Graphics {
		pen = new Point();
		localBounds = new Bounds();
		graphicsBounds = new Bounds();
		widgetBounds = new Bounds();
		var newGraphics = super.clear();

		isEmpty = true;
		isSvg = false;
		deleteNativeWidget();

		if (parent != null) {
			invalidateStage();
		}

		return newGraphics;
	};

	private function updateNativeWidgetGraphicsData() : Void {
		if (isMask) {
			if (isNativeWidget) {
				deleteNativeWidget();
			}

			return;
		} else if (!isEmpty) {
			initNativeWidget();
		}

		if (nativeWidget != null) {
			while (nativeWidget.firstChild != null) {
			    nativeWidget.removeChild(nativeWidget.firstChild);
			}

			if (graphicsData.length != 1 || isSvg || untyped this.hasMask) {
				nativeWidget.style.marginLeft = null;
				nativeWidget.style.marginTop = null;
				nativeWidget.style.borderRadius = null;
				if (Platform.isIE) {
					nativeWidget.style.background = '';
				} else {
					nativeWidget.style.background = null;
				}

				for (data in graphicsData) {
					var svg = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'svg');

					svg.style.width = '${Math.max(graphicsBounds.maxX - graphicsBounds.minX + filterPadding * 2.0, 1.0)}px';
					svg.style.height = '${Math.max(graphicsBounds.maxY - graphicsBounds.minY + filterPadding * 2.0, 1.0)}px';
					svg.style.left = '${graphicsBounds.minX - filterPadding}px';
					svg.style.top = '${graphicsBounds.minY - filterPadding}px';
					svg.style.position = 'absolute';

					if (data.fill != null && data.fillAlpha > 0) {
						svg.setAttribute("fill", RenderSupportJSPixi.makeCSSColor(data.fillColor, data.fillAlpha));
					} else {
						svg.setAttribute("fill", "none");
					}

					if (data.lineWidth != null && data.lineWidth > 0 && data.lineAlpha > 0) {
						svg.setAttribute("stroke", RenderSupportJSPixi.makeCSSColor(data.lineColor, data.lineAlpha));
						svg.setAttribute("stroke-width", Std.string(data.lineWidth));
					} else {
						svg.setAttribute("stroke", "none");
					}

					if (untyped data.fillGradient != null) {
						var gradient : Dynamic = untyped data.gradient;
						var defs = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'defs');
						var linearGradient = Browser.document.createElementNS("http://www.w3.org/2000/svg", gradient.type == 'radial' ? 'radialGradient' : 'linearGradient');

						defs.appendChild(linearGradient);

						linearGradient.setAttribute('id', nativeWidget.getAttribute('id') + "gradient");

						linearGradient.setAttribute('x1', '' + (50.0 - Math.sin((gradient.matrix.rotation + 90.0) * 0.0174532925) * 50.0) + '%');
						linearGradient.setAttribute('y1', '' + (50.0 + Math.cos((gradient.matrix.rotation + 90.0) * 0.0174532925) * 50.0) + '%');
						linearGradient.setAttribute('x2', '' + (50.0 - Math.sin((gradient.matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * 50.0) + '%');
						linearGradient.setAttribute('y2', '' + (50.0 + Math.cos((gradient.matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * 50.0) + '%');


						for (i in 0...gradient.colors.length) {
							var stop = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'stop');

							stop.setAttribute("offset", '' + trimFloat(gradient.offsets[i], 0.0, 1.0) * 100.0 + '%');
							stop.setAttribute("style", 'stop-color:' + RenderSupportJSPixi.makeCSSColor(gradient.colors[i], gradient.alphas[i]));

							linearGradient.appendChild(stop);
						}

						svg.appendChild(defs);
					}

					if (data.shape.type == 0) {
						var path = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'path');

						var d : String = untyped __js__("data.shape.points.map(function(p, i) {
							return i % 2 == 0 ? (i == 0 ? 'M' : 'L') + p + ' ' : '' + p + ' ';
						}).join('')");
						path.setAttribute("d", d);
						path.setAttribute('transform', 'matrix(1 0 0 1 ${filterPadding - graphicsBounds.minX} ${filterPadding - graphicsBounds.minY})');

						if (untyped data.fillGradient != null) {
							path.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.appendChild(path);
					} else if (data.shape.type == 1) {
						var rect = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'rect');

						rect.setAttribute("x", Std.string(data.shape.x));
						rect.setAttribute("y", Std.string(data.shape.y));
						rect.setAttribute("width", Std.string(data.shape.width));
						rect.setAttribute("height", Std.string(data.shape.height));
						rect.setAttribute('transform', 'matrix(1 0 0 1 ${filterPadding - graphicsBounds.minX} ${filterPadding - graphicsBounds.minY})');

						if (untyped data.fillGradient != null) {
							rect.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.appendChild(rect);
					} else if (data.shape.type == 2) {
						var circle = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'circle');

						circle.setAttribute("cx", Std.string(data.shape.x));
						circle.setAttribute("cy", Std.string(data.shape.y));
						circle.setAttribute("r", Std.string(data.shape.radius));
						circle.setAttribute('transform', 'matrix(1 0 0 1 ${filterPadding - graphicsBounds.minX} ${filterPadding - graphicsBounds.minY})');

						if (untyped data.fillGradient != null) {
							circle.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.appendChild(circle);
					} else if (data.shape.type == 4) {
						var rect = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'rect');

						rect.setAttribute("x", Std.string(data.shape.x));
						rect.setAttribute("y", Std.string(data.shape.y));
						rect.setAttribute("width", Std.string(data.shape.width));
						rect.setAttribute("height", Std.string(data.shape.height));
						rect.setAttribute("rx", Std.string(data.shape.radius));
						rect.setAttribute("ry", Std.string(data.shape.radius));
						rect.setAttribute('transform', 'matrix(1 0 0 1 ${filterPadding - graphicsBounds.minX} ${filterPadding - graphicsBounds.minY})');

						if (untyped data.fillGradient != null) {
							rect.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.appendChild(rect);
					} else {
						trace("updateNativeWidgetGraphicsData: Unknown shape type");
						trace(data);
					}

					if (nativeWidget.childNodes.length > 0 && nativeWidget.lastChild.tagName.toLowerCase() == 'svg' &&
						nativeWidget.lastChild.getAttribute("fill") == svg.getAttribute("fill") &&
						nativeWidget.lastChild.getAttribute("stroke") == svg.getAttribute("stroke")) {
						for (child in svg.childNodes) {
							nativeWidget.lastChild.appendChild(child);
						}
					} else {
						nativeWidget.appendChild(svg);
					}
				}
			} else {
				var data = graphicsData[0];

				if (data.fillAlpha > 0 || data.lineAlpha > 0) {
					if (data.shape.type == 0) {
						var svg = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'svg');
						var path = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'path');

						var d : String = untyped __js__("data1.shape.points.map(function(p, i) {
							return i % 2 == 0 ? (i == 0 ? 'M' : 'L') + p + ' ' : '' + p + ' ';
						}).join('')");
						path.setAttribute("d", d);
						path.setAttribute('transform', 'matrix(1 0 0 1 ${filterPadding - graphicsBounds.minX} ${filterPadding - graphicsBounds.minY})');

						if (data.fill != null && data.fillAlpha > 0) {
							path.setAttribute("fill", RenderSupportJSPixi.makeCSSColor(data.fillColor, data.fillAlpha));
						} else {
							path.setAttribute("fill", "none");
						}

						if (data.lineWidth != null && data.lineWidth > 0 && data.lineAlpha > 0) {
							path.setAttribute("stroke", RenderSupportJSPixi.makeCSSColor(data.lineColor, data.lineAlpha));
							path.setAttribute("stroke-width", Std.string(data.lineWidth));
						} else {
							path.setAttribute("stroke", "none");
						}

						if (untyped data.fillGradient != null) {
							var gradient : Dynamic = untyped data.gradient;
							var defs = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'defs');
							var linearGradient = Browser.document.createElementNS("http://www.w3.org/2000/svg", gradient.type == 'radial' ? 'radialGradient' : 'linearGradient');

							defs.appendChild(linearGradient);

							linearGradient.setAttribute('id', nativeWidget.getAttribute('id') + "gradient");

							linearGradient.setAttribute('x1', '' + (50.0 - Math.sin((gradient.matrix.rotation + 90.0) * 0.0174532925) * 50.0) + '%');
							linearGradient.setAttribute('y1', '' + (50.0 + Math.cos((gradient.matrix.rotation + 90.0) * 0.0174532925) * 50.0) + '%');
							linearGradient.setAttribute('x2', '' + (50.0 - Math.sin((gradient.matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * 50.0) + '%');
							linearGradient.setAttribute('y2', '' + (50.0 + Math.cos((gradient.matrix.rotation + 90.0) * 0.0174532925 - Math.PI) * 50.0) + '%');

							for (i in 0...gradient.colors.length) {
								var stop = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'stop');

								stop.setAttribute("offset", '' + trimFloat(gradient.offsets[i], 0.0, 1.0) * 100.0 + '%');
								stop.setAttribute("style", 'stop-color:' + RenderSupportJSPixi.makeCSSColor(gradient.colors[i], gradient.alphas[i]));

								linearGradient.appendChild(stop);
							}

							svg.appendChild(defs);

							path.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.style.width = '${Math.max(graphicsBounds.maxX - graphicsBounds.minX + filterPadding * 2.0, 1.0)}px';
						svg.style.height = '${Math.max(graphicsBounds.maxY - graphicsBounds.minY + filterPadding * 2.0, 1.0)}px';
						svg.style.left = '${graphicsBounds.minX - filterPadding}px';
						svg.style.top = '${graphicsBounds.minY - filterPadding}px';
						svg.style.position = 'absolute';

						svg.appendChild(path);
						nativeWidget.appendChild(svg);
					} else {
						if (data.fill != null && data.fillAlpha > 0) {
							nativeWidget.style.background = RenderSupportJSPixi.makeCSSColor(data.fillColor, data.fillAlpha);
						} else {
							nativeWidget.style.background = null;
						}

						if (data.lineWidth != null && data.lineWidth > 0 && data.lineAlpha > 0) {
							nativeWidget.style.border = '${data.lineWidth}px solid ' + RenderSupportJSPixi.makeCSSColor(data.lineColor, data.lineAlpha);
						} else {
							nativeWidget.style.border = null;
						}

						if (untyped data.fillGradient != null) {
							nativeWidget.style.background = untyped data.fillGradient;
						}

						if (data.shape.type == 1) {
							var left = data.shape.x - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);
							var top = data.shape.y - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);

							nativeWidget.style.marginLeft = left != 0 ? '${left}px' : null;
							nativeWidget.style.marginTop = top != 0 ? '${top}px' : null;
							nativeWidget.style.borderRadius = null;
						} else if (data.shape.type == 2) {
							var left = data.shape.x - DisplayObjectHelper.round(data.shape.radius) - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);
							var top = data.shape.y - DisplayObjectHelper.round(data.shape.radius) - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);
							nativeWidget.style.marginLeft = left != 0 ? '${left}px' : null;
							nativeWidget.style.marginTop = top != 0 ? '${top}px' : null;
							nativeWidget.style.borderRadius = '${DisplayObjectHelper.round(data.shape.radius)}px';
						} else if (data.shape.type == 3) {
							var left = data.shape.x - DisplayObjectHelper.round(data.shape.width - data.lineWidth) - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);
							var top = data.shape.y - DisplayObjectHelper.round(data.shape.height - data.lineWidth) - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);
							nativeWidget.style.marginLeft = left != 0 ? '${left}px' : null;
							nativeWidget.style.marginTop = top != 0 ? '${top}px' : null;
							nativeWidget.style.borderRadius = '${DisplayObjectHelper.round(data.shape.width - data.lineWidth)}px /
								${DisplayObjectHelper.round(data.shape.height - data.lineWidth)}px';
						} else if (data.shape.type == 4) {
							var left = data.shape.x - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);
							var top = data.shape.y - (data.lineWidth != null ? data.lineWidth / 2.0 : 0.0);
							nativeWidget.style.marginLeft = left != 0 ? '${left}px' : null;
							nativeWidget.style.marginTop = top != 0 ? '${top}px' : null;
							nativeWidget.style.borderRadius = '${DisplayObjectHelper.round(data.shape.radius)}px';
						} else {
							trace('updateNativeWidgetGraphicsData: Unknown shape type');
							trace(data);
						}
					}
				}
			}
		}
	}

	private function createNativeWidget(?tagName : String = "div") : Void {
		if (!isNativeWidget) {
			return;
		}

		deleteNativeWidget();

		nativeWidget = Browser.document.createElement(tagName);
		updateClipID();
		nativeWidget.className = 'nativeWidget';

		isNativeWidget = true;
	}
}