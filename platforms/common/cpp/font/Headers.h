#ifndef FONT_HEADERS_H
#define FONT_HEADERS_H

#include <stdint.h>

static const unsigned short UNICODE_INVALID_CHAR = 0xFFFD;

struct FontHeader {
    static const unsigned MAGIC = 0x544E4644;

    unsigned magic;

    unsigned short hdr_size;
    unsigned short glyph_hdr_size;

    unsigned short tile_size;
    unsigned short grid_size;
    unsigned short grid_px_size; // = grid_size*tile_size
    unsigned short grid_glyph_cnt; // = grid_size^2
    unsigned short grid_count;
    unsigned short glyph_count;

    float render_em_size;
    float active_tile_size; // (tile_size-2)/render_em_size
    float dist_scale;

    float ascender, descender;
    float line_height, max_advance;
    float underline_position, underline_thickness;
};

struct GlyphHeader {
    uint32_t unicode_char;
    // From unscaled font metrics:
    float bearing_x, bearing_y;
    float size_x, size_y;
    float advance;
    // Unscaled bearing to the active tile
    float field_bearing_x, field_bearing_y;
};

#endif // HEADERS_H
