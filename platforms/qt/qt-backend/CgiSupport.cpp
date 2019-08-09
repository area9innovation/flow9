#include "CgiSupport.h"
#include "core/RunnerMacros.h"

#include <QCoreApplication>

#include <sstream>

using std::endl;
using std::stringstream;

CgiSupport::CgiSupport(ByteCodeRunner *Runner, bool cgi_headers)
  : NativeMethodHost(Runner), Runner(Runner), cgi_headers(cgi_headers)
{
    quitPending = false;
    headersFlushed = contentTypeWritten = false;
}

void CgiSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    quitPending = false;
    headersFlushed = contentTypeWritten = false;
}

void CgiSupport::OnHostEvent(HostEvent event)
{
    NativeMethodHost::OnHostEvent(event);

    if (event == HostEventError) {
        QCoreApplication::exit(1);
        quitPending = true;
        quitCode = 1;

        flushHeaders();
        getFlowRunner()->flow_out << getFlowRunner()->GetLastErrorMsg() << endl
                                  << getFlowRunner()->GetLastErrorInfo() << endl;
    }
}

void CgiSupport::flushHeaders()
{
    if (!cgi_headers || headersFlushed) return;

    if (!contentTypeWritten)
        getFlowRunner()->flow_out << "Content-Type: text/html\r\n";

    getFlowRunner()->flow_out << "\r\n";
    getFlowRunner()->flow_out.flush();

    headersFlushed = true;
}

#ifdef FASTCGI
void CgiSupport::setEnvp(FCGX_ParamArray envp)
{
    _envp = envp;
}
#endif

NativeFunction *CgiSupport::MakeNativeFunction(const char *name, int num_args)
{
    #undef NATIVE_NAME_PREFIX
    #define NATIVE_NAME_PREFIX "Native."
    TRY_USE_NATIVE_METHOD(CgiSupport, quit, 1);
    TRY_USE_NATIVE_METHOD(CgiSupport, println, 1);
    TRY_USE_NATIVE_METHOD(CgiSupport, addHttpHeader, 1);
    TRY_USE_NATIVE_METHOD(CgiSupport, getCgiParameter, 1);

    return NULL;
}

StackSlot CgiSupport::quit(RUNNER_ARGS)
{
    RUNNER_PopArgs1(rawcode);
    RUNNER_CheckTag(TInt, rawcode);

	if (!quitPending) {
		quitPending = true;
		quitCode = rawcode.GetInt();
		QCoreApplication::exit(quitCode);
	}

    RETVOID;
}

StackSlot CgiSupport::println(RUNNER_ARGS)
{
    flushHeaders();
    return RUNNER->println(RUNNER, &RUNNER_ARG(0));
}

StackSlot CgiSupport::addHttpHeader(RUNNER_ARGS)
{
    RUNNER_PopArgs1(header);
    RUNNER_CheckTag(TString, header);

    std::string data = encodeUtf8(RUNNER->GetString(header));
    static std::string content_type = "Content-Type:";

    if (headersFlushed) {
        RUNNER->flow_err << "HTTP header ignored: " << data << endl;
    } else {
        RUNNER->flow_out << data << "\r\n";
        if (data.size() > content_type.size() && data.substr(0,content_type.size()) == content_type)
            contentTypeWritten = true;
    }

    RETVOID;
}

StackSlot CgiSupport::getCgiParameter(RUNNER_ARGS)
{
    RUNNER_PopArgs1(name);
    RUNNER_CheckTag1(TString, name);

    char* value = NULL;

#ifdef FASTCGI
    value = FCGX_GetParam(encodeUtf8(RUNNER->GetString(name)).c_str(), _envp);
#endif

    if (value == NULL) {
        return RUNNER->AllocateString("");
    }

    return RUNNER->AllocateString(value);
}
