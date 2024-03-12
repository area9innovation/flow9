#ifndef GLFONT_H
#define GLFONT_H

#include "font/Headers.h"
#include <ft2build.h>
#include FT_FREETYPE_H

#include "GLRenderer.h"
#include "GLRenderSupport.h"

// We shouldn't have so many GlyphInfos, so might be used as flag to save memory.
// Fallback font's ((is_fallback = true) methods ignore the flag.
// Others fonts' methods pass the work to the same methods of the fallback font.
#define FALLBACK_FLAG 0x40000000

// This struct describes mapping of one characters having glyph variants.
// Source character is hardcoded in the translating function, ‘form’ is a destination range start.
// So, assuming isolated glyph variant always exists, ‘form’ is its code.
// Second field, ‘mask’, is a bit field, if a corresponding glyph variant exists in the range.
struct TRANSLATION_UNIT { ucs4_char form; unsigned char mask; };

// All registered translations. If you add some, please do not forget to update getCharVariant function.
// Here source character (to be translated) is shown in comment at the line beginning.
static const TRANSLATION_UNIT TRANSLATION[] = {
    /* 0x0622      */ { 0xFE81, 3 },
    /* 0x0623      */ { 0xFE83, 3 },
    /* 0x0624      */ { 0xFE85, 3 },
    /* 0x0625      */ { 0xFE87, 3 },
    /* 0x0626      */ { 0xFE89, 15 },
    /* 0x0627 Alef */ { 0xFE8D, 3 },
    /* 0x0628      */ { 0xFE8F, 15 },
    /* 0x0629      */ { 0xFE93, 3 },
    /* 0x062A      */ { 0xFE95, 15 },
    /* 0x062B      */ { 0xFE99, 15 },
    /* 0x062C      */ { 0xFE9D, 15 },
    /* 0x062D      */ { 0xFEA1, 15 },
    /* 0x062E Khah */ { 0xFEA5, 15 },
    /* 0x062F Dal  */ { 0xFEA9, 3 },
    /* 0x0630      */ { 0xFEAB, 3 },
    /* 0x0631      */ { 0xFEAD, 3 },
    /* 0x0632      */ { 0xFEAF, 3 },
    /* 0x0633      */ { 0xFEB1, 15 },
    /* 0x0634      */ { 0xFEB5, 15 },
    /* 0x0635      */ { 0xFEB9, 15 },
    /* 0x0636      */ { 0xFEBD, 15 },
    /* 0x0637      */ { 0xFEC1, 15 },
    /* 0x0638 Zah  */ { 0xFEC5, 15 },
    /* 0x0639 Ain  */ { 0xFEC9, 15 },
    /* 0x063A      */ { 0xFECD, 15 },
    /* 0x0641      */ { 0xFED1, 15 },
    /* 0x0642      */ { 0xFED5, 15 },
    /* 0x0643      */ { 0xFED9, 15 },
    /* 0x0644 Lam  */ { 0xFEDD, 15 },
    /* 0x0645 Meem */ { 0xFEE1, 15 },
    /* 0x0646      */ { 0xFEE5, 15 },
    /* 0x0647      */ { 0xFEE9, 15 },
    /* 0x0648 Waw  */ { 0xFEED, 3 },
    /* 0x0649      */ { 0xFEEF, 3 },
    /* 0x064A Yeh  */ { 0xFEF1, 15 },

// Ligatures
    /* 0xFEF5      */ { 0xFEF5, 3 },
    /* 0xFEF7      */ { 0xFEF7, 3 },
    /* 0xFEF9      */ { 0xFEF9, 3 },
    /* 0xFEFB      */ { 0xFEFB, 3 },
};

// This struct describes ligatures that have to be applied before string rendering.
// Each ‘meaning’ (Z-terminated UTF-32 string) is to be replaced with single UTF-32 char ‘form’.
struct LIGATURE { const ucs4_char form; const ucs4_char meaning[3]; };

static const LIGATURE LIGATURES[] = {
    { 0xFEF5, { 0x644, 0x622, 0x0 }},
    { 0xFEF7, { 0x644, 0x623, 0x0 }},
    { 0xFEF9, { 0x644, 0x625, 0x0 }},
    { 0xFEFB, { 0x644, 0x627, 0x0 }},
};

class GLFont;
class GLRenderSupport;
typedef std::map<size_t, size_t> size_t2size_t;

class PasswordUtf32Iter: public Utf32InputIterator {
protected:
    shared_ptr<Utf32InputIterator> org, cur, nx, end;
    PasswordUtf32Iter& next();
public:
    PasswordUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end);
    PasswordUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end, Utf32InputIterator &cur);
    virtual size_t position() {return cur->position();}
    virtual void *data() {return org->data();}
    virtual ucs4_char operator *();
    virtual ucs4_char_tracer traceCurrent();
    virtual Utf32InputIterator &operator ++() {return next();}
    virtual Utf32InputIterator &operator ++(int)  {return next();}
    virtual shared_ptr<Utf32InputIterator> clone();
    virtual shared_ptr<Utf32InputIterator> cloneReversed();
    virtual void seekBegin() { cur = org->clone(); nx = org->clone(); ++*nx; };
    virtual void seekEnd() { cur = end->clone(); nx = org->clone(); };
};

class LigatureUtf32Iter: public Utf32InputIterator {
protected:
    typedef struct {
        shared_ptr<Utf32InputIterator> org, end;

        // There's way to optimize memory consuming
        // making this field static and adding mapping by org->data and usage counter.
        // This will keep single size_t->size_t map per origin, not per
        // LigatureUtf32Iter instance. Not forget to remove org->data key on last
        // LigatureUtf32Iter instance disposal.
        size_t2size_t reverseMap;

        virtual void *data() {return org->data();}
    } Shared;

    shared_ptr<Utf32InputIterator> cur, nx;
    size_t ligalen;  // input characters decoded count
    ucs4_char yieldedChar;

    LigatureUtf32Iter(shared_ptr<Shared> shared, shared_ptr<Utf32InputIterator> cur);

    void yieldSelf();
    LigatureUtf32Iter& next();

    void buildReverseMap();

    shared_ptr<Shared> shared;

    class Reversed: public Utf32InputIterator {
        friend class LigatureUtf32Iter;
    protected:
        shared_ptr<Shared> master;
        shared_ptr<Utf32InputIterator> cur, masterNx;

        Reversed(shared_ptr<Shared> master, shared_ptr<Utf32InputIterator> cur);
        Reversed& next();
    public:
        virtual size_t position() {return cur->position();}
        virtual void *data() {return master->data();}
        virtual ucs4_char operator *();
        virtual ucs4_char_tracer traceCurrent();
        virtual Utf32InputIterator &operator ++() {return next();}
        virtual Utf32InputIterator &operator ++(int)  {return next();}
        virtual shared_ptr<Utf32InputIterator> clone();
        virtual shared_ptr<Utf32InputIterator> cloneReversed();
        bool isEnd() {return *cur==*master->end;}
        virtual void seekEnd() { cur = master->end->cloneReversed(); };

        virtual ~Reversed(){};
    };


public:
    LigatureUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end);
    LigatureUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end, Utf32InputIterator &cur);
    virtual size_t position() {return cur->position();}
    virtual void *data() {return shared->data();}
    virtual ucs4_char operator *();
    virtual ucs4_char_tracer traceCurrent();
    static ucs4_char yield(Utf32InputIterator *cur, Utf32InputIterator *end, shared_ptr<Utf32InputIterator> *nx, size_t *ligalen);
    virtual Utf32InputIterator &operator ++() {return next();}
    virtual Utf32InputIterator &operator ++(int)  {return next();}
    virtual shared_ptr<Utf32InputIterator> clone();
    virtual shared_ptr<Utf32InputIterator> cloneReversed();
    bool isEnd() {return *cur==*shared->end;}
    virtual void seekBegin() { cur = shared->org->clone(); yieldSelf(); };
    virtual void seekEnd() { cur = shared->end->clone(); yieldSelf(); };
};


class GLFontLibrary
{
    friend class GLFont;

    STL_HASH_MAP<unicode_string, shared_ptr<GLFont> > Fonts;

    weak_ptr<GLFontLibrary> self;

    GLRenderSupport *owner;

    FT_Library library;

    static void reportError(FT_Error code)
    {
        switch (code) {
        case 0: break;
        case FT_Err_Unknown_File_Format:
            cerr << "Unknown font file format." << endl;
            break;

        default:
            cerr << "FreeType error " << code << endl;
        }
    }

    int max_texture_size;

    GLFontLibrary(GLRenderSupport *owner);

public:
    typedef shared_ptr<GLFontLibrary> Ptr;

    ~GLFontLibrary();

    static Ptr Load(GLRenderSupport *owner)
    {
        FT_Library library;
        FT_Error error = FT_Init_FreeType(&library);

        if (error) {
            reportError(error);
            return Ptr();
        }

        Ptr ptr(new GLFontLibrary(owner));
        ptr->self = ptr;
        
        ptr->library = library;
        
        return ptr;
    }

    void setMaxTextureSize(int max_size) { max_texture_size = max_size; }

    shared_ptr<GLFont> loadFont(TextFont textFont);
    shared_ptr<GLFont> loadNativeFont(std::string file);
};

class GLTextLayout;

class GLCompoundTexture : public GLTextureBitmap {
public:
    typedef shared_ptr<GLCompoundTexture> Ptr;

    static Ptr Make(int max_size, GLenum format)
    {
        Ptr obj(new GLCompoundTexture(max_size, format));
        obj->self = obj;
        return obj;
    }

    struct Item {
        typedef shared_ptr<Item> Ptr;
        GLCompoundTexture::Ptr texture;
        ivec2 pos, size;
        vec2 tex_points[2];
        float tex_coords[4*2];
    };

    Item::Ptr allocItem(ivec2 size);

private:
    GLCompoundTexture(int max_size, GLenum format);

    weak_ptr<GLCompoundTexture> self;
    std::vector<weak_ptr<Item> > items;
    int cur_row_height;
    ivec2 cur_row_pos;

    void resize(int new_size);
    void setTexCoords(Item::Ptr item);
};

class GLFont
{
    friend class GLFontLibrary;
    friend class GLTextLayout;
    friend class GLRenderSupport; // To give access to is_fallback

    weak_ptr<GLFont> self;

    GLFontLibrary::Ptr library;

    FT_Face face;
    
    bool is_freetype;
    bool is_system;
    bool is_fallback;
    TextFont text_font;
    StaticBuffer index_dat;

    const FontHeader *font_header;
    std::vector<GlyphHeader> glyph_headers;

    STL_HASH_MAP<ucs4_char, unsigned> unicode_charmap;
    unsigned default_glyph;

    int cur_system_idx, cur_emoji_idx;
    GLTextureBitmap::Ptr cur_system_grid, cur_emoji_grid;

    std::vector<GLTextureImage::Ptr> glyph_grids, emoji_grids;
    vec2 tex_tile_step, tex_active_tile, tex_origin;
    vec2 active_tile_size;

    float em_size_factor;
    float ascender, descender;
    float line_height, max_advance;
    float underline_position, underline_thickness;

    struct GlyphInfo {
        uint32_t id; //const is removed to use top bit as flag
        unsigned tile_id;
        vec2 bearing, size;
        float advance;

        GlyphInfo(uint32_t id, unsigned tile_id) : id(id), tile_id(tile_id) {}
    };

    struct GlyphBitmap {
        vec2 bearing;
        float advance;
        GLCompoundTexture::Item::Ptr bitmap;
        GlyphBitmap(vec2 bearing, float advance, GLCompoundTexture::Item::Ptr bitmap)
            : bearing(bearing), advance(advance), bitmap(bitmap) {}
    };

    typedef STL_HASH_MAP<ucs4_char, GlyphInfo*> T_glyphs;
    T_glyphs glyphs;

    struct Size {
        typedef shared_ptr<Size> Ptr;

        GLFont *font;

        const int pixels;
        FT_Size face_size;

        float ascender, descender;
        float line_height, max_advance;

        int texture_size;
        std::vector<GLCompoundTexture::Ptr> textures;

        typedef STL_HASH_MAP<ucs4_char, GlyphBitmap*> T_glyph_bitmaps;
        T_glyph_bitmaps glyph_bitmaps;

        Size(GLFont *font, int sz, FT_Size face_size);
        ~Size();

        GlyphBitmap *getGlyphBitmap(GlyphInfo *info);

    private:
        GlyphBitmap *loadGlyphBitmap(uint32_t id);
        GLCompoundTexture::Item::Ptr cacheBitmap(FT_Bitmap &bitmap);
    };

    std::map<uint32_t, Size::Ptr> sizes;

    std::string family_name;
    std::string style_name;
    bool has_kerning;

    unsigned loadSystemGlyph(ucs4_char char_code, bool force);

    GlyphInfo *getGlyphByChar(ucs4_char char_code);
    float getKerning(GlyphInfo *prev, GlyphInfo *cur);

    Size::Ptr getSize(int px_size);
    
    GLTextureImage::Ptr getGlyphTile(GlyphInfo *info, vec2 *bearing, vec2 *tcoord1, vec2 *tcoord2);
    GLTextureImage::Ptr loadGlyphGrid(unsigned grid_id);

    GLFont(GLFontLibrary::Ptr library, FT_Face face);
    GLFont(GLFontLibrary::Ptr library, StaticBuffer &data);
    GLFont(GLFontLibrary::Ptr library, const FontHeader &data);

    void initHeader();

public:
    typedef shared_ptr<GLFont> Ptr;

    ~GLFont();

    shared_ptr<GLTextLayout> layoutTextLine(Utf32InputIterator &strb, Utf32InputIterator &stre, float size, float width_limit = -1.0f, float spacing = 0.0f, bool crop_long_words = true, bool rtl = false);

    std::string getFamilyName() { return family_name; }
    std::string getStyleName() { return style_name; }
    float getAscender() { return ascender; }
};

enum CharDirection {LTR = '\0', RTL = '\1'};

class GLTextLayout {
    friend class GLFont;

protected:
    GLFont::Ptr font;

    float size, spacing;
    GLBoundingBox bbox;

    std::vector<size_t> char_indices;
    std::vector<unsigned char> char_counts;
    std::map<size_t, size_t> char_to_glyph_index;
    std::vector<GLFont::GlyphInfo*> glyphs;
    std::vector<float> positions;
    std::vector<CharDirection> directions;
    CharDirection direction;
    shared_ptr<Utf32InputIterator> endpos;

    GLTextLayout(GLFont::Ptr font, float size, bool rtl);

    void reverseGlyphRange(size_t b, size_t e);
    void buildLayout(shared_ptr<Utf32InputIterator> begin, shared_ptr<Utf32InputIterator> end, float width_limit, float spacing, bool crop_long_words);

    struct RenderPass {
        GLRectStrip pcoords;
        GLRectStrip tcoords;

        void reserve(int s) {
            if (!pcoords.size()) {
                pcoords.reserve(s);
                tcoords.reserve(s);
            }
        }
    };

    typedef std::map<GLTextureImage::Ptr, RenderPass> T_passes;
    T_passes passes;
    vec2 pass_origin, pass_adj_origin;
    float pass_scale;

    void computePasses(const GLTransform &transform, vec2 origin, vec2 adj_origin);
    void renderPasses(GLRenderer *renderer, const T_passes &passes, vec4 color, float alpha, float radius);

    static int getCharTranslationIdx(unicode_char chr) {
        int idx = -1;
        if (chr >  0x621 && chr <=  0x63A) idx = ((unsigned int) chr) + ( 0 -  0x622);
        if (chr >  0x640 && chr <=  0x64A) idx = ((unsigned int) chr) + (25 -  0x641);

        // Ligatures
        if (chr > 0xFEF4 && chr <= 0xFEFB) idx = (((unsigned int) chr) - 0xFEF5)/2 + 35;
        return idx;
    }

public:
    // In respect to https://en.wikipedia.org/wiki/Arabic_alphabet#Table_of_basic_letters
    enum GLYPH_VARIANT {
        GV_ISOLATED = 0,
        GV_FINAL = 1,
        GV_INITIAL = 2,
        GV_MEDIAL = 3,
    };

    typedef shared_ptr<GLTextLayout> Ptr;

    GLFont::Ptr getFont() { return font; }
    float getFontSize() { return size; }

    float getAscent() { return ceilf(font->ascender * size); }
    float getDescent() { return floorf(font->descender * size); }
    float getLineHeight() { return ceilf(font->line_height * size); }
    float getWidth() { return bbox.size().x; }

    shared_ptr<Utf32InputIterator> getEndPos() { return endpos; }
    const std::vector<float> &getPositions() { return positions; }
    const std::vector<CharDirection> &getDirections() { return directions; }
    double getGlyphAdvance(int glyphIdx) { return glyphIdx < 0 || glyphIdx >= int(glyphs.size()) ? 0.0 : glyphs[glyphIdx]->advance * size; }
    unsigned char getGlyphCharsCompo(int glyphIdx) {return glyphIdx < 0 || glyphIdx >= int(glyphs.size()) ? 0 : char_counts[glyphIdx]; }
    const std::vector<size_t> &getCharIndices() { return char_indices; }
    int getCharGlyphPositionIdx(int charidx);

    const GLBoundingBox &getBoundingBox() { return bbox; }

    static bool isDigit(ucs4_char c);  // Defined to work with 32 bits characters.
    static bool isWeakChar(ucs4_char c);
    static bool isRtlChar(ucs4_char c);
    static bool isLtrChar(ucs4_char c);
    static ucs4_char tryMirrorChar(ucs4_char code);
    static bool isCharCombining(ucs4_char chr) {
        return
            (chr >= 0x300 && chr < 0x370) || (chr >= 0x483 && chr < 0x488) || (chr >= 0x591 && chr < 0x5C8) ||
            (chr >= 0x610 && chr < 0x61B) || (chr >= 0x64B && chr < 0x660) || (chr == 0x670) ||
            (chr >= 0x6D6 && chr < 0x6EE) || (chr == 0x711) || (chr >= 0x730 && chr < 0x7F4) ||
            (chr >= 0x816 && chr < 0x82E) || (chr >= 0x859 && chr < 0x85C) || (chr >= 0x8D4 && chr < 0x903) ||
            (chr >= 0x93A && chr < 0x93D) || (chr >= 0x941 && chr < 0x94E) || (chr >= 0x951 && chr < 0x958) ||
            (chr >= 0x962 && chr < 0x964) || (chr == 0x981) || (chr == 0x9BC) || (chr >= 0x9C1 && chr < 0x9C5) ||
            (chr == 0x9BC) || (chr >= 0x9E2 && chr < 0x9E3) || (chr >= 0xA01 && chr < 0xA03) || (chr == 0xA3C) ||
            (chr >= 0xA41 && chr < 0xA43) || (chr >= 0xA47 && chr < 0xA49) || (chr >= 0xA4B && chr < 0xA4E) ||
            (chr == 0xA51) || (chr >= 0xA70 && chr < 0xA72) || (chr == 0xA75) || (chr >= 0xA81 && chr < 0xA83) ||
            (chr == 0xABC) || (chr >= 0xAC1 && chr < 0xACE) || (chr >= 0xAE2 && chr < 0xAE4) ||
            (chr >= 0xAFA && chr < 0xB00) || (chr == 0xB01) || (chr == 0xB3C) || (chr == 0xB3F) ||
            (chr >= 0xB41 && chr < 0xB45) || (chr == 0xB4D) || (chr == 0xB56) || (chr >= 0xB62 && chr < 0xB64) ||
            (chr == 0xB82) || (chr == 0xBC0) || (chr == 0xBCD) || (chr == 0xC00) ||
            (chr >= 0xC3E && chr < 0xC41) || (chr >= 0xC46 && chr < 0xC4E && chr != 0xC49) ||
            (chr >= 0xC55 && chr < 0xC57) || (chr >= 0xC62 && chr < 0xC64) || (chr == 0xC81) || (chr == 0xCBC) ||
            (chr == 0xCBF) || (chr == 0xCC6) || (chr >= 0xCCC && chr < 0xCCE) || (chr >= 0xCE2 && chr < 0xCE4) ||
            // TODO add ranges from 0xD00..0x1AB0 from http://www.fileformat.info/info/unicode/category/Mn/list.htm
            (chr >= 0x1AB0 && chr < 0x1B00);
    }

    static ucs4_char getCharVariantsMask(ucs4_char chr) {
        int idx = getCharTranslationIdx(chr);
        if (idx<0) return 1;
        return TRANSLATION[idx].mask;
    }

    static ucs4_char getCharVariant(ucs4_char chr, GLYPH_VARIANT gv) {
        int idx = getCharTranslationIdx(chr);
        if (idx<0) return chr;

        // Assume isolated form (bit 0 of mask) always present, otherwise code amending needed.
        // Another assumption is glyphs exist without gaps: ISOLATED, FINAL, INITIAL, MEDIAL.
        // So, if MEDIAL exists, others do. If INITIAL exists, FINAL does.
        char tr_gv = (char)gv;
        char mask = getCharVariantsMask(chr);
        if (0==((mask >> tr_gv) & 1)) tr_gv &= -3;
        if (0==((mask >> tr_gv) & 1)) tr_gv &= -2;
        return TRANSLATION[idx].form + tr_gv;
    }

    int findIndexByPos(float x, bool nearest = false);

    ~GLTextLayout();

    void render(GLRenderer *renderer, const GLTransform &transform,
                vec2 origin, vec2 adj_origin, vec4 color, float alpha, bool underline = false);
};

void smoothFontBitmap(const FontHeader *header, StaticBuffer *pixels, const uint8_t *input = NULL, int input_size_mul = 1);

#endif // GLFONT_H
