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

	private var fillGradient : Dynamic;
	private var strokeGradient : Dynamic;

	public var transformChanged : Bool = false;
	private var worldTransformChanged : Bool = false;

	private var nativeWidget : Dynamic;
	private var accessWidget : AccessWidget;

	public var isEmpty : Bool = true;
	public var isSvg : Bool = false;
	public var isNativeWidget : Bool;

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

		localBounds.addPoint(new Point(x - lineWidth / 2.0, y - lineWidth / 2.0));
		localBounds.addPoint(new Point(x + lineWidth / 2.0, y + lineWidth / 2.0));

		return newGraphics;
	}

	public override function lineTo(x : Float, y : Float) : Graphics {
		var newGraphics = super.lineTo(x, y);
		pen.x = x;
		pen.y = y;

		isSvg = true;

		localBounds.addPoint(new Point(x - lineWidth / 2.0, y - lineWidth / 2.0));
		localBounds.addPoint(new Point(x + lineWidth / 2.0, y + lineWidth / 2.0));

		return newGraphics;
	}

	public override function quadraticCurveTo(cx : Float, cy : Float, x : Float, y : Float) : Graphics {
		var dx = x - pen.x;
		var dy = y - pen.y;

		var newGraphics = super.quadraticCurveTo(cx, cy, x, y);
		pen.x = x;
		pen.y = y;

		isSvg = true;

		localBounds.addPoint(new Point(x - lineWidth / 2.0, y - lineWidth / 2.0));
		localBounds.addPoint(new Point(x + lineWidth / 2.0, y + lineWidth / 2.0));

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

		if (fillGradient != null) {
			if (RenderSupportJSPixi.DomRenderer) {
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
				var bounds = getLocalBounds();
				canvas.width = untyped bounds.width;
				canvas.height = untyped bounds.height;

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
		}

		if (untyped this.mask == null) {
			var currentBounds = new Bounds();

			if (parent != null && localBounds.minX != Math.POSITIVE_INFINITY) {
				applyLocalBoundsTransform(currentBounds);
			}

			updateLocalBounds();
			localBounds = untyped this._localBounds;

			if (parent != null) {
				var newBounds = applyLocalBoundsTransform();
				if (!currentBounds.isEqualBounds(newBounds)) {
					parent.replaceLocalBounds(currentBounds, newBounds);
				}
			}
		}

		graphicsBounds = localBounds;

		if (parent != null) {
			invalidateStage();
		}

		if (RenderSupportJSPixi.DomRenderer && !isEmpty) {
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

			localBounds.addPoint(new Point(x - lineWidth / 2.0, y - lineWidth / 2.0));
			localBounds.addPoint(new Point(x + width + lineWidth / 2.0, y + height + lineWidth / 2.0));

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

				localBounds.addPoint(new Point(x - lineWidth / 2.0, y - lineWidth / 2.0));
				localBounds.addPoint(new Point(x + width + lineWidth / 2.0, y + height + lineWidth / 2.0));

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

			localBounds.addPoint(new Point(x - width - lineWidth / 2.0, y - height - lineWidth / 2.0));
			localBounds.addPoint(new Point(x + width + lineWidth / 2.0, y + height + lineWidth / 2.0));

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

			localBounds.addPoint(new Point(x - radius - lineWidth / 2.0, y - radius - lineWidth / 2.0));
			localBounds.addPoint(new Point(x + radius + lineWidth / 2.0, y + radius + lineWidth / 2.0));

			endFill();

			return newGraphics;
		} else {
			return this;
		}
	}

	public override function getLocalBounds(?rect : Rectangle) : Rectangle {
		return localBounds.getRectangle(rect);
	}

	public override function getBounds(?skipUpdate : Bool, ?rect : Rectangle) : Rectangle {
		if (!skipUpdate) {
			updateTransform();
		}

		if (untyped this._boundsID != untyped this._lastBoundsID)
		{
			calculateBounds();
		}

		return _bounds.getRectangle(rect);
	}

	public function calculateBounds() : Void {
		_bounds.minX = localBounds.minX * worldTransform.a + localBounds.minY * worldTransform.c + worldTransform.tx;
		_bounds.minY = localBounds.minX * worldTransform.b + localBounds.minY * worldTransform.d + worldTransform.ty;
		_bounds.maxX = localBounds.maxX * worldTransform.a + localBounds.maxY * worldTransform.c + worldTransform.tx;
		_bounds.maxY = localBounds.maxX * worldTransform.b + localBounds.maxY * worldTransform.d + worldTransform.ty;
	}

	public function calculateLocalBounds() : Void {
		var currentBounds = new Bounds();

		if (parent != null && localBounds.minX != Math.POSITIVE_INFINITY) {
			applyLocalBoundsTransform(currentBounds);
		}

		if (mask != null || untyped this.alphaMask != null || scrollRect != null) {
			var mask = mask != null ? mask : untyped this.alphaMask != null ? untyped this.alphaMask : scrollRect;

			if (untyped mask.localBounds.minX != Math.POSITIVE_INFINITY) {
				localBounds.clear();
				cast(mask, DisplayObject).applyLocalBoundsTransform(localBounds);
			} else {
				localBounds = graphicsBounds;
			}
		} else {
			localBounds = graphicsBounds;
		}

		if (parent != null) {
			var newBounds = applyLocalBoundsTransform();
			if (!currentBounds.isEqualBounds(newBounds)) {
				parent.replaceLocalBounds(currentBounds, newBounds);
				invalidateTransform();
			}
		}
	}

	public override function clear() : Graphics {
		pen = new Point();
		localBounds = new Bounds();
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
			// if (isSvg) {
			// 	replaceWithCanvas();
			// } else {
			// 	initNativeWidget();
			// }
			initNativeWidget();
		}

		if (nativeWidget != null) {
			while (nativeWidget.firstChild != null) {
			    nativeWidget.removeChild(nativeWidget.firstChild);
			}

			if (graphicsData.length != 1) {
				for (data in graphicsData) {
					var svg = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'svg');

					svg.style.width = '${localBounds.maxX - localBounds.minX}px';
					svg.style.height = '${localBounds.maxY - localBounds.minY}px';
					svg.style.left = '${localBounds.minX}px';
					svg.style.top = '${localBounds.minY}px';
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

						var localBounds = this.localBounds;
						var d : String = untyped __js__("data.shape.points.map(function(p, i) {
							return i % 2 == 0 ? (i == 0 ? 'M' : 'L') + (p - localBounds.minX) + ' ' : '' + (p - localBounds.minY) + ' ';
						}).join('')");
						path.setAttribute("d", d);

						if (untyped data.fillGradient != null) {
							path.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.appendChild(path);
					} else if (data.shape.type == 1) {
						var rect = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'rect');

						rect.setAttribute("x", Std.string(data.shape.x - localBounds.minX));
						rect.setAttribute("y", Std.string(data.shape.y - localBounds.minY));
						rect.setAttribute("width", Std.string(data.shape.width));
						rect.setAttribute("height", Std.string(data.shape.height));

						if (untyped data.fillGradient != null) {
							rect.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.appendChild(rect);
					} else if (data.shape.type == 2) {
						var circle = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'circle');

						circle.setAttribute("cx", Std.string(data.shape.x - localBounds.minX));
						circle.setAttribute("cy", Std.string(data.shape.y - localBounds.minY));
						circle.setAttribute("r", Std.string(data.shape.radius));

						if (untyped data.fillGradient != null) {
							circle.setAttribute("fill", "url(#" + nativeWidget.getAttribute('id') + "gradient)");
						}

						svg.appendChild(circle);
					} else if (data.shape.type == 4) {
						var rect = Browser.document.createElementNS("http://www.w3.org/2000/svg", 'rect');

						rect.setAttribute("x", Std.string(data.shape.x - localBounds.minX));
						rect.setAttribute("y", Std.string(data.shape.y - localBounds.minY));
						rect.setAttribute("width", Std.string(data.shape.width));
						rect.setAttribute("height", Std.string(data.shape.height));
						rect.setAttribute("rx", Std.string(data.shape.radius));
						rect.setAttribute("ry", Std.string(data.shape.radius));

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

						var localBounds = this.localBounds;
						var d : String = untyped __js__("data1.shape.points.map(function(p, i) {
							return i % 2 == 0 ? (i == 0 ? 'M' : 'L') + (p - localBounds1.minX) + ' ' : '' + (p - localBounds1.minY) + ' ';
						}).join('')");
						path.setAttribute("d", d);

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

						svg.style.width = '${localBounds.maxX - localBounds.minX}px';
						svg.style.height = '${localBounds.maxY - localBounds.minY}px';
						svg.style.left = '${localBounds.minX}px';
						svg.style.top = '${localBounds.minY}px';
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
							trace("---");
							trace(untyped data.fillGradient);
							trace(nativeWidget.style.background);
						}

						if (data.shape.type == 1) {
							nativeWidget.style.marginLeft = '${data.shape.x}px';
							nativeWidget.style.marginTop = '${data.shape.y}px';
							nativeWidget.style.width = '${data.shape.width - data.lineWidth * 2}px';
							nativeWidget.style.height = '${data.shape.height - data.lineWidth * 2}px';
							nativeWidget.style.borderRadius = null;
						} else if (data.shape.type == 2) {
							nativeWidget.style.marginLeft = '${data.shape.x - data.shape.radius}px';
							nativeWidget.style.marginTop = '${data.shape.y - data.shape.radius}px';
							nativeWidget.style.width = '${data.shape.radius * 2 - data.lineWidth * 2}px';
							nativeWidget.style.height = '${data.shape.radius * 2 - data.lineWidth * 2}px';
							nativeWidget.style.borderRadius = '${data.shape.radius}px';
						} else if (data.shape.type == 3) {
							nativeWidget.style.marginLeft = '${data.shape.x - (data.shape.width * 2.0 - data.lineWidth * 2) / 2.0}px';
							nativeWidget.style.marginTop = '${data.shape.y - (data.shape.height * 2.0 - data.lineWidth * 2) / 2.0}px';
							nativeWidget.style.width = '${data.shape.width * 2.0 - data.lineWidth * 2}px';
							nativeWidget.style.height = '${data.shape.height * 2.0 - data.lineWidth * 2}px';
							nativeWidget.style.borderRadius = '${data.shape.width - data.lineWidth}px / ${data.shape.height - data.lineWidth}px';
						} else if (data.shape.type == 4) {
							nativeWidget.style.marginLeft = '${data.shape.x}px';
							nativeWidget.style.marginTop = '${data.shape.y}px';
							nativeWidget.style.width = '${data.shape.width - data.lineWidth * 2}px';
							nativeWidget.style.height = '${data.shape.height - data.lineWidth * 2}px';
							nativeWidget.style.borderRadius = '${data.shape.radius}px';
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
		nativeWidget.setAttribute('id', getClipUUID());
		nativeWidget.className = 'nativeWidget';

		isNativeWidget = true;
	}
}