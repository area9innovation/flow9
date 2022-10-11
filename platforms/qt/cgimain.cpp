#include <QtCore/QCoreApplication>
#include <QtCore/QProcessEnvironment>

#include "core/ByteCodeRunner.h"
#include "qt-backend/DatabaseSupport.h"
#include "qt-backend/HttpSupport.h"
#include "qt-backend/QtTimerSupport.h"
#include "qt-backend/CgiSupport.h"

#include "utils/FileSystemInterface.h"

#include <QUrl>
#include <QUrlQuery>

#include <stdlib.h>
#include <time.h>

extern char **environ;

#define MAX_BUF_SIZE 256

#ifdef FLOW_JIT
FlowJitProgram *loadJitProgram(ostream &e, const std::string &bytecode_file, const std::string &log_file);
#endif

static QUrl getParameters(QByteArray source) {
    QUrl params;
    params.setQuery(QUrlQuery(source));

    return params;
}

QByteArray readStream(FCGX_Stream * stream) {
    char buffer[MAX_BUF_SIZE + 1];
    QByteArray buf;

    while (!FCGX_HasSeenEOF(stream)) {
        int total = FCGX_GetStr(buffer, MAX_BUF_SIZE, stream);
        buffer[total] = '\0';
        buf.append(buffer);
    }

    return buf;
}

static void PrintEnv(FCGX_Stream *out, char *label, char **envp)
{
    FCGX_FPrintF(out, "%s:<br>\n<pre>\n", label);
    for( ; *envp != NULL; envp++) {
        FCGX_FPrintF(out, "%s\n", *envp);
    }
    FCGX_FPrintF(out, "</pre><p>\n");
}

FCGX_Stream *defaultErrorStream;

// custom message handler to send debug messages to the server error log
void messageHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QString txt;
    switch (type) {
        case QtDebugMsg:
            txt = QString("Debug: %1").arg(msg);
            break;
        case QtWarningMsg:
            txt = QString("Warning: %1").arg(msg);
            break;
        case QtCriticalMsg:
            txt = QString("Critical: %1").arg(msg);
            break;
        case QtFatalMsg:
            txt = QString("Fatal: %1").arg(msg);
            abort();
    }

    FCGX_FPrintF(defaultErrorStream, "%s\n", txt.toUtf8().constData());
}

class FCGIOutputStreambuf : public std::streambuf
{
protected:
    FCGX_Stream *out;
    std::vector<char> buffer;

public:
    FCGIOutputStreambuf(FCGX_Stream *out) : out(out), buffer(8*1024) {
        setp(&buffer[0], &buffer[buffer.size()]);
    }
    virtual ~FCGIOutputStreambuf() {
        sync();
    }

protected:
    virtual int overflow (int c) {
        if (sync())
            return EOF;
        if (c != EOF) {
            *pptr() = c;
            pbump(1);
        }
        return c;
    }

    virtual int sync() {
        int num = pptr() - pbase();
        if (num > 0) {
            FCGX_PutStr(pbase(), num, out);
            pbump(-num);
        }
        return 0;
    }
};

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);
    a.setApplicationName("Flow Bytecode Runner");

    QProcessEnvironment penv = QProcessEnvironment::systemEnvironment();
    const char* MAX_HEAP_KEY = "FLOWCGI_MAX_HEAP";
    const char* MIN_HEAP_KEY = "FLOWCGI_MIN_HEAP";
    MAX_HEAP_SIZE = 1048576 * penv.value(MAX_HEAP_KEY, "512").toInt();
    MIN_HEAP_SIZE = 1048576 * penv.value(MIN_HEAP_KEY, "256").toInt();

    FCGX_Init();
    FCGX_Stream *in, *out, *err;
    FCGX_ParamArray envp;
    int count = 0;

    srand(time(NULL)); rand();

    ByteCodeRunner FlowRunner;
    QtTimerSupport QtTimer(&FlowRunner);
    FileSystemInterface FileSystem(&FlowRunner);
    CgiSupport Cgi(&FlowRunner, true);
    DatabaseSupport DbManager(&FlowRunner);
    QtHttpSupport HttpManager(&FlowRunner);

    FlowRunner.TargetTokens.insert("cgi");
    FlowRunner.TargetTokens.insert("fastcgi");

    qInstallMessageHandler(messageHandler);

    FlowRunner.flow_out.setf(std::ios_base::unitbuf);
    FlowRunner.flow_err.setf(std::ios_base::unitbuf);

    while (FCGX_Accept(&in, &out, &err, &envp) >= 0) {
        ++count;
        defaultErrorStream = err;

        FCGIOutputStreambuf out_buf(out);
        FCGIOutputStreambuf err_buf(err);
        FlowRunner.flow_out.rdbuf(&out_buf);
        FlowRunner.flow_err.rdbuf(&err_buf);

        Cgi.setEnvp(envp);

        //PrintEnv(out, "Request environment", envp);
        //PrintEnv(out, "Initial environment", environ);

        QString method = FCGX_GetParam("REQUEST_METHOD", envp);
        QByteArray query;
        if (method == "GET") {
            query = QByteArray(FCGX_GetParam("QUERY_STRING", envp));
        } else if (method == "POST") {
            QString contentType = FCGX_GetParam("CONTENT_TYPE", envp);
            if (contentType.startsWith("application/x-www-form-urlencoded")) {
                query = readStream(in);
            }
        }

        QUrl params = getParameters(query);
        FlowRunner.NotifyStubs = QUrlQuery(params).hasQueryItem("debug");
        setUtf8JsStyleGlobalFlag(QUrlQuery(params).hasQueryItem("use_utf8_js_style"));
        //FlowRunner.flow_err << "URL: " << params.toString().toStdString() << endl;

        FlowRunner.setUrl(params);

        std::string flow = FCGX_GetParam("SCRIPT_FILENAME", envp);

        if (flow.length() == 0) {
            Cgi.flushHeaders();
            FCGX_FPrintF(out,
            "<title>FastCGI echo (fcgiapp version)</title>"
            "<h1>FastCGI echo (fcgiapp version)</h1>\n"
            "Request number %d<p>\n", count);
            FCGX_SetExitStatus(-1, out);
            continue;
        }

#ifdef FLOW_JIT
#ifdef DEBUG_FLOW
        FlowJitProgram *jit = loadJitProgram(cout, flow, "flowjit");
#else
        FlowJitProgram *jit = loadJitProgram(cerr, flow, "");
#endif

        if (!jit)
            return 1;

        FlowRunner.Init(jit);
#else
        FlowRunner.Init(flow);
#endif
        FlowRunner.RunMain();

        int status = 0;
        if (!FlowRunner.IsErrorReported() && !Cgi.quitPending)
            status = a.exec();
        else if (Cgi.quitPending)
            status = Cgi.quitCode;

        Cgi.flushHeaders();

        FCGX_SetExitStatus(status, out);
        Cgi.quitPending = false;
        FlowRunner.ResetState();
    }

    return 0;
}
