#ifndef ANDROID_UTILS_H
#define ANDROID_UTILS_H

#include "core/CommonTypes.h"

#include <streambuf>

#define RUNNER_PACKAGE "dk.area9.flowrunner"

extern ostream log_info;
extern ostream log_error;

class AndroidLogStreambuf : public std::streambuf
{
protected:
    int log_level;
    std::string tag;
    std::vector<char> buffer;

public:
    AndroidLogStreambuf(int level, std::string tag);
    virtual ~AndroidLogStreambuf();

protected:
    int flushBuffer ();
    virtual int overflow(int c = EOF);
    virtual int sync();
};

#endif
