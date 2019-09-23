DropShadowFilter.sharedCopyFilter = new PIXI.Filter();

function DropShadowFilter(rotation, distance, blur, color, alpha) {
	PIXI.Filter.call(this);

	this.angle = rotation * PIXI.DEG_TO_RAD;
	this.rotation = rotation;
	this.distance = distance;
	this.blur = Math.max(blur, 1.0);
	this.alpha = alpha;
	this.color = color;
	this.padding = this.distance + (this.blur * 2);
	this.shadowOnly = false;
	this.pixelSize = 1;
	this.resolution = 1;
	this.quality = Math.min(Math.max(this.blur / 2.0, 3.0), 20.0);

	if (typeof RenderSupportJSPixi !== 'undefined' && RenderSupportJSPixi.DomRenderer) {
		return;
	}

	this.targetTransform = new PIXI.Matrix();
	this.targetTransform.tx = this.distance * Math.cos(this.angle);
	this.targetTransform.ty = this.distance * Math.sin(this.angle);

	this.tintFilter = new PIXI.Filter(
		['attribute vec2 aVertexPosition;',
		'attribute vec2 aTextureCoord;',
		'uniform mat3 projectionMatrix;',
		'varying vec2 vTextureCoord;',
		'void main(void)',
		'{',
		'	gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);',
		'	vTextureCoord = aTextureCoord;',
		'}'].join("\n"),
		['varying vec2 vTextureCoord;',
		'uniform sampler2D uSampler;',
		'uniform float alpha;',
		'uniform vec3 color;',
		'void main(void){',
		'	vec4 sample = texture2D(uSampler, vTextureCoord);',
		'	if (sample.a > 0.0) {',
		'		sample.rgb /= sample.a;',
		'	}',
		'	sample.rgb = color.rgb * sample.a;',
		'	sample *= alpha;',
		'	gl_FragColor = sample;',
		'}'].join("\n")
	);
	this.tintFilter.uniforms.alpha = this.alpha;
	this.tintFilter.uniforms.color = PIXI.utils.hex2rgb(this.color);
	this.tintFilter.resolution = this.resolution;

	this.blurFilter = new PIXI.filters.BlurFilter(this.blur, this.quality);
}

DropShadowFilter.prototype = Object.create(PIXI.Filter.prototype);
DropShadowFilter.prototype.constructor = DropShadowFilter;
DropShadowFilter.prototype.apply = function (filterManager, input, output, clear) {
	var rt = filterManager.getRenderTarget();

	rt.transform = this.targetTransform;
	this.tintFilter.apply(filterManager, input, rt, true);
	rt.transform = null;

	this.blurFilter.apply(filterManager, rt, output);

	if (this.shadowOnly !== true) {
		filterManager.applyFilter(this, input, output, false);
	}

	filterManager.returnRenderTarget(rt);
};

PIXI.filters.DropShadowFilter = DropShadowFilter;

///////////////////////////////
// Canvas Alpha Mask support //
///////////////////////////////

var AlphaMask_use_getImageData = !PIXI.CanvasTinter.canUseMultiply;

function apply_alpha_mask(main_ctx, mask_ctx, w, h, res)
{
	var img = main_ctx.getImageData(0, 0, w * res, h * res);
	var mask = mask_ctx.getImageData(0, 0, w * res, h * res);

	var imgdata = img.data;
	var maskdata = mask.data;
	var bufsize = imgdata.length|0;

	for (var i = 3; i < bufsize; i += 4)
		imgdata[i] = ((imgdata[i] * maskdata[i])/255)|0;

	main_ctx.putImageData(img, 0, 0);
}

function allocate_render_texture(texture, renderer, w, h)
{
	if (texture == null)
	{
		return PIXI.RenderTexture.create(w|0, h|0, PIXI.settings.SCALE_MODE.DEFAULT, renderer.resolution);
	}

	if (texture.width != w || texture.height != h || texture.resolution != renderer.resolution)
	{
		// resize broken with resolution != 1
		//texture.resize(w|0, h|0, true);

		texture.destroy();
		return PIXI.RenderTexture.create(w|0, h|0, PIXI.settings.SCALE_MODE.DEFAULT, renderer.resolution);
	}
	return texture;
}

PIXI.Container.prototype._alphaMask = null;
PIXI.Container.prototype._canvasFilters = null;

Object.defineProperties(PIXI.Container.prototype, {
	alphaMask: {
		get: function ()
		{
			return this._alphaMask;
		},
		set: function (value)
		{
			if (this._alphaMask === value)
			{
				return;
			}

			if (this._alphaMask)
			{
				this._alphaMask.renderable = true;
			}

			this._alphaMask = value;

			if (value)
			{
				this._alphaMask.renderable = false;
			}

			this._updateFilterHooks();
		},
	configurable: true
	},
	canvasFilters: {
		get: function ()
		{
			return this._canvasFilters && this._canvasFilters.slice();
		},
		set: function (value)
		{
			this._canvasFilters = value && value.slice();
			this._updateFilterHooks();
		},
	configurable: true
	}
});

PIXI.Container.prototype._updateFilterHooks = function ()
{
	if (this._alphaMask || (this._canvasFilters && this._canvasFilters.length > 0))
	{
		if (this._CF_originalCalculateBounds == null)
		{
			this._CF_originalRenderCanvas = this.renderCanvas;
			this._CF_originalCalculateBounds = this.calculateBounds;
			this.renderCanvas = this._renderFilterCanvas;
			this.calculateBounds = this._calculateFilterBounds;
		}
	}
	else if (this._CF_originalCalculateBounds != null)
	{
		this.renderCanvas = this._CF_originalRenderCanvas;
		this.calculateBounds = this._CF_originalCalculateBounds;
		this._CF_originalCalculateBounds = null;
	}
}

PIXI.Filter.prototype.expandCanvasBounds = function (bounds)
{
	// nop
}

PIXI.Filter.prototype.drawToCanvas = function (input_tex, aux_tex, out_ctx, x, y)
{
	return input_tex;
}


PIXI.filters.DropShadowFilter.prototype.expandCanvasBounds = function (bounds)
{
	bounds.minX -= this.padding;
	bounds.minY -= this.padding;
	bounds.maxX += this.padding;
	bounds.maxY += this.padding;
}

function create_canvas_render_target(texture)
{
	var renderTexture = texture.baseTexture;
	renderTexture._canvasRenderTarget = new PIXI.CanvasRenderTarget(renderTexture.width, renderTexture.height, renderTexture.resolution);
	renderTexture.source = renderTexture._canvasRenderTarget.canvas;
	renderTexture.valid = true;
}

PIXI.filters.DropShadowFilter.prototype.drawToCanvas = function (input_tex, aux_tex, out_ctx, x, y)
{
	var outtex = null;

	if (out_ctx == null) {
		outtex = aux_tex;
		if (!aux_tex.baseTexture._canvasRenderTarget) {
			create_canvas_render_target(aux_tex);
		}

		out_ctx = aux_tex.baseTexture._canvasRenderTarget.context;

		outtex.baseTexture._canvasRenderTarget.clear();
	}

	var dist = this.distance;
	var angle = this.angle;
	var color = PIXI.utils.hex2rgb(this.color);
	var res = input_tex.baseTexture.resolution;

	out_ctx.save();
	out_ctx.shadowColor = "rgba("+color[0]*255+","+color[1]*255+","+color[2]*255+","+this.alpha+")";
	out_ctx.shadowBlur = this.blur * 2 * res;
	out_ctx.shadowOffsetX = Math.cos(angle) * dist * res;
	out_ctx.shadowOffsetY = Math.sin(angle) * dist * res;

	out_ctx.setTransform(1, 0, 0, 1, 0, 0);
	out_ctx.drawImage(input_tex.baseTexture._canvasRenderTarget.canvas, x * res, y * res);
	out_ctx.restore();

	return outtex;
}

PIXI.filters.BlurFilter.prototype.expandCanvasBounds = function (bounds)
{
	bounds.minX -= this.padding;
	bounds.minY -= this.padding;
	bounds.maxX += this.padding;
	bounds.maxY += this.padding;
}

PIXI.filters.BlurFilter.prototype.drawToCanvas = function (input_tex, aux_tex, out_ctx, x, y)
{
	var res = input_tex.baseTexture.resolution;

	StackBlur.canvasRGBA(
		input_tex.baseTexture._canvasRenderTarget.canvas,
		0, 0, input_tex.width * res, input_tex.height * res,
		this.padding * res
	);

	return input_tex;
}

PIXI.Container.prototype._calculateFilterBounds = function ()
{
	this._CF_originalCalculateBounds();

	var bounds = this._bounds;
	var filters = this._canvasFilters;

	if (filters != null) {
		for (var i = 0; i < filters.length; i++) {
			filters[i].expandCanvasBounds(bounds);
		}
	}
}

PIXI.Container.prototype.isGraphics = function () {
	return this.parent != null && this._alphaMask == null && this.filters != null && this.filters.length == 1 &&
		this.filters[0] instanceof PIXI.filters.DropShadowFilter &&
		(this.parent.filters == null || this.parent.filters.length == 0) &&
		(
			(this.graphicsData != null && (this.children == null || this.children.length == 0)) ||
			(this.children != null && this.children.length == 1 && this.children[0].filters == null &&
				(this.children[0].graphicsData != null ||
					(this.children[0].children != null && this.children[0].children.length > 0 &&
						this.children[0].children[0].graphicsData != null && this.children[0].children[0].filters == null
					)
				)
			)
		)
}

PIXI.Container.prototype._renderFilterCanvas = function (renderer)
{
	if (!this.visible || this.alpha <= 0 || !this.renderable)
	{
		return;
	}

	var filters = this._canvasFilters;

	if ((filters == null || filters.length == 0) && this._alphaMask == null)
	{
		return this._CF_originalRenderCanvas(renderer);
	}

	if (this.glShaders) {
		const bounds = this.getBounds(true);
		const resolution = renderer.resolution;

		const x = bounds.x - this.filterPadding;
		const y = bounds.y - this.filterPadding;

		const wd = bounds.width + this.filterPadding * 2.0;
		const hgt = bounds.height + this.filterPadding * 2.0;

		if (renderer.width != renderer.gl.width || renderer.height != renderer.gl.height) {
			renderer.gl.resize(renderer.width, renderer.height);
		}

		if (resolution != renderer.gl.resolution) {
			renderer.gl.resolution = resolution;
		}

		renderer.gl.render(this, null, true, null, true);

		const ctx = renderer.context;

		ctx.globalAlpha = this.worldAlpha;
		ctx.setTransform(1, 0, 0, 1, 0, 0);
		ctx.drawImage(renderer.gl.view, x, y, wd, hgt, x * resolution, y * resolution, wd * resolution, hgt * resolution);

		return;
	}

	if (this.isGraphics()) {
		// Special fast case
		// Shadow around graphics
		var filter = filters[0];
		var dist = filter.distance;
		var angle = filter.angle;
		var color = PIXI.utils.hex2rgb(filter.color);
		var res = renderer.resolution;
		var ctx = renderer.context;

		ctx.save();
		ctx.shadowColor = "rgba("+color[0]*255+","+color[1]*255+","+color[2]*255+","+filter.alpha+")";
		ctx.shadowBlur = filter.blur * 2 * res;
		ctx.shadowOffsetX = Math.cos(angle) * dist * res;
		ctx.shadowOffsetY = Math.sin(angle) * dist * res;
		this._CF_originalRenderCanvas(renderer);
		ctx.restore();

		return;
	}

	var bounds = this.getLocalBounds();
	var wt = this.worldTransform.clone();

	var x = Math.floor(bounds.x);
	var y = Math.floor(bounds.y);
	var w = Math.ceil(bounds.width);
	var h = Math.ceil(bounds.height);

	// evaluate filters
	var ctx = renderer.context;
	var res = renderer.resolution;

	if (this.rvlast != null)
	{
		ctx.globalAlpha = this.worldAlpha;
		ctx.setTransform(wt.a, wt.b, wt.c, wt.d, wt.tx * res, wt.ty * res);
		ctx.drawImage(this.rvlast.baseTexture._canvasRenderTarget.canvas, x * res, y * res);
		return;
	}

	// Expand area to increments of 32 to minimize reallocations
	w = (w+31) & ~31;
	h = (h+31) & ~31;

	if (w < 1 || h < 1)
		return;

	var cachedRenderTarget = renderer.context;

	this._filterMatrix = this.localTransform.clone();
	this._filterTexMain = allocate_render_texture(this._filterTexMain, renderer, w, h);
	this._filterTexAux = allocate_render_texture(this._filterTexAux, renderer, w, h);

	// render
	var originalRenderCanvas = this.renderCanvas;
	this.renderCanvas = this._CF_originalRenderCanvas;

	if (!this._filterTexMain.baseTexture._canvasRenderTarget) {
		create_canvas_render_target(this._filterTexMain);
	}
	this._filterTexMain.baseTexture._canvasRenderTarget.clear();

	DisplayObjectHelper.invalidateTransform(this);

	renderer.render(this, this._filterTexMain, true, null, false);

	this.renderCanvas = originalRenderCanvas;

	// mask
	if (this._alphaMask != null)
	{
		var main_ctx = this._filterTexMain.baseTexture._canvasRenderTarget.context;

		if (!this._filterTexAux.baseTexture._canvasRenderTarget) {
			create_canvas_render_target(this._filterTexAux);
		}

		this._filterTexAux.baseTexture._canvasRenderTarget.clear();

		this._alphaMask.renderable = true;

		DisplayObjectHelper.invalidateTransform(this._alphaMask);

		renderer.render(this._alphaMask, this._filterTexAux, true, null, false);
		this._alphaMask.renderable = false;

		var mask_ctx = this._filterTexAux.baseTexture._canvasRenderTarget.context;

		if (AlphaMask_use_getImageData)
		{
			apply_alpha_mask(main_ctx, mask_ctx, w, h, res);
		}
		else
		{
			main_ctx.globalCompositeOperation = 'destination-in';
			main_ctx.setTransform(1, 0, 0, 1, 0, 0);
			main_ctx.drawImage(this._filterTexAux.baseTexture._canvasRenderTarget.canvas, x * res, y * res);
			main_ctx.globalCompositeOperation = 'source-over';
		}

		DisplayObjectHelper.invalidateTransform(this._alphaMask);
		this._alphaMask.updateTransform();
	}

	// restore context
	renderer.context = cachedRenderTarget;

	ctx.globalAlpha = this.worldAlpha;

	var curtex = this._filterTexMain;
	var auxtex = this._filterTexAux;
	this.rvlast = curtex;

	if (filters != null && filters.length > 0)
	{
		for (var i = 0; i < filters.length-1; i++)
		{
			var rv = filters[i].drawToCanvas(curtex, auxtex, null, -x / filters.length, -y / filters.length);

			if (rv == auxtex)
			{
				var tmp = auxtex;
				auxtex = curtex;
				curtex = tmp;
			}
		}

		// evaluate last filter and render
		this.rvlast = filters[filters.length-1].drawToCanvas(curtex, auxtex, null, -x / filters.length, -y / filters.length);
	}

	if (this.rvlast != null)
	{
		ctx.setTransform(wt.a, wt.b, wt.c, wt.d, wt.tx * res, wt.ty * res);
		ctx.drawImage(this.rvlast.baseTexture._canvasRenderTarget.canvas, x * res, y * res);
	}

	DisplayObjectHelper.invalidateTransform(this);
	this.updateTransform();
}