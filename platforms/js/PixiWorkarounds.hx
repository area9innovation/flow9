class PixiWorkarounds {
	public static function workaroundDOMOverOutEventsTransparency() : Void {
		untyped __js__("
		var binder = function(fn) {
			return fn.bind(RenderSupportJSPixi.PixiRenderer.plugins.interaction);
		}

		var emptyFn = function() {};

		var old_pointer_over = PIXI.interaction.InteractionManager.prototype.onPointerOver;
		var old_pointer_out = PIXI.interaction.InteractionManager.prototype.onPointerOut;

		PIXI.interaction.InteractionManager.prototype.onPointerOver = emptyFn;
		PIXI.interaction.InteractionManager.prototype.onPointerOut = emptyFn;

		var pointer_over = function(e) {
			if (e.fromElement == null)
				binder(old_pointer_over)(e);
		}

		var mouse_move = function(e) {
			pointer_over(e);
			document.removeEventListener('mousemove', mouse_move);
		}

		// if mouse is already over document
		document.addEventListener('mousemove', mouse_move);

		document.addEventListener('mouseover', pointer_over);

		document.addEventListener('mouseout', function(e) {
			if (e.toElement == null)
				binder(old_pointer_out)(e);
		});

		document.addEventListener('pointerover', function (e) {
			if (e.fromElement == null)
				binder(old_pointer_over)(e);
		});
		document.addEventListener('pointerout', function (e) {
			if (e.toElement == null)
				binder(old_pointer_out)(e);
		});");
	}

	public static function workaroundRendererDestroy() : Void {
		untyped __js__("
			PIXI.WebGLRenderer.prototype.bindTexture = function(texture, location, forceLocation)
			{
				texture = texture || this.emptyTextures[location];
				texture = texture.baseTexture || texture;
				texture.touched = this.textureGC.count;

				if (!forceLocation)
				{
					// TODO - maybe look into adding boundIds.. save us the loop?
					for (let i = 0; i < this.boundTextures.length; i++)
					{
						if (this.boundTextures[i] === texture)
						{
							return i;
						}
					}

					if (location === undefined)
					{
						this._nextTextureLocation++;
						this._nextTextureLocation %= this.boundTextures.length;
						location = this.boundTextures.length - this._nextTextureLocation - 1;
					}
				}
				else
				{
					location = location || 0;
				}

				const gl = this.gl;
				const glTexture = texture._glTextures[this.CONTEXT_UID];

				if (!glTexture)
				{
					// this will also bind the texture..
					try {
						this.textureManager.updateTexture(texture, location);
					} catch (error) {
						// usually a crossorigin problem
					}
				}
				else
				{
					// bind the current texture
					this.boundTextures[location] = texture;
					gl.activeTexture(gl.TEXTURE0 + location);
					gl.bindTexture(gl.TEXTURE_2D, glTexture.texture);
				}

				return location;
			}

			PIXI.WebGLRenderer.prototype.destroy = function(removeView)
			{
				// this.destroyPlugins();

				// remove listeners
				this.view.removeEventListener('webglcontextlost', this.handleContextLost);
				this.view.removeEventListener('webglcontextrestored', this.handleContextRestored);

				this.textureManager.destroy();

				// call base destroy
				this.type = PIXI.RENDERER_TYPE.UNKNOWN;

				this.view = null;

				this.screen = null;

				this.resolution = 0;

				this.transparent = false;

				this.autoResize = false;

				this.blendModes = null;

				this.options = null;

				this.preserveDrawingBuffer = false;
				this.clearBeforeRender = false;

				this.roundPixels = false;

				this._backgroundColor = 0;
				this._backgroundColorRgba = null;
				this._backgroundColorString = null;

				this._tempDisplayObjectParent = null;
				this._lastObjectRendered = null;

				this.uid = 0;

				// destroy the managers
				this.maskManager.destroy();
				this.stencilManager.destroy();
				this.filterManager.destroy();

				this.maskManager = null;
				this.filterManager = null;
				this.textureManager = null;
				this.currentRenderer = null;

				this.handleContextLost = null;
				this.handleContextRestored = null;

				this._contextOptions = null;
				// this.gl.useProgram(null);

				// if (this.gl.getExtension('WEBGL_lose_context'))
				// {
				// 	this.gl.getExtension('WEBGL_lose_context').loseContext();
				// }

				this.gl = null;
			}
		");
	}

	public static function workaroundProcessInteractive() : Void {
		untyped __js__("
			PIXI.interaction.InteractionManager.prototype.processInteractive = function(interactionEvent, displayObject, func, hitTest, interactive)
			{
				if (!displayObject || !displayObject.visible)
				{
					return false;
				}

				const point = interactionEvent.data.global;

				// Took a little while to rework this function correctly! But now it is done and nice and optimised. ^_^
				//
				// This function will now loop through all objects and then only hit test the objects it HAS
				// to, not all of them. MUCH faster..
				// An object will be hit test if the following is true:
				//
				// 1: It is interactive.
				// 2: It belongs to a parent that is interactive AND one of the parents children have not already been hit.
				//
				// As another little optimisation once an interactive object has been hit we can carry on
				// through the scenegraph, but we know that there will be no more hits! So we can avoid extra hit tests
				// A final optimisation is that an object is not hit test directly if a child has already been hit.

				interactive = displayObject.interactive || interactive;

				let hit = false;
				let interactiveParent = interactive;

				// Flag here can set to false if the event is outside the parents hitArea or mask
				let hitTestChildren = true;

				// If there is a hitArea, no need to test against anything else if the pointer is not within the hitArea
				// There is also no longer a need to hitTest children.
				if (displayObject.hitArea)
				{
					if (hitTest)
					{
						displayObject.worldTransform.applyInverse(point, this._tempPoint);
						if (!displayObject.hitArea.contains(this._tempPoint.x, this._tempPoint.y))
						{
							hitTest = false;
							hitTestChildren = false;
						}
						else
						{
							hit = true;
						}
					}
					interactiveParent = false;
				}
				// If there is a mask, no need to test against anything else if the pointer is not within the mask
				else if (displayObject._mask)
				{
					if (hitTest)
					{
						if (!displayObject._mask.containsPoint(point))
						{
							hitTest = false;
							// hitTestChildren = false;
						}
					}
				}

				// ** FREE TIP **! If an object is not interactive or has no buttons in it
				// (such as a game scene!) set interactiveChildren to false for that displayObject.
				// This will allow PixiJS to completely ignore and bypass checking the displayObjects children.
				if (hitTestChildren && displayObject.interactiveChildren && displayObject.children)
				{
					const children = displayObject.children;

					for (let i = children.length - 1; i >= 0; i--)
					{
						const child = children[i];

						// time to get recursive.. if this function will return if something is hit..
						const childHit = this.processInteractive(interactionEvent, child, func, hitTest, interactiveParent);

						if (childHit)
						{
							// its a good idea to check if a child has lost its parent.
							// this means it has been removed whilst looping so its best
							if (!child.parent)
							{
								continue;
							}

							// we no longer need to hit test any more objects in this container as we we
							// now know the parent has been hit
							interactiveParent = false;

							// If the child is interactive , that means that the object hit was actually
							// interactive and not just the child of an interactive object.
							// This means we no longer need to hit test anything else. We still need to run
							// through all objects, but we don't need to perform any hit tests.

							if (childHit)
							{
								if (interactionEvent.target)
								{
									hitTest = false;
								}
								hit = true;
							}
						}
					}
				}

				// no point running this if the item is not interactive or does not have an interactive parent.
				if (interactive)
				{
					// if we are hit testing (as in we have no hit any objects yet)
					// We also don't need to worry about hit testing if once of the displayObjects children
					// has already been hit - but only if it was interactive, otherwise we need to keep
					// looking for an interactive child, just in case we hit one
					if (hitTest && !interactionEvent.target)
					{
						// already tested against hitArea if it is defined
						if (!displayObject.hitArea && displayObject.containsPoint)
						{
							if (displayObject.containsPoint(point))
							{
								hit = true;
							}
						}
					}

					if (displayObject.interactive)
					{
						if (hit && !interactionEvent.target)
						{
							interactionEvent.target = displayObject;
						}

						if (func)
						{
							func(interactionEvent, displayObject, !!hit);
						}
					}
				}

				return hit;
			}
		");
	}

	public static function workaroundIEArrayFromMethod() : Void {
		untyped __js__("
		if (!Array.from) {
			Array.from = (function () {
				var toStr = Object.prototype.toString;
				var isCallable = function (fn) {
					return typeof fn === 'function' || toStr.call(fn) === '[object Function]';
				};
				var toInteger = function (value) {
					var number = Number(value);
					if (isNaN(number)) { return 0; }
					if (number === 0 || !isFinite(number)) { return number; }
					return (number > 0 ? 1 : -1) * Math.floor(Math.abs(number));
				};
				var maxSafeInteger = Math.pow(2, 53) - 1;
				var toLength = function (value) {
					var len = toInteger(value);
					return Math.min(Math.max(len, 0), maxSafeInteger);
				};

				// The length property of the from method is 1.
				return function from(arrayLike/*, mapFn, thisArg */) {
					// 1. Let C be the this value.
					var C = this;

					// 2. Let items be ToObject(arrayLike).
					var items = Object(arrayLike);

					// 3. ReturnIfAbrupt(items).
					if (arrayLike == null) {
						throw new TypeError('Array.from requires an array-like object - not null or undefined');
					}

					// 4. If mapfn is undefined, then let mapping be false.
					var mapFn = arguments.length > 1 ? arguments[1] : void undefined;
					var T;
					if (typeof mapFn !== 'undefined') {
						// 5. else
						// 5. a If IsCallable(mapfn) is false, throw a TypeError exception.
						if (!isCallable(mapFn)) {
							throw new TypeError('Array.from: when provided, the second argument must be a function');
						}

						// 5. b. If thisArg was supplied, let T be thisArg; else let T be undefined.
						if (arguments.length > 2) {
							T = arguments[2];
						}
					}

					// 10. Let lenValue be Get(items, 'length').
					// 11. Let len be ToLength(lenValue).
					var len = toLength(items.length);

					// 13. If IsConstructor(C) is true, then
					// 13. a. Let A be the result of calling the [[Construct]] internal method of C with an argument list containing the single item len.
					// 14. a. Else, Let A be ArrayCreate(len).
					var A = isCallable(C) ? Object(new C(len)) : new Array(len);

					// 16. Let k be 0.
					var k = 0;
					// 17. Repeat, while k < len… (also steps a - h)
					var kValue;
					while (k < len) {
						kValue = items[k];
						if (mapFn) {
							A[k] = typeof T === 'undefined' ? mapFn(kValue, k) : mapFn.call(T, kValue, k);
						} else {
							A[k] = kValue;
						}
						k += 1;
					}
					// 18. Let putStatus be Put(A, 'length', len, true).
					A.length = len;
					// 20. Return A.
					return A;
				};
			}());
		}");
	}

	public static function workaroundIECustomEvent() : Void {
		untyped __js__("
		if ( typeof window.CustomEvent !== 'function' ) {
			function CustomEvent ( event, params ) {
				params = params || { bubbles: false, cancelable: false, detail: undefined };
				var evt = document.createEvent( 'CustomEvent' );
				evt.initCustomEvent( event, params.bubbles, params.cancelable, params.detail );

				for (var key in params) {
					evt[key] = params[key];
				}

				return evt;
			}

			CustomEvent.prototype = window.Event.prototype;

			window.CustomEvent = CustomEvent;
		};");
	}

	public static function workaroundTextMetrics() : Void {
		untyped __js__("
			if (!HTMLElement.prototype.scrollTo) { HTMLElement.prototype.scrollTo = function (left, top) {this.scrollTop = top; this.scrollLeft = left; } }

			PIXI.TextMetrics.measureFont = function(font)
			{
				// as this method is used for preparing assets, don't recalculate things if we don't need to
				if (PIXI.TextMetrics._fonts[font])
				{
					return PIXI.TextMetrics._fonts[font];
				}

				const properties = {};

				const canvas = PIXI.TextMetrics._canvas;
				const context = PIXI.TextMetrics._context;

				context.font = font;

				const metricsString = PIXI.TextMetrics.METRICS_STRING + PIXI.TextMetrics.BASELINE_SYMBOL;
				const width = Math.ceil(context.measureText(metricsString).width);
				let baseline = Math.ceil(context.measureText(PIXI.TextMetrics.BASELINE_SYMBOL).width) * 2;
				const height = 2 * baseline;

				baseline = baseline * PIXI.TextMetrics.BASELINE_MULTIPLIER | 0;

				canvas.width = width;
				canvas.height = height;

				context.fillStyle = '#f00';
				context.fillRect(0, 0, width, height);

				context.font = font;

				context.textBaseline = 'alphabetic';
				context.fillStyle = '#000';
				context.fillText(metricsString, 0, baseline);

				const imagedata = context.getImageData(0, 0, width, height).data;
				const pixels = imagedata.length;
				const line = width * 4;

				let i = 0;
				let idx = 0;
				let stop = false;

				// ascent. scan from top to bottom until we find a non red pixel
				for (i = 0; i < baseline; ++i)
				{
					for (let j = 0; j < line; j += 4)
					{
						if (imagedata[idx + j] !== 255)
						{
							stop = true;
							break;
						}
					}
					if (!stop)
					{
						idx += line;
					}
					else
					{
						break;
					}
				}

				properties.ascent = baseline - i;

				idx = pixels - line;
				stop = false;

				// descent. scan from bottom to top until we find a non red pixel
				for (i = height; i > baseline; --i)
				{
					for (let j = 0; j < line; j += 4)
					{
						if (imagedata[idx + j] !== 255)
						{
							stop = true;
							break;
						}
					}

					if (!stop)
					{
						idx -= line;
					}
					else
					{
						break;
					}
				}

				properties.descent = i - baseline;
				properties.fontSize = properties.ascent + properties.descent;

				PIXI.TextMetrics._fonts[font] = properties;

				return properties;
			};

			// PIXI.TextMetrics.wordWrap = function(text, style, canvas)
			// {
			// 	if (typeof canvas == 'undefined') {
			// 		canvas = PIXI.TextMetrics._canvas;
			// 	}

			// 	const context = canvas.getContext('2d');

			// 	var width = 0;
			// 	var line = '';
			// 	var lines = '';

			// 	const cache = {};
			// 	const letterSpacing = style.letterSpacing;
			// 	const whiteSpace = style.whiteSpace;
			// 	const truncate = style.truncate ? style.truncate : Number.MAX_SAFE_INTEGER;

			// 	// How to handle whitespaces
			// 	const collapseSpaces = PIXI.TextMetrics.collapseSpaces(whiteSpace);
			// 	const collapseNewlines = PIXI.TextMetrics.collapseNewlines(whiteSpace);

			// 	// whether or not spaces may be added to the beginning of lines
			// 	var canPrependSpaces = !collapseSpaces;

			// 	// There is letterSpacing after every char except the last one
			// 	// t_h_i_s_' '_i_s_' '_a_n_' '_e_x_a_m_p_l_e_' '_!
			// 	// so for convenience the above needs to be compared to width + 1 extra letterSpace
			// 	// t_h_i_s_' '_i_s_' '_a_n_' '_e_x_a_m_p_l_e_' '_!_
			// 	// ________________________________________________
			// 	// And then the final space is simply no appended to each line
			// 	const wordWrapWidth = style.wordWrapWidth + letterSpacing;

			// 	// break text into words, spaces and newline chars
			// 	const tokens = PIXI.TextMetrics.tokenize(text);

			// 	var i = -1;
			// 	var linesCount = 0;
			// 	var token = '';

			// 	var addLine = function(newLine)
			// 	{
			// 		if (typeof newLine == 'undefined') {
			// 			newLine = true;
			// 		}

			// 		if (linesCount == truncate - 1)
			// 		{
			// 			if (newLine) {
			// 				line += token;

			// 				const threeDotWidth = PIXI.TextMetrics.getFromCache('…', letterSpacing, cache, context);
			// 				var lineWidth = PIXI.TextMetrics.getFromCache(line, letterSpacing, cache, context);

			// 				while (line.length > 1 && (lineWidth + threeDotWidth > wordWrapWidth || PIXI.TextMetrics.isNewline(line[line.length - 1]) || line.endsWith('\\n')))
			// 				{
			// 					line = line.substring(0, line.length - 1);
			// 					lineWidth = PIXI.TextMetrics.getFromCache(line, letterSpacing, cache, context);
			// 				}

			// 				line += '…';
			// 			}

			// 			if (style.truncateCallback) {
			// 				style.truncateCallback(newLine);
			// 			}

			// 			lines += PIXI.TextMetrics.addLine(line, false);

			// 			return true;
			// 		}
			// 		else
			// 		{
			// 			console.log(line);
			// 			console.log(PIXI.TextMetrics.addLine(line, newLine));
			// 			lines += PIXI.TextMetrics.addLine(line, newLine);

			// 			if (newLine)
			// 			{
			// 				linesCount++;
			// 			}

			// 			line = '';
			// 			width = 0;

			// 			return false;
			// 		}
			// 	}

			// 	while (i < tokens.length - 1 && linesCount < truncate)
			// 	{
			// 		i++;

			// 		// get the word, space or newlineChar
			// 		token = tokens[i];

			// 		// if word is a new line
			// 		if (PIXI.TextMetrics.isNewline(token))
			// 		{
			// 			// keep the new line
			// 			if (!collapseNewlines)
			// 			{
			// 				if (addLine(true)) return lines;
			// 				canPrependSpaces = !collapseSpaces;
			// 				continue;
			// 			}

			// 			// if we should collapse new lines
			// 			// we simply convert it into a space
			// 			token = ' ';
			// 		}

			// 		// if we should collapse repeated whitespaces
			// 		if (collapseSpaces)
			// 		{
			// 			// check both this and the last tokens for spaces
			// 			const currIsBreakingSpace = PIXI.TextMetrics.isBreakingSpace(token);
			// 			const lastIsBreakingSpace = PIXI.TextMetrics.isBreakingSpace(line[line.length - 1]);

			// 			if (currIsBreakingSpace && lastIsBreakingSpace)
			// 			{
			// 				continue;
			// 			}
			// 		}

			// 		// get word width from cache if possible
			// 		var tokenWidth = PIXI.TextMetrics.getFromCache(token, letterSpacing, cache, context);

			// 		// word is longer than desired bounds
			// 		if (tokenWidth > wordWrapWidth)
			// 		{
			// 			// if we are not already at the beginning of a line
			// 			if (line !== '')
			// 			{
			// 				// start newlines for overflow words
			// 				if (addLine(true)) return lines;
			// 			}

			// 			// break large word over multiple lines
			// 			if (PIXI.TextMetrics.canBreakWords(token, style.breakWords))
			// 			{
			// 				// break word into characters
			// 				const characters = token.split('');

			// 				// loop the characters
			// 				for (var j = 0; j < characters.length; j++)
			// 				{
			// 					var char = characters[j];

			// 					var k = 1;
			// 					// we are not at the end of the token

			// 					while (characters[j + k])
			// 					{
			// 						const nextChar = characters[j + k];
			// 						const lastChar = char[char.length - 1];

			// 						// should not split chars
			// 						if (!PIXI.TextMetrics.canBreakChars(lastChar, nextChar, token, j, style.breakWords))
			// 						{
			// 							// combine chars & move forward one
			// 							char += nextChar;
			// 						}
			// 						else
			// 						{
			// 							break;
			// 						}

			// 						k++;
			// 					}

			// 					j += char.length - 1;

			// 					const characterWidth = PIXI.TextMetrics.getFromCache(char, letterSpacing, cache, context);

			// 					if (characterWidth + width > wordWrapWidth)
			// 					{
			// 						if (addLine(true)) return lines;
			// 						canPrependSpaces = false;
			// 					}

			// 					line += char;
			// 					width += characterWidth;
			// 				}
			// 			}

			// 			// run word out of the bounds
			// 			else
			// 			{
			// 			   // if there are words in this line already
			// 				// finish that line and start a new one
			// 				if (line.length > 0)
			// 				{
			// 					if (addLine(true)) return lines;
			// 				}

			// 				const isLastToken = i === tokens.length - 1;

			// 				line = token;
			// 				// give it its own line if it's not the end
			// 				if (addLine(!isLastToken)) return lines;
			// 				canPrependSpaces = false;
			// 			}
			// 		}

			// 		// word could fit
			// 		else
			// 		{
			// 			// word won't fit because of existing words
			// 			// start a new line
			// 			if (tokenWidth + width > wordWrapWidth)
			// 			{
			// 				// if its a space we don't want it
			// 				canPrependSpaces = false;

			// 				// add a new line
			// 				if (addLine()) return lines;
			// 			}

			// 			// don't add spaces to the beginning of lines
			// 			if (line.length > 0 || !PIXI.TextMetrics.isBreakingSpace(token) || canPrependSpaces)
			// 			{
			// 				// add the word to the current line
			// 				line += token;

			// 				// update width counter
			// 				width += tokenWidth;
			// 			}
			// 		}
			// 	}

			// 	addLine(false);

			// 	if (style.truncateCallback) {
			// 		style.truncateCallback(false);
			// 	}

			// 	console.log(lines);

			// 	return lines;
			// }

			PIXI.Text.prototype.drawLetterSpacing = function(text, x, y)
			{
				var isStroke = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : false;

				const style = this._style;

				// letterSpacing of 0 means normal
				// Skip directional chars
				const letterSpacing = style.letterSpacing;

				if (letterSpacing === 0)
				{
					if (isStroke)
					{
						this.context.strokeText(text, x, y);
					}
					else
					{
						this.context.fillText(text, x, y);
					}

					return;
				}

				var currentPosition = x;
				var allWidth = this.context.measureText(text).width;
				var char, tailWidth, charWidth;

				do {
					char = text.substr(0, 1);
					text = text.substr(1);

					if (isStroke) {
						this.context.strokeText(char, currentPosition, y);
					} else {
						this.context.fillText(char, currentPosition, y);
					}

					if (text == '')
						tailWidth = 0;
					else
						tailWidth = this.context.measureText(text).width;


					charWidth = allWidth - tailWidth;

					currentPosition += charWidth +
						((char.charCodeAt(0) === 0x202A || char.charCodeAt(0) === 0x202B || char.charCodeAt(0) === 0x202C) ? 0.0 : letterSpacing);
					allWidth = tailWidth;
				} while (text != '');
			}

			PIXI.Text.prototype._renderCanvas = function(renderer)
			{
				const scaleX = this.worldTransform.a;
				const scaleY = this.worldTransform.d;
				const scaleFactor = Math.min(scaleX, scaleY) * renderer.resolution * this.style.resolution;
				const fontSize = scaleFactor * this.style.fontSize;
				const scaleText = fontSize > 0.6 && scaleFactor != 1.0;

				const tempRoundPixels = renderer.roundPixels;
				renderer.roundPixels = renderer.resolution === this.style.resolution;

				if (scaleText) {
					this.worldTransform.a = scaleX / scaleFactor;
					this.worldTransform.d = scaleY / scaleFactor;

					const tempFontSize = this.style.fontSize;
					const tempLetterSpacing = this.style.letterSpacing;
					const tempLineHeight = this.style.lineHeight;
					const tempWordWrapWidth = this.style.wordWrapWidth;
					const tempStrokeThickness = this.style.strokeThickness;
					const tempDropShadowDistance = this.style.dropShadowDistance;
					const tempLeading = this.style.leading;

					this.style.scaleFactor = scaleFactor;
					this.style.fontSize = fontSize;
					this.style.letterSpacing = this.style.letterSpacing * scaleFactor;
					this.style.lineHeight = this.style.lineHeight * scaleFactor;
					this.style.wordWrapWidth = this.style.wordWrapWidth * scaleFactor;
					this.style.strokeThickness = this.style.strokeThickness * scaleFactor;
					this.style.dropShadowDistance = this.style.dropShadowDistance * scaleFactor;
					this.style.leading = this.style.leading * scaleFactor;
					this.style.fontString = this.style.toFontString();

					if (!PIXI.TextMetrics._fonts[this.style.fontString])
					{
						PIXI.TextMetrics._fonts[this.style.fontString] = {
							fontSize : this.style.fontProperties.fontSize * scaleFactor,
							ascent : this.style.fontProperties.ascent * scaleFactor,
							descent : this.style.fontProperties.descent * scaleFactor
						};
					}

					PIXI.Text.prototype.updateText.call(this, true);
					PIXI.Sprite.prototype._renderCanvas.call(this, renderer);

					this.style.fontSize = tempFontSize;
					this.style.letterSpacing = tempLetterSpacing;
					this.style.lineHeight = tempLineHeight;
					this.style.wordWrapWidth = tempWordWrapWidth;
					this.style.strokeThickness = tempStrokeThickness;
					this.style.dropShadowDistance = tempDropShadowDistance;
					this.style.leading = tempLeading;

					this.worldTransform.a = scaleX;
					this.worldTransform.d = scaleY;
				} else {
					PIXI.Text.prototype.updateText.call(this, true);
					PIXI.Sprite.prototype._renderCanvas.call(this, renderer);
				}

				renderer.roundPixels = tempRoundPixels;
			}

			Object.defineProperty(PIXI.DisplayObject.prototype, 'worldVisible', {
				get : function() {
					return this.clipVisible;
				}
			});

			Object.defineProperty(PIXI.DisplayObject.prototype, 'parent', {
				set : function(p) {
					this._parent = p;

					if (p == null) {
						this.worldTransformChanged = false;
					} else if (this.cacheAsBitmap) {
						DisplayObjectHelper.invalidateTransform(this, 'parent');
					}
				},
				get : function() {
					return this._parent;
				}
			});

			if (RenderSupportJSPixi.DomRenderer) {
				Element.prototype.getContext = function(a, b) {
					return { imageSmoothingEnabled : true };
				}
			}

			PIXI.Container.prototype.updateTransform = function() {
				if (this.parent.worldTransformChanged) {
					this.parent.updateTransform();
				} else {
					this.transformChanged = false;

					if (this.worldTransformChanged)
					{
						this.worldTransformChanged = false;
						this._boundsId++;
						this.transform.updateTransform(this.parent.transform);
						this.worldAlpha = this.alpha * this.parent.worldAlpha;

						for (let i = 0, j = this.children.length; i < j; ++i) {
							const child = this.children[i];

							if (child.transformChanged) {
								child.updateTransform();
							}
						}

						this.emit('transformchanged');

						if (!RenderSupportJSPixi.DomRenderer) {
							if (this.accessWidget) {
								this.accessWidget.updateTransform();
							}
						}
					} else for (let i = 0, j = this.children.length; i < j; ++i) {
						const child = this.children[i];

						if (child.transformChanged) {
							child.updateTransform();
						}
					}

					if (RenderSupportJSPixi.DomRenderer && this.localTransformChanged) {
						this.localTransformChanged = false;

						if (this.isNativeWidget && this.parentClip) {
							DisplayObjectHelper.updateNativeWidget(this);
						}
					} else {
						this.localTransformChanged = false;
					}
				}
			};

			TextClip.prototype.updateTransform = function() {
				if (this.parent.worldTransformChanged) {
					this.parent.updateTransform();
				} else {
					this.transformChanged = false;

					if (this.worldTransformChanged)
					{
						this.worldTransformChanged = false;
						this._boundsId++;
						this.transform.updateTransform(this.parent.transform);
						this.worldAlpha = this.alpha * this.parent.worldAlpha;

						this.layoutText();

						for (let i = 0, j = this.children.length; i < j; ++i) {
							const child = this.children[i];

							if (child.transformChanged) {
								child.updateTransform();
							}
						}

						if (!RenderSupportJSPixi.DomRenderer) {
							if (this.accessWidget) {
								this.accessWidget.updateTransform();
							}
						}

						this.emit('transformchanged');
					} else for (let i = 0, j = this.children.length; i < j; ++i) {
						const child = this.children[i];

						if (child.transformChanged) {
							child.updateTransform();
						}
					}

					if (RenderSupportJSPixi.DomRenderer && this.localTransformChanged) {
						this.localTransformChanged = false;

						if (this.isNativeWidget && this.parentClip) {
							DisplayObjectHelper.updateNativeWidget(this);
						}
					} else {
						this.localTransformChanged = false;
					}
				}
			};
		");
	}
}