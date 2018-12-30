// INCREMENT THE VERSION WHEN MAKE ANY CHANGES HERE
// Requres the version to be incremented in RenderSupportJSPixi.hx class FontLoader : DFontVersionExpected
var DFONT_VERSION = 4;

function init_dfont_data(fontname, metrics) {
	// Register the newly loaded font
	DFontText.dfont_table[fontname] = metrics;

	if (DFontText.default_font == null)
		DFontText.default_font = metrics;

	// Index characters
	var grid_char_cnt = metrics.grid_size * metrics.grid_size;

	metrics.chars = {};

	metrics.tex_step = metrics.tile_size / metrics.grid_px_size;
	metrics.tex_active = (metrics.tile_size-2) / metrics.grid_px_size;
	metrics.tex_base = 1 / metrics.grid_px_size;

	if (metrics.glyphdata) {
		var glyphs = metrics.glyphs = []
		var coeff1 = 1.0 / metrics.em_size_factor;
		var coeff2 = -1.0 / metrics.render_em_size;

		for (var i = 0; i < metrics.glyphdata.length; i++) {
			var item = metrics.glyphdata[i];
			glyphs[i] = {
				uchar: item[0],
				// original font metrics
				bearing_x: item[1] * coeff1, bearing_y: item[2] * coeff1,
				size_x: item[3] * coeff1, size_y: item[4] * coeff1,
				advance: item[5] * coeff1,
				// character offset within our grid cell
				field_bearing_x: item[6] * coeff2, field_bearing_y: item[7] * coeff2
			};
		}
	}

	for (var i = 0; i < metrics.glyphs.length; i++) {
		var glyph = metrics.glyphs[i];
		glyph.index = i;
		glyph.grid_idx = (i / grid_char_cnt|0);
		var grid_char = i % grid_char_cnt;
		glyph.grid_y = (grid_char / metrics.grid_size|0);
		glyph.grid_x = grid_char % metrics.grid_size;
		metrics.chars[glyph.uchar] = glyph;
	}

	metrics.default_glyph = metrics.glyphs[0];
	if ('\ufffd' in metrics.chars) // unicode fallback
		metrics.default_glyph = metrics.chars['\ufffd'];
	else if (' ' in metrics.chars)
		metrics.default_glyph = metrics.chars[' '];
}

// Returns [glyph, found in fallback font]
function find_dfont_glyph(metrics, chr) {
	if (chr in metrics.chars) {
		return [metrics.chars[chr], false];
	} else if (DFontText.fallback_font && chr in DFontText.fallback_font.chars) {
		return [DFontText.fallback_font.chars[chr], true];
	} else {
		return [metrics.default_glyph, false];
	}
}

function draw_dfont_glyph(metrics, chr, pen, size, vertexElements, canvasElements, rect, letterspacing) {
	if (chr == '\n') {
		pen.max_x = Math.max(pen.max_x, pen.x);
		pen.x = pen.x_start;
		pen.y += metrics.line_height * size;
		pen.num_lines++;
		return;
	}

	var glyphPair = find_dfont_glyph(metrics, chr);

	var glyph = glyphPair[0];
	var foundInFallback = glyphPair[1];
	var gridoffset = 0;

	if (foundInFallback) {
		gridoffset = metrics.grid_count;
		metrics = DFontText.fallback_font;
	}

	var penx = pen.x;
	pen.x = pen.x + glyph.advance * size + letterspacing;

	// pixel coords
	var baseline = metrics.ascender * size;
	var x1 = penx + glyph.field_bearing_x * size;
	var y1 = pen.y + glyph.field_bearing_y * size + baseline;
	var sz = metrics.active_tile_size * size;
	var x2 = x1 + sz;
	var y2 = y1 + sz;

	if (glyph.uchar != ' ' && glyph.uchar != '\u3000' && chr != '\t') {
		// uv coords
		var tx1 = metrics.tex_base + metrics.tex_step * glyph.grid_x;
		var ty1 = metrics.tex_base + metrics.tex_step * glyph.grid_y;
		var tx2 = tx1 + metrics.tex_active;
		var ty2 = ty1 + metrics.tex_active;

		// store coords interleaved in the per-texture array
		var grid = glyph.grid_idx + gridoffset;

		if (!vertexElements[grid])
			vertexElements[grid] = [];

		vertexElements[grid].push(
			x1, y1, tx1, ty1, x2, y1, tx2, ty1, x1, y2, tx1, ty2,
			x1, y2, tx1, ty2, x2, y1, tx2, ty1, x2, y2, tx2, ty2
		);

		// parameters for the CanvasRenderingContext2D.drawImage() method when drawing the glyph
		canvasElements.push({
			page  : grid,
			sx    : 1 + metrics.tile_size * glyph.grid_x,
			sy    : 1 + metrics.tile_size * glyph.grid_y,
			sSize : metrics.tile_size - 2,
			dx    : x1,
			dy    : y1,
			dSize : sz
		});
	}

	// also compute the bounding box
	if (x1 < rect.x) rect.x = x1;
	if (y1 < rect.y) rect.y = y1;
	if (x2 > rect.width) rect.width = x2;
	if (y2 > rect.height) rect.height = y2;

	return foundInFallback;
}

function compute_rotated_bbox(matrix, verts, round_to_ints)
{
	// Compute true bounding box by enumerating vertex data
	var a = matrix.a;
	var b = matrix.b;
	var c = matrix.c;
	var d = matrix.d;
	var tx = matrix.tx;
	var ty = matrix.ty;

	var xmin = a*verts[0] + c*verts[1] + tx;
	var xmax = xmin;
	var ymin = b*verts[0] + d*verts[1] + ty;
	var ymax = ymin;

	for (var i = 2; i < verts.length; i+=2)
	{
		var x = verts[i], y = verts[i+1];
		var x1 = a*x + c*y + tx;
		if (x1 < xmin) xmin = x1;
		if (x1 > xmax) xmax = x1;
		var y1 = b*x + d*y + ty;
		if (y1 < ymin) ymin = y1;
		if (y1 > ymax) ymax = y1;
	}

	if (round_to_ints)
	{
		xmin = Math.floor(xmin);
		ymin = Math.floor(ymin);
		xmax = Math.ceil(xmax);
		ymax = Math.ceil(ymax);
	}

	return new PIXI.Rectangle(xmin, ymin, xmax-xmin, ymax-ymin);
}

function compute_rotated_rect(matrix, rect, round_to_ints)
{
	var x1 = rect.x;
	var y1 = rect.y;
	var w = rect.width;
	var h = rect.height;
	var verts = [x1, y1, x1, y1+h, x1+w, y1, x1+w, y1+h];

	return compute_rotated_bbox(matrix, verts, round_to_ints);
}

function measure_dfont_text(metrics, text, size) {
	var dimensions = {
		advance: 0
	}

	var scale = size;
	for (var i = 0; i < text.length; i++) {
		var horiAdvance = find_dfont_glyph(metrics, text[i]).advance;
		dimensions.advance += horiAdvance * scale;
	}

	return dimensions;
}

function dfont_flush_elements(vertdata,offsets,sizes,elements) {
	var start = vertdata.length;

	if (elements)
		vertdata = vertdata.concat(elements);

	offsets.push(start);
	sizes.push(vertdata.length - start);

	return vertdata;
}

function create_dfont_text(metrics, str, size, letterspacing, x0, y0) {
	// Gather vertices
	var vertexElements = {};
	var canvasElements = [];
	x0 = x0||0;
	// A hack for OpenType fonts, otherwise the glyphs are top-aligned
	// For TrueType fonts, this offset is zero (or very close to zero)
	y0 = y0||0 + ((metrics.line_height - (metrics.ascender - metrics.descender))) * size;
	var pen = { x: x0, y: y0, max_x: x0, x_start: x0, num_lines:1 };

	var rect = new PIXI.Rectangle(pen.x, pen.y, pen.x, pen.y);

	var has_fallback = false;

	for (var i = 0; i < str.length; i++) {
		var chr = str[i];

		var fb = draw_dfont_glyph(metrics, chr, pen, size, vertexElements, canvasElements, rect, letterspacing);
		has_fallback = has_fallback || fb;
	}

	rect.width -= rect.x;
	rect.height -= rect.y;

	// Merge per-texture stretches into one array
	var vertdata = [];
	var offsets = [];
	var sizes = [];
	var textures = metrics.textures;

	for (var i = 0; i < metrics.grid_count; i++) {
		vertdata = dfont_flush_elements(vertdata, offsets, sizes, vertexElements[i]);
	}

	var fallback_font = DFontText.fallback_font;
	if (has_fallback) {
		// Append fallback font textures after our own
		textures = textures.concat(fallback_font.textures);

		for (var i = 0; i < fallback_font.grid_count; i++) {
			vertdata = dfont_flush_elements(vertdata, offsets, sizes, vertexElements[i + metrics.grid_count]);
		}
	}

	// Fuzz radius coefficient at 1:1 scale
	var fct = 1.0 / size * metrics.render_em_size;
	var radius = 0.8 * fct * metrics.dist_scale;

	return {
		array: new Float32Array(vertdata),
		offsets: offsets,
		sizes: sizes,
		textures: textures,
		dcoeff: radius,
		canvas_items: canvasElements,
		tile_size_dest: metrics.active_tile_size * size,
		bounding_rect: rect,
		dimensions: {
			baseline: pen.y,
			width: Math.max(pen.max_x, pen.x) - x0,
			height: (metrics.ascender-metrics.descender) * size,
			line_height: metrics.line_height * size, // includes inter-line space if any
			line_count: pen.num_lines
		}
	};
}

function dfont_loader_fn()
{
	return function (resource, next)
	{
		// skip if no data, its not json, or it isn't dfont data
		if (!resource.data || resource.type !== PIXI.loaders.Resource.TYPE.JSON ||
			!resource.data.dist_scale || (!resource.data.glyphs && !resource.data.glyphdata))
		{
			return next();
		}

		var metrics = resource.data;
		metrics.basepath = resource.url.substr(0, resource.url.lastIndexOf("/")) + "/";
		metrics.crossOrigin = resource.crossOrigin;
		metrics.textures = [];

		init_dfont_data(resource.name, resource.data);
		if (resource.name == "DejaVuSans")
			DFontText.fallback_font = metrics;

		next();
	};
}

PIXI.loaders.Loader.addPixiMiddleware(dfont_loader_fn);
//PIXI.loader.use(dfont_loader_fn());


function DFontShader(renderer)
{
	var vertexSrc = DFontShader.defaultVertexSrc;
	var fragmentSrc = DFontShader.defaultFragmentSrc;

	PIXI.Shader.call(this, renderer.gl, vertexSrc, fragmentSrc);
}

DFontShader.prototype = Object.create(PIXI.Shader.prototype);
DFontShader.prototype.constructor = DFontShader;

DFontShader.prototype.setMatrix = function (matrix, tmatrix, data)
{
	this.uniforms.projectionMatrix = matrix.toArray(true);

	// Compute the effective scaling of the matrix and apply inverse to the fuzz radius
	var r05 = Math.max(0.0, Math.min(0.5, 0.5 * (data.dcoeff / getMatrixScale(tmatrix))));

	var vals = this.uniforms.uFontDistAlpha;
	vals[0] = 0.5 - r05;
	vals[1] = 0.5 / r05;
	this.uniforms.uFontDistAlpha = vals;
}

DFontShader.prototype.setColor = function (color, alpha)
{
	this.uniforms.uFontColor = PIXI.utils.hex2rgb(color);

	var font_dist_alpha = this.uniforms.uFontDistAlpha;
	font_dist_alpha[2] = alpha;
	this.uniforms.uFontDistAlpha = font_dist_alpha;
}

DFontShader.defaultVertexSrc = [
	'precision mediump float;',

	'attribute vec2 aVertexPosition;',
	'attribute vec2 aTextureCoord;',

	'uniform mat3 projectionMatrix;',
	'varying vec2 vTextureCoord;',

	'void main(void){',
	' gl_Position = vec4((projectionMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);',
	' vTextureCoord = aTextureCoord;',
	'}'
].join('\n');

DFontShader.defaultFragmentSrc = [
	'precision mediump float;',

	'varying vec2 vTextureCoord;',
	'uniform sampler2D uSampler;',

	'uniform vec3 uFontDistAlpha;', // [ dist_min, dist_coeff, alpha ]
	'uniform vec3 uFontColor;',

	'void main() {',
	'  float dist = texture2D(uSampler, vTextureCoord).r - uFontDistAlpha.x;',
	'  float t = clamp(dist * uFontDistAlpha.y, 0.0, 1.0);',
	'  float alpha = t * uFontDistAlpha.z;',
	'  gl_FragColor = vec4(uFontColor, 1.0) * alpha;',
	'}'
].join('\n');


function DFontRenderer(renderer)
{
	PIXI.ObjectRenderer.call(this, renderer);

	this.matrix = new PIXI.Matrix();
	this.shader = null;
}

DFontRenderer.prototype = Object.create(PIXI.ObjectRenderer.prototype);
DFontRenderer.prototype.constructor = DFontRenderer;

PIXI.WebGLRenderer.registerPlugin('dfont', DFontRenderer);

DFontRenderer.prototype.onContextChange = function ()
{
	var gl = this.renderer.gl;

	this.shader = new DFontShader(this.renderer);

	this.vertexBuffer = gl.createBuffer();
};

DFontRenderer.prototype.destroy = function ()
{
	this.renderer.gl.deleteBuffer(this.vertexBuffer);
	this.shader.destroy();
	this.renderer = null;
	this.vertexBuffer = null;
	this.shader = null;
};

DFontRenderer.prototype.start = function ()
{
	var gl = this.renderer.gl;

	this.renderer.bindVao(null); // Reset to not overwrite data
	this.renderer.bindShader(this.shader);
	this.renderer.setBlendMode(PIXI.BLEND_MODES.NORMAL);

	gl.bindBuffer(gl.ARRAY_BUFFER, this.vertexBuffer);

	var stride = 4 * 4;
	gl.vertexAttribPointer(this.shader.attributes.aVertexPosition.location, 2, gl.FLOAT, false, stride, 0);
	gl.enableVertexAttribArray(this.shader.attributes.aVertexPosition.location);
	gl.vertexAttribPointer(this.shader.attributes.aTextureCoord.location, 2, gl.FLOAT, false, stride, 2 * 4);
	gl.enableVertexAttribArray(this.shader.attributes.aTextureCoord.location);
};

/*DFontRenderer.prototype.stop = function ()
{
	this.flush();
};

DFontRenderer.prototype.flush = function ()
{
// flush!
};*/

DFontRenderer.prototype.render = function (object) // jshint unused:false
{
	var gl = this.renderer.gl;
	var data = object.render_data;
	var shader = this.shader;

	var mat = this.matrix;
	var m1 = this.renderer._activeRenderTarget.projectionMatrix;
	var m2 = object.worldTransform;
	m1.copy(mat);
	mat.append(m2);

	shader.setMatrix(mat, m2, data);
	shader.setColor(object._font.tint||0xFFFFFF, object.worldAlpha);
	//shader.syncUniforms();

	gl.activeTexture(gl.TEXTURE0);
	gl.bufferData(gl.ARRAY_BUFFER, data.array, gl.DYNAMIC_DRAW);

	for (var i = 0; i < data.sizes.length; i++)
	{
		if (data.sizes[i] > 0 && data.textures[i] /* It may be not ready yet */)
		{
			var texture = data.textures[i].baseTexture;

			if (!texture._glTextures[this.renderer.CONTEXT_UID])
			{
				this.renderer.textureManager.updateTexture(texture);
			}
			else
			{
				gl.bindTexture(gl.TEXTURE_2D, texture._glTextures[this.renderer.CONTEXT_UID].texture);
			}

			gl.drawArrays(gl.TRIANGLES, data.offsets[i]>>2, data.sizes[i]>>2);
		}
	}
};


function DFontText(text, style) {
	PIXI.DisplayObject.call(this);

	style = style || {};

	this._font = {
		tint: style.tint !== undefined ? style.tint : 0xFFFFFF,
		name: null,
		letterspacing: style.letterSpacing !== undefined ? style.letterSpacing : 0xFFFFFF,
		size: 12
	};

	this.font = style.font; // run font setter

	this._text = text;
	if (style.size)
		this._font.size = style.size;

	this.render_data = null;

	this.render_cached = false;
	this.local_bounds = new PIXI.Rectangle();
}

DFontText.prototype = Object.create(PIXI.DisplayObject.prototype);
DFontText.prototype.constructor = DFontText;

DFontText.prototype.interactiveChildren = false; // no children at all!

DFontText.prototype.cache_canvas = null;
DFontText.prototype.cache_context = null;

DFontText.default_font = null
DFontText.fallback_font = null
DFontText.dfont_table = {}

DFontText.temp_canvas = null;
DFontText.temp_context = null;

DFontText.initDFontData = init_dfont_data;

DFontText.getNumPages = function(fontfamily) {
	var metrics = DFontText.dfont_table[fontfamily];
	if (!metrics)
		return 0;
	return metrics.grid_count;
}

DFontText.loadTextures = function(fontfamily, metrics, callback) {
	var loadOptions = {
		crossOrigin: metrics.crossOrigin,
		loadType: PIXI.loaders.Resource.LOAD_TYPE.IMAGE
	};

	metrics.textures = [];

	for (var i = 0; i < metrics.grid_count; i++) {
		var name = (i <= 9 ? "0"+i : ""+i) + ".png";
		var onload = (function(idx) {
			return function(res) {
				metrics.textures[idx] = res.texture;
				callback();
			};
		}.bind(this, i))();

		PIXI.loader.add(fontfamily + '_img'+i, metrics.basepath + name, loadOptions, onload);
	}
	PIXI.loader.load();
}

DFontText.addTexture2Loader = function(fontfamily, metrics, page, callback, loader) {
	var loadOptions = {
		crossOrigin: metrics.crossOrigin,
		loadType: PIXI.loaders.Resource.LOAD_TYPE.IMAGE
	};

	if (!metrics.textures)
		metrics.textures = [];

	var name = (page <= 9 ? "0"+page : ""+page) + ".png";
	var onload = (function(idx) {
		return function(res) {
			metrics.textures[page] = res.texture;
			callback();
		};
	}.bind(this, page))();

	loader.add(fontfamily + '_img'+page, metrics.basepath + name, loadOptions, onload);
}

DFontText.loadTexture = function(fontfamily, metrics, page, callback) {
	DFontText.addTexture2Loader(fontfamily, metrics, page, callback, PIXI.loader);
	PIXI.loader.load();
}

Object.defineProperties(DFontText.prototype, {
	tint: {
		get: function ()
		{
			return this._font.tint;
		},
		set: function (value)
		{
			this._font.tint = (typeof value === 'number' && value >= 0) ? value : 0xFFFFFF;
		}
	},
	font: {
		get: function ()
		{
			return this._font;
		},
		set: function (value)
		{
			if (!value) {
				return;
			}
			if (typeof value === 'string') {
				value = value.split(' ');
				this._font.name = value.length === 1 ? value[0] : value.slice(1).join(' ');
				this._font.size = value.length >= 2 ? parseInt(value[0], 10) : 0;
			}
			else {
				this._font.name = value.name;
				this._font.size = typeof value.size === 'number' ? value.size : parseInt(value.size, 10);
			}
			if (!(this._font.size > 0)) // also catches NaN
				this._font.size = 12;
			this.invalidate();
		}
	},
	letterSpacing: {
		get: function ()
		{
			return this._font.letterspacing;
		},
		set: function (value)
		{
			value = (typeof value === 'numbe' && value >= 0) ? value : 0;
			if (this._font.letterspacing === value)
				return;
			this._font.letterspacing = value;
			this.invalidate();
		}
	},
	size: {
		get: function ()
		{
			return this._font.size;
		},
		set: function (value)
		{
			value = (typeof value === 'number' && value >= 0) ? value : 12;
			if (this._font.size === value)
				return;
			this._font.size = value;
			this.invalidate();
		}
	},
	text: {
		get: function ()
		{
			return this._text;
		},
		set: function (value)
		{
			value = value.toString() || ' ';
			if (this._text === value)
				return;
			this._text = value;
			this.invalidate();
		}
	}
});

DFontText.prototype.invalidate = function ()
{
	this.render_data = null;
	this._currentBounds = null;
	this._boundsID++;
}

DFontText.prototype.layout = function ()
{
	if (this.render_data == null)
		this.doLayoutText();
}

DFontText.prototype.doLayoutText = function ()
{
	var metrics = DFontText.dfont_table[this._font.name] || DFontText.default_font;

	// TODO: implement text alignment etc
	this.render_data = create_dfont_text(metrics, this._text, this._font.size, this._font.letterspacing);

	this.render_cached = false;
	this.local_bounds = this.render_data.bounding_rect;
	this._boundsID++;
}

DFontText.prototype.renderWebGL = function (renderer) {
	this.layout();

	renderer.setObjectRenderer(renderer.plugins.dfont);
	renderer.plugins.dfont.render(this);
}

DFontText.prototype.getLocalBounds = function (rect)
{
	this.layout();

	if (!rect)
	{
		if (!this._localBoundsRect)
		{
			this._localBoundsRect = new PIXI.Rectangle();
		}

		rect = this._localBoundsRect;
	}

	rect.copy(this.local_bounds)

	return rect;
};

DFontText.prototype.calculateBounds = function ()
{
	this._bounds.clear();

	this.layout();

	var wt = this.worldTransform.clone().prepend(new PIXI.Matrix().scale(this.resolution, this.resolution));
	var rrect = compute_rotated_rect(wt, this.local_bounds, true);

	this._bounds.addQuad([
		rrect.x, rrect.y,
		rrect.x + rrect.width, rrect.y,
		rrect.x, rrect.y + rrect.height,
		rrect.x + rrect.width, rrect.y + rrect.height
	]);

	this._lastBoundsID = this._boundsID;
};

DFontText.prototype.updateTransform = function ()
{
	this.displayObjectUpdateTransform();

	this._boundsID++;
}

DFontText.prototype.getTextDimensions = function ()
{
	this.layout();
	return this.render_data.dimensions;
}

function clamp(x, xmin, xmax) {
	if (x < xmin) return xmin;
	if (x > xmax) return xmax;
	return x;
}

function apply_dfont_shading(imgbytes, tint, r05) {
	tint = tint|0;
	r05 = +r05;

	var bufsize = imgbytes.length|0;

	var tintb = (tint & 0xff)|0;
	var tintg = ((tint>>8) & 0xff)|0;
	var tintr = ((tint>>16) & 0xff)|0;

	var dbase = (255.0 * (0.5 - r05))|0;
	var dmul = +((0.5 / 255.0) / r05);

	for (var i = 0; i < bufsize; i += 4) {
		var cv = imgbytes[i]|0;

		//float dist = texture2D(uSampler, vTextureCoord).r - uFontDistAlpha.x;',
		var dist = (cv-dbase)|0;

		//float t = clamp(dist * uFontDistAlpha.y, 0.0, 1.0);',
		var t = clamp(+(dist*dmul), 0.0, 1.0);

		//float alpha = t * t * (3.0 - 2.0*t) * uFontDistAlpha.z;
		// var tv = t * t * (3.0 - 2.0 * t);
		var tv = t;

		imgbytes[i] = tintr;
		imgbytes[i+1] = tintg;
		imgbytes[i+2] = tintb;
		imgbytes[i+3] = (tv * 255.0)|0;
	}
}

DFontText.prototype.dfontsLoaded = function()
{
	var metrics = DFontText.dfont_table[this._font.name];

	if (typeof metrics === 'undefined')
		return false;

	for (var i = 0; i < metrics.grid_count; i++)
		if (typeof metrics.textures[i] === 'undefined')
			return false;

	return true;
}

DFontText.prototype.renderCanvas = function (renderer)
{
	var cacheEnabled = this.dfontsLoaded();
	if (!cacheEnabled)
		this.render_cached = false;

	this.layout();

	if (this.render_data.canvas_items.length == 0)
		return;

	this.resolution = renderer.resolution;
	var wt = this.worldTransform.clone().prepend(new PIXI.Matrix().scale(renderer.resolution, renderer.resolution));
	if (isNaN(wt.a)) {
		// WT is not ready somehow. 
		return;
	}
	var bbox = this.getBounds(true);

	if (this.render_cached)
	{
		var ct = this.cache_matrix;
		var same_rot = (ct.a == wt.a && ct.b == wt.b && ct.c == wt.c && ct.d == wt.d);

		if (same_rot)
		{
			renderer.context.setTransform(1, 0, 0, 1, 0, 0);
			renderer.context.globalAlpha = this.worldAlpha;
			renderer.context.drawImage(this.cache_canvas, bbox.x, bbox.y);
			return;
		}

		this.render_cached = false;
	}

	var tmp_cnv = this.cache_canvas;
	var tmp_ctx = this.cache_context;

	if (tmp_cnv == null)
	{
		this.cache_matrix = new PIXI.Matrix();
		this.cache_canvas = tmp_cnv = document.createElement('canvas');
		this.cache_context = tmp_ctx = tmp_cnv.getContext('2d');

		tmp_ctx.fillStyle = 'black';
	}

	var full_w = bbox.width;
	var full_h = bbox.height;

	if (full_w < 1 || full_h < 1)
		return;

	if (full_w != tmp_cnv.width || full_h != tmp_cnv.height)
	{
		tmp_cnv.width = full_w;
		tmp_cnv.height = full_h;
	}

	this.renderCanvasChars(renderer, wt, bbox, tmp_cnv, tmp_ctx, full_w, full_h);

	wt.copy(this.cache_matrix);
	if (cacheEnabled)
		this.render_cached = true;

	// Draw the image
	renderer.context.setTransform(1, 0, 0, 1, 0, 0);
	renderer.context.globalAlpha = this.worldAlpha;
	renderer.context.drawImage(tmp_cnv, bbox.x, bbox.y);
}

function getMatrixScale(m) {
	return Math.max( 0.001, Math.sqrt(Math.sqrt(m.a * m.a + m.b * m.b) * Math.sqrt(m.c * m.c + m.d * m.d)) );
}

DFontText.prototype.renderCanvasCharsBlend = function (renderer, wt, bbox, tmp_cnv, tmp_ctx, full_w, full_h)
{
	var data = this.render_data;
	var chars = data.canvas_items;

	// Clean the temporary canvas
	tmp_ctx.setTransform(1, 0, 0, 1, 0, 0);

	tmp_ctx.globalCompositeOperation = 'source-over';
	tmp_ctx.fillRect(0, 0, full_w, full_h);

	tmp_ctx.globalCompositeOperation = 'lighten';

	tmp_ctx.setTransform(
		wt.a, wt.b, wt.c, wt.d,
		(wt.tx - bbox.x),
		(wt.ty - bbox.y)
	);

	// Draw raw characters to temporary
	for (var i = 0; i < chars.length; i++)
	{
		var texture = data.textures[chars[i].page];
		if (!texture)
			continue;
		var resolution = texture.baseTexture.resolution;

		var tsize_src = chars[i].sSize;
		var tsize_dst = chars[i].dSize;

		tmp_ctx.drawImage(
			texture.baseTexture.source,
			chars[i].sx * resolution,
			chars[i].sy * resolution,
			tsize_src, tsize_src,
			chars[i].dx,
			chars[i].dy,
			tsize_dst, tsize_dst
		);
	}

	// Apply the shader in code
	var img = tmp_ctx.getImageData(0, 0, full_w, full_h);

	var r05 = Math.max(0.0, Math.min(0.5, 0.5 * (data.dcoeff / getMatrixScale(wt))));

	apply_dfont_shading(img.data, this._font.tint, r05);

	tmp_ctx.putImageData(img, 0, 0);
}

DFontText.prototype.renderCanvasCharsNoBlend = function (renderer, wt, cache_bbox, cache_cnv, cache_ctx, cache_w, cache_h)
{
	var data = this.render_data;
	var chars = data.canvas_items;

	// Clean the temporary canvas
	cache_ctx.setTransform(1, 0, 0, 1, 0, 0);
	cache_ctx.clearRect(0, 0, cache_w, cache_h);

	if (DFontText.temp_canvas == null)
	{
		DFontText.temp_canvas = document.createElement('canvas');
		DFontText.temp_context = DFontText.temp_canvas.getContext('2d');

		DFontText.temp_context.fillStyle = 'black';
	}

	var tmp_cnv = DFontText.temp_canvas;
	var tmp_ctx = DFontText.temp_context;

	// Compute character-independent info
	var tsize_dst_main = data.tile_size_dest;

	var rect = new PIXI.Rectangle(0,0,tsize_dst_main,tsize_dst_main);
	var max_bbox = compute_rotated_rect(wt, rect, true);
	var full_w = tmp_cnv.width = max_bbox.width;
	var full_h = tmp_cnv.height = max_bbox.height;

	if (full_w == 0 || full_h == 0) {
		return;
	}

	var r05 = Math.max(0.0, Math.min(0.5, 0.5 * (data.dcoeff / getMatrixScale(wt))));

	// Without blend mode support characters have to be drawn one by one
	for (var i = 0; i < chars.length; i++)
	{
		var texture = data.textures[chars[i].page];
		if (!texture)
			continue;
		var resolution = texture.baseTexture.resolution;

		var tsize_src = chars[i].sSize;
		var tsize_dst = chars[i].dSize;

		rect.x = chars[i].dx * resolution;
		rect.y = chars[i].dy * resolution;
		rect.width = tsize_dst;
		rect.height = tsize_dst;

		var bbox = compute_rotated_rect(wt, rect, true);

		tmp_ctx.setTransform(1, 0, 0, 1, 0, 0);
		tmp_ctx.fillRect(0, 0, full_w, full_h);

		tmp_ctx.setTransform(
			wt.a, wt.b, wt.c, wt.d,
			(wt.tx - bbox.x),
			(wt.ty - bbox.y)
		);

		tmp_ctx.drawImage(
			texture.baseTexture.source,
			chars[i].sx * resolution,
			chars[i].sy * resolution,
			tsize_src, tsize_src,
			rect.x, rect.y,
			tsize_dst, tsize_dst
		);

		// Apply the shader in code
		var img = tmp_ctx.getImageData(0, 0, full_w, full_h);
		apply_dfont_shading(img.data, this._font.tint, r05);
		tmp_ctx.putImageData(img, 0, 0);

		// Draw the image
		cache_ctx.drawImage(tmp_cnv, bbox.x-cache_bbox.x, bbox.y-cache_bbox.y);
	}
}

DFontText.prototype.renderCanvasChars = (
	PIXI.CanvasTinter.canUseMultiply ?
		DFontText.prototype.renderCanvasCharsBlend :
		DFontText.prototype.renderCanvasCharsNoBlend
);
