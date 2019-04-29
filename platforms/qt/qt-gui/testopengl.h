#ifndef TESTOPENGL_H
#define TESTOPENGL_H

#ifdef WIN32
  #include <GL/glew.h>
#else
  #ifdef __APPLE__
    #include <OpenGL/gl.h>
  #else
    #include <GL/gl.h>
  #endif
#endif
#ifdef __APPLE__
  #include <OpenGL/glext.h>
#else
  #include <GL/glext.h>
#endif

#include <stdlib.h>
#include <functional>
#include <iostream>

#include <QOpenGLWidget>

class TestOpenGLWidget : public QOpenGLWidget
{
private:
    std::function<void(bool)> openGlCallback;
public:
    TestOpenGLWidget(std::function<void(bool)> callback) : QOpenGLWidget(), openGlCallback(callback) {}
    void initializeGL() {
#ifdef GLEW_VERSION
        if (glewInit() != GLEW_OK) {
            cerr << "Failed to initialize GLEW." << endl;
            exit(1);
        }
#endif

        GLint isMultiSamplingSupported = -1;
        glGetIntegerv(GL_MULTISAMPLE, &isMultiSamplingSupported);
        openGlCallback((bool)isMultiSamplingSupported);
    }
};

#endif // TESTOPENGL_H
