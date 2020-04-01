#include "GLPictureClip.h"

#include "core/GarbageCollector.h"
#include "core/RunnerMacros.h"

#include <algorithm>

const unsigned int MAX_TEXTURE_SIDE = 4096;

IMPLEMENT_FLOW_NATIVE_OBJECT(GLPictureClip, GLClip);

GLPictureClip::GLPictureClip(GLRenderSupport *owner, unicode_string name) :
    GLClip(owner), name(name)
{
    size_callback = error_callback = StackSlot::MakeVoid();
    pending = true;
}

void GLPictureClip::flowGCObject(GarbageCollectorFn ref)
{
    GLClip::flowGCObject(ref);
    ref << size_callback << error_callback;
}

bool GLPictureClip::flowDestroyObject()
{
    if (pending)
        owner->removePictureFromPending(this);

    return GLClip::flowDestroyObject();
}

void GLPictureClip::setCallbacks(const StackSlot &size_cb, const StackSlot &error_cb, bool only_dl)
{
    size_callback = size_cb;
    error_callback = error_cb;
    only_download = only_dl;
}

void GLPictureClip::reportError(unicode_string msg)
{
    if (!error_callback.IsVoid()) {
        RUNNER_VAR = getFlowRunner();

        RUNNER_DefSlots1(str);
        str = RUNNER->AllocateString(msg);
        RUNNER->EvalFunction(error_callback, 1, str);
    }

    pending = false;

    size_callback = error_callback = StackSlot::MakeVoid();
}

void GLPictureClip::setDownloaded()
{
    assert(only_download);

    if (!size_callback.IsVoid()) {
        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(size_callback, 2, StackSlot::MakeDouble(1), StackSlot::MakeDouble(1));
    }

    pending = false;

    size_callback = error_callback = StackSlot::MakeVoid();
}

void GLPictureClip::setImage(GLTextureBitmap::Ptr image)
{
    vec2 imageSize = vec2(image->getSize());
#ifdef ANDROID
    this->imageGrid = {{image}};
#else
    if (imageSize.x < MAX_TEXTURE_SIDE && imageSize.y < MAX_TEXTURE_SIDE) {
        this->imageGrid = {{image}};
    } else {
        for (int i = 0; i * MAX_TEXTURE_SIDE < imageSize.y; i++) {
            this->imageGrid.push_back(vector<GLTextureImage::Ptr>());

            for (int j = 0; j * MAX_TEXTURE_SIDE < imageSize.x; j++) {
                vec2 offset(j * MAX_TEXTURE_SIDE, i * MAX_TEXTURE_SIDE);
                vec2 size(std::min<unsigned int>(MAX_TEXTURE_SIDE, imageSize.x - offset.x), std::min<unsigned int>(MAX_TEXTURE_SIDE, imageSize.y - offset.y));
                
                this->imageGrid[i].push_back(cropTextureBitmap(image, offset, size));
            }
        }
    }
#endif
    
    wipeFlags(WipeGraphicsChanged);

    if (!size_callback.IsVoid()) {
        ivec2 size = ivec2(computeImageGridSize());

        RUNNER_VAR = getFlowRunner();
        RUNNER->EvalFunction(size_callback, 2, StackSlot::MakeDouble(size.x), StackSlot::MakeDouble(size.y));
    }

    pending = false;

    size_callback = error_callback = StackSlot::MakeVoid();
}

GLTextureBitmap::Ptr GLPictureClip::cropTextureBitmap(GLTextureBitmap::Ptr image, vec2 offset, vec2 size) {
    vec2 imageSize = vec2(image->getSize());
    bool isSolidCopy = imageSize.x == size.x;
    
    GLTextureBitmap::Ptr cellImage(new GLTextureBitmap(ivec2(size), image->getDataFormat()));
    uint8_t* cellData = cellImage->getDataPtr();
    unsigned int cellDataSize = size.x * size.y * image->getBytesPerPixel();
    
    uint8_t* data = image->getDataPtr();
    
    if (isSolidCopy) {
        unsigned long offsetBytes = offset.y*imageSize.x*image->getBytesPerPixel();
        memcpy(cellData, data + offsetBytes, cellDataSize);
    } else {
        unsigned long imageCellLineDataSize = size.x * image->getBytesPerPixel();
        unsigned long imageLineDataSize = imageSize.x * image->getBytesPerPixel();
        unsigned long startOffset = offset.y * imageLineDataSize + offset.x * image->getBytesPerPixel();
        for (int line = 0; line < size.y; line++) {
            memcpy(cellData + line * imageCellLineDataSize, data + startOffset + line * imageLineDataSize, imageCellLineDataSize);
        }
    }
    
    return cellImage;
}

vec2 GLPictureClip::computeImageGridSize() {
    if (!imageGrid.empty()) {
        vec2 size = vec2(0,0);
        for (int i = 0; i < this->imageGrid.size(); i++) {
            size.y += this->imageGrid[i][0]->getSize().y;
        }
        for (int i = 0; i < this->imageGrid[0].size(); i++) {
            size.x += this->imageGrid[0][i]->getSize().x;
        }
        
        return size;
    }
    
    return vec2(0,0);
}

void GLPictureClip::computeBBoxSelf(GLBoundingBox &bbox, const GLTransform &transform)
{
    GLClip::computeBBoxSelf(bbox, transform);
    if (!imageGrid.empty()) {
        bbox |= transform * GLBoundingBox(vec2(0,0), computeImageGridSize());
    }
}

void GLPictureClip::renderInner(GLRenderer *renderer, GLDrawSurface *surface, const GLBoundingBox &clip_box)
{
    // Actually painting - force lazy-loaded pictures
    if (!imageGrid.empty() && imageGrid[0][0]->isStub() && !owner->loadStubPicture(name, imageGrid[0][0])) {
        cerr << "Could not force lazy-loaded picture." << endl;
        imageGrid[0][0].reset();
    }

    if (!imageGrid.empty()) {
        surface->makeCurrent();

        renderer->beginDrawFancy(vec4(0,0,0,0), true);

        glVertexAttrib4f(GLRenderer::AttrVertexColor, global_alpha, global_alpha, global_alpha, global_alpha);
        
        for (int i = 0; i < imageGrid.size(); i++) {
            for (int j = 0; j < imageGrid[i].size(); j++) {
                vec2 offset(MAX_TEXTURE_SIDE * j, MAX_TEXTURE_SIDE * i);
                imageGrid[i][j]->drawRect(renderer, offset, offset + vec2(imageGrid[i][j]->getSize()));
            }
        }

        renderer->reportGLErrors("GLPictureClip::renderInner post image");
    }

    GLClip::renderInner(renderer, surface, clip_box);
}
