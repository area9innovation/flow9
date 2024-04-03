#include <string>
#include <sstream>

#include "GLRenderer.h"

#ifndef FLOW_EMBEDDED
  #ifdef __APPLE__
    #include <OpenGL/glu.h>
  #else
    #include <GL/glu.h>
  #endif //__APPLE__
#endif

#include <glm/gtc/type_ptr.hpp>

#include "shaders/code.inc"

static const int MIN_FB_SIZE = 64;

/* Generic initialization */

GLRenderer::GLRenderer(double devicePixelRatio) : devicePixelRatio(devicePixelRatio)
{
    max_texture_size = 64;
    root_fb_id = 0;
    frame_idx = 1;
    init_ok = false;
    workarounds = 0;
    invalidateDependents();
}

GLRenderer::~GLRenderer()
{
    invalidateDependents();
}

void GLRenderer::invalidateDependents()
{
    screen_size = ivec2(0,0);
    program_u_cmatrix_set = program_out_dim_set = program_in_dim_set = 0;
    cur_program = ProgLAST;
    fb_stencil_type = fb_stencil_attachment = fb_stencil_attachment2 = 0;
    current_framebuffer.reset();
    memset(programs, 0xFF, sizeof(programs));

    for (T_framebuffer_map::iterator it1 = all_framebuffers.begin();
         it1 != all_framebuffers.end(); ++it1)
    {
        T_framebuffers &fbvec = it1->second;
        for (T_framebuffers::iterator it = fbvec.begin(); it != fbvec.end(); ++it)
            (*it)->invalidate();
    }

    all_framebuffers.clear();
    free_framebuffers.clear();
    stencil_buffers.clear();
    framebuffer_usage_tbl.clear();

    if (root_framebuffer)
        root_framebuffer->invalidate();

    for (T_textures::iterator it = textures.begin(); it != textures.end(); ++it) {
        (*it)->renderer = NULL;
        (*it)->texture_id = 0;
    }

    textures.clear();
    dead_textures.clear();
    crop_depth = 0;
}

bool GLRenderer::Init(GLuint root_fb)
{
#ifdef GLEW_VERSION
    if (glewInit() != GLEW_OK) {
        cerr << "Could not initialize GLEW" << endl;
        return false;
    }
    if (!GLEW_VERSION_2_0) {
        cerr << "OpenGL 2.0 API is not available" << endl;
        return false;
    }
    if (!GLEW_ARB_framebuffer_object) {
        cerr << "OpenGL ARB_framebuffer_object extension is not available" << endl;
        return false;
    }
#endif

    reportGLErrors("GLRenderer::Init");
    invalidateDependents();

    init_ok = true;
    root_fb_id = root_fb;

    all_extensions = getOpenGLExtensions();
    //cout << "'" << all_extensions << "'" << endl;

    workarounds = 0;

    std::string renderer = std::string((char*)glGetString(GL_RENDERER));
    std::transform(renderer.begin(), renderer.end(), renderer.begin(), ::tolower);

    // Don't use stencil on these for now since it totally breaks everything
    if (renderer == "adreno (tm) 418" || renderer == "adreno (tm) 420" ||
        renderer == "mali-t830")
        workarounds |= WorkaroundNoStencil;

    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glDisable(GL_SCISSOR_TEST);
    glDisable(GL_STENCIL_TEST);

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
    glStencilOp(GL_KEEP,GL_KEEP,GL_KEEP);

#ifndef FLOW_EMBEDDED
    glDisable(GL_LINE_SMOOTH);
    glDisable(GL_POINT_SMOOTH);

    glDepthRange(-1.0f, 1.0f);
#endif

    glDepthMask(GL_TRUE);
    glClearStencil(0);
    glEnableVertexAttribArray(AttrVertexPos);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    glGetIntegerv(GL_MAX_TEXTURE_SIZE, &max_texture_size);

    compileShaders();
    chooseFramebufferMode();

    return init_ok;
}

void GLRenderer::SetSize(int w, int h)
{
    disposeFrameBuffers(screen_size);
    screen_size = ivec2(w,h);

    if (root_framebuffer)
        root_framebuffer->invalidate();

    root_framebuffer = makeRootFrameBuffer(root_fb_id);
}

void GLRenderer::setDevicePixelRatio(double ratio)
{
    if (devicePixelRatio == ratio)
        return;

    devicePixelRatio = ratio;

    // We need to rebuild all framebuffers, since they will have a
    // different size due to the change in the device pixel ratio
    disposeAllFrameBuffers();

    root_framebuffer = makeRootFrameBuffer(root_fb_id);
}

GLRenderer::FrameBuffer::Ptr GLRenderer::makeRootFrameBuffer(GLuint id)
{
    FrameBuffer::Ptr fb(new FrameBuffer(screen_size));
    fb->fb_id = id;
    fb->is_root = true;
    return fb;
}

void GLRenderer::CleanStaleObjectsPre()
{
    if (!dead_textures.empty()) {
        glDeleteTextures(dead_textures.size(), &dead_textures[0]);
        dead_textures.clear();
    }

    framebuffer_usage_tbl.clear();
}

void GLRenderer::BeginFrame()
{
    frame_idx++;

    CleanStaleObjectsPre();
}

void GLRenderer::CleanStaleObjectsPost()
{
    disposeUnusedFrameBuffers();
    discardUnusedTextures();
}

/* Shader control */

void GLRenderer::setAlphaMode(bool src_premultiplied)
{
    if (src_premultiplied)
        glBlendFunc(GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
    else
        glBlendFuncSeparate(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA,GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
}

void GLRenderer::setCurMatrix(const mat3 &cmatrix)
{
    program_u_cmatrix_set = 0;
    u_cmatrix = cmatrix;
}

void GLRenderer::setProgram(ProgramId prog)
{
    if (cur_program != prog) {
        glUseProgram(programs[prog].program_id);
        cur_program = prog;
    }

    unsigned bit = 1<<prog;

    if ((program_out_dim_set & bit) == 0) {
        glUniform2fv(programs[prog].u_out_pixel_size, 1, glm::value_ptr(u_out_pixel_size));
        glUniform2fv(programs[prog].u_out_offset, 1, glm::value_ptr(u_out_offset));
        program_out_dim_set |= bit;
    }

    if ((program_u_cmatrix_set & bit) == 0)
    {
        if (programs[prog].u_cmatrix >= 0)
            glUniformMatrix3fv(programs[prog].u_cmatrix, 1, GL_FALSE, glm::value_ptr(u_cmatrix));
        program_u_cmatrix_set |= bit;
    }

    if ((program_in_dim_set & bit) == 0)
    {
        if (programs[prog].u_in_pixel_size >= 0)
            glUniform2fv(programs[prog].u_in_pixel_size, 1, glm::value_ptr(u_in_pixel_size));
        if (programs[prog].u_in_offset >= 0)
            glUniform2fv(programs[prog].u_in_offset, 1, glm::value_ptr(u_in_offset));
        program_in_dim_set |= bit;
    }
}

void GLRenderer::makeFramebufferCurrent(FrameBuffer::Ptr buffer, vec2 bias)
{
    if (buffer == current_framebuffer) return;

    reportGLErrors("GLRenderer::makeFramebufferCurrent start");

    FrameBuffer::Ptr old_buffer = current_framebuffer;

    //glFinish();

    current_framebuffer = buffer;
    glBindFramebuffer(GL_FRAMEBUFFER, buffer->fb_id);

    if (old_buffer && old_buffer->stack)
        old_buffer->stack->claimElapsedTime(103);

    vec2 new_offset = buffer->out_offset + bias;

    if (u_out_pixel_size != buffer->out_pixel_size ||
        u_out_offset != new_offset)
    {
        glViewport(0, 0, devicePixelRatio*buffer->size.x, devicePixelRatio*buffer->size.y);
        u_out_pixel_size = buffer->out_pixel_size;
        u_out_offset = new_offset;
        program_out_dim_set = 0;
    }

    crop_depth = 0;
    glDisable(GL_SCISSOR_TEST);
    glDisable(GL_STENCIL_TEST);

    reportGLErrors("GLRenderer::makeFramebufferCurrent end");
}

void GLRenderer::makeFramebufferInput(FrameBuffer::Ptr buffer, vec2 bias, GLenum tex_unit)
{
    glActiveTexture(tex_unit);

    if (!buffer || !buffer->isValid()) {
        glBindTexture(GL_TEXTURE_2D, 0);
        return;
    }

    if (u_in_pixel_size != buffer->pixel_size || u_in_offset != bias) {
        u_in_pixel_size = buffer->pixel_size;
        u_in_offset = bias;
        program_in_dim_set = 0;
    }

    glBindTexture(GL_TEXTURE_2D, buffer->tex_id);

    reportGLErrors("GLRenderer::makeFramebufferInput end");
}

void GLRenderer::beginDrawSimple(const vec4 &color)
{
    setProgram(ProgDrawSimple);

    glUniform4fv(programs[cur_program].u_mainColor, 1, glm::value_ptr(color));
}

void GLRenderer::beginDrawFancy(const vec4 &color, bool useTexture, bool swizzleRB)
{
    setProgram(ProgDrawFancy);

    glUniform4fv(programs[cur_program].u_mainColor, 1, glm::value_ptr(color));
    glUniform1i(programs[cur_program].u_useTexture, useTexture);
    glUniform1i(programs[cur_program].u_swizzleRB, swizzleRB);

    glActiveTexture(GL_TEXTURE0);
    if (!useTexture)
        glBindTexture(GL_TEXTURE_2D, 0);
}

void GLRenderer::beginDrawFancyExternalTexture(const vec4 &color)
{
    setProgram(ProgDrawFancyExternalTexture);

    glUniform4fv(programs[cur_program].u_mainColor, 1, glm::value_ptr(color));
    glUniform1i(programs[cur_program].u_useTexture, true);

    glActiveTexture(GL_TEXTURE0);
}


void GLRenderer::beginDrawFont(float radius)
{
    setProgram(ProgDrawFont);

    float r05 = glm::clamp(0.5f*radius, 0.0f, 0.5f);

    glUniform1f(programs[cur_program].u_font_dist_min, 0.5f - r05);
    glUniform1f(programs[cur_program].u_font_dist_coeff, 0.5f / r05);

    glActiveTexture(GL_TEXTURE0);
}

void GLRenderer::beginFilter(GLDrawSurface *main, GLDrawSurface *mask)
{
    //assert(!mask || main->isCompatible(mask));

    main->bindToTexture(GL_TEXTURE0);
    if (mask)
        mask->bindToTexture(GL_TEXTURE1);
}

void GLRenderer::endFilter(GLDrawSurface *main, GLDrawSurface *mask)
{
    main->drawBBox();

    if (mask)
        glBindTexture(GL_TEXTURE_2D, 0);
}

void GLRenderer::renderMask(GLDrawSurface *main, GLDrawSurface *mask)
{
    beginFilter(main, mask);
    setProgram(ProgFilterMask);
    endFilter(main, mask);
}

void GLRenderer::initFilterBlur(float sigma)
{
    if (programs[cur_program].u_local_blur_shift >= 0) {
        float blur = 0.0f;

        if (sigma > 0) {
            float ev = 2.0f*expf(-0.5f/sigma/sigma);
            blur = ev/(1.0f + ev);
        }

        glUniform2fv(programs[cur_program].u_local_blur_shift, 1, glm::value_ptr(blur * u_in_pixel_size));
    }
}

void GLRenderer::renderShadow(GLDrawSurface *main, GLDrawSurface *mask, vec2 shift, vec4 color, bool inner, float sigma)
{
    beginFilter(main, mask);

    setProgram((sigma <= 0) ? ProgFilterShadow : ProgFilterShadowBlur);
    glUniform1i(programs[cur_program].u_filter_inner, inner);
    glUniform2fv(programs[cur_program].u_tex_shifts, 1, glm::value_ptr(shift));
    glUniform4fv(programs[cur_program].u_shadow_color, 1, glm::value_ptr(color));

    initFilterBlur(sigma);

    endFilter(main, mask);
}

void GLRenderer::renderBevel(GLDrawSurface *main, GLDrawSurface *mask, vec2 shift, vec4 color1, vec4 color2, bool inner, float sigma)
{
    beginFilter(main, mask);

    // Save one abs call in the shader
    color2 = -color2;

    setProgram((sigma <= 0) ? ProgFilterBevel : ProgFilterBevelBlur);
    glUniform1i(programs[cur_program].u_filter_inner, inner);
    glUniform2fv(programs[cur_program].u_tex_shifts, 1, glm::value_ptr(shift));
    glUniform4fv(programs[cur_program].u_bevel_color1, 1, glm::value_ptr(color1));
    glUniform4fv(programs[cur_program].u_bevel_color2, 1, glm::value_ptr(color2));

    initFilterBlur(sigma);

    endFilter(main, mask);
}

std::vector<std::string> split_string(const std::string &str, const std::string &delimiter)
{
    std::vector<std::string> strings;

    std::string::size_type pos = 0;
    std::string::size_type prev = 0;
    while ((pos = str.find(delimiter, prev)) != std::string::npos)
    {
        strings.push_back(str.substr(prev, pos - prev));
        prev = pos + 1;
    }

    if (prev > 0) {
        // To get the last substring (or only, if delimiter is not found)
        strings.push_back(str.substr(prev + 1));
    } else {
        strings.push_back(str);
    }

    return strings;
}

void GLRenderer::renderShader(GLDrawSurface *main, GLDrawSurface * /*mask*/, unsigned program_id, float &time, float &seed)
{
    beginFilter(main, NULL);

    ProgramInfo *info = &programs[program_id];

    setProgram((ProgramId) program_id);

    vec2 tex[2] = {
        (main->bbox.min_pt - u_in_offset) * vec2(u_in_pixel_size.x, -u_in_pixel_size.y),
        vec2(1.0f, 1.0f) + (main->bbox.min_pt - u_in_offset) * vec2(-u_in_pixel_size.x, u_in_pixel_size.y)
    };

    float coords[4*2] = {
        tex[0].x, tex[1].y,
        tex[1].x, tex[1].y,
        tex[0].x, tex[0].y,
        tex[1].x, tex[0].y
    };

    glEnableVertexAttribArray(GLRenderer::AttrVertexTexCoord);
    glVertexAttribPointer(GLRenderer::AttrVertexTexCoord, 2, GL_FLOAT, GL_FALSE, 0, coords);

    int loc = glGetUniformLocation(info->program_id, "time");

    if (loc >= 0) {
        time = time + 0.1f;
        glUniform1f(loc, time);
    }

    loc = glGetUniformLocation(info->program_id, "u_cmatrix");

    if (loc >= 0) {
        mat3 cmatrix =
            mat3(
                u_out_pixel_size.x, 0.0f, 0.0f,
                0.0f, u_out_pixel_size.y, 0.0f,
                -u_out_offset.x * u_out_pixel_size.x, -u_out_offset.y * u_out_pixel_size.y, 1.0f
            );

        glUniformMatrix3fv(info->u_cmatrix, 1, GL_FALSE, glm::value_ptr(cmatrix));
    }

    loc = glGetUniformLocation(info->program_id, "seed");

    if (loc >= 0) {
        seed = static_cast <float> (rand()) / static_cast <float> (RAND_MAX);
        glUniform1f(loc, seed);
    }

    loc = glGetUniformLocation(info->program_id, "bounds");

    if (loc >= 0) {
        vec4 bounds = vec4(main->bbox.min_pt.x, main->bbox.min_pt.y, main->bbox.max_pt.x - main->bbox.min_pt.x, main->bbox.max_pt.y - main->bbox.min_pt.y);
        glUniform4fv(loc, 1, glm::value_ptr(bounds));
    }

    loc = glGetUniformLocation(info->program_id, "filterArea");

    if (loc >= 0) {
        vec4 filterArea = vec4(main->size.x, main->size.y, u_in_offset.x, u_in_offset.y);
        glUniform4fv(loc, 1, glm::value_ptr(filterArea));
    }

    endFilter(main, NULL);

    glDisableVertexAttribArray(GLRenderer::AttrVertexTexCoord);
}

void GLRenderer::renderLocalBlur(GLDrawSurface *input, float sigma)
{
    vec2 nullshift(0.0f, 0.0f);

    beginFilter(input, NULL);
    setProgram(ProgGauss3x3);
    glUniform2fv(programs[cur_program].u_tex_shifts, 1, glm::value_ptr(nullshift));
    initFilterBlur(sigma);
    endFilter(input, NULL);
}

void GLRenderer::renderBigBlur(GLDrawSurface *input, bool vertical, float base_coeff, int steps, float *deltas, float *coeffs)
{
    beginFilter(input, NULL);

    setProgram(ProgGauss);

    float* gauss_coeffs = new float[steps];
    for (int i = 0; i < steps; i++)
        gauss_coeffs[i] = coeffs[i];

    float* v_shifts = new float[2 * steps];
    for (int i = 0; i < 2 * steps; i++)
        v_shifts[i] = 0.0;

    if (vertical)
        for (int i = 0; i < steps; i++)
            v_shifts[2*i+1] = deltas[i] * u_in_pixel_size.y;
    else
        for (int i = 0; i < steps; i++)
            v_shifts[2*i] = deltas[i] * u_in_pixel_size.x;

    glUniform1i(programs[cur_program].u_gauss_steps, steps);
    glUniform1f(programs[cur_program].u_gauss_base_coeff, base_coeff);
    glUniform1fv(programs[cur_program].u_gauss_shift_coeff, steps, gauss_coeffs);
    glUniform2fv(programs[cur_program].u_gauss_shifts, steps, v_shifts);

    endFilter(input, NULL);
}

void GLRenderer::drawRect(vec2 minv, vec2 maxv)
{
    float coords[4*2] = {
        minv.x, minv.y,
        maxv.x, minv.y,
        minv.x, maxv.y,
        maxv.x, maxv.y
    };

    glVertexAttribPointer(GLRenderer::AttrVertexPos, 2, GL_FLOAT, GL_FALSE, 0, coords);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

int GLRenderer::getCropStencilMask(int *pval, int *pmask)
{
    if (crop_depth > 0)
    {
        *pmask = *pval = ((1<<crop_depth)-1) & StencilCropBits;
        return crop_depth;
    }
    else
    {
        *pmask = *pval = 0;
        return 0;
    }
}

void GLRenderer::resetStencilTest(bool only_func)
{
    if (crop_depth > 0)
    {
        int val, mask;
        getCropStencilMask(&val, &mask);

        glEnable(GL_STENCIL_TEST);
        glStencilFunc(GL_EQUAL, val, mask);
    }
    else
    {
        if (!only_func)
            glDisable(GL_STENCIL_TEST);
        glStencilFunc(GL_ALWAYS, 0, 0);
    }
}

void GLRenderer::setRootFramebufferId(GLuint id)
{
    root_fb_id = id;
    if (root_framebuffer)
        root_framebuffer->fb_id = id;
}

/* SHADER COMPILATION */

void GLRenderer::compileShaders()
{
    std::vector<std::string> pfix;
    bool ok;

    pfix.clear();

    compileShaderPair(ProgDrawSimple, SHADER_draw_vert, SHADER_draw_frag, pfix,
                      1, AttrVertexPos, "a_VertexPos");

    pfix.clear();
    pfix.push_back("#define DRAW_FANCY\n");
    compileShaderPair(ProgDrawFancy, SHADER_draw_vert, SHADER_draw_frag, pfix,
                      3,
                      AttrVertexPos, "a_VertexPos",
                      AttrVertexColor, "a_VertexColor",
                      AttrVertexTexCoord, "a_VertexTexCoord");

    compileShaderPair(ProgDrawFont, SHADER_draw_vert, SHADER_font_frag, pfix,
                      3,
                      AttrVertexPos, "a_VertexPos",
                      AttrVertexColor, "a_VertexColor",
                      AttrVertexTexCoord, "a_VertexTexCoord");

    if (all_extensions.find("GL_OES_EGL_image_external") != std::string::npos) {
        pfix.clear();
        pfix.push_back("#define DRAW_FANCY\n#define EXTERNAL_TEXTURE\n");
        compileShaderPair(ProgDrawFancyExternalTexture, SHADER_draw_vert, SHADER_draw_frag, pfix,
                      3,
                      AttrVertexPos, "a_VertexPos",
                      AttrVertexColor, "a_VertexColor",
                      AttrVertexTexCoord, "a_VertexTexCoord");
    }

    pfix.clear();
    pfix.push_back("#define FILTER_MASK\n");
    compileShaderPair(ProgFilterMask, SHADER_filter_vert, SHADER_filter_frag, pfix,
                      1, AttrVertexPos, "a_VertexPos");

    pfix.clear();
    pfix.push_back("#define TEX_SHIFTS 1\n");
    pfix.push_back("#define FILTER_SHADOW\n");
    compileShaderPair(ProgFilterShadow, SHADER_filter_vert, SHADER_filter_frag, pfix,
                      1, AttrVertexPos, "a_VertexPos");

    pfix.push_back("#define LOCAL_BLUR\n");
    compileShaderPair(ProgFilterShadowBlur, SHADER_filter_vert, SHADER_filter_frag, pfix,
                      1, AttrVertexPos, "a_VertexPos");

    pfix.clear();
    pfix.push_back("#define TEX_SHIFTS 1\n");
    pfix.push_back("#define FILTER_BEVEL\n");
    compileShaderPair(ProgFilterBevel, SHADER_filter_vert, SHADER_filter_frag, pfix,
                      1, AttrVertexPos, "a_VertexPos");

    pfix.push_back("#define LOCAL_BLUR\n");
    ok = doCompileShaderPair(ProgFilterBevelBlur, SHADER_filter_vert, SHADER_filter_frag, pfix,
                             1, AttrVertexPos, "a_VertexPos");

    if (!ok) {
        pfix.push_back("#define USE_SWIZZLE_SHIFT\n");
        compileShaderPair(ProgFilterBevelBlur, SHADER_filter_vert, SHADER_filter_frag, pfix,
                          1, AttrVertexPos, "a_VertexPos");
    }

    pfix.clear();
    pfix.push_back("#define TEX_SHIFTS 1\n");
    pfix.push_back("#define ONE_TEXTURE\n");
    pfix.push_back("#define FILTER_BLUR\n");
    compileShaderPair(ProgGauss3x3, SHADER_filter_vert, SHADER_filter_frag, pfix,
                      1, AttrVertexPos, "a_VertexPos");

    pfix.clear();
    pfix.push_back("#define USE_MASK_B\n");
    compileShaderPair(ProgGauss, SHADER_filter_vert, SHADER_gauss_frag, pfix,
                      1, AttrVertexPos, "a_VertexPos");

    if (!ok) {
        pfix.push_back("#define USE_SWIZZLE_SHIFT\n");
        compileShaderPair(ProgGauss, SHADER_filter_vert, SHADER_gauss_frag, pfix,
                          1, AttrVertexPos, "a_VertexPos");
    }

#if defined(GL_ES_VERSION_2_0) || defined(GL_ARB_ES2_compatibility)
    glReleaseShaderCompiler();
#endif
}

void GLRenderer::reportGLErrors(const char *where)
{
    GLenum err;
    while ((err = glGetError()) != GL_NO_ERROR) {
#ifdef FLOW_EMBEDDED
        const char *msg = "?";
#else
        const char *msg = (const char*)gluErrorString(err);
#endif
        cerr << "OpenGL error " << err << " " << msg;
        if (where)
            cerr << " in " << where;
        cerr << endl;
    }
}

std::string GLRenderer::getOpenGLInfo()
{
    std::ostringstream oss;

    const unsigned char *vendor = glGetString(GL_VENDOR);
    const unsigned char *renderer = glGetString(GL_RENDERER);
    const unsigned char *version = glGetString(GL_VERSION);
    const unsigned char *glsl_version = glGetString(GL_SHADING_LANGUAGE_VERSION);

    oss << "---------------------------------------- OpenGL Info ----------------------------------------" << endl;
    oss << "Vendor: " << vendor << endl;
    oss << "Renderer: " << renderer << endl;
    oss << "Version: " << version << endl;
    oss << "Shading Language Version: " << glsl_version << endl;
    oss << "Extensions: " << getOpenGLExtensions() << endl;
    oss << "---------------------------------------------------------------------------------------------" << endl;

    return oss.str();
}

std::string GLRenderer::getOpenGLExtensions()
{
    std::string extensions = "";

#ifdef GL_NUM_EXTENSIONS
#ifdef GLEW_VERSION
    // For some mysterious reason when using glew glGetStringi sometimes is not initialized when calling this method.
    // TODO: Update glew and see if the issue has been solved.
    if (glGetStringi)
    {
#endif // GLEW_VERSION
        GLint n;
        glGetIntegerv(GL_NUM_EXTENSIONS, &n);
        for (int i = 0; i < n; i++)
            extensions += std::string((const char *)glGetStringi(GL_EXTENSIONS, i));
        return extensions;
#ifdef GLEW_VERSION
    } else {
#endif
#endif
#ifdef GL_EXTENSIONS
        const unsigned char *gl_extensions = glGetString(GL_EXTENSIONS);
        if (gl_extensions)
            extensions = std::string((const char *)gl_extensions) + " ";
        return extensions;

#endif // GL_NUM_EXTENSIONS
#ifdef GLEW_VERSION
    }
#endif
}

bool GLRenderer::compileShader(GLuint shader, const std::vector<std::string> &prefix, const char **list)
{
    std::vector<const char*> data;

    const char **p = 0;

#if defined(WIN32)
    // version directive must be the first statement, and we only need to
    // specify GLSL v1.40 for some AMD drivers on windows
    // under vmware, version 140 is not supported
    // vmware video driver reports GL_SHADING_LANGUAGE_VERSION = 1.30 so we should not requst 1.40

    if (strcmp((const char*)glGetString(GL_SHADING_LANGUAGE_VERSION), "1.30") != 0) {
        const char *versionLine = "#version 140\n";
        data.push_back(versionLine);
    }
#endif

    p = SHADER_common;
    while (*p)
        data.push_back(*p++);

    for (std::vector<std::string>::const_iterator it = prefix.begin(); it != prefix.end(); ++it)
        data.push_back(it->c_str());

    p = list;
    while (*p)
        data.push_back(*p++);

    glShaderSource(shader, data.size(), &data[0], NULL);
    glCompileShader(shader);

    GLint status, ll;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &ll);

    if (status != GL_TRUE)
        reportGLErrors("GLRenderer::compileShader");

    if (ll > 1) {
        char *buf = new char[ll];
        glGetShaderInfoLog(shader, ll, &ll, buf);
        (status ? cout : cerr) << buf << endl;
        delete[] buf;
    }

    return (status == GL_TRUE);
}

void GLRenderer::initUniforms(ProgramId id, std::vector<ShaderUniform> uniforms)
{
    ProgramInfo *info = &programs[id];

    for (unsigned i = 0; i < uniforms.size(); i++) {
        ShaderUniform uniform = uniforms[i];

        if (uniform.type == "1f" || uniform.type == "2f" || uniform.type == "3f" || uniform.type == "4f") {
            int loc = glGetUniformLocation(info->program_id, uniform.name.c_str());

            if (loc >= 0) {
                if (uniform.type == "1f") {
                    glUniform1f(loc, atof(uniform.value.c_str()));
                } else if (uniform.type == "2f") {
                    std::vector<std::string> value_split = split_string(uniform.value.substr(1, uniform.value.length() - 2), ",");
                    glUniform2f(loc, atof(value_split[0].c_str()), atof(value_split[1].c_str()));
                } else if (uniform.type == "3f") {
                    std::vector<std::string> value_split = split_string(uniform.value.substr(1, uniform.value.length() - 2), ",");
                    glUniform3f(loc, atof(value_split[0].c_str()), atof(value_split[1].c_str()), atof(value_split[2].c_str()));
                } else if (uniform.type == "4f") {
                    std::vector<std::string> value_split = split_string(uniform.value.substr(1, uniform.value.length() - 2), ",");
                    glUniform4f(loc, atof(value_split[0].c_str()), atof(value_split[1].c_str()), atof(value_split[2].c_str()), atof(value_split[3].c_str()));
                }
            }
        }
    }
}

void GLRenderer::compileShaderPair(ProgramId id, const char **vlist, const char **flist,
                                   const std::vector<std::string> &prefix,
                                   unsigned nattrs, ...)
{
    va_list args;
    va_start(args, nattrs);
    if (!vdoCompileShaderPair(id, vlist, flist, prefix, nattrs, args))
        init_ok = false;
    va_end(args);
}

void GLRenderer::vcompileShaderPair(ProgramId id, const char **vlist, const char **flist,
                                   const std::vector<std::string> &prefix,
                                   int nattrs, va_list attrs)
{
    if (!vdoCompileShaderPair(id, vlist, flist, prefix, nattrs, attrs))
        init_ok = false;
}

bool GLRenderer::doCompileShaderPair(ProgramId id, const char **vlist, const char **flist,
                                     const std::vector<std::string> &prefix,
                                     int nattrs, ...)
{
    va_list args;
    va_start(args, nattrs);
    bool ok = vdoCompileShaderPair(id, vlist, flist, prefix, nattrs, args);
    va_end(args);
    return ok;
}

bool GLRenderer::vdoCompileShaderPair(ProgramId id, const char **vlist, const char **flist,
                                     const std::vector<std::string> &prefix,
                                     int nattrs, va_list attrs)
{
    ProgramInfo *info = &programs[id];
    memset(info, 0xFF, sizeof(ProgramInfo));

    // Create objects
    info->program_id = glCreateProgram();
    info->vert_shader_id = glCreateShader(GL_VERTEX_SHADER);
    info->frag_shader_id = glCreateShader(GL_FRAGMENT_SHADER);

    if (!info->program_id || !info->vert_shader_id || !info->frag_shader_id) {
        reportGLErrors("GLRenderer::compileShaderPair (1)");
        cerr << "Couldn't allocate shader program #" << id << endl;
        return false;
    }

    // Bind the attribute names to their locations
    for (int i = 0; i < nattrs; i++) {
        int index = va_arg(attrs, int);
        char *attr = va_arg(attrs, char*);
        glBindAttribLocation(info->program_id, index, attr);
    }

    // Compile shaders
    glAttachShader(info->program_id, info->vert_shader_id);
    glAttachShader(info->program_id, info->frag_shader_id);

    bool ok = compileShader(info->vert_shader_id, prefix, vlist) &&
              compileShader(info->frag_shader_id, prefix, flist);

    if (!ok) {
        glDeleteShader(info->vert_shader_id);
        glDeleteShader(info->frag_shader_id);
        glDeleteProgram(info->program_id);
        cerr << "Couldn't compile shader program #" << id << endl;
        return false;
    }

    // Link the program
    glLinkProgram(info->program_id);

    GLint status, ll;
    glGetProgramiv(info->program_id, GL_LINK_STATUS, &status);
    glGetProgramiv(info->program_id, GL_INFO_LOG_LENGTH, &ll);

    if (status != GL_TRUE)
        reportGLErrors("GLRenderer::compileShaderPair (2)");

    if (ll > 1) {
        char *buf = new char[ll];
        glGetProgramInfoLog(info->program_id, ll, &ll, buf);
        (status ? cout : cerr) << buf << endl;
        delete[] buf;
    }

    if (status != GL_TRUE) {
        glDeleteShader(info->vert_shader_id);
        glDeleteShader(info->frag_shader_id);
        glDeleteProgram(info->program_id);
        cerr << "Couldn't link shader program #" << id << endl;
        return false;
    }

    // Get uniform locations
    listUniforms(info);
    return true;
}

void GLRenderer::listUniforms(ProgramInfo *info)
{
    glUseProgram(info->program_id);

#define UNIFORM(name) info->name = glGetUniformLocation(info->program_id, #name);
    RENDERER_UNIFORMS
#undef UNIFORM

    if (info->s_tex >= 0)
        glUniform1i(info->s_tex, 0);
    if (info->s_mask >= 0)
        glUniform1i(info->s_mask, 1);
}

/* FRAMEBUFFER MANAGEMENT */

void GLRenderer::FrameBuffer::dispose()
{
    if (is_root) return;

    if (fb_id) {
        glDeleteFramebuffers(1, &fb_id);
        fb_id = 0;
    }

    if (tex_id) {
        glDeleteTextures(1, &tex_id);
        tex_id = 0;
    }
}

ivec2 GLRenderer::fitFrameBufferSize(int min_w, int min_h)
{
#if 1
    ivec2 size = (ivec2(min_w-1, min_h-1)/MIN_FB_SIZE+ivec2(1))*MIN_FB_SIZE;
#else
    ivec2 size = ivec2(MIN_FB_SIZE,MIN_FB_SIZE);

    while (size.x < min_w)
        size.x <<= 1;
    while (size.y < min_h)
        size.y <<= 1;
#endif

    if (size.x > max_texture_size ||
        size.y > max_texture_size ||
        size.x*size.y > screen_size.x*screen_size.y)
    {
        size = screen_size;
    }

    return size;
}

GLRenderer::FrameBuffer::Ptr GLRenderer::getFrameBuffer(int min_w, int min_h)
{
    reportGLErrors("GLRenderer::getFrameBuffer start");

    ivec2 size = fitFrameBufferSize(min_w, min_h);

    //cout << min_w << " " << min_h << " -> " << size.x << " " << size.y << endl;

    T_framebuffers &fbvec = free_framebuffers[size];

    // Select a framebuffer from the cache or make a new one
    FrameBuffer::Ptr rv;
    if (fbvec.empty())
        rv = makeFrameBuffer(size);
    else {
        rv = fbvec.back();
        fbvec.pop_back();
    }

    // Count its use for GC
    framebuffer_usage_tbl.insert(rv.get());
    return rv;
}

void GLRenderer::releaseFrameBuffer(FrameBuffer::Ptr buffer)
{
    if (current_framebuffer == buffer)
        current_framebuffer.reset();

    buffer->retained_frame = 0;

    if (!buffer->isValid()) return;

    free_framebuffers[buffer->size].push_back(buffer);
}

GLRenderer::FrameBuffer::Ptr GLRenderer::makeFrameBuffer(ivec2 size)
{
    FrameBuffer::Ptr new_fb(new FrameBuffer(size));

    reportGLErrors("GLRenderer::makeFrameBuffer start");

    glGenFramebuffers(1, &new_fb->fb_id);
    glGenTextures(1, &new_fb->tex_id);

    glBindTexture(GL_TEXTURE_2D, new_fb->tex_id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, devicePixelRatio*size.x, devicePixelRatio*size.y, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    current_framebuffer.reset();
    glBindFramebuffer(GL_FRAMEBUFFER, new_fb->fb_id);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, new_fb->tex_id, 0);

    bool new_stencil = false;
    GLuint &stencil = stencil_buffers[size];

    if (!stencil) {
        new_stencil = true;

        glGenRenderbuffers(1, &stencil);
        glBindRenderbuffer(GL_RENDERBUFFER, stencil);
        glRenderbufferStorage(GL_RENDERBUFFER, fb_stencil_type, devicePixelRatio*size.x, devicePixelRatio*size.y);
        glBindRenderbuffer(GL_RENDERBUFFER, 0);
    }

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, fb_stencil_attachment, GL_RENDERBUFFER, stencil);
    if (fb_stencil_attachment2)
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, fb_stencil_attachment2, GL_RENDERBUFFER, stencil);

    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

    if (status != GL_FRAMEBUFFER_COMPLETE) {
        switch (status) {
        case GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT:
            cerr << "Framebuffer: incomplete attachment." << endl;
            break;

        /*case GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS:
            cerr << "Framebuffer: incomplete dimensions." << endl;
            break;*/

        case GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT:
            cerr << "Framebuffer: missing attachment." << endl;
            break;

        case GL_FRAMEBUFFER_UNSUPPORTED:
            cout << "Framebuffer: unsupported; trying another config." << endl;
            break;

        default:
            cerr << "Framebuffer incomplete!" << endl;
        }

        reportGLErrors("GLRenderer::makeFrameBuffer fail");

        new_fb->dispose();

        if (new_stencil) {
            glDeleteRenderbuffers(1, &stencil);
            stencil = 0;
        }
    } else {
        all_framebuffers[size].push_back(new_fb);
    }

    reportGLErrors("GLRenderer::makeFrameBuffer end");

    return new_fb;
}

bool GLRenderer::chooseFramebufferMode() {
    FrameBuffer::Ptr fbp;

    reportGLErrors("chooseFramebufferMode");

    /* Try a couple of configurations to see which one works */

    // 1: Separate 8-bit stencil
    fb_stencil_type = GL_STENCIL_INDEX8;
    fb_stencil_attachment = GL_STENCIL_ATTACHMENT;
    fb_stencil_attachment2 = 0;

    if ((fbp = makeFrameBuffer(ivec2(MIN_FB_SIZE)))->isValid()) goto found;

    // 2: 24-bit depth + 8-bit stencil
#ifdef FLOW_EMBEDDED
    if (all_extensions.find("GL_OES_packed_depth_stencil ") != std::string::npos) {
        fb_stencil_type = GL_DEPTH24_STENCIL8_OES;
        fb_stencil_attachment2 = GL_DEPTH_ATTACHMENT;

        if ((fbp = makeFrameBuffer(ivec2(MIN_FB_SIZE)))->isValid()) goto found;
    }
#else
    fb_stencil_type = GL_DEPTH_STENCIL;
    fb_stencil_attachment = GL_DEPTH_STENCIL_ATTACHMENT;

    if ((fbp = makeFrameBuffer(ivec2(MIN_FB_SIZE)))->isValid()) goto found;
#endif

    cerr << "Could not find an acceptable framebuffer configuration." << endl;
    return (init_ok = false);

found:
    reportGLErrors("chooseFramebufferMode end");
    releaseFrameBuffer(fbp);
    return true;
}

void GLRenderer::disposeFrameBuffers(ivec2 size) {
    T_framebuffers &fbvec = all_framebuffers[size];
    for (T_framebuffers::iterator it = fbvec.begin(); it != fbvec.end(); ++it)
        (*it)->dispose();

    all_framebuffers.erase(size);
    free_framebuffers.erase(size);

    GLuint &stencil = stencil_buffers[size];
    if (stencil)
        glDeleteRenderbuffers(1, &stencil);
    stencil_buffers.erase(size);
}

void GLRenderer::disposeAllFrameBuffers() {

    for (T_framebuffer_map::iterator it1 = all_framebuffers.begin(); it1 != all_framebuffers.end(); ++it1)
    {
        T_framebuffers &fbvec = it1->second;
        for (T_framebuffers::iterator it = fbvec.begin(); it != fbvec.end(); ++it)
            (*it)->dispose();
    }
    all_framebuffers.clear();
    free_framebuffers.clear();
    framebuffer_usage_tbl.clear();

    // Delete all the stencil buffers
    for (T_stencil_buffers::iterator it = stencil_buffers.begin(); it != stencil_buffers.end(); it++) {
        GLuint &stencil = it->second;
        glDeleteRenderbuffers(1, &stencil);
    }
    stencil_buffers.clear();

    if (root_framebuffer)
        root_framebuffer->invalidate();
}

void GLRenderer::disposeUnusedFrameBuffers()
{
    int bytes = 0;
    int retained_cnt = 0, retained_area = 0;

    for (T_framebuffer_map::iterator it1 = all_framebuffers.begin();
         it1 != all_framebuffers.end(); ++it1)
    {
        T_framebuffers &fbvec = it1->second;
        T_framebuffers &free_vec = free_framebuffers[it1->first];

        if (fbvec.empty() && free_vec.empty()) continue;

        int old_size = fbvec.size();
        disposeUnusedFrameBuffers(fbvec);
        disposeUnusedFrameBuffers(free_vec);

        if (fbvec.empty() && free_vec.empty()) {
            GLuint &stencil = stencil_buffers[it1->first];
            glDeleteRenderbuffers(1, &stencil);
            stencil_buffers.erase(it1->first);
        }

        int cbytes = it1->first.x*it1->first.y*4*(fbvec.size() + 1);
        bytes += cbytes;

        if (0) {
            cout << "framebuffers " << it1->first.x << "x" << it1->first.y << ": "
                 << old_size << " -> " << fbvec.size() << " (" << cbytes << " bytes)" << endl;
        }

        int num_retained = 0;
        for (unsigned i = 0; i < fbvec.size(); i++) {
            if (fbvec[i]->retained_frame == frame_idx) {
                num_retained++; retained_cnt++;
                retained_area += fbvec[i]->size.x * fbvec[i]->size.y;
            }
        }

        if (fbvec.size() != free_vec.size() + num_retained) {
            cout << "framebuffer free/total count mismatch: "
                 << free_vec.size() << " vs " << fbvec.size() << endl;
        }
    }

    static int last_bytes = 0;

    if (abs(last_bytes - bytes) >= 1500000) {
        // TODO: Have some way to control this debug output
        // cout << "total active framebuffers: " << bytes << " bytes." << endl;
        last_bytes = bytes;
    }

    //cout << "retaining " << retained_cnt << " buffers, " << retained_area << " pixels." << endl;
}

void GLRenderer::disposeUnusedFrameBuffers(T_framebuffers &vec)
{
    unsigned j = 0;

    for (unsigned i = 0; i < vec.size(); i++) {
        if (framebuffer_usage_tbl.count(vec[i].get())) {
            if (i != j)
                vec[j] = vec[i];
            j++;
        } else {
            vec[i]->dispose();
        }
    }

    vec.resize(j);
}

void GLRenderer::InvalidateStaleRetainedBuffers()
{
    int reused_cnt = 0, reused_area = 0;

    for (T_framebuffer_map::iterator it1 = all_framebuffers.begin();
         it1 != all_framebuffers.end(); ++it1)
    {
        T_framebuffers &fbvec = it1->second;
        T_framebuffers &free_vec = free_framebuffers[it1->first];

        for (unsigned i = 0; i < fbvec.size(); i++) {
            FrameBuffer::Ptr fb = fbvec[i];
            int frame = fb->retained_frame;

            if (frame <= 0) continue;

            if (frame == frame_idx) {
                reused_cnt++;
                reused_area += fb->size.x * fb->size.y;
                continue;
            }

            // The buffer pointer is retained somewhere
            // in a GLDrawSurface, so create a copy and move
            // the GL object ownership to it.
            FrameBuffer::Ptr copy(new FrameBuffer(fb->size));
            copy->fb_id = fb->fb_id;
            copy->tex_id = fb->tex_id;
            fb->invalidate();

            fbvec[i] = copy;
            free_vec.push_back(copy);
        }
    }

    //cout << "reused " << reused_cnt << " buffers, " << reused_area << " pixels." << endl;
}

GLDrawSurface::GLDrawSurface(GLRenderer *renderer, GLuint ad_hoc_fb)
    : renderer(renderer), bbox(vec2(0,0), vec2(renderer->screen_size)), stack(NULL)
{
    if (ad_hoc_fb)
        fb = renderer->makeRootFrameBuffer(ad_hoc_fb);
    else
        fb = renderer->root_framebuffer;

    size = renderer->screen_size;
    bias = vec2(0.0f, 0.0f);
    isInitialized = true;
    used_crop_depth = GLRenderer::StencilNumCropLevels;
    crop_depth = 0;
}

GLDrawSurface::GLDrawSurface(GLRenderer *renderer, const GLBoundingBox &bbox_, FlowStackSnapshot *stack_)
    : renderer(renderer), bbox(bbox_), stack(stack_)
{
    bbox.roundOut();
    size = bbox.size();
    bias = vec2(0.0f, 0.0f);
    isInitialized = false;
    used_crop_depth = 0;
    crop_depth = 0;
}

GLDrawSurface::~GLDrawSurface()
{
    discard();
}

bool GLDrawSurface::isReady()
{
    return (isInitialized && fb && fb->isValid());
}

bool GLDrawSurface::isCompatible(GLDrawSurface *surf)
{
    return size == surf->size && bias == surf->bias;
}

bool GLDrawSurface::isCurrent()
{
    return isInitialized && fb == renderer->current_framebuffer;
}

void GLDrawSurface::makeCurrent()
{
    renderer->reportGLErrors("GLDrawSurface::makeCurrent start");

    if (!isInitialized)
        materialize();
    else if (fb != renderer->current_framebuffer)
    {
        renderer->makeFramebufferCurrent(fb, bias);
        updateCrop();
    }
}

void GLDrawSurface::materialize()
{
    if (isInitialized) return;

    if (!fb || !fb->isValid()) {
        fb = renderer->getFrameBuffer(size.x, size.y);

        if (fb->size == renderer->screen_size)
            bias = vec2(0.0f, 0.0f);
        else
            bias = glm::floor(bbox.min_pt - 0.5f*vec2(fb->size - size));

        fb->stack = stack;
    }

    renderer->makeFramebufferCurrent(fb, bias);

    renderer->reportGLErrors("GLDrawSurface::materialize pre clear");

    glStencilMask(GLuint(-1));
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    isInitialized = true;

    renderer->reportGLErrors("GLDrawSurface::materialize end");
}

void GLDrawSurface::reset()
{
    isInitialized = false;
    crop_stack.clear();
    used_crop_depth = 0;
    crop_depth = 0;
}

void GLDrawSurface::discard()
{
    isInitialized = false;
    if (fb && !fb->is_root)
        renderer->releaseFrameBuffer(fb);
    fb.reset();
    crop_stack.clear();
    used_crop_depth = 0;
    crop_depth = 0;
}

bool GLDrawSurface::isRetained()
{
    return isReady() && fb->retained_frame == renderer->getFrameIndex();
}

void GLDrawSurface::retain()
{
    if (!isReady()) return;

    fb->retained_frame = renderer->frame_idx;
    renderer->framebuffer_usage_tbl.insert(fb.get());
}

void GLDrawSurface::bindToTexture(GLenum tex_unit)
{
    renderer->makeFramebufferInput(fb, bias, tex_unit);
}

void GLDrawSurface::drawBBox()
{
    if (bbox.isEmpty || !isReady()) return;

    renderer->drawRect(bbox.min_pt, bbox.max_pt);
}

void GLDrawSurface::setScissor(const GLBoundingBox &bbox)
{
    vec2 minp = bbox.min_pt - bias;
    vec2 maxp = bbox.max_pt - bias;
    vec2 bsize = maxp - minp;
    double dpr = renderer->getDevicePixelRatio();
    glScissor(dpr*minp.x, dpr*(fb->size.y - maxp.y), dpr*(bsize.x), dpr*(bsize.y));
}

void GLDrawSurface::redrawCropStencil()
{
    glEnable(GL_STENCIL_TEST);

    if (used_crop_depth > crop_depth)
    {
        glDisable(GL_SCISSOR_TEST);
        int cmask = (1<<crop_depth)-1;
        glStencilMask((~cmask) & GLRenderer::StencilCropBits);
        glClear(GL_STENCIL_BUFFER_BIT);
        used_crop_depth = crop_depth;
    }

    mat3 save_matrix = renderer->u_cmatrix;

    glEnable(GL_SCISSOR_TEST);
    renderer->beginDrawSimple(vec4(0,0,0,0));

    for (size_t i = 0; i < crop_stack.size(); i++)
    {
        CropRect &item = crop_stack[i];

        if (item.depth > GLRenderer::StencilNumCropLevels)
            break;
        if (!item.is_rotated || item.depth <= crop_depth)
            continue;

        setScissor(item.clipbox);

        int bit = (1 << (item.depth-1));
        glStencilMask(bit);
        glStencilFunc(GL_NEVER, bit, 0);
        glStencilOp(GL_REPLACE,GL_REPLACE,GL_REPLACE);

        renderer->setCurMatrix(item.trf.forward);
        renderer->drawRect(item.bbox.min_pt, item.bbox.max_pt);

        used_crop_depth = crop_depth = item.depth;
    }

    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
    renderer->setCurMatrix(save_matrix);
}

void GLDrawSurface::updateCrop()
{
    if (crop_stack.empty())
    {
        glDisable(GL_SCISSOR_TEST);

        renderer->crop_depth = crop_depth = 0;
        renderer->resetStencilTest();
    }
    else
    {
        glEnable(GL_SCISSOR_TEST);

        CropRect &last = crop_stack.back();
        if (last.depth > crop_depth)
            redrawCropStencil();

        setScissor(last.clipbox);
        renderer->crop_depth = crop_depth;
        renderer->resetStencilTest();
    }
}

void GLDrawSurface::pushCropRect(const GLTransform &matrix, const GLBoundingBox &bbox)
{
    if (!isCurrent())
        makeCurrent();

    CropRect crop;
    crop.is_rotated = false;
    crop.depth = 0;
    crop.trf = matrix;
    crop.bbox = bbox;

    crop.clipbox = matrix * bbox;
    crop.clipbox.min_pt = glm::floor(crop.clipbox.min_pt);
    crop.clipbox.max_pt = glm::floor(crop.clipbox.max_pt);
    crop.bbox.max_pt += vec2(1.0f);

    if (!crop_stack.empty())
    {
        CropRect &prev = crop_stack.back();
        crop.depth = prev.depth;
        crop.clipbox &= prev.clipbox;
    }

    // check if visibly rotated
    if (crop.depth < GLRenderer::StencilNumCropLevels && !renderer->useWorkaround(GLRenderer::WorkaroundNoStencil))
    {
        vec2 dxp = toVec2(matrix * vec2(bbox.min_pt.x, bbox.max_pt.y)) - toVec2(matrix * bbox.min_pt);
        vec2 dyp = toVec2(matrix * vec2(bbox.max_pt.x, bbox.min_pt.y)) - toVec2(matrix * bbox.min_pt);

        bool horz = fabs(dxp.x) < 0.5f && fabsf(dyp.y) < 0.5f;
        bool vert = fabs(dxp.y) < 0.5f && fabsf(dyp.x) < 0.5f;

        if (!(horz || vert))
        {
            crop.is_rotated = true;
            crop.depth++;
        }
    }

    crop_stack.push_back(crop);
    updateCrop();
}

void GLDrawSurface::popCropRect()
{
    if (!crop_stack.empty())
        crop_stack.pop_back();

    crop_depth = std::min(crop_depth, crop_stack.empty() ? 0 : crop_stack.back().depth);

    if (isCurrent())
        updateCrop();
}

/* TEXTURE MANAGEMENT */

void GLRenderer::allocTexture(GLTextureImage *tximg)
{
    assert(!tximg->renderer);

    tximg->renderer = this;
    textures.insert(tximg);

    if (tximg->target == GL_TEXTURE_2D) {
        glGenTextures(1, &tximg->texture_id);
        glBindTexture(GL_TEXTURE_2D, tximg->texture_id);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

void GLRenderer::deleteTexture(GLTextureImage *tximg)
{
    assert(tximg->renderer == this);

    dead_textures.push_back(tximg->texture_id);
    textures.erase(tximg);

    tximg->renderer = NULL;
    tximg->texture_id = 0;
}

void GLRenderer::discardUnusedTextures()
{
    int total_size = 0, freed_size = 0;

    for (T_textures::iterator it = textures.begin(); it != textures.end(); )
    {
        GLTextureImage *tex = *it;
        ++it;

        int size = tex->size.x * tex->size.y;

        if (size > 256*256 && (frame_idx - tex->last_used_frame) >= 20)
        {
            deleteTexture(tex);
            freed_size += size;
        }
        else
            total_size += size;
    }

    if (freed_size > 0)
    {
        glDeleteTextures(dead_textures.size(), &dead_textures[0]);
        dead_textures.clear();

        cout << "Freed " << freed_size << " texture pixels, " << total_size << " alive." << endl;
    }
}


GLTextureImage::GLTextureImage(ivec2 size, bool flip) :
    swizzle_rb(false), renderer(NULL), target(GL_TEXTURE_2D), texture_id(0)
{
    setSize(size, flip);
}

void GLTextureImage::setSize(ivec2 size, bool flip)
{
    invalidate();

    this->size = size;
    this->flip = flip;

    pixel_size = vec2(1.0f/size.x, 1.0f/size.y);

    tex[0] = vec2(0.0f,0.0f);
    tex[1] = vec2(1.0f,1.0f);
    if (flip) {
        pixel_size.y = -pixel_size.y;
        std::swap(tex[0].y, tex[1].y);
    }
}

GLTextureImage::~GLTextureImage()
{
    invalidate();
}

void GLTextureImage::invalidate()
{
    if (renderer)
        renderer->deleteTexture(this);
}

void GLTextureImage::bindTo(GLRenderer *nrenderer)
{
    assert (!renderer || renderer == nrenderer);

    renderer->reportGLErrors("GLTextureImage::bindTo start");

    if (!renderer) {
        nrenderer->allocTexture(this);
        loadData();
    }
    else
        glBindTexture(target, texture_id);

    last_used_frame = nrenderer->frame_idx;

    renderer->reportGLErrors("GLTextureImage::bindTo end");
}

void GLTextureImage::loadTextureData(GLenum internal_fmt, GLenum data_fmt, GLenum data_type, const void *data)
{
    glTexImage2D(GL_TEXTURE_2D, 0, internal_fmt, size.x, size.y, 0, data_fmt, data_type, data);
    renderer->reportGLErrors("GLTextureImage::loadTextureData end");
}

void GLTextureImage::drawRect(GLRenderer *renderer, vec2 minv, vec2 maxv)
{
    bindTo(renderer);

    float coords[4*2] = {
        tex[0].x, tex[0].y,
        tex[1].x, tex[0].y,
        tex[0].x, tex[1].y,
        tex[1].x, tex[1].y
    };

    glEnableVertexAttribArray(GLRenderer::AttrVertexTexCoord);
    glVertexAttribPointer(GLRenderer::AttrVertexTexCoord, 2, GL_FLOAT, GL_FALSE, 0, coords);

    renderer->drawRect(minv, maxv);

    glDisableVertexAttribArray(GLRenderer::AttrVertexTexCoord);
}

void GLTextureImage::setSwizzleRB(bool swizzle)
{
    swizzle_rb = swizzle;
}

bool GLTextureImage::swizzleRB() const
{
    return swizzle_rb;
}

GLTextureBitmap::GLTextureBitmap(ivec2 size, GLenum format, bool flip, bool use_mipmaps, bool /*swizzleRB*/) :
    GLTextureImage(size, flip), format(format), use_mipmaps(use_mipmaps)
{
    bytes_per_pixel = getBytesPerPixel(format);
    reallocate(bytes_per_pixel * size.x * size.y);
}

unsigned GLTextureBitmap::getBytesPerPixel(GLenum format)
{
    switch (format) {
    case GL_FALSE:
        return 0;
    case GL_LUMINANCE:
    case GL_ALPHA:
        return 1;
    case GL_LUMINANCE_ALPHA:
        return 2;
    case GL_RGB:
        return 3;
    case GL_RGBA:
        return 4;
    case GL_UNSIGNED_SHORT_5_6_5:
    case GL_UNSIGNED_SHORT_5_5_5_1:
        return 2;
    default:
        assert(false);
        return 0;
    }
}

void GLTextureBitmap::loadData()
{
    if (format == GL_FALSE) {
        cerr << "GLTextureBitmap::loadData called on a stub." << endl;
        return;
    }

    if (format == GL_UNSIGNED_SHORT_5_5_5_1)
        loadTextureData(GL_RGBA, GL_RGBA, GL_UNSIGNED_SHORT_5_5_5_1, data.data());
    else if (format == GL_UNSIGNED_SHORT_5_6_5)
        loadTextureData(GL_RGB, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, data.data());
    else
        loadTextureData(format, format, GL_UNSIGNED_BYTE, data.data());

    if (use_mipmaps && is_pow2(getSize().x) && is_pow2(getSize().y)) {
        glGenerateMipmap(GL_TEXTURE_2D);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    }
}

void GLTextureBitmap::resize(ivec2 new_size, bool flip)
{
    setSize(new_size, flip);

    reallocate(bytes_per_pixel * new_size.x * new_size.y);
}

void GLTextureBitmap::share(GLTextureBitmap::Ptr other)
{
    if (!other) return;

    setSize(other->getSize(), other->getFlip());

    format = other->format;
    bytes_per_pixel = other->bytes_per_pixel;
    use_mipmaps = other->use_mipmaps;

    data = other->data;
}

void GLTextureBitmap::reallocate(size_t bytes)
{
    size_t old_bytes = data.size();
    if (bytes == old_bytes)
        return;

    StaticBuffer old = data;

    data.allocate(bytes, bytes > 64*1024);

    if (old_bytes > 0 || bytes > 0)
    {
        memcpy(data.writable_data(), old.data(), std::min(old_bytes, bytes));
        if (bytes > old_bytes)
            memset(data.writable_data() + old_bytes, 0, bytes-old_bytes);
    }
}

void GLTextureBitmap::compress()
{
    unsigned pixels = getSize().x * getSize().y;
    uint8_t * pixel_data = data.writable_data();

    if (format == GL_RGB) {
        format = GL_UNSIGNED_SHORT_5_6_5;
        for (unsigned i = 0; i < pixels; ++i) {
            uint16_t r = pixel_data[i * 3] >> 3;
            uint16_t g = pixel_data[i * 3 + 1] >> 2;
            uint16_t b = pixel_data[i * 3 + 2] >> 3;
            *(uint16_t*)(pixel_data + i * 2) = (r << 11) | (g << 5) | b;
        }
    } else if (format == GL_RGBA) {
        format = GL_UNSIGNED_SHORT_5_5_5_1;
        for (unsigned i = 0; i < pixels; ++i) {
            uint16_t r = pixel_data[i * 4] >> 3;
            uint16_t g = pixel_data[i * 4 + 1] >> 3;
            uint16_t b = pixel_data[i * 4 + 2] >> 3;
            uint16_t a = pixel_data[i * 4 + 3] != 0;
            *(uint16_t*)(pixel_data + i * 2) = (r << 11) | (g << 6) | (b << 1) | a;
        }
    } else {
        return;
    }

    bytes_per_pixel = getBytesPerPixel(format);
    reallocate(pixels * bytes_per_pixel);
}
