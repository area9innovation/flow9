#include "core/STLHelpers.h"

#include <fstream>

#include "BezierUtils.h"
#include "Headers.h"

#include <unistd.h>
#include <zlib.h>

#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_OUTLINE_H

using glm::ivec2;

FT_Library library;

void reportError(FT_Error code)
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

void init() {
    FT_Error error = FT_Init_FreeType(&library);

    if (error) {
        reportError(error);
        exit(1);
    }
}

FT_Face face;

void openFont(const char *file) {
    FT_Error error = FT_New_Face(library, file, 0, &face);

    if (error) {
        cerr << "Couldn't load " << file << endl;
        reportError(error);
        exit(1);
    }

    if (!FT_IS_SCALABLE(face)) {
        cerr << "Not a scalable font - unsupported: " << file << endl;
        FT_Done_Face(face);
        exit(1);
    }
}

std::map<unsigned, unsigned> font_chars;
std::set<unsigned> font_glyphs;

void enumChars() {
    FT_ULong  charcode;
    FT_UInt   gindex;

    charcode = FT_Get_First_Char(face, &gindex);
    while (gindex != 0)
    {
        font_chars[charcode] = gindex;
        font_glyphs.insert(gindex);

        charcode = FT_Get_Next_Char(face, charcode, &gindex);
    }
}

inline vec2 ft2vec(const FT_Vector &fv) {
    return vec2(fv.x/64.0f, -fv.y/64.0f);
}

void extractGlyphOutline(std::vector<std::vector<vec2> > *buf, FT_GlyphSlot glyph, vec2 fixup) {
    FT_Outline &outline = glyph->outline;

    buf->reserve(outline.n_points);

    for (int contour = 0; contour < outline.n_contours; contour++) {
        int sp = (contour > 0) ? outline.contours[contour-1]+1 : 0;
        int ep = outline.contours[contour];

        std::vector<vec2> points;
        std::vector<bool> ends;

        vec2 pp = fixup + ft2vec(outline.points[ep]);
        unsigned ptag = FT_CURVE_TAG(outline.tags[ep]);
        bool full = false;

        for (int pt = sp; pt <= ep; pt++) {
            vec2 cpt = fixup + ft2vec(outline.points[pt]);
            unsigned tag = FT_CURVE_TAG(outline.tags[pt]);

            if (tag == FT_CURVE_TAG_CONIC && ptag == FT_CURVE_TAG_CONIC) {
                points.push_back((pp + cpt)*0.5f);
                ends.push_back(true);
            } else if (pt == sp && tag != FT_CURVE_TAG_ON && ptag == FT_CURVE_TAG_ON) {
                points.push_back(pp);
                ends.push_back(true);
                full = true;
            }

            points.push_back(pp = cpt);
            ends.push_back((ptag = tag) == FT_CURVE_TAG_ON);
        }

        if (!full && ends[0]) {
            points.push_back(points[0]);
            ends.push_back(ends[0]);
        }

        std::vector<vec2> curve;

        for (unsigned i = 0; i < points.size(); i++) {
            curve.push_back(points[i]);

            if (ends[i] && curve.size() > 1) {
                buf->push_back(curve);
                curve.clear();
                curve.push_back(points[i]);
            }
        }
    }
}

float distanceToOutline(std::vector<std::vector<vec2> > *buf, vec2 pt)
{
    float min_dist = 1e+6;

    for (unsigned i = 0; i < buf->size(); i++) {
        float dist = closestPointToBezier((*buf)[i], pt).second;
        if (dist < min_dist)
            min_dist = dist;
    }

    return min_dist;
}

FontHeader header;
float em_size_factor;

std::vector<unsigned char> buffer;
std::vector<GlyphHeader> glyphs;

void initFont(int TileSize, int TileCnt, int EmSize, int DistRadius) {
    header.magic = FontHeader::MAGIC;
    header.hdr_size = sizeof(FontHeader);
    header.glyph_hdr_size = sizeof(GlyphHeader);
    header.tile_size = TileSize;
    header.grid_size = TileCnt;
    header.grid_px_size = TileSize*TileCnt;
    header.grid_glyph_cnt = TileCnt*TileCnt;
    header.grid_count = 0;
    header.glyph_count = 0;

    header.render_em_size = EmSize;
    header.active_tile_size = (TileSize-2)/header.render_em_size;

    // Prepare rendering
    header.dist_scale = 1.0f/DistRadius;

    buffer.resize(TileSize*TileSize*TileCnt*TileCnt);
    memset(&buffer[0], 0, buffer.size());

    glyphs.clear();
    glyphs.reserve(font_glyphs.size());

    // Configure font size and save metrics
    FT_Error error = FT_Set_Pixel_Sizes(face, EmSize, EmSize);
    if (error) {
        reportError(error);
        exit(1);
    }

    em_size_factor = 1.0f / face->units_per_EM;

    header.ascender = face->ascender * em_size_factor;
    header.descender = face->descender * em_size_factor;
    header.line_height = face->height * em_size_factor;
    header.max_advance = face->max_advance_width * em_size_factor;

    header.underline_position = face->underline_position * em_size_factor;
    header.underline_thickness = face->underline_thickness * em_size_factor;
}

void renderGlyph(unsigned id, unsigned unicode_char) {
    glyphs.push_back(GlyphHeader());
    GlyphHeader &gheader = glyphs.back();

    gheader.unicode_char = unicode_char;

    // Load unscaled, save metrics
    FT_Error error = FT_Load_Glyph(face, id, FT_LOAD_NO_SCALE);
    if (error) {
        cerr << "Error loading glyph " << id << endl;
        reportError(error);
        exit(1);
    }

    FT_Glyph_Metrics &metrics = face->glyph->metrics;

    vec2 raw_bearing = vec2(metrics.horiBearingX, -metrics.horiBearingY) * em_size_factor;
    gheader.bearing_x = raw_bearing.x;
    gheader.bearing_y = raw_bearing.y;
    vec2 raw_size = vec2(metrics.width,metrics.height) * em_size_factor;
    gheader.size_x = raw_size.x;
    gheader.size_y = raw_size.y;
    gheader.advance = metrics.horiAdvance * em_size_factor;

    // Load and render
    error = FT_Load_Glyph(face, id, FT_LOAD_RENDER | FT_LOAD_NO_HINTING);
    if (error) {
        cerr << "Error loading glyph " << id << endl;
        reportError(error);
        exit(1);
    }

    FT_GlyphSlot glyph = face->glyph;
    FT_Bitmap &bitmap = glyph->bitmap;

    assert (bitmap.pixel_mode == FT_PIXEL_MODE_GRAY && bitmap.num_grays == 256);

    // Compute integer bearing
    ivec2 bearing(glyph->bitmap_left, -glyph->bitmap_top);
    ivec2 size(bitmap.width, bitmap.rows);
    ivec2 in_offset = (ivec2(header.tile_size) - size)/2;

    vec2 field_bearing(bearing - in_offset);
    gheader.field_bearing_x = (field_bearing.x+1)/header.render_em_size;
    gheader.field_bearing_y = (field_bearing.y+1)/header.render_em_size;

    // Extract outline curves
    std::vector<std::vector<vec2> > outline;
    extractGlyphOutline(&outline, glyph, -field_bearing);

    // Prepare rendering the bitmap
    int cur_tile = header.glyph_count%header.grid_glyph_cnt;
    int cur_tile_y = cur_tile/header.grid_size;
    int cur_tile_x = cur_tile%header.grid_size;

    unsigned in_pitch = bitmap.pitch;
    unsigned char *input = bitmap.buffer;
    unsigned out_pitch = header.grid_px_size;
    unsigned out_base = header.tile_size*cur_tile_y*out_pitch + header.tile_size*cur_tile_x;
    unsigned char *output = &buffer[out_base];

    //float atan_scale = 254.0f/M_PI;
    //float fct = sqrt((atan_scale - 1)/header.tile_size/header.tile_size);

    //float vdiff = 4.0f;
    //float fct = sqrt((vdiff-1)*4/header.tile_size/header.tile_size);
    //float atan_scale = 128.0f/atanf(fct*header.tile_size/4);

    float scale = 128.0f * header.dist_scale;

    for (unsigned y = 0; y < header.tile_size; ++y) {
        int in_y = y - in_offset.y;
        unsigned char *in_row = (in_y >= 0 && in_y < size.y) ? &input[in_y*in_pitch] : NULL;
        unsigned char *out_row = output + out_pitch*y;

        for (unsigned x = 0; x < header.tile_size; ++x) {
            int in_x = x - in_offset.x;
            unsigned char in = (in_row && in_x >= 0 && in_x < size.x) ? in_row[in_x] : 0;

            float dist = distanceToOutline(&outline, vec2(x,y)+vec2(0.5f));
            float sdist = ((in >= 128) ? dist : -dist);
            //float cv = 128.0f + atan_scale*atanf(fct*sdist);
            float cv = 128.0f + scale*sdist;

            out_row[x] = (unsigned char)glm::clamp(cv, 0.0f, 255.0f);
        }
    }

    header.glyph_count++;
}

std::string out_prefix;
bool save_pgm = false;
bool save_xmf = false;

void flushTileField() {
    if (header.glyph_count <= header.grid_count*header.grid_glyph_cnt)
        return;

    // Write a pgm image file for inspection
    if (save_pgm) {
        std::string fname = out_prefix + stl_sprintf("%02d.pgm", header.grid_count);

        FILE *f = fopen(fname.c_str(), "wb");
        fprintf(f, "P5\n%d %d %d\n", header.grid_px_size, header.grid_px_size, 255);
        fwrite(&buffer[0], buffer.size(), 1, f);
        fclose(f);
    }

    if (save_xmf) {
        // Write a compressed copy of the raw data
        std::vector<unsigned char> cbuf(buffer.size());
        uLongf len = cbuf.size();

        if (compress2(&cbuf[0], &len, &buffer[0], buffer.size(), Z_BEST_COMPRESSION) != Z_OK) {
            cerr << "Could not compress bitmap." << endl;
            exit(1);
        }

        std::string fname = out_prefix + stl_sprintf("%02d.xmf", header.grid_count);
        FILE *f = fopen(fname.c_str(), "wb");
        fwrite(&cbuf[0], len, 1, f);
        fclose(f);
    }

    // Switch to next grid
    header.grid_count++;
    memset(&buffer[0], 0, buffer.size());
}

void saveJsonHeaders() {
    std::string fname = out_prefix + "index.json";
    std::ofstream out(fname.c_str());

    out << "{\n";
#define EMIT_HDR(name) out << ("\"" #name "\":") << header.name << ",\n"
    EMIT_HDR(tile_size);
    EMIT_HDR(grid_size);
    EMIT_HDR(grid_px_size);
    EMIT_HDR(grid_glyph_cnt);
    EMIT_HDR(grid_count);
    EMIT_HDR(glyph_count);
    EMIT_HDR(render_em_size);
    EMIT_HDR(active_tile_size);
    EMIT_HDR(dist_scale);
    EMIT_HDR(ascender);
    EMIT_HDR(descender);
    EMIT_HDR(line_height);
    EMIT_HDR(max_advance);
    EMIT_HDR(underline_position);
    EMIT_HDR(underline_thickness);
#undef EMIT_HDR

    out << "\"em_size_factor\":" << (1.0f / em_size_factor) << ",\n";
    out << "\"glyphdata\":[" << std::endl;


    for (size_t i = 0; i < glyphs.size(); i++)
    {
        GlyphHeader &glyph = glyphs[i];

        out << "[\"\\u" << stl_sprintf("%04x", glyph.unicode_char) << "\"";

#define EMIT_GLYPH(name) out << "," << (int)round(glyph.name / em_size_factor);
#define EMIT_GLYPH2(name) out << "," << (int)round(glyph.name * -header.render_em_size);
        EMIT_GLYPH(bearing_x);
        EMIT_GLYPH(bearing_y);
        EMIT_GLYPH(size_x);
        EMIT_GLYPH(size_y);
        EMIT_GLYPH(advance);
        EMIT_GLYPH2(field_bearing_x);
        EMIT_GLYPH2(field_bearing_y);
#undef EMIT_GLYPH2
#undef EMIT_GLYPH

        out << "]" << (i < glyphs.size()-1 ? "," : "") << std::endl;
    }

    out << "]}" << std::endl;
}

void saveFontHeaders() {
    flushTileField();

    if (save_pgm)
        saveJsonHeaders();

    if (save_xmf) {
        std::string fname = out_prefix + "index.dat";

        assert(header.glyph_count == glyphs.size());
        assert((sizeof(FontHeader)%4) == 0);
        assert((sizeof(GlyphHeader)%4) == 0);

        FILE *f = fopen(fname.c_str(), "wb");
        fwrite(&header, sizeof(FontHeader), 1, f);
        fwrite(&glyphs[0], sizeof(GlyphHeader), glyphs.size(), f);
        fclose(f);
    }
}

void addGlyph(unsigned id, unsigned uchar) {
    renderGlyph(id, uchar);

    if ((header.glyph_count % header.grid_glyph_cnt) == 0)
        flushTileField();
}

void usage() {
    cerr << "Usage: FontConvertor [-s em-size] [-t tile-size] [-i grid-size] [-r dist-radius] [-o output-dir] [-g glyph-file] [-p] <font-file>" << endl;
    cerr << "  -x            Generate .xmf files for c++ runner" << endl;
    cerr << "  -p            Generate .pgm files for JS dfont" << endl;
    cerr << "  -s <em-size>  Font size. Default is tile-size - 2" << endl;
    exit(1);
}

int main(int argc, char *argv[]) {
    int TileSize = 32;
    int GridSize = 16;
    int EmSize = 0;
    int DistRadius = 0;

    std::string glyph_file;

    int c;
    while ((c = getopt (argc, argv, "t:i:s:r:o:g:px")) != -1) {
        switch (c)
        {
        case 't':
            TileSize = atoi(optarg);
            break;
        case 'i':
            GridSize = atoi(optarg);
            break;
        case 's':
            EmSize = atoi(optarg);
            break;
        case 'r':
            DistRadius = atoi(optarg);
            break;
        case 'o':
            out_prefix = std::string(optarg);
            if (!out_prefix.empty() && out_prefix[out_prefix.size()] != '/')
                out_prefix += "/";
            break;
        case 'g':
            glyph_file = std::string(optarg);
            break;
        case 'p':
            save_pgm = true;
            break;
        case 'x':
            save_xmf = true;
            break;
        case '?':
            cerr << "Unknown option, or missing argument: '" << char(optopt) << "'" << endl;
        default:
            usage();
        }
    }

    if (optind >= argc)
        usage();

    init();
    openFont(argv[optind]);
    enumChars();

    cout << "Total characters for " << argv[optind] << ": " << font_chars.size() << ", glyphs: " << font_glyphs.size() << endl;

    if (!EmSize)
        EmSize = TileSize-2;
    if (!DistRadius)
        DistRadius = TileSize/4;

    initFont(TileSize, GridSize, EmSize, DistRadius);

    // Load the set of characters
    unicode_string chars;
    if (!glyph_file.empty())
		chars = parseUtf8u(readFileAsUnicodeString(glyph_file, nullptr));
    else {
        for (std::map<unsigned,unsigned>::iterator it = font_chars.begin(); it != font_chars.end(); ++it)
            chars.push_back(it->first);
    }

    // Ensure these are always there somewhere
    chars.push_back(' '); // space
    chars.push_back(UNICODE_INVALID_CHAR); // invalid character

    // Pack the characters
    std::set<unicode_char> handled;
    handled.insert('\n');
    handled.insert('\r');
    handled.insert(0xFEFF);

    for (unsigned i = 0; i < chars.size(); i++) {
        unicode_char c = chars[i];
        if (handled.count(c)) continue;

        handled.insert(c);
        unsigned id = font_chars[c];
        addGlyph(id, c);
    }

    // Complete the job
    saveFontHeaders();

    return 0;
}
