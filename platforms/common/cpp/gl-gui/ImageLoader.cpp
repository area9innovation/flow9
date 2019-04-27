#include "ImageLoader.h"

extern "C" {
#include <jpeglib.h>
#include <jerror.h>
}

#ifdef _MSC_VER
#define _INLINE_ATTR __forceinline
#else
#define _INLINE_ATTR __attribute__((always_inline))
#endif

#if BITS_IN_JSAMPLE != 8
    #error JSAMPLE must be 1 byte
#endif

#include <png.h>
#include <zlib.h>

/****************************
 *          COMMON          *
 ****************************/

namespace {
    struct DecodeError : public std::exception {};
}

/****************************
 *      JPEG DECODING       *
 ****************************/

/* Read from memory support for JPEG */
static void no_op(j_decompress_ptr) {}

static boolean fill_input_buffer(j_decompress_ptr cinfo)
{
    struct jpeg_source_mgr * src = cinfo->src;
    static JOCTET FakeEOI[] = { 0xFF, JPEG_EOI };

    cerr << "Input buffer too short in JPEG decode." << endl;

    src->next_input_byte = FakeEOI;
    src->bytes_in_buffer = 2;

    return TRUE;
}

static void skip_input_data(j_decompress_ptr cinfo, long num_bytes)
{
    struct jpeg_source_mgr *src = cinfo->src;

    if(num_bytes >= (long)src->bytes_in_buffer) {
        fill_input_buffer(cinfo);
    } else {
        src->bytes_in_buffer -= num_bytes;
        src->next_input_byte += num_bytes;
    }
}

static void get_jpeg_mem_src(j_decompress_ptr cinfo, const uint8_t *data, int size)
{
    if (cinfo->src == NULL)
    {   /* first time for this JPEG object? */
        void *ptr = (*cinfo->mem->alloc_small)((j_common_ptr)cinfo, JPOOL_PERMANENT, sizeof(jpeg_source_mgr));
        cinfo->src = (jpeg_source_mgr*)ptr;
    }

    jpeg_source_mgr *src = cinfo->src;

    /* Set up function pointers */
    src->init_source = no_op;
    src->fill_input_buffer = fill_input_buffer;
    src->skip_input_data = skip_input_data;
    src->resync_to_restart = jpeg_resync_to_restart; /* use default method */
    src->term_source = no_op;

    /* Set up data pointer */
    src->bytes_in_buffer = size;
    src->next_input_byte = (JOCTET*)data;
}

/* JPEG error handling */

namespace {
    struct JPEGError : public DecodeError {};

    struct JPEGErrorHandler {
        jpeg_error_mgr mgr;

        JPEGErrorHandler() {
            jpeg_std_error(&mgr);

            mgr.error_exit = cbExit;
            mgr.output_message = cbMessage;
        }

    private:
        static void cbExit(j_common_ptr cinfo) {
            (cinfo->err->output_message)(cinfo);
            // Non-local exit required by API
            throw JPEGError();
        }

        static void cbMessage(j_common_ptr cinfo) {
            char buffer[JMSG_LENGTH_MAX];
            (cinfo->err->format_message)(cinfo, buffer);
            cerr << "JPEG ERROR: " << buffer << endl;
        }
    };

    struct JPEGDecoder {
        JPEGErrorHandler err_handler;
        jpeg_decompress_struct cinfo;

        JPEGDecoder() {
            cinfo.err = &err_handler.mgr;
            jpeg_create_decompress(&cinfo);
        }

        ~JPEGDecoder() {
            jpeg_destroy_decompress(&cinfo);
        }

        jpeg_decompress_struct *operator->() { return &cinfo; }
        operator jpeg_decompress_struct*() { return &cinfo; }
    };

    struct AutoFILE {
        FILE *file;

        AutoFILE(FILE *file) : file(file) {}
        ~AutoFILE() { if (file) fclose(file); }

        operator FILE*() { return file; }
    };
}

static GLTextureBitmap::Ptr decodeJPEG(JPEGDecoder &cinfo, size_t max_load_size)
{
    jpeg_read_header(cinfo, TRUE);

    GLenum format;
    if (cinfo->out_color_space == JCS_GRAYSCALE)
        format = GL_LUMINANCE;
    else {
        format = GL_RGB;
        cinfo->out_color_space = JCS_RGB;
    }

    ivec2 size(cinfo->image_width, cinfo->image_height);

    // Lazy load: bail out here if too big
    if (size_t(size.x * size.y) > max_load_size)
        return GLTextureBitmap::Ptr(new GLTextureBitmap(size, GL_FALSE));

    jpeg_start_decompress(cinfo);

    if (cinfo->output_components != (format == GL_RGB ? 3 : 1)) {
        cerr << "Invalid output component count: " << cinfo->output_components << endl;
        throw DecodeError();
    }

    if (ivec2(cinfo->output_width, cinfo->output_height) != size) {
        cerr << "Invalid output size in decodeJPEG" << endl;
        throw DecodeError();
    }

    GLTextureBitmap::Ptr bmp(new GLTextureBitmap(size, format));

    JSAMPLE *buf = (JSAMPLE*)bmp->getDataPtr();
    unsigned stride = cinfo->output_components * cinfo->output_width;

    while (cinfo->output_scanline < cinfo->output_height)
    {
        JSAMPLE *line = buf + cinfo->output_scanline * stride;
        jpeg_read_scanlines (cinfo, &line, 1);
    }

    jpeg_finish_decompress (cinfo);
    return bmp;
}

GLTextureBitmap::Ptr loadJPEG(std::string filename, size_t max_load_size)
{
    try {
        AutoFILE fd(fopen(filename.c_str(), "rb"));
        if (!fd) {
            cerr << "Could not open JPEG: " << filename << endl;
            return GLTextureBitmap::Ptr();
        }
        
        JPEGDecoder decoder;
        jpeg_stdio_src(decoder, fd);
        
        return decodeJPEG(decoder, max_load_size);
    } catch (DecodeError) {
        return GLTextureBitmap::Ptr();
    }
}

bool isJPEG(const uint8_t *data, unsigned size)
{
    return size>=2 && !memcmp(data, "\xFF\xD8", 2);
}

GLTextureBitmap::Ptr loadJPEG(const uint8_t *data, unsigned size, size_t max_load_size)
{
    try {
        JPEGDecoder decoder;
        get_jpeg_mem_src(decoder, data, size);

        return decodeJPEG(decoder, max_load_size);
    } catch (DecodeError) {
        return GLTextureBitmap::Ptr();
    }
}

/****************************
 *       PNG DECODING       *
 ****************************/
namespace {
    struct PNGError : public DecodeError {};

    struct PNGDecoder {
        png_structp png;
        png_infop info;

        PNGDecoder() : png(NULL), info(NULL) {
            png = png_create_read_struct(PNG_LIBPNG_VER_STRING, this, cbError, cbWarn);
            if (!png)
                throw PNGError();

            info = png_create_info_struct(png);
            if (!info) {
                png_destroy_read_struct(&png, NULL, NULL);
                throw PNGError();
            }
        }

        ~PNGDecoder() {
            png_destroy_read_struct(&png, &info, NULL);
        }

    private:
        static void cbError(png_structp, png_const_charp msg) {
            cerr << "PNG ERROR: " << msg << endl;
            throw PNGError();
        }

        static void cbWarn(png_structp, png_const_charp msg) {
            cerr << "PNG WARNING: " << msg << endl;
        }
    };

    struct PNGMemoryReader {
        const uint8_t *data;
        unsigned size;

        PNGMemoryReader(PNGDecoder &decoder, const uint8_t *data, unsigned size) : data(data), size(size) {
            png_set_read_fn(decoder.png, this, cbRead);
        }

    private:
        static void cbRead(png_structp ptr, png_bytep buf, png_size_t length) {
            PNGMemoryReader *reader = (PNGMemoryReader*)png_get_io_ptr(ptr);
            if (length > reader->size)
                png_error(ptr, "Unexpected end of input");

            memcpy(buf, reader->data, length);
            reader->data += length;
            reader->size -= length;
        }
    };
}

_INLINE_ATTR inline unsigned char premultiply(unsigned char color, unsigned char alpha)
{
    uint16_t product = uint16_t(color) * alpha + 128;
    return (unsigned char)((product + (product>>8))>>8); // divide by 255
}

static void premultiplyAlpha(GLTextureBitmap::Ptr bmp)
{
    unsigned char *pdata = bmp->getDataPtr();
    unsigned char *pend = pdata + bmp->getDataSize();

    switch (bmp->getDataFormat())
    {
    case GL_LUMINANCE_ALPHA:
        for (; pdata < pend; pdata += 2)
            pdata[0] = premultiply(pdata[0], pdata[1]);
        break;

    case GL_RGBA:
        for (; pdata < pend; pdata += 4)
        {
            pdata[0] = premultiply(pdata[0], pdata[3]);
            pdata[1] = premultiply(pdata[1], pdata[3]);
            pdata[2] = premultiply(pdata[2], pdata[3]);
        }
        break;

    default:
        break;
    }
}

static GLTextureBitmap::Ptr decodePNG(PNGDecoder &decoder, size_t max_load_size)
{
    png_read_info(decoder.png, decoder.info);

    // Extract format info
    png_uint_32 width, height;
    int bit_depth, color_type, interlace_type;
    png_get_IHDR(decoder.png, decoder.info, &width, &height, &bit_depth, &color_type,
                 &interlace_type, NULL, NULL);

    // Lazy load: bail out here if too big
    if (size_t(width * height) > max_load_size)
        return GLTextureBitmap::Ptr(new GLTextureBitmap(ivec2(width, height), GL_FALSE));

    GLenum format;
    bool has_tRNS = png_get_valid(decoder.png, decoder.info, PNG_INFO_tRNS);

    switch (color_type) {
    case PNG_COLOR_TYPE_GRAY:
        if (!has_tRNS) {
            format = GL_LUMINANCE;
            break;
        }
    case PNG_COLOR_TYPE_GRAY_ALPHA:
        format = GL_LUMINANCE_ALPHA;
        break;
    case PNG_COLOR_TYPE_PALETTE:
    case PNG_COLOR_TYPE_RGB:
        if (!has_tRNS) {
            format = GL_RGB;
            break;
        }
    case PNG_COLOR_TYPE_RGB_ALPHA:
        format = GL_RGBA;
        break;
    default:
        cerr << "Unknown PNG color type: " << color_type << endl;
        throw DecodeError();
    }

    int size = GLTextureBitmap::getBytesPerPixel(format);

    // Set up transformations

    /* Convert 16-bit to 8-bit */
    png_set_strip_16(decoder.png);

    /* Explode packed pixels into separate bytes. */
    png_set_packing(decoder.png);

    /* Expand paletted colors into true RGB triplets */
    /* Expand grayscale images to the full 8 bits from 1, 2, or 4 bits/pixel */
    /* Expand paletted or RGB images with transparency to full alpha channels
     * so the data will be available as RGBA quartets. */
    png_set_expand(decoder.png);

    png_read_update_info(decoder.png, decoder.info);

    // Check consistency
    unsigned rbytes = png_get_rowbytes(decoder.png, decoder.info);
    unsigned stride = width*size;
    if (rbytes != stride) {
        cerr << "Row length mismatch: " << rbytes << " instead of " << stride << endl;
        throw DecodeError();
    }

    // Allocate
    GLTextureBitmap::Ptr bmp(new GLTextureBitmap(ivec2(width, height), format));
    std::vector<png_bytep> row_pointers(height);

    png_bytep buf = (png_bytep)bmp->getDataPtr();
    for (unsigned i = 0; i < height; i++)
        row_pointers[i] = buf + i*stride;

    // Read data
    png_read_image(decoder.png, row_pointers.data());

    premultiplyAlpha(bmp);

    png_read_end(decoder.png, decoder.info);
    return bmp;
}

GLTextureBitmap::Ptr loadPNG(std::string filename, size_t max_load_size)
{
    try {
        AutoFILE fd(fopen(filename.c_str(), "rb"));
        if (!fd) {
            cerr << "Could not open PNG: " << filename << endl;
            return GLTextureBitmap::Ptr();
        }
        
        PNGDecoder decoder;
        png_init_io(decoder.png, fd);
        
        return decodePNG(decoder, max_load_size);
    } catch (DecodeError) {
        return GLTextureBitmap::Ptr();
    }
}

bool isPNG(const uint8_t *data, unsigned size)
{
    static const uint8_t png_sig[] = {137, 80, 78, 71, 13, 10, 26, 10}; 
    return size >= 8 && memcmp(data, png_sig, 8) == 0;
}

GLTextureBitmap::Ptr loadPNG(const uint8_t *data, unsigned size, size_t max_load_size)
{
    try {
        PNGDecoder decoder;
        PNGMemoryReader reader(decoder, data, size);
        (void)&reader;

        return decodePNG(decoder, max_load_size);
    } catch (DecodeError) {
        return GLTextureBitmap::Ptr();
    }
}

/****************************
 *       SWF DECODING       *
 ****************************/

namespace {
    struct SWFError : public DecodeError {};

    struct SWFHeader {
        uint8_t  Signature[3];
        uint8_t  Version;
        uint32_t FileLength;
    };

    enum SWFTags
    {
        Unknown = -1,
        End = 0,
        DefineShape = 2,
        JpegTable = 8,
        DefineBitsLossLess = 20,
        DefineShape2 = 22,
        DefineBitsJpeg2 = 21,
        DefineShape3 = 32,
        DefineBitsJpeg3 = 35,
        DefineBitsLossLess2 = 36
    };
}

template<class T>
void getItem(T *value, const uint8_t *&data, const uint8_t *end)
{
    const uint8_t *nptr = data + sizeof(T);
    if (nptr > end)
        throw SWFError();

    *value = *(T*)data;
    data = nptr;
}

static void skipItem(const uint8_t *&data, const uint8_t *end, unsigned len)
{
    const uint8_t *nptr = data + len;
    if (nptr > end)
        throw SWFError();
    data = nptr;
}

static bool matchPrefix(const uint8_t *&data, const uint8_t *end, const char *mask, unsigned len)
{
    const uint8_t *nptr = data + len;
    if (nptr > end)
        return false;
    return memcmp(data, mask, len) == 0;
}

static GLTextureBitmap::Ptr loadSWFJpeg(const uint8_t *data, const uint8_t *alpha, const uint8_t *end, size_t max_load_size)
{
    if (data >= alpha || alpha > end)
        throw SWFError();

    GLTextureBitmap::Ptr bmp;

    if (isPNG(data, alpha-data)) {
        if (alpha != end) {
            cerr << "PNG data in SWF is not compatible with separate alpha." << endl;
            throw SWFError();
        }

        bmp = loadPNG(data, alpha-data, max_load_size);
    } else {
        // Work around a known legacy bug in SWF storage format
        if (matchPrefix(data, alpha, "\xFF\xD9\xFF\xD8", 4))
            skipItem(data, alpha, 4);

        bmp = loadJPEG(data, alpha-data, max_load_size);
    }

    if (!bmp)
        throw SWFError();
    if (bmp->isStub())
        return bmp;

    if (alpha != end) {
        ivec2 bsize = bmp->getSize();

        // Decompress alpha data
        std::vector<uint8_t> alpha_data(bsize.x * bsize.y);

        uLongf len = alpha_data.size();
        if (uncompress(&alpha_data[0], &len, alpha, end-alpha) != Z_OK || len != alpha_data.size()) {
            cerr << "Could not uncompress DefineBitsJpeg3 alpha data" << endl;
            throw SWFError();
        }

        // Allocate a new bitmap
        bool rgb = bmp->getDataFormat() == GL_RGB;
        GLenum afmt = (rgb ? GL_RGBA : GL_LUMINANCE_ALPHA);
        GLTextureBitmap::Ptr abmp(new GLTextureBitmap(bsize, afmt));

        uint8_t *cdata = bmp->getDataPtr();
        uint8_t *rdata = abmp->getDataPtr();
        uint8_t *adata = alpha_data.data();

        // Merge data
        if (rgb) {
            for (unsigned i = 0; i < alpha_data.size(); i++, cdata += 3, rdata += 4, adata++) {
                // Assume these RGB data is premultiplied already.
                rdata[0] = cdata[0]; //premultiply(cdata[0], adata[0]);
                rdata[1] = cdata[1]; //premultiply(cdata[1], adata[0]);
                rdata[2] = cdata[2]; //premultiply(cdata[2], adata[0]);
                rdata[3] = adata[0];
            }
        } else {
            for (unsigned i = 0; i < alpha_data.size(); i++, cdata++, rdata += 2, adata++) {
                rdata[0] = premultiply(cdata[0], adata[0]);
                rdata[1] = adata[0];
            }
        }

        bmp = abmp;
    }

    return bmp;
}

static GLTextureBitmap::Ptr decodeSWFTag(uint16_t tag, const uint8_t *data, const uint8_t *end, size_t max_load_size)
{
    uint32_t offset;

    switch (tag) {
    case DefineBitsJpeg2:
        skipItem(data, end, sizeof(uint16_t));
        return loadSWFJpeg(data, end, end, max_load_size);

    case DefineBitsJpeg3:
        skipItem(data, end, sizeof(uint16_t));
        getItem(&offset, data, end);
        return loadSWFJpeg(data, data+offset, end, max_load_size);

    default:
        return GLTextureBitmap::Ptr();
    }
}

static void skipHeader(const uint8_t *&data, const uint8_t *end)
{
    uint8_t rect_nbits = 0;
    getItem(&rect_nbits, data, end);
    rect_nbits = (rect_nbits & 0xF8) >> 3;
    uint32_t bytes_count = ((rect_nbits * 4) - 3 + 7) / 8;

    // Skip frame size, rate and count
    skipItem(data, end, bytes_count + 2*sizeof(uint16_t));
}

static GLTextureBitmap::Ptr decodeSWF(const uint8_t *data, const uint8_t *end, size_t max_load_size)
{
    skipHeader(data, end);

    bool shapes = false;

    for (;;)
    {
        // Decode tag and length
        uint16_t tag_and_length;
        getItem(&tag_and_length, data, end);

        uint16_t tag = (tag_and_length & 0xFFC0) >> 6;
        uint32_t tag_len = (tag_and_length & 0x003F);

        if (tag == End)
            break;
        if (tag_len == 0x003F)
            getItem(&tag_len, data, end);

        // Decode tag contents
        const uint8_t *tag_end = data + tag_len;
        if (tag_end > end)
            throw SWFError();

        GLTextureBitmap::Ptr bmp = decodeSWFTag(tag, data, tag_end, max_load_size);
        if (bmp)
            return bmp;

        if (tag == DefineShape || tag == DefineShape2 || tag == DefineShape3)
            shapes = true;

        // Proceed to the next tag
        data = tag_end;
    }

    cerr << "No supported bitmaps in SWF" << (shapes ? " (has shapes)" : "") << endl;

    return GLTextureBitmap::Ptr();
}

bool isSWF(const uint8_t *ptr, unsigned size)
{
    return size>=3 && (!memcmp(ptr, "CWS", 3) || !memcmp(ptr, "FWS", 3));
}

GLTextureBitmap::Ptr loadSWF(const uint8_t *data, unsigned size, size_t max_load_size)
{
    const unsigned hdr_size = sizeof(SWFHeader);
    if (!isSWF(data, size) || size < hdr_size) {
        cerr << "Not an SWF file." << endl;
        return GLTextureBitmap::Ptr();
    }

    try {
        const SWFHeader *header = (SWFHeader*)data;
        const uint8_t *dptr = data + hdr_size;
        size -= hdr_size;

        std::vector<uint8_t> uncompressed_data;

        if (header->Signature[0] == 'C') {
            uncompressed_data.resize(header->FileLength-hdr_size);

            uint8_t *uc_dptr = uncompressed_data.data();
            uLongf len = uncompressed_data.size();

            if (uncompress(uc_dptr, &len, dptr, size) != Z_OK) {
                cerr << "Could not uncompress SWF data." << endl;
                return GLTextureBitmap::Ptr();
            }

            dptr = uc_dptr;
            size = len;
        }

        return decodeSWF(dptr, dptr+size, max_load_size);
    } catch (DecodeError) {
        cerr << "SWF decoding failed" << endl;
        return GLTextureBitmap::Ptr();
    }
}

GLTextureBitmap::Ptr loadImageAuto(const uint8_t *data, unsigned size, size_t max_load_size)
{
    if (isSWF(data, size))
        return loadSWF(data, size, max_load_size);

    if (isPNG(data, size))
        return loadPNG(data, size, max_load_size);

    if (isJPEG(data, size))
        return loadJPEG(data, size, max_load_size);

    cerr << "Unrecognized image format." << endl;
    return GLTextureBitmap::Ptr();
}
