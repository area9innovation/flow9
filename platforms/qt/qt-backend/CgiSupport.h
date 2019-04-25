#ifndef CGISUPPORT_H
#define CGISUPPORT_H

#include "core/ByteCodeRunner.h"

#include <QObject>
#include <QMap>
#include <QUrl>
#include <QTimerEvent>

#ifdef FASTCGI
#include "fcgiapp.h"
#endif

class CgiSupport : public QObject, public NativeMethodHost
{
    Q_OBJECT

public:
    CgiSupport(ByteCodeRunner *Runner, bool cgi_headers);

    bool quitPending;
    int quitCode;

    void flushHeaders();
#ifdef FASTCGI
    void setEnvp(FCGX_ParamArray envp);
#endif

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    void OnRunnerReset(bool inDestructor);
    void OnHostEvent(HostEvent event);

    bool headersFlushed;
    bool contentTypeWritten;

private:
    ByteCodeRunner* Runner;
    bool cgi_headers;

#ifdef FASTCGI
    FCGX_ParamArray _envp;
#endif

    DECLARE_NATIVE_METHOD(quit);
    DECLARE_NATIVE_METHOD(println);
    DECLARE_NATIVE_METHOD(addHttpHeader);
    DECLARE_NATIVE_METHOD(getCgiParameter);
};

#endif // CGISUPPORT_H
