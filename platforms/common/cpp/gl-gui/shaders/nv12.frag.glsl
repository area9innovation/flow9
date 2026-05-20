// NV12/YUV420P to RGBA conversion shader.
// Y plane in s_tex (GL_RED), UV plane in s_tex_uv (GL_RG).
// Uses ITU-R BT.601 color space conversion.

uniform lowp sampler2D s_tex;     // Y plane  (single channel in .r)
uniform lowp sampler2D s_tex_uv;  // UV plane (U in .r, V in .g)
uniform lowp vec4 u_mainColor;

in frag_highp vec2 v_texCoord;
in lowp vec4 v_drawColor;

#if !defined(GL_ES) || (__VERSION__ >= 300)
out frag_highp vec4 fragColor;
#endif

void main() {
    // Sample Y
    highp float y = texture2D(s_tex, v_texCoord).r;

    // Sample UV: U in red channel, V in green channel
    lowp vec2 uv_sample = texture2D(s_tex_uv, v_texCoord).rg;
    highp float u = uv_sample.r;
    highp float v = uv_sample.g;

    // BT.601 conversion (Y: 16-235, UV: 16-240 range)
    y = 1.1643 * (y - 0.0625);
    u = u - 0.5;
    v = v - 0.5;

    mediump vec3 rgb;
    rgb.r = y + 1.5958 * v;
    rgb.g = y - 0.39173 * u - 0.81290 * v;
    rgb.b = y + 2.017 * u;

    gl_FragColor = vec4(clamp(rgb, 0.0, 1.0), 1.0) * v_drawColor;
}
