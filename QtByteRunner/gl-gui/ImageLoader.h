#ifndef IMAGELOADER_H
#define IMAGELOADER_H

#include "GLRenderer.h"

#define ALWAYS_LOAD ((size_t)-1)

bool isJPEG(const uint8_t *data, unsigned size);

GLTextureBitmap::Ptr loadJPEG(std::string filename, size_t max_load_size = ALWAYS_LOAD);
GLTextureBitmap::Ptr loadJPEG(const uint8_t *data, unsigned size, size_t max_load_size = ALWAYS_LOAD);

bool isPNG(const uint8_t *data, unsigned size);

GLTextureBitmap::Ptr loadPNG(std::string filename, size_t max_load_size = ALWAYS_LOAD);
GLTextureBitmap::Ptr loadPNG(const uint8_t *data, unsigned size, size_t max_load_size = ALWAYS_LOAD);

bool isSWF(const uint8_t *data, unsigned size);

GLTextureBitmap::Ptr loadSWF(const uint8_t *data, unsigned size, size_t max_load_size = ALWAYS_LOAD);

GLTextureBitmap::Ptr loadImageAuto(const uint8_t *data, unsigned size, size_t max_load_size = ALWAYS_LOAD);

#endif // IMAGELOADER_H
