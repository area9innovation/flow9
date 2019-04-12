#ifndef GLRENDERER_H
#define GLRENDERER_H

#include "GLUtils.h"
#include "core/STLHelpers.h"

#include "core/ByteCodeRunner.h"

#define RENDERER_UNIFORMS \
    UNIFORM(s_tex) \
    UNIFORM(s_mask) \
    UNIFORM(u_out_pixel_size) \
    UNIFORM(u_out_offset) \
    UNIFORM(u_in_pixel_size) \
    UNIFORM(u_in_offset) \
    UNIFORM(u_cmatrix) \
    UNIFORM(u_mainColor) \
    UNIFORM(u_useTexture) \
    UNIFORM(u_swizzleRB) \
    UNIFORM(u_tex_shifts) \
    UNIFORM(u_gauss_shifts) \
    UNIFORM(u_gauss_steps) \
    UNIFORM(u_gauss_base_coeff) \
    UNIFORM(u_gauss_shift_coeff) \
    UNIFORM(u_local_blur_shift) \
    UNIFORM(u_filter_inner) \
    UNIFORM(u_shadow_color) \
    UNIFORM(u_bevel_color1) \
    UNIFORM(u_bevel_color2) \
    UNIFORM(u_font_dist_min) \
    UNIFORM(u_font_dist_coeff)

class GLDrawSurface;
class GLTextureImage;

class GLRenderer
{
    friend class GLDrawSurface;
    friend class GLTextureImage;

    /* SHADERS */

    enum ProgramId {
        ProgDrawSimple = 0,
        ProgDrawFancy,
        ProgDrawFancyExternalTexture,
        ProgDrawFont,
        ProgFilterMask,
        ProgFilterShadow,
        ProgFilterShadowBlur,
        ProgFilterBevel,
        ProgFilterBevelBlur,
        ProgGauss3x3,
        ProgGauss,
        ProgLAST
    };

    struct ProgramInfo {
        GLuint program_id;
        GLuint vert_shader_id;
        GLuint frag_shader_id;

#define UNIFORM(name) GLint name;
        RENDERER_UNIFORMS
#undef UNIFORM
    } programs[ProgLAST];

    bool compileShader(GLuint shader, const std::vector<std::string> &prefix, const char **list);

    bool doCompileShaderPair(ProgramId id, const char **vlist , const char **flist,
                           const std::vector<std::string> &prefix, int nattrs, ...);
    bool vdoCompileShaderPair(ProgramId id, const char **vlist, const char **flist,
                              const std::vector<std::string> &prefix,
                              int nattrs, va_list attrList);

    void compileShaderPair(ProgramId id, const char **vlist , const char **flist,
                           const std::vector<std::string> &prefix, int nattrs, ...);
    void vcompileShaderPair(ProgramId id, const char **vlist , const char **flist,
                            const std::vector<std::string> &prefix,
                            int nattrs, va_list attrList);

    void listUniforms(ProgramInfo *info);
    void compileShaders();

    /* SHADER STATE */

    int max_texture_size;
    ivec2 screen_size;

    ProgramId cur_program;

    mat3 u_cmatrix;
    unsigned program_u_cmatrix_set;

    vec2 u_out_pixel_size, u_out_offset;
    unsigned program_out_dim_set;
    vec2 u_in_pixel_size, u_in_offset;
    unsigned program_in_dim_set;

    void setProgram(ProgramId prog);

    /* FRAMEBUFFERS */

    struct FrameBuffer {
        typedef shared_ptr<FrameBuffer> Ptr;

        const ivec2 size;
        const vec2 pixel_size;
        const vec2 out_pixel_size;
        const vec2 out_offset;

        bool is_root;
        GLuint fb_id;
        GLuint tex_id;

        int retained_frame;

        FlowStackSnapshot *stack;

        FrameBuffer(ivec2 size)
            : size(size)
            , pixel_size(1.0f/size.x, -1.0f/size.y)
            , out_pixel_size(2.0f/size.x, -2.0f/size.y)
            , out_offset(size.x*0.5f, size.y*0.5f)
            , is_root(false), fb_id(0), tex_id(0), retained_frame(0), stack(0) {}

        bool isValid() { return is_root || fb_id != 0; }
        void dispose();
        void invalidate() { is_root = false; fb_id = tex_id = 0; }
    };

    typedef STL_HASH_MAP<ivec2, GLuint> T_stencil_buffers;
    typedef std::vector<FrameBuffer::Ptr> T_framebuffers;
    typedef STL_HASH_MAP<ivec2, T_framebuffers> T_framebuffer_map;

    GLenum fb_stencil_type, fb_stencil_attachment, fb_stencil_attachment2;

    T_stencil_buffers stencil_buffers;
    T_framebuffer_map all_framebuffers, free_framebuffers;

    STL_HASH_SET<FrameBuffer*, ptr_hash> framebuffer_usage_tbl;

    GLuint root_fb_id;
    double devicePixelRatio;

    FrameBuffer::Ptr root_framebuffer, current_framebuffer;

    FrameBuffer::Ptr makeRootFrameBuffer(GLuint id);
    ivec2 fitFrameBufferSize(int min_w, int min_h);
    FrameBuffer::Ptr getFrameBuffer(int min_w, int min_h);
    void releaseFrameBuffer(FrameBuffer::Ptr buffer);

    FrameBuffer::Ptr makeFrameBuffer(ivec2 size);
    bool chooseFramebufferMode();

    void disposeFrameBuffers(ivec2 size);
    void disposeAllFrameBuffers();
    void disposeUnusedFrameBuffers();
    void disposeUnusedFrameBuffers(T_framebuffers &vec);

    void makeFramebufferCurrent(FrameBuffer::Ptr buffer, vec2 bias);
    void makeFramebufferInput(FrameBuffer::Ptr buffer, vec2 bias, GLenum tex_unit = GL_TEXTURE0);

    /* TEXTURES */

    typedef STL_HASH_SET<GLTextureImage*, ptr_hash> T_textures;
    T_textures textures;
    std::vector<GLuint> dead_textures;

    void allocTexture(GLTextureImage *tximg);
    void deleteTexture(GLTextureImage *tximg);

    void discardUnusedTextures();

    /* MISC */

    int frame_idx, crop_depth;

    bool init_ok;
    std::string all_extensions;
    unsigned workarounds;

    void invalidateDependents();

    void beginFilter(GLDrawSurface *main, GLDrawSurface *mask);
    void initFilterBlur(float sigma);
    void endFilter(GLDrawSurface *main, GLDrawSurface *mask);
public:
    enum AttrId {
        AttrVertexPos = 0,
        AttrVertexColor = 1,
        AttrVertexTexCoord = 2
    };

    enum StencilBit {
        // Concave polygon rendering
        StencilDrawFill = 0x10,
        StencilDrawLine = 0x20,
        StencilDrawBits = 0x30,
        // Rotated crop
        StencilNumCropLevels = 4,
        StencilCropBits = 0xf
    };

    enum WorkaroundBit {
        WorkaroundNoStencil = 0x1 // Don't use the stencil buffer at all
    };

    bool useWorkaround(WorkaroundBit val) { return (workarounds & val) != 0; }

    GLRenderer(double devicePixelRatio = 1.0);
    ~GLRenderer();
    
    static void reportGLErrors(const char *where = NULL);
    static std::string getOpenGLInfo();
    static std::string getOpenGLExtensions();

    bool Init(GLuint root_fb = 0);
    bool isInitialized() { return init_ok; }

    void SetSize(int w, int h);
    ivec2 getSize() { return screen_size; }

    double getDevicePixelRatio() const { return devicePixelRatio; }
    // Invalidates all framebuffers
    void setDevicePixelRatio(double ratio);

    int getFrameIndex() { return frame_idx; }

    void BeginFrame();
    void CleanStaleObjectsPre();
    void InvalidateStaleRetainedBuffers();
    void CleanStaleObjectsPost();

    int getMaxTextureSize() { return max_texture_size; }

    void setCurMatrix(const mat3 &cmatrix);

    void beginDrawSimple(const vec4 &color);
    void beginDrawFancy(const vec4 &color, bool useTexture, bool swizzleRB = false);
    void beginDrawFancyExternalTexture(const vec4 &color);

    void beginDrawFont(float radius);

    void setAlphaMode(bool src_premultiplied);

    void drawRect(vec2 minv, vec2 maxv);

    void renderMask(GLDrawSurface *main, GLDrawSurface *mask);

    void renderShadow(GLDrawSurface *main, GLDrawSurface *mask, vec2 shift, vec4 color, bool inner, float sigma = -1);
    void renderBevel(GLDrawSurface *main, GLDrawSurface *mask, vec2 shift, vec4 color1, vec4 color2, bool inner, float sigma = -1);

    void renderLocalBlur(GLDrawSurface *input, float sigma);
    void renderBigBlur(GLDrawSurface *input, bool vertical, float base_coeff, int steps, float *deltas, float *coeffs);

    int getCropStencilMask(int *pval, int *pmask);
    void resetStencilTest(bool only_func = false);

    // For changing the root framebuffer id after initialization.
    // QOpenGLWidget requires this, for instance, since the default framebuffer id
    // is not available by the time we initialize OpenGL
    void setRootFramebufferId(GLuint id);
};

class GLDrawSurface {
    friend class GLRenderer;

    GLRenderer *renderer;
    GLBoundingBox bbox;
    ivec2 size;

    vec2 bias;
    bool isInitialized;
    GLRenderer::FrameBuffer::Ptr fb;

    FlowStackSnapshot *stack;

    struct CropRect {
        // scissor crop
        GLTransform trf;
        GLBoundingBox bbox, clipbox;
        // rotated mode
        bool is_rotated;
        char depth;
    };
    std::vector<CropRect> crop_stack;
    int used_crop_depth, crop_depth;

    void updateCrop();
    void redrawCropStencil();
    void setScissor(const GLBoundingBox &bbox);
public:
    GLDrawSurface(GLRenderer *renderer, GLuint ad_hoc_fb = 0); // ROOT surface
    GLDrawSurface(GLRenderer *renderer, const GLBoundingBox &bbox, FlowStackSnapshot *stack = NULL);
    ~GLDrawSurface();

    const GLBoundingBox &getBBox() { return bbox; }

    FlowStackSnapshot *getFlowStack() { return stack; }

    bool isReady();
    bool isCurrent();
    bool isCompatible(GLDrawSurface *surf);

    void makeCurrent();
    void materialize();

    void reset();
    void discard();

    void retain();
    bool isRetained();

    void bindToTexture(GLenum tex_unit);
    void drawBBox();

    void pushCropRect(const GLTransform &matrix, const GLBoundingBox &bbox);
    void popCropRect();
};

class GLTextureImage {
    friend class GLRenderer;

    ivec2 size;
    vec2 pixel_size, tex[2];
    bool flip;

    // For GLVIdeoClip, we may have to swizzle the red and blue components
    bool swizzle_rb;

    GLRenderer *renderer;
    int last_used_frame;
protected:
    GLenum target;
    GLuint texture_id;

    void setSize(ivec2 size, bool flip);
    void loadTextureData(GLenum internal_fmt, GLenum data_fmt, GLenum data_type, const void *data);

    virtual void loadData() = 0;

public:
    typedef shared_ptr<GLTextureImage> Ptr;

    GLTextureImage(ivec2 size, bool flip = false);
    virtual ~GLTextureImage();

    virtual bool isBitmap() { return false; } // is GLTextureBitmap
    virtual bool isStub() { return false; }   // contains no data
    bool isTexture2D() { return target == GL_TEXTURE_2D; }

    const ivec2 getSize() { return size; }
    bool getFlip() { return flip; }

    const vec2 getPixelSize() { return pixel_size; }
    const vec2 *getTexCoords() { return tex; }

    void invalidate();
    void bindTo(GLRenderer *renderer);

    void drawRect(GLRenderer *renderer, vec2 minv, vec2 maxv);

    void setSwizzleRB(bool swizzle);
    bool swizzleRB() const;
};

#ifndef GL_TEXTURE_EXTERNAL_OES
#define GL_TEXTURE_EXTERNAL_OES 0x8D65
#endif
class GLExternalTextureImage : public GLTextureImage {
protected:
    void loadData() {}
public:
	GLExternalTextureImage(ivec2 size, GLuint id) : GLTextureImage(size, false) { texture_id = id; target = GL_TEXTURE_EXTERNAL_OES; }
};

class GLTextureBitmap : public GLTextureImage {
    GLenum format;
    int bytes_per_pixel;
    bool use_mipmaps;

    StaticBuffer data;
    void reallocate(size_t bytes);

protected:
    virtual void loadData();

public:
    typedef shared_ptr<GLTextureBitmap> Ptr;

    GLTextureBitmap(ivec2 size, GLenum format, bool flip = false, bool use_mipmaps = false, bool swizzleRB = false);

    virtual bool isBitmap() { return true; }
    virtual bool isStub() { return format == GL_FALSE; }

    void share(GLTextureBitmap::Ptr other);

    void resize(ivec2 new_size, bool flip = false);

    static unsigned getBytesPerPixel(GLenum format);

    GLenum getDataFormat() { return format; }
    unsigned getBytesPerPixel() { return bytes_per_pixel; }

    unsigned char *getDataPtr() { return data.writable_data(); }
    unsigned getDataSize() { return data.size(); }
    
    void compress();
};

#endif // GLRENDERER_H
