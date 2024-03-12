#include "GLFont.h"
#include "GLRenderSupport.h"
#include "core/CommonTypes.h"

#include FT_SIZES_H
#include FT_GLYPH_H

#include <zlib.h>

#include <deque>
#include <stdio.h>

#include <glm/gtc/type_ptr.hpp>

inline float ftToFloat(int v) {
    return v / 64.0f;
}


PasswordUtf32Iter::PasswordUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end) {
    this->org = org.clone();
    this->cur = org.clone();
    this->nx = org.clone();
    this->end = end.clone();
    ++*nx;
}
PasswordUtf32Iter::PasswordUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end, Utf32InputIterator &cur) {
    this->org = org.clone();
    this->cur = cur.clone();
    this->nx = cur.clone();
    this->end = end.clone();
    ++*nx;
}

ucs4_char PasswordUtf32Iter::operator *() {
    return *cur == *end? 0: 0x2022;
}

ucs4_char_tracer PasswordUtf32Iter::traceCurrent() {
    return ucs4_char_tracer(cur->position(), nx->position(), **this);
}

PasswordUtf32Iter& PasswordUtf32Iter::next() {
    cur = nx;
    nx = nx->clone();
    ++*nx;
    return *this;
}

shared_ptr<Utf32InputIterator> PasswordUtf32Iter::clone() {
    shared_ptr<Utf32InputIterator> r(new PasswordUtf32Iter(*this->org, *this->end, *this->cur));
    return r;
}

shared_ptr<Utf32InputIterator> PasswordUtf32Iter::cloneReversed() {
    shared_ptr<Utf32InputIterator> r(new PasswordUtf32Iter(*this->org->cloneReversed(), *this->end->cloneReversed(), *this->cur->cloneReversed()));
    return r;
}

void LigatureUtf32Iter::yieldSelf() {
    yieldedChar = yield(&*cur, &*shared->end, &nx, &ligalen);
}

ucs4_char LigatureUtf32Iter::yield(
    Utf32InputIterator *cur, Utf32InputIterator *end,
    shared_ptr<Utf32InputIterator> *nx, size_t *ligalen
) {
    if (*cur == *end) {
        *ligalen = 1;
        *nx = cur->clone();
        ++**nx;
        return **end;
    }
    int ligacnt = (sizeof LIGATURES)/(sizeof *LIGATURES);
    std::vector<size_t> matchlengths(ligacnt, 0);
    int ligai;
    *ligalen = 0;
    bool anyCandidate = true;
    *nx = cur->clone();
    for (**nx; anyCandidate && **nx!=*end; ++**nx, ++*ligalen) {
        anyCandidate = false;
        for (ligai=0; ligai<ligacnt; ++ligai) {
            if (matchlengths[ligai] != *ligalen) continue;
            anyCandidate = true;
            if (***nx == LIGATURES[ligai].meaning[matchlengths[ligai]])
                ++matchlengths[ligai];
            if (!LIGATURES[ligai].meaning[matchlengths[ligai]]) {
                ++**nx;
                return LIGATURES[ligai].form;
            }
        }
    }
    // No ligature match
    *ligalen = 1;
    *nx = cur->clone();
    ++**nx;
    return **cur;
}

LigatureUtf32Iter& LigatureUtf32Iter::next() {
    cur = nx;
    yieldSelf();
    return *this;
}

LigatureUtf32Iter::LigatureUtf32Iter(shared_ptr<Shared> shared, shared_ptr<Utf32InputIterator> cur):
    cur(cur), nx(cur->clone()), shared(shared)
{
    yieldSelf();
}
LigatureUtf32Iter::LigatureUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end):
    cur(org.clone()), nx(org.clone()), shared(new LigatureUtf32Iter::Shared())
{
    shared->org = org.clone();
    shared->end = end.clone();
    yieldSelf();
}

LigatureUtf32Iter::LigatureUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end, Utf32InputIterator &cur):
    cur(cur.clone()), nx(cur.clone()), shared(new LigatureUtf32Iter::Shared())
{
    shared->org = org.clone();
    shared->end = end.clone();
    yieldSelf();
}

void LigatureUtf32Iter::buildReverseMap() {
    if (shared->reverseMap.size()) return;
    shared_ptr<LigatureUtf32Iter> passer;
    passer.reset(new LigatureUtf32Iter(*this->shared->org, *this->shared->end));
    shared_ptr<Utf32InputIterator> probe;
    while (*passer->cur != *this->shared->end) {
        probe = passer->cur->clone();
        ++*probe;
        if (*probe != *passer->nx) shared->reverseMap[passer->nx->position()] = passer->cur->position();
        ++*passer;
    }

    // Just any valid key-value pair to make map non-empty.
    if (!shared->reverseMap.size())
        shared->reverseMap[shared->org->position()] = shared->end->position();
}

ucs4_char LigatureUtf32Iter::operator *() {
    return yieldedChar;
}

ucs4_char_tracer LigatureUtf32Iter::traceCurrent() {
    return ucs4_char_tracer(cur->position(), nx->position(), yieldedChar);
}

shared_ptr<Utf32InputIterator> LigatureUtf32Iter::clone() {
    shared_ptr<Utf32InputIterator> r(new LigatureUtf32Iter(shared, cur->clone()));
    return r;
}

shared_ptr<Utf32InputIterator> LigatureUtf32Iter::cloneReversed() {
    buildReverseMap();
    shared_ptr<Utf32InputIterator> r(new LigatureUtf32Iter::Reversed(shared, cur->cloneReversed()));
    return r;
}

LigatureUtf32Iter::Reversed& LigatureUtf32Iter::Reversed::next() {
    size_t2size_t::iterator mappedNx = master->reverseMap.find(cur->position());
    ++*cur;
    if (mappedNx != master->reverseMap.end())
        while (*cur != *master->end && mappedNx->second != cur->position()) ++*cur;
    return *this;
}

LigatureUtf32Iter::Reversed::Reversed(shared_ptr<Shared> master, shared_ptr<Utf32InputIterator> cur) {
    this->master = master;
    this->cur = cur;
}

ucs4_char LigatureUtf32Iter::Reversed::operator *() {
    size_t ligalen;
    return LigatureUtf32Iter::yield(&*cur->cloneReversed(), &*master->end, &masterNx, &ligalen);
}

ucs4_char_tracer LigatureUtf32Iter::Reversed::traceCurrent() {
    ucs4_char r = **this;
    return ucs4_char_tracer(cur->position(), masterNx->position(), r);
}

shared_ptr<Utf32InputIterator> LigatureUtf32Iter::Reversed::clone() {
    shared_ptr<Utf32InputIterator> r(new LigatureUtf32Iter::Reversed(master, cur->clone()));
    return r;
}
shared_ptr<Utf32InputIterator> LigatureUtf32Iter::Reversed::cloneReversed() {
    return shared_ptr<Utf32InputIterator>(new LigatureUtf32Iter(*master->org, *master->end, *cur->cloneReversed()));
}


GLFontLibrary::GLFontLibrary(GLRenderSupport *owner) : owner(owner)
{
    max_texture_size = 64;
}

GLFontLibrary::~GLFontLibrary()
{
    FT_Done_FreeType(library);
}

GLFont::Ptr GLFontLibrary::loadNativeFont(std::string file)
{
    FT_Face face;
    FT_Error error = FT_New_Face(library, file.c_str(), 0, &face);

    if (error) {
        cerr << "Couldn't load " << file << endl;
        reportError(error);
        return GLFont::Ptr();
    }

    if (!FT_IS_SCALABLE(face)) {
        cerr << "Not a scalable font - unsupported: " << file << endl;
        FT_Done_Face(face);
        return GLFont::Ptr();
    }

    GLFont::Ptr ptr(new GLFont(self.lock(), face));
    
    ptr->self = ptr;
    return ptr;
}

GLFont::Ptr GLFontLibrary::loadFont(TextFont textFont)
{
    StaticBuffer data;
    GLFont::Ptr ptr;

    if (owner->loadAssetData(&data, textFont.family + textFont.suffix() + "/index.dat", StaticBuffer::AUTO_SIZE)) {
        FontHeader *header = (FontHeader*)data.data();

        if (header->magic != FontHeader::MAGIC ||
            header->hdr_size != sizeof(FontHeader) ||
            header->glyph_hdr_size != sizeof(GlyphHeader))
        {
            cerr << "Invalid font format: " << textFont.family << endl;
            return GLFont::Ptr();
        }

        ptr = GLFont::Ptr(new GLFont(self.lock(), data));
    } else {
        FontHeader header;
        memset(&header, 0, sizeof(header));

        if (!owner->loadSystemFont(&header, textFont)) {
            cerr << "Couldn't load " << textFont.family << endl;
            return GLFont::Ptr();
        }

        ptr = GLFont::Ptr(new GLFont(self.lock(), header));
    }

    ptr->text_font = textFont;

    ptr->self = ptr;
    return ptr;
}

// COMPOUND TEXTURE

GLCompoundTexture::GLCompoundTexture(int max_size, GLenum format) :
    GLTextureBitmap(ivec2(max_size, 8), format)
{
    cur_row_height = 0;
    cur_row_pos = ivec2(1,1);
}

GLCompoundTexture::Item::Ptr GLCompoundTexture::allocItem(ivec2 size)
{
    int tex_size = getSize().x;
    ivec2 rsize = ivec2(tex_size-1) - cur_row_pos;

    if (size.x > tex_size-2 || size.y > rsize.y)
        return Item::Ptr();

    if (size.x > rsize.x) {
        int ylsize = rsize.y - cur_row_height - 1;
        if (size.y > ylsize)
            return Item::Ptr();

        cur_row_pos = ivec2(1, cur_row_pos.y + cur_row_height + 1);
        cur_row_height = 0;
    }

    Item::Ptr nitem(new Item());
    nitem->texture = self.lock();
    nitem->pos = cur_row_pos;
    nitem->size = size;

    cur_row_pos.x += size.x + 1;
    cur_row_height = std::max(cur_row_height, size.y);

    resize(cur_row_pos.y + cur_row_height + 1);

    setTexCoords(nitem);
    items.push_back(nitem);
    return nitem;
}

void GLCompoundTexture::setTexCoords(Item::Ptr item)
{
    if (!item) return;
    vec2 tc0 = getTexCoords()[0];
    vec2 px = getPixelSize();
    vec2 c0 = item->tex_points[0] = tc0 + vec2(item->pos)*px;
    vec2 c1 = item->tex_points[1] = tc0 + vec2(item->pos + item->size)*px;
    float coords[4 * 2] = {
        c0.x, c0.y, c1.x, c0.y,
        c0.x, c1.y, c1.x, c1.y
    };
    memcpy(item->tex_coords, coords, sizeof(coords));
}

void GLCompoundTexture::resize(int new_size)
{
    ivec2 size = getSize();
    if (new_size <= size.y)
        return;

    int height = size.y;
    while (height < new_size)
        height *= 2;

    GLTextureBitmap::resize(ivec2(size.x, height));

    for (unsigned i = 0; i < items.size(); ++i)
        setTexCoords(items[i].lock());
}

// FONT

GLFont::GLFont(GLFontLibrary::Ptr library, FT_Face face) :
    library(library), face(face)
{
    is_freetype = true;
    
    FontHeader* header = new FontHeader();
    
    family_name = std::string(face->family_name);
    style_name = std::string(face->style_name);
    
    header->render_em_size = face->units_per_EM;
    em_size_factor = 1.0f / face->units_per_EM;
    ascender = header->ascender = face->ascender * em_size_factor;
    descender = header->descender = face->descender * em_size_factor;
    line_height = header->line_height = face->height * em_size_factor;
    max_advance = header->max_advance = face->max_advance_width * em_size_factor;
    
    underline_position = header->underline_position = face->underline_position * em_size_factor;
    underline_thickness = header->underline_thickness = face->underline_thickness * em_size_factor;
    
    font_header = header;

    has_kerning = FT_HAS_KERNING(face);
}

void GLFont::initHeader()
{
    em_size_factor = 1.0f;
    ascender = font_header->ascender;
    descender = font_header->descender;
    line_height = font_header->line_height;
    max_advance = font_header->max_advance;

    underline_position = font_header->underline_position;
    underline_thickness = font_header->underline_thickness;

    has_kerning = false;

    // texture coordinates
    float rpx_size = 1.0f/font_header->grid_px_size;
    vec2 rpx_size_v = vec2(rpx_size, rpx_size);
    tex_tile_step = rpx_size_v*float(font_header->tile_size);
    tex_active_tile = rpx_size_v*float(font_header->tile_size-2);
    tex_origin = rpx_size_v;
    active_tile_size = vec2(font_header->active_tile_size);
}

GLFont::GLFont(GLFontLibrary::Ptr library, StaticBuffer &data) :
    library(library)
{
    is_system = false;
    is_freetype = false;
    is_fallback = false;
    index_dat = data;

    font_header = (FontHeader*)index_dat.data();
    glyph_headers = std::vector<GlyphHeader>();
    const GlyphHeader* headers = (const GlyphHeader*)(index_dat.data() + sizeof(FontHeader));
    glyph_headers.assign(headers, headers + font_header->glyph_count);

    initHeader();

    glyph_grids.resize(font_header->grid_count);

    // Build a character code lookup table
    for (unsigned i = 0; i < font_header->glyph_count; i++)
        unicode_charmap[glyph_headers[i].unicode_char] = i+1;

    // Ensure an invalid char exists
    default_glyph = unicode_charmap[UNICODE_INVALID_CHAR];
    if (!default_glyph)
        default_glyph = unicode_charmap[' '];
    if (!default_glyph)
        default_glyph = 1;
}

GLFont::GLFont(GLFontLibrary::Ptr library, const FontHeader &header) :
    library(library)
{
    is_system = true;
    is_freetype = false;
    index_dat.allocate(sizeof(FontHeader), false);

    FontHeader *hdr = (FontHeader*)index_dat.data();
    font_header = hdr;
    glyph_headers = std::vector<GlyphHeader>();

    *hdr = header;

    hdr->grid_count = 0;
    hdr->grid_px_size = hdr->grid_size * hdr->tile_size;
    hdr->grid_glyph_cnt = hdr->grid_size * hdr->grid_size;

    initHeader();

    default_glyph = 0;
}

GLFont::~GLFont()
{
    for (T_glyphs::iterator it = glyphs.begin(); it != glyphs.end(); ++it)
        delete it->second;

    sizes.clear();

    FT_Done_Face(face);
}

GLFont::Size::Size(GLFont *font, int sz, FT_Size face_size) :
    font(font), pixels(sz), face_size(face_size)
{
    ascender = ftToFloat(face_size->metrics.ascender);
    descender = ftToFloat(face_size->metrics.descender);
    line_height = ftToFloat(face_size->metrics.height);
    max_advance = ftToFloat(face_size->metrics.max_advance);

    texture_size = std::min(512, font->library->max_texture_size);
    while (((texture_size-1) / (sz + 1)) > 16)
        texture_size /= 2;
}

GLFont::Size::~Size()
{
    for (T_glyph_bitmaps::iterator it = glyph_bitmaps.begin(); it != glyph_bitmaps.end(); ++it)
        delete it->second;

    FT_Done_Size(face_size);
}

GLFont::GlyphBitmap *GLFont::Size::getGlyphBitmap(GLFont::GlyphInfo *info)
{
    if (!info) return NULL;

//    if ((info->id & FALLBACK_FLAG) && !is_fallback && font->library->owner->FallbackFont) {
//       return font->library->owner->FallbackFont->getGlyphBitmap(info);
//    }

    const uint32_t id = info->id & ~FALLBACK_FLAG;

    T_glyph_bitmaps::iterator it = glyph_bitmaps.find(id);
    if (it != glyph_bitmaps.end())
        return it->second;

    GLFont::GlyphBitmap *&obj = glyph_bitmaps[id];
    if (!obj)
        obj = loadGlyphBitmap(id);
    return obj;
}

GLFont::GlyphBitmap *GLFont::Size::loadGlyphBitmap(uint32_t id)
{
    FT_Error error;
    FT_Face face = font->face;

    FT_Activate_Size(face_size);

    error = FT_Load_Glyph(face, id, FT_LOAD_RENDER);
    if (error) {
        GLFontLibrary::reportError(error);
        return NULL;
    }

    float advance = ftToFloat(face->glyph->metrics.horiAdvance);
    vec2 bearing(face->glyph->bitmap_left, -face->glyph->bitmap_top);

    return new GlyphBitmap(bearing, advance, cacheBitmap(face->glyph->bitmap));
}

GLCompoundTexture::Item::Ptr GLFont::Size::cacheBitmap(FT_Bitmap &bitmap)
{
    assert (bitmap.pixel_mode == FT_PIXEL_MODE_GRAY);

    ivec2 size = glm::min(ivec2(bitmap.width, bitmap.rows), ivec2(texture_size-2));

    GLCompoundTexture::Item::Ptr item;

    for (unsigned i = 0; i < textures.size(); i++) {
        item = textures[i]->allocItem(size);
        if (item)
            break;
    }

    if (!item) {
        textures.push_back(GLCompoundTexture::Make(texture_size, GL_ALPHA));
        item = textures.back()->allocItem(size);
        assert(item);
    }

    GLCompoundTexture::Ptr ptr = item->texture;

    unsigned char *data = ptr->getDataPtr() + item->pos.x + item->pos.y * texture_size;
    unsigned char *input = bitmap.buffer;

    for (int y = 0; y < item->size.y; y++) {
        for (int x = 0; x < item->size.x; x++)
            data[x] = input[x]*255/(bitmap.num_grays-1);
        data += texture_size;
        input += bitmap.pitch;
    }

    ptr->invalidate();
    return item;
}

GLFont::Size::Ptr GLFont::getSize(int px_size)
{
    Size::Ptr &ptr = sizes[px_size];
    if (ptr)
        return ptr;

    FT_Size size;
    FT_New_Size(face, &size);
    FT_Activate_Size(size);

    FT_Error error = FT_Set_Pixel_Sizes(face, px_size, px_size);
    if (error) {
        GLFontLibrary::reportError(error);
        return Size::Ptr();
    }

    return ptr = Size::Ptr(new Size(this, px_size, size));
}

unsigned GLFont::loadSystemGlyph(ucs4_char char_code, bool force)
{
    StaticBuffer pixels;
    GlyphHeader header;
    memset(&header, 0, sizeof(header));

    unsigned size = font_header->tile_size*font_header->tile_size;
    bool ok = library->owner->loadSystemGlyph(font_header, &header, &pixels, text_font, char_code);

    bool isUtf32Glyph = header.unicode_char > 0xFFFF;
    short scale = isUtf32Glyph ? 3 : 1;
    short bytesSizeScale = isUtf32Glyph ? 4 : 1;

    if (!ok || (pixels.size() != size * bytesSizeScale * scale * scale)) {
        if (ok)
            cout << "Invalid pixel tile size: " << pixels.size() << endl;
        if (!force)
            return 0;

        pixels.allocate(size * bytesSizeScale * scale * scale, false);
        memset(&header, 0, sizeof(header));
        header.unicode_char = char_code;
        header.advance = font_header->max_advance;
    }

    unsigned idx = glyph_headers.size();
    glyph_headers.push_back(header);

    int& current_grid_idx = isUtf32Glyph ? cur_emoji_idx : cur_system_idx;
    GLTextureBitmap::Ptr& current_glyph_grid = isUtf32Glyph ? cur_emoji_grid : cur_system_grid;
    std::vector<GLTextureImage::Ptr>& grids = isUtf32Glyph ? emoji_grids : glyph_grids;

    if (!current_glyph_grid) {
        unsigned glMode = isUtf32Glyph ? GL_RGBA : GL_ALPHA;
        GLTextureBitmap::Ptr bmp(new GLTextureBitmap(ivec2(font_header->grid_px_size * scale), glMode, false));
        bmp->setSwizzleRB(isUtf32Glyph);

        memset(bmp->getDataPtr(), 0, bmp->getDataSize());

        current_glyph_grid = bmp;
        current_grid_idx = 0;

        grids.push_back(static_pointer_cast<GLTextureImage>(bmp));
    }

    unsigned tile_idx = current_grid_idx++;

    unsigned xoff = bytesSizeScale * scale * font_header->tile_size * (tile_idx % font_header->grid_size);
    unsigned yoff = bytesSizeScale * scale * scale * font_header->grid_px_size * font_header->tile_size * (tile_idx / font_header->grid_size);

    const uint8_t *ppix = pixels.data();
    unsigned char *pgrid = current_glyph_grid->getDataPtr() + yoff + xoff;

    for (int y = 0; y < font_header->tile_size * scale; y++, pgrid += bytesSizeScale * scale * font_header->grid_px_size)
        for (int x = 0; x < bytesSizeScale * scale * font_header->tile_size; x++)
            pgrid[x] = *ppix++;

    current_glyph_grid->invalidate();

    if (current_grid_idx >= font_header->grid_size * font_header->grid_size)
        current_glyph_grid.reset();

    return unicode_charmap[char_code] = idx+1;
}

GLFont::GlyphInfo *GLFont::getGlyphByChar(ucs4_char char_code)
{
    if ((char_code|1) == 0x200F || ((char_code-0x202A)|3) == 3 || ((char_code-0x2066)|3) == 3) char_code = 0x200B;
    int idx = unicode_charmap[char_code];
    if (!idx && is_system)
        idx = loadSystemGlyph(char_code, false);
    if (!idx && is_freetype)
        idx = FT_Get_Char_Index(face, char_code);
    if (!idx && !is_fallback) {
        GLFont::Ptr fallbackFont = library->owner->FallbackFont;
        if (fallbackFont) {
            GlyphInfo *ptr = fallbackFont->getGlyphByChar(char_code);
            if (ptr) {
                if (!(ptr->id & FALLBACK_FLAG)) {
                    cerr << "Glyph " << hex << char_code << dec << " is found in fallback font" << endl;
                    ptr->id = ptr->id | FALLBACK_FLAG;
                }
                return ptr;
            }
        }
    }
    if (!idx) {
        cout << "Unknown glyph " << hex << char_code << dec << endl;
        if (is_system && !default_glyph)
            default_glyph = loadSystemGlyph(UNICODE_INVALID_CHAR, true);
        idx = unicode_charmap[char_code] = default_glyph;
        char_code = UNICODE_INVALID_CHAR;
    }
    
    if (!is_freetype) {
        idx--;
    }

    GlyphInfo *&ptr = glyphs[idx];
    if (!ptr) {
        
        bool isUtf32Glyph = is_system && glyph_headers[idx].unicode_char > 0xFFFF;
        unsigned tile_id = is_system ?
                                ((
                                    isUtf32Glyph ?
                                        (emoji_grids.size() - 1) * font_header->grid_glyph_cnt + cur_emoji_idx
                                        : (glyph_grids.size() - 1) * font_header->grid_glyph_cnt + cur_system_idx
                                ) - 1)
                                : idx;
        ptr = new GlyphInfo(idx, tile_id);
        
        if (is_freetype) {
            FT_Error error = FT_Load_Glyph(face, idx, FT_LOAD_NO_SCALE);
            if (error) {
                GLFontLibrary::reportError(error);
                return NULL;
            }

            FT_Glyph_Metrics &metrics = face->glyph->metrics;
            
            ptr->bearing = vec2(metrics.horiBearingX, -metrics.horiBearingY) * em_size_factor;
            ptr->size = vec2(metrics.width,metrics.height) * em_size_factor;
            ptr->advance = metrics.horiAdvance * em_size_factor;
        } else {
            ptr->bearing = vec2(glyph_headers[idx].bearing_x, glyph_headers[idx].bearing_y);
            ptr->size = vec2(glyph_headers[idx].size_x, glyph_headers[idx].size_y);
            ptr->advance = glyph_headers[idx].advance;
        }
    }

    return ptr;
}

float GLFont::getKerning(GlyphInfo *prev, GlyphInfo *cur)
{
    if (is_freetype) {
        if (!has_kerning || !prev || !cur)
            return 0.0f;

        FT_Vector delta;
        FT_Get_Kerning(face, prev->id, cur->id, FT_KERNING_UNSCALED, &delta);

        return delta.x * em_size_factor;
    }
    
    UNUSED(prev);
    UNUSED(cur);
    return 0.0f;
}

GLTextureImage::Ptr GLFont::loadGlyphGrid(unsigned grid_id)
{
    GLTextureBitmap::Ptr bmp(new GLTextureBitmap(ivec2(font_header->grid_px_size), GL_ALPHA, false));

    StaticBuffer data;

    if (!library->owner->loadAssetData(&data, text_font.family + text_font.suffix() + stl_sprintf("/%02d.xmf", grid_id), StaticBuffer::AUTO_SIZE)) {
        cerr << "Could not load grid #" << grid_id << " of font " << text_font.family << endl;
    } else {
        uLongf len = bmp->getDataSize();
        if (uncompress(bmp->getDataPtr(), &len, data.data(), data.size()) != Z_OK) {
            cerr << "Could not uncompress grid #" << grid_id << " of font " << text_font.family << endl;
        }
    }

    return static_pointer_cast<GLTextureImage>(bmp);
}

GLTextureImage::Ptr GLFont::getGlyphTile(GlyphInfo *info, vec2 *bearing, vec2 *tcoord1, vec2 *tcoord2)
{
    if (!info)
        return GLTextureImage::Ptr();

    if ((info->id & FALLBACK_FLAG) && !is_fallback && library->owner->FallbackFont) {
        return library->owner->FallbackFont->getGlyphTile(info, bearing, tcoord1, tcoord2);
    }

    const uint32_t id = info->id & ~FALLBACK_FLAG;

    // Don't paint normal and CJK space characters
    const GlyphHeader &hdr = glyph_headers[id];
    uint32_t code = hdr.unicode_char;
    bool isUtf32Glyph = code > 0xFFFF;
    if (code == ' ' || code == 0x3000)
        return GLTextureImage::Ptr();

    unsigned grid_id = info->tile_id / font_header->grid_glyph_cnt;
    unsigned tile_id = info->tile_id % font_header->grid_glyph_cnt;

    GLTextureImage::Ptr &tex = isUtf32Glyph ? emoji_grids[grid_id] : glyph_grids[grid_id];
    if (!tex)
        tex = loadGlyphGrid(grid_id);

    unsigned tile_x = tile_id % font_header->grid_size;
    unsigned tile_y = tile_id / font_header->grid_size;

    *bearing = vec2(hdr.field_bearing_x, hdr.field_bearing_y);
    *tcoord1 = tex_origin + vec2(tile_x,tile_y)*tex_tile_step;
    *tcoord2 = *tcoord1 + tex_active_tile;

    return tex;
}

int GLTextLayout::getCharGlyphPositionIdx(int charidx) {
    if (charidx < 0 || charidx > int(endpos->position())) return -1;
    typename std::map<size_t, size_t>::const_iterator it = char_to_glyph_index.find( charidx );
    // For case of ligature
    int delta = 1;
    while (it == char_to_glyph_index.end()) {
        if (delta > charidx && charidx + delta >= int(char_indices.size())) return charidx;
        it = char_to_glyph_index.find(charidx-delta);
        ++delta;
    }
    return it->second;
}

GLTextLayout::Ptr GLFont::layoutTextLine(Utf32InputIterator &strb, Utf32InputIterator &stre, float size, float width_limit, float spacing, bool crop_long_words, bool rtl) {
    GLTextLayout::Ptr layout(new GLTextLayout(self.lock(), size, rtl));
    layout->buildLayout(strb.clone(), stre.clone(), width_limit, spacing, crop_long_words);
    return layout;
}

GLTextLayout::GLTextLayout(GLFont::Ptr font, float size, bool rtl) :
    font(font), size(size)
{
    direction = rtl? RTL : LTR;
    pass_scale = -1e+6;
    spacing = 0.0f;
    pass_origin = pass_adj_origin = vec2(-1e+6);
}

void clippedIncrementReversedIterator(shared_ptr<Utf32InputIterator> &iter, Utf32InputIterator &bound, Utf32InputIterator &deportation) {
    if (*iter == bound) iter = deportation.cloneReversed(); else ++*iter;
}

void GLTextLayout::reverseGlyphRange(size_t b, size_t e) {
    while(b<e) {
        GLFont::GlyphInfo *glyph;
        int char_idx;
        CharDirection dir;
        --e;
        glyph = glyphs[b];
        glyphs[b] = glyphs[e];
        glyphs[e] = glyph;
        char_idx = char_indices[b];
        char_indices[b] = char_indices[e];
        char_indices[e] = char_idx;
        char_idx = char_counts[b];
        char_counts[b] = char_counts[e];
        char_counts[e] = char_idx;
        // Numbers might be here, so directions to swap also.
        dir = directions[b];
        directions[b] = directions[e];
        directions[e] = dir;
        ++b;
    }
}

void GLTextLayout::buildLayout(shared_ptr<Utf32InputIterator> begin, shared_ptr<Utf32InputIterator> end, float width_limit, float spacing, bool crop_long_words) {
    shared_ptr<Utf32InputIterator> strIter;
    shared_ptr<Utf32InputIterator> strDirectAgain;
    shared_ptr<Utf32InputIterator> strReverseRemains;
    strReverseRemains = strDirectAgain = end;
    {
        strIter = begin->clone();
        ++*strIter;
        size_t elemcount = strIter->position() > begin->position()? end->position() - begin->position() : begin->position();
        char_indices.reserve(elemcount+1);
        char_to_glyph_index.clear();
        glyphs.reserve(elemcount);
        positions.reserve(elemcount+1);
        directions.reserve(elemcount);
    }

    GLFont::GlyphInfo *info = nullptr;
    GLFont::GlyphInfo *prev = nullptr;
    bool (*isReverse)(ucs4_char code) = direction == RTL? isLtrChar : isRtlChar;
    bool (*isDirect)(ucs4_char code) = direction == RTL? isRtlChar : isLtrChar;

    bbox.clear();

    GLTextLayout::GLYPH_VARIANT gv = GLTextLayout::GV_ISOLATED;
    shared_ptr<Utf32InputIterator> strPrevNC(end->clone());
    shared_ptr<Utf32InputIterator> strNextNC(strIter->clone());
    ucs4_char chr;
    size_t chrIdx;
    size_t directionChangeGlyphIdx=-1;
    float width = 0.0;

    for (strIter = begin->clone(); *strIter != *end;) {
        if (*strNextNC == *strIter) {
            ++*strNextNC;
            // Find next non-combining character to determine connection.
            while (*strNextNC != *end && isCharCombining(**strNextNC)) ++*strNextNC;
        }
        if (strIter == strDirectAgain) {
            reverseGlyphRange(directionChangeGlyphIdx, glyphs.size());
            directionChangeGlyphIdx = -1;
            strReverseRemains = strDirectAgain = end;
        }
        chrIdx = strIter->position();
        chr = **strIter;

        if (strDirectAgain == end && isReverse(chr)) {  // Exploring and saving reverse fragment boundary.
            directionChangeGlyphIdx = glyphs.size();
            strReverseRemains = strIter->clone();
            strDirectAgain = strIter->clone();
            prev = nullptr;  // No kerning between directions.
            if (isWeakChar(chr)) {
                for (; *strDirectAgain != *end && isWeakChar(**strDirectAgain); ++*strDirectAgain)
                    chr = **strDirectAgain;
                if (!isReverse(chr)) {  // For cases of punctuation after punctuation-separated numbers.
                    strDirectAgain = strDirectAgain->cloneReversed();
                    ++*strDirectAgain;
                    strDirectAgain = strDirectAgain->cloneReversed();
                }
                chr = **strIter;
            } else {
                for (; *strDirectAgain != *end && !isDirect(**strDirectAgain); ++*strDirectAgain);
                strDirectAgain = strDirectAgain->cloneReversed();
                ++*strDirectAgain;
                for (; *strDirectAgain != *end && !isReverse(**strDirectAgain); ++*strDirectAgain);
                strDirectAgain = strDirectAgain->cloneReversed();
                ++*strDirectAgain;
            }
        } // Otherwise direction remains intact.

        // Convert all whitespace to ordinary space
        if (chr < 256 && isspace(chr))
            chr = ' ';

        bool nextConnect = getCharVariantsMask(*strNextNC == *end?' ':**strNextNC) & (1<<GLTextLayout::GV_FINAL);
        bool prevConnect = getCharVariantsMask(*strPrevNC == *end?' ':**strPrevNC) & (1<<GLTextLayout::GV_INITIAL);
        // TODO check current direction for RTL.
        bool currentRTL = (strDirectAgain == end) ^ (direction == LTR);
        if (currentRTL) chr = tryMirrorChar(chr);
        gv = prevConnect? (nextConnect?GV_MEDIAL:GV_FINAL) : (nextConnect?GV_INITIAL:GV_ISOLATED);

        info = font->getGlyphByChar(getCharVariant(chr, gv));

        // Place some code here to calculate glyphs total width and rewrite regarding it layout quit condition below.

        width += font->getKerning(prev, info) * size;
        float width_inc = info? info->advance * size : 0.0;
        if (width_inc) width_inc = fmax(0.0, spacing + width_inc);

        // This quits layout cycle.
        if (width_limit > 0.0f && width + width_inc > width_limit && (crop_long_words || chr == ' ')) break;
        width += width_inc;

        // Keep behind current iterator, stay until non-combining
        // character met to determine connection.
        if (!isCharCombining(chr)) {
            strPrevNC = strIter->clone();
            prev = info;
        }

        ++*strIter;
        char_indices.push_back(chrIdx);
        char_counts.push_back(strIter->position()-chrIdx);
        glyphs.push_back(info);
        directions.push_back(currentRTL? RTL : LTR);

    }
    char_indices.push_back(strIter->position());
    if (strDirectAgain != end)
        reverseGlyphRange(directionChangeGlyphIdx, glyphs.size());
    if (direction == RTL) reverseGlyphRange(0, glyphs.size());

    endpos = strIter->clone();
    float cursor = 0.0f;
    float new_cursor = 0.0f;
    float pos = 0.0f;
    this->spacing = spacing;
    info = nullptr;

    for (chrIdx = 0; chrIdx < glyphs.size(); ++chrIdx) {
        // Move cursor
        prev = info;
        info = glyphs[chrIdx];
        pos = cursor + font->getKerning(prev, info) * size;
        if (info) new_cursor = info->advance * size;
        new_cursor = pos + (!!new_cursor) * (spacing + new_cursor);
        if (new_cursor<cursor) new_cursor = cursor;
        positions.push_back(pos);
        if (info) {
            bbox |= vec2(pos,0) + info->bearing * size;
            bbox |= vec2(pos,0) + (info->bearing + info->size) * size;
        }
        cursor = new_cursor;
    }
    cursor -= spacing;
    positions.push_back(cursor);  // We shouldn't add spacing after the last glyph.


    // TODO calculate positions, including final position depending on flow direction(s).
    for(size_t i=0; i<char_indices.size(); ++i)
        char_to_glyph_index[char_indices[i]] = i;

    if (!glyphs.empty()) {
        bbox |= vec2(0.0f);
        bbox |= vec2(cursor, -getAscent());
        bbox |= vec2(cursor, -getDescent());

        bbox.roundOut();
    }
}

int GLTextLayout::findIndexByPos(float x, bool nearest)
{
    if (!nearest && (bbox.isEmpty || x < bbox.min_pt.x || x > bbox.max_pt.x))
        return -1;

    unsigned i = 1;
    // TODO add direction and advance checking.
    while (i < positions.size() && positions[i] <= x)
        i++;

    return i-1;
}

GLTextLayout::~GLTextLayout()
{

}

void GLTextLayout::renderPasses(GLRenderer *renderer, const T_passes &passes, vec4 color, float alpha, float radius)
{
    glEnableVertexAttribArray(GLRenderer::AttrVertexTexCoord);

    for (T_passes::const_iterator pit = passes.begin(); pit != passes.end(); ++pit) {
        if (pit->first->swizzleRB()) {
            renderer->beginDrawFancy(vec4(0,0,0,0), true, true);
            glVertexAttrib4f(GLRenderer::AttrVertexColor, alpha, alpha, alpha, alpha);
        } else {
            renderer->beginDrawFont(radius);
            glVertexAttrib4fv(GLRenderer::AttrVertexColor, glm::value_ptr(color * alpha));
        }

        pit->first->bindTo(renderer);
        pit->second.pcoords.bindToAttrib(GLRenderer::AttrVertexPos);
        pit->second.tcoords.bindToAttrib(GLRenderer::AttrVertexTexCoord);
        pit->second.pcoords.drawStrip();
    }

    glDisableVertexAttribArray(GLRenderer::AttrVertexTexCoord);
}

bool GLTextLayout::isDigit(ucs4_char code) {
    return (code >= 0x30 && code < 0x3A);
}

bool GLTextLayout::isWeakChar(ucs4_char code) {
    return isDigit(code) || code == 0x2E;  // Maybe more.
}

bool GLTextLayout::isRtlChar(ucs4_char code) {
    return (code >= 0x590 && code < 0x900)
        || (code == 0x200F) || (code == 0x202B)
        || (code >= 0xFB1D && code < 0xFDD0)
        || (code >= 0xFDF0 && code < 0xFE00)
        || (code >= 0xFE70 && code < 0xFF00)
        || (code >= 0x10800 && code < 0x11000)
        || (code >= 0x1E800 && code < 0x1F000);
}

bool GLTextLayout::isLtrChar(ucs4_char code) {
    return (code >= 0x30 && code < 0x3A)
        || (code >= 0x41 && code < 0x5B)
        || (code >= 0x61 && code < 0x7B)
        || (code >= 0xA0 && code < 0x590)
        || (code >= 0x700 && code < 0x2000)
        || (code == 0x200E) || (code == 0x202A)  // FIXME: MText("Spell Check (lang)\u200E", []) shows parentheses mirrored.
        || (code >= 0x2100 && code < 0x2190)
        || (code >= 0x2460 && code < 0x2500)
        || (code >= 0x2800 && code < 0x2900)
        || (code >= 0x2E80 && code < 0x3000)
        || (code >= 0x3040 && code < 0xD800)
        || (code >= 0xF900 && code < 0xFB1D)
        || (code >= 0xFE20 && code < 0xFE70)
        || (code >= 0xFF00 && code < 0xFFF0)
        || (code >= 0x1D300 && code < 0x1D800)
        || (code >= 0x20000 && code < 0x2FA20);
}

ucs4_char GLTextLayout::tryMirrorChar(ucs4_char code) {
	// Does not mirror 0x3C and 0x3E hence they're supposed to be
	// HTML tag delimiters and all our texts are HTML-encoded.
    #define PAIRS_COUNT 8
    ucs4_char chars[PAIRS_COUNT*2] = {0x3C, 0x3E, 0x28, 0x29, 0x5B, 0x5D, 0x7B, 0x7D, 0xBB, 0xAB, 0x2019, 0x2018, 0x201C, 0x201D};
    for (int i=0; i<PAIRS_COUNT*2; ++i) if (chars[i] == code) return chars[i^1];
    return code;
    #undef PAIRS_COUNT
}

void GLTextLayout::computePasses(const GLTransform &transform, vec2 /*origin*/, vec2 adj_origin)
{
    if (font->is_freetype) {
        float pixel_size = transform.getScaleRev();
        float pixel_div = transform.getScale();

        if (pixel_div == pass_scale && adj_origin == pass_adj_origin && !passes.empty())
            return;

        pass_scale = pixel_div;
        pass_adj_origin = adj_origin;
        passes.clear();

        int i_size = floorf(size * pixel_div + 0.3);
        float sfactor = pixel_size;

        if (i_size > 50) {
            sfactor *= i_size / 50.0f;
            i_size = 50;
        }

        GLFont::Size::Ptr fsize = font->getSize(i_size);

        // Compute bitmaps
        std::vector<GLFont::GlyphBitmap*> bitmaps(glyphs.size(), NULL);

        for (unsigned i = 0; i < glyphs.size(); i++) {
            GLFont::GlyphInfo *info = glyphs[i];
            GLFont::GlyphBitmap *bmp = fsize->getGlyphBitmap(info);

            if (bmp && bmp->bitmap) {
                bitmaps[i] = bmp;
            }
        }

        // Arrange bitmaps into triangle strips
        for (unsigned i = 0; i < glyphs.size(); i++)
        {
            GLFont::GlyphInfo *info = glyphs[i];
            GLFont::GlyphBitmap *bmp = bitmaps[i];

            if (!bmp) continue;

            float size_diff = 0.5f*(bmp->bitmap->size.x*sfactor - info->size.x*size);
            float fpos_raw = positions[i] + info->bearing.x*size - size_diff;
            float fpos = pixel_size * roundf(fpos_raw * pixel_div);

            vec2 pos1 = adj_origin + vec2(fpos,bmp->bearing.y*sfactor);
            vec2 pos2 = pos1 + vec2(bmp->bitmap->size)*sfactor;

            RenderPass &pass = passes[static_pointer_cast<GLTextureImage>(bmp->bitmap->texture)];
            pass.reserve(glyphs.size());
            pass.pcoords.addRect(pos1, pos2);
            pass.tcoords.addRect(bmp->bitmap->tex_points[0], bmp->bitmap->tex_points[1]);
        }
    } else {
        if (adj_origin == pass_adj_origin && !passes.empty())
            return;

        pass_adj_origin = adj_origin;
        passes.clear();

        // Arrange bitmaps into triangle strips
        for (unsigned i = 0; i < glyphs.size(); i++)
        {
            GLFont::GlyphInfo *info = glyphs[i];

            vec2 bearing, tex1, tex2;
            GLTextureImage::Ptr tex = font->getGlyphTile(info, &bearing, &tex1, &tex2);
            if (!tex) continue;

            vec2 pos1 = adj_origin + vec2(positions[i], 0) + bearing*size;
            vec2 pos2 = pos1 + font->active_tile_size*size;

            RenderPass &pass = passes[tex];
            pass.reserve(glyphs.size());
            pass.pcoords.addRect(pos1, pos2);
            pass.tcoords.addRect(tex1, tex2);
        }
    }
}

void GLTextLayout::render(GLRenderer *renderer, const GLTransform &transform,
                          vec2 origin, vec2 adj_origin, vec4 color, float alpha, bool underline)
{
    renderer->beginDrawFancy(vec4(1,1,1,1), true);
    
    float pixel_size = transform.getScaleRev();
    float fct = pixel_size / size * font->font_header->render_em_size;
    float r = 0.8f * fct * font->font_header->dist_scale;

    // Build the layout structure
    computePasses(transform, origin, adj_origin);

    // Flush the strips
    renderPasses(renderer, passes, color, alpha, r);

    // Add underline
    if (underline) {
        float pixel_div = transform.getScale();

        renderer->beginDrawSimple(color);
        glLineWidth(renderer->getDevicePixelRatio() * font->underline_thickness * size * pixel_div);

        float y_pos = adj_origin.y - font->underline_position * size;
        float coords[4] = { adj_origin.x, y_pos, adj_origin.x + bbox.max_pt.x, y_pos };

        glVertexAttribPointer(GLRenderer::AttrVertexPos, 2, GL_FLOAT, GL_FALSE, 0, coords);
        glDrawArrays(GL_LINE_STRIP, 0, 2);
    }
}

namespace {
    inline float sqr(float x) { return x*x; }

    struct SmoothData {
        unsigned size, extent;
        const uint8_t *data;
        float scale;
        int step;

        unsigned max_dist;

        struct Idx {
            short x, y;
        };
        std::vector<Idx> queue;
        unsigned qsize, qptr, qlimit;

        struct State {
            short vx, vy;
            unsigned dist;
        };
        std::vector<State> state;

        SmoothData(unsigned tile_size, const uint8_t *data, float scale, int step = 1)
        {
            this->size = tile_size;
            this->extent = tile_size * tile_size;
            this->data = data;
            this->scale = scale;
            this->step = step;

            max_dist = (unsigned)ceilf(sqr(2 * step / scale));

            qsize = extent+1;
            queue.resize(qsize);
            qptr = qlimit = 0;

            State init = { -32768, -1, 0xFFFFFFFFU };
            state.resize(extent, init);
        }

        bool valid(int x, int y) {
            return unsigned(x) < size && unsigned(y) < size;
        }

        void update(int x, int y, short vx, short vy)
        {
            int dx = (x<<1) - vx;
            int dy = (y<<1) - vy;
            unsigned dval = dx*dx + dy*dy;
            if (dval >= max_dist)
                return;

            State &cell = state[x + y * size];
            if (cell.dist <= dval)
                return;

            if (cell.vx == -32768)
            {
                Idx &idx = queue[qlimit++];
                idx.x = x;
                idx.y = y;
                if (qlimit == qsize)
                    qlimit = 0;
            }

            cell.vx = vx;
            cell.vy = vy;
            cell.dist = dval;
        }

        bool check_inner(int x, int y) {
            return valid(x, y) && data[x + y * size] >= 128;
        }

        void check_update(int x, int y, short vx, short vy)
        {
            if (valid(x, y))
                update(x, y, vx, vy);
        }

        void init()
        {
            int isize = size;

            for (int y = -1; y < isize; y++)
            {
                short vy = y<<1;
                bool inmask[2][2];

                inmask[1][0] = inmask[1][1] = false;

                for (int x = -1; x < isize; x++)
                {
                    short vx = x<<1;

                    inmask[0][0] = inmask[1][0];
                    inmask[0][1] = inmask[1][1];
                    inmask[1][0] = check_inner(x+1, y);
                    inmask[1][1] = check_inner(x+1, y+1);

                    if (inmask[1][0] != inmask[1][1])
                    {
                        check_update(x+1, y, vx+2, vy+1);
                        check_update(x+1, y+1, vx+2, vy+1);
                    }

                    if (inmask[1][0] != inmask[0][0])
                    {
                        check_update(x+1, y, vx+1, vy);
                        check_update(x, y, vx+1, vy);
                    }
                    else if (inmask[1][0] != inmask[0][1])
                    {
                        check_update(x+1, y, vx+1, vy+1);
                        check_update(x, y+1, vx+1, vy+1);
                    }

                    if (inmask[1][1] != inmask[0][1])
                    {
                        check_update(x+1, y+1, vx+1, vy+2);
                        check_update(x, y+1, vx+1, vy+2);
                    }
                    else if (inmask[1][1] != inmask[0][0])
                    {
                        check_update(x+1, y+1, vx+1, vy+1);
                        check_update(x, y, vx+1, vy+1);
                    }
                }
            }
        }

        void process()
        {
            int count = 0;
            int isize = size;

            while (qptr != qlimit)
            {
                count++;

                Idx pos = queue[qptr++];
                if (qptr == qsize)
                    qptr = 0;

                int idx = pos.x + pos.y * isize;

                State &cell = state[idx];
                //uint8_t center_in = (data[idx] & 128);

                int min_x = std::max(0,pos.x-1), max_x = std::min(isize,pos.x+2);
                int min_y = std::max(0,pos.y-1), max_y = std::min(isize,pos.y+2);
                int i0 = min_y * isize;

                for (int y = min_y; y < max_y; y++, i0 += isize)
                {
                    for (int x = min_x, i = i0; x < max_x; x++, i++)
                    {
                        if (i == idx)
                            continue;
                        //if ((data[i] & 128) != center_in)
                        //    continue;

                        update(x, y, cell.vx, cell.vy);
                    }
                }

                cell.vx = -32768;
            }

            //cout << "count " << count << " (" << (float(count)/(size*size)) << ")" << endl;
        }

        void encode(uint8_t *out, int bias = 0)
        {
            static bool sqrt_ready = false;
            static uint8_t sqrt_table[16384];

            if (!sqrt_ready)
            {
                int pidx = 0;

                for (int i = 0; i < 128; i++)
                {
                    int sidx = (i+1)*(i+1);
                    for (int j = pidx; j < sidx; j++)
                        sqrt_table[j] = i;
                    pidx = sidx;
                }

                sqrt_ready = true;
            }

            unsigned mul_factor = (unsigned)floorf(sqr(65536.0f)/max_dist);
            int osize = size/step;

            memset(out, 0, osize*osize);

            for (int y = 1; y < osize-1; y++)
            {
                int i = (y*step+bias)*size + bias + step;
                uint8_t *p = out + y * osize + 1;

                for (int x = 1; x < osize-1; x++, i += step)
                {
                    unsigned vdist = state[i].dist;
                    uint8_t sqrtv = sqrt_table[(vdist*mul_factor) >> (32-14)];
                    int distval = (vdist >= max_dist) ? 128 : sqrtv;
                    int dist = 128 + ((data[i] >= 128) ? distval : -distval);
                    *p++ = (uint8_t)std::min(dist, 255);
                }
            }
        }
    };
}

//double GetCurrentTime();

void smoothFontBitmap(const FontHeader *header, StaticBuffer *pixels, const uint8_t *input, int input_size_mul)
{
    if (input)
    {
        SmoothData info(header->tile_size * input_size_mul, input, header->dist_scale, input_size_mul);

        //double t1 = GetCurrentTime();
        info.init();
        //double t2 = GetCurrentTime();
        info.process();
        //double t3 = GetCurrentTime();
        pixels->allocate(header->tile_size * header->tile_size);
        info.encode(pixels->writable_data(), input_size_mul/2);
        //double t4 = GetCurrentTime();
        //cout << "Smooth " << (t2-t1) << " " << (t3-t2) << " " << (t4-t3) << endl;
    }
    else
    {
        SmoothData info(header->tile_size, pixels->writable_data(), header->dist_scale);

        info.init();
        info.process();
        info.encode(pixels->writable_data());
    }
}
