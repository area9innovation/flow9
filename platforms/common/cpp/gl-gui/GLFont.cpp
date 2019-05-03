#include "GLFont.h"
#include "GLRenderSupport.h"
#include "core/CommonTypes.h"

#include <zlib.h>
#include <deque>
#include <stdio.h>

#include <glm/gtc/type_ptr.hpp>

inline float ftToFloat(int v) {
    return v / 64.0f;
}


void LigatureUtf32Iter::yield() {
    if (*cur == *end) {
        ligalen = 1;
        yieldedChar = **org;
        return;
    }
    int ligacnt = (sizeof LIGATURES)/(sizeof *LIGATURES);
    std::vector<int> matchlengths(ligacnt, 0);
    int ligai;
    ligalen = 0;
    bool anyCandidate = true;
    shared_ptr<Utf32InputIterator> aux(cur->clone());
    for (*aux; anyCandidate && *aux!=*end; ++*aux, ++ligalen) {
        anyCandidate = false;
        for (ligai=0; ligai<ligacnt; ++ligai) {
            if (matchlengths[ligai] != ligalen) continue;
            anyCandidate = true;
            if (**aux == LIGATURES[ligai].meaning[matchlengths[ligai]])
                ++matchlengths[ligai];
            if (!LIGATURES[ligai].meaning[matchlengths[ligai]]) {
                cur = aux;
                yieldedChar = LIGATURES[ligai].form;
                return;
            }
        }
    }
    // No ligature match
    ligalen = 1;
    yieldedChar = **cur;
}

LigatureUtf32Iter& LigatureUtf32Iter::next() {
    ++*cur;
    yield();
    return *this;
}

LigatureUtf32Iter::LigatureUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end):
    org(org.clone()), cur(org.clone()), end(end.clone())
{
    yield();
}

LigatureUtf32Iter::LigatureUtf32Iter(Utf32InputIterator &org, Utf32InputIterator &end, Utf32InputIterator &cur):
    org(org.clone()), cur(cur.clone()), end(end.clone())
{
    yield();
}

ucs4_char LigatureUtf32Iter::operator *() {
    return yieldedChar;
}
shared_ptr<Utf32InputIterator> LigatureUtf32Iter::clone() {
    shared_ptr<Utf32InputIterator> r(new LigatureUtf32Iter(*this->org, *this->end, *this->cur));
   return r;
}

GLFontLibrary::GLFontLibrary(GLRenderSupport *owner) : owner(owner)
{
    max_texture_size = 64;
}

GLFontLibrary::~GLFontLibrary()
{
}

GLFont::Ptr GLFontLibrary::loadFont(TextFont textFont)
{
    StaticBuffer data;
    GLFont::Ptr ptr;

    if (owner->loadAssetData(&data, textFont.family + "/index.dat", StaticBuffer::AUTO_SIZE)) {
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

    for (unsigned y = 0; y < font_header->tile_size * scale; y++, pgrid += bytesSizeScale * scale * font_header->grid_px_size)
        for (unsigned x = 0; x < bytesSizeScale * scale * font_header->tile_size; x++)
            pgrid[x] = *ppix++;

    current_glyph_grid->invalidate();

    if (current_grid_idx >= font_header->grid_size * font_header->grid_size)
        current_glyph_grid.reset();

    return unicode_charmap[char_code] = idx+1;
}

GLFont::GlyphInfo *GLFont::getGlyphByChar(ucs4_char char_code)
{
    int idx = unicode_charmap[char_code];
    if (!idx && is_system)
        idx = loadSystemGlyph(char_code, false);
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
    idx--;

    GlyphInfo *&ptr = glyphs[idx];
    if (!ptr) {
        bool isUtf32Glyph = glyph_headers[idx].unicode_char > 0xFFFF;
        unsigned tile_id = is_system ?
                                ((
                                    isUtf32Glyph ?
                                        (emoji_grids.size() - 1) * font_header->grid_glyph_cnt + cur_emoji_idx
                                        : (glyph_grids.size() - 1) * font_header->grid_glyph_cnt + cur_system_idx
                                ) - 1)
                                : idx;
        ptr = new GlyphInfo(idx, tile_id);

        ptr->bearing = vec2(glyph_headers[idx].bearing_x, glyph_headers[idx].bearing_y);
        ptr->size = vec2(glyph_headers[idx].size_x, glyph_headers[idx].size_y);
        ptr->advance = glyph_headers[idx].advance;
    }

    return ptr;
}

float GLFont::getKerning(GlyphInfo *prev, GlyphInfo *cur)
{
    return 0.0f;
}

GLTextureImage::Ptr GLFont::loadGlyphGrid(unsigned grid_id)
{
    GLTextureBitmap::Ptr bmp(new GLTextureBitmap(ivec2(font_header->grid_px_size), GL_ALPHA, false));

    StaticBuffer data;

    if (!library->owner->loadAssetData(&data, text_font.family + stl_sprintf("/%02d.xmf", grid_id), StaticBuffer::AUTO_SIZE)) {
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

GLTextLayout::Ptr GLFont::layoutTextLine(unicode_string str, float size, float width_limit, float spacing, bool crop_long_words, bool rtl)
{
    GLTextLayout::Ptr layout(new GLTextLayout(self.lock(), size));
    layout->buildLayout(str, width_limit, spacing, crop_long_words, rtl);
    return layout;
}

GLTextLayout::GLTextLayout(GLFont::Ptr font, float size) :
    font(font), size(size)
{
    pass_scale = -1e+6;
    spacing = 0.0f;
    pass_origin = pass_adj_origin = vec2(-1e+6);
}

void GLTextLayout::buildLayout(unicode_string str, float width_limit, float spacing, bool crop_long_words, bool rtl)
{
    float cursor = 0.0f;

    this->spacing = spacing;

    text.reserve(str.size());
    glyphs.reserve(str.size());
    positions.reserve(str.size()+1);

    GLFont::GlyphInfo *info = NULL, *prev = NULL;
    DecodeUtf16toUtf32 decoder(str);
    shared_ptr<Utf32ReversibleInputIterator> strIter(decoder.begin().cloneDirect());
    shared_ptr<Utf32ReversibleInputIterator> strEnd(decoder.end().cloneDirect());
    shared_ptr<Utf32ReversibleInputIterator> strRevStart(decoder.end().cloneDirect());
    shared_ptr<Utf32ReversibleInputIterator> strRevEnd(decoder.end().cloneDirect());
    bool (*isReverse)(ucs4_char code) = rtl? isLtrChar : isRtlChar;
    bool (*isDirect)(ucs4_char code) = rtl? isRtlChar : isLtrChar;

    bbox.clear();

	// String str comes LTR always, already BiDi-processed,
	// so, leftmost character is first for LTR, and last for RTL.
    GLTextLayout::GLYPH_VARIANT gv = GLTextLayout::GV_ISOLATED;
    if (rtl) {
        strIter = decoder.rbegin().cloneDirect();
        strEnd = decoder.rend().cloneDirect();
    } else {
        strIter = decoder.begin().cloneDirect();
        strEnd = decoder.end().cloneDirect();
    }

    shared_ptr<Utf32ReversibleInputIterator> leftPos(strEnd->cloneDirect()); // Setting to End state, so connecting algo won't connect left.
    shared_ptr<Utf32ReversibleInputIterator> rightPos(strIter->cloneDirect());
    shared_ptr<Utf32ReversibleInputIterator> strProc(strIter->cloneDirect());

    for (*strIter; *strIter != *strEnd; prev = info) {
        unicode_char charUTF16[2];
        char charLen;
        ucs4_char chr;
        chr = **strIter;
        if (*strRevStart == *strEnd) {
            if (isReverse(chr)) {
                strRevStart = leftPos;
                leftPos = rightPos;
                rightPos = strRevStart;
                strRevStart = strIter->cloneDirect();
                //rightPos = strIter->cloneDirect();
                strRevEnd = strProc = strEnd;  // *strProc == *strEnd — no character processing
            } else {
                strProc = strIter;  // character processing goes on from strProc
            }
        } else {
            #define IS_DIGIT(x) (x>=0x30 && x<0x3A)
            if (
                isDirect(chr) ||
                (
                    !isReverse(chr) &&
                    !((chr==0x27 || chr==0x2C || chr==0x2E) && IS_DIGIT(**leftPos) && IS_DIGIT(**rightPos)) &&
                    !(!IS_DIGIT(**leftPos) && !IS_DIGIT(**rightPos))
                )
            ) {
                if (*strRevEnd == *strEnd) {
                    strRevEnd = strIter->cloneReversed();
                    ++*strRevEnd;
                    chr = **strRevEnd;
                    while (!isReverse(chr)) {
                        ++*strRevEnd;
                        chr = **strRevEnd;
                    }
                    strProc = strRevEnd->cloneReversed();
                    strRevEnd = strProc->cloneDirect();
                    ++*strRevEnd;
                    while (isCharCombining(chr) && (*strRevEnd != *strEnd)) {
                        ++*strRevEnd;
                        ++*strProc;
                        chr = **strRevEnd;
                    }
                    leftPos = strProc->cloneReversed();
                    strRevEnd = strProc->cloneReversed();
                    rightPos = strRevEnd->cloneDirect();
                    ++*rightPos;
                    strProc = strRevEnd->cloneDirect();
                }
                chr = **strProc;
            } else {
                ++*rightPos;
                chr = **strProc;
                ++*strIter;
                ++*leftPos;
            }
            #undef IS_DIGIT
        }

        if (*strProc != *strEnd) {
            // Always go ahead current iterator.
            if (*rightPos == *strProc) ++*rightPos;
            // Find next non-combining character to determine connection.
            while (*rightPos != *strEnd && isCharCombining(**rightPos)) ++*rightPos;
            bool rightConnect = getCharVariantsMask(*rightPos == *strEnd?' ':**rightPos) & (1<<GLTextLayout::GV_INITIAL);
            if (rtl ^ (*strRevStart != *strEnd)) chr = tryMirrorChar(chr);
            if (getCharVariantsMask(*leftPos == *strEnd?' ':**leftPos) & (1<<GLTextLayout::GV_FINAL)) {
                gv = rightConnect? GLTextLayout::GV_MEDIAL : GLTextLayout::GV_INITIAL;
            } else {
                gv = rightConnect? GLTextLayout::GV_FINAL : GLTextLayout::GV_ISOLATED;
            }

            // Keep behind current iterator, stay until non-combining
            // character met to determine connection.
            if (!isCharCombining(**strProc)) leftPos = strProc->cloneDirect();

            if (*strProc == *strRevStart && *strRevStart != *strEnd) {
                // Reversed sequence processed, prepare to the direct back.
                strRevStart = strEnd;
                strIter = strRevEnd->cloneReversed();
                ++*strIter;
                rightPos = strIter->cloneDirect();
            } else ++*strProc;
            ++*rightPos;

            // Convert all whitespace to ordinary space
            if (chr < 256 && isspace(chr))
                chr = ' ';

            info = font->getGlyphByChar(getCharVariant(chr, gv));

            float kerning = font->getKerning(prev, info);
            float pos = cursor + kerning * size;
            float g_size = info ? info->advance * size : 0.0f;

            // We shouldn't add spacing after the last char in the string
            float new_cursor = std::max(pos + g_size + spacing * (*strProc != *strEnd), cursor);

            if (width_limit > 0.0f && new_cursor > width_limit && (crop_long_words || chr == ' '))
                break;

            charLen = encodeCharUtf32toUtf16(chr, charUTF16);
            for (int j = 0; j < charLen; ++j) text.push_back(charUTF16[j]);
            glyphs.push_back(info);
            positions.push_back(pos);

            if (info) {
                bbox |= vec2(pos,0) + info->bearing * size;
                bbox |= vec2(pos,0) + (info->bearing + info->size) * size;
            }

            cursor = new_cursor;
        }
    }

    positions.push_back(cursor);

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

bool GLTextLayout::isRtlChar(ucs4_char code) {
    return (code >= 0x590 && code < 0x900)
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
    #define PAIRS_COUNT 6
    ucs4_char chars[PAIRS_COUNT*2] = {0x28, 0x29, 0x5B, 0x5D, 0x7D, 0x7B, 0xBB, 0xAB, 0x2019, 0x2018, 0x201C, 0x201D};
    for (int i=0; i<PAIRS_COUNT*2; ++i) if (chars[i] == code) return chars[i^1];
    return code;
    #undef PAIRS_COUNT
}

void GLTextLayout::computePasses(const GLTransform &/*transform*/, vec2 /*origin*/, vec2 adj_origin)
{
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

        vec2 pos1 = adj_origin + vec2(positions[i],0) + bearing*size;
        vec2 pos2 = pos1 + font->active_tile_size*size;

        RenderPass &pass = passes[tex];
        pass.reserve(glyphs.size());
        pass.pcoords.addRect(pos1, pos2);
        pass.tcoords.addRect(tex1, tex2);
    }
}

void GLTextLayout::render(GLRenderer *renderer, const GLTransform &transform,
                          vec2 origin, vec2 adj_origin, vec4 color, float alpha, bool underline)
{
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
