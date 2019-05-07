#ifndef SWFLOADER_H
#define SWFLOADER_H
#include <QtGui>

class SWFLoader
{
public:
    static QPixmap LoadImageFromSWF(const char * path_to_swf);
};

#endif // SWFLOADER_H
