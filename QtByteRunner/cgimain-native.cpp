#include <QtCore/QCoreApplication>

#include "core/ByteCodeRunner.h"
#include "qt-backend/DatabaseSupport.h"
#include "qt-backend/HttpSupport.h"
#include "qt-backend/QtTimerSupport.h"
#include "qt-backend/CgiSupport.h"

#include <QUrl>

#include <stdlib.h>
#include <time.h>

#define MAX_BUF_SIZE 256

static QUrl getParameters(QByteArray source) {
    QUrl params;
    params.setEncodedQuery(source);

    return params;
}

NativeProgram *load_native_program();

int main(int argc, char *argv[])
{
    srand(time(NULL)); rand();

    ByteCodeRunner FlowRunner;
    QtTimerSupport QtTimer(&FlowRunner);
    CgiSupport Cgi(&FlowRunner, true);
    DatabaseSupport DbManager(&FlowRunner);
    QtHttpSupport HttpManager(&FlowRunner);

    FlowRunner.TargetTokens.insert("cgi");

    QCoreApplication a(argc, argv);
    a.setApplicationName("Flow Bytecode Runner");

    const char *qstring = getenv("QUERY_STRING");
    if (qstring == NULL)
	qstring = "";

    QUrl params = getParameters(QByteArray(qstring));
    FlowRunner.NotifyStubs = params.hasQueryItem("debug");
    //FlowRunner.flow_err << "URL: " << params.toString().toAscii().data() << endl;
    FlowRunner.setUrl(params);

    FlowRunner.Init(load_native_program());
    FlowRunner.RunMain();

    int status = 0;
    if (!FlowRunner.IsErrorReported() && !Cgi.quitPending)
        status = a.exec();
    else if (Cgi.quitPending)
        status = Cgi.quitCode;

    Cgi.flushHeaders();
    return 0;
}
