#include "AndroidUtils.h"

#include <android/log.h>

ostream log_info(new AndroidLogStreambuf(ANDROID_LOG_INFO, RUNNER_PACKAGE));
ostream log_error(new AndroidLogStreambuf(ANDROID_LOG_ERROR, RUNNER_PACKAGE));

AndroidLogStreambuf::AndroidLogStreambuf(int level, std::string tag) :
    log_level(level), tag(tag), buffer(8*1024+2)
{
    // Leave 2 characters beyond the end
    setp(&buffer[0], &buffer[buffer.size()-2]);
}

AndroidLogStreambuf::~AndroidLogStreambuf()
{
    sync();
}

int AndroidLogStreambuf::flushBuffer () {
    char *base = pbase();
    int num = pptr() - base, last_nl;

    // Nothing to do
    if (num <= 0) return 0;

    // Find last newline
    for (last_nl = num-1; last_nl >= 0 && base[last_nl] != '\n'; --last_nl);

    // If none, do a line break at the end
    if (last_nl < 0) last_nl = num;

    // Output the lines if there's anything to output
    if (last_nl > 0) {
        base[last_nl] = 0;
        __android_log_write(log_level, tag.c_str(), base);
    }

    // Shift the remaining characters
    if (last_nl < num) {
        last_nl++;
        memmove(base, base + last_nl, num - last_nl);
    }

    pbump(-last_nl);

    return num;
}

int AndroidLogStreambuf::overflow (int c) {
    if (c != EOF) {
        *pptr() = c;    // insert character into the buffer
        pbump(1);
    }
    if (flushBuffer() == EOF)
        return EOF;
    return c;
}

int AndroidLogStreambuf::sync() {
    if (flushBuffer() == EOF)
        return -1;    // ERROR
    return 0;
}
