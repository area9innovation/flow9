#ifdef QT_GUI_LIB
#define GL_GLEXT_PROTOTYPES
#ifdef WIN32
#include <GL/glew.h>
#else
#include <GL/gl.h>
#include <GL/glext.h>
#endif
#endif

#ifdef __cplusplus

#include <string>
#include <vector>
#include <map>
#include <set>

#ifdef _MSC_VER
#include <memory>
#else
#include <tr1/memory>
#endif

#ifdef QT_GUI_LIB
#include <glm/glm.hpp>
#endif

/*
#ifdef QT_CORE_LIB
#include <QDebug>
#include <QFile>
#include <QString>
#include <QObject>
#include <QMap>
#include <QList>
#include <QHash>
#endif
*/

#else

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#endif
