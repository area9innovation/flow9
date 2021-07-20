#ifndef DATABASESUPPORT_H
#define DATABASESUPPORT_H

#include <QSqlQuery>

#include "core/ByteCodeRunner.h"
#include "core/RunnerMacros.h"

class DatabaseResult;
class DatabaseSupport;

class DatabaseConnection : public FlowNativeObject {
    friend class DatabaseSupport;
    friend class DatabaseResult;

    DatabaseSupport *host;

    QString name;
    QSqlDatabase db;

    std::set<DatabaseResult*> results;
    DatabaseResult *last_result;

    int last_insert_id;

    QString last_error;

protected:
    void flowFinalizeObject();

    void destroy(bool fromHost = false);

public:
    DatabaseConnection(DatabaseSupport *host, int id);

    DEFINE_FLOW_NATIVE_OBJECT(DatabaseConnection, FlowNativeObject);

public:
    DECLARE_NATIVE_METHOD(connectExceptionDb);

    DECLARE_NATIVE_METHOD(closeDb);
    DECLARE_NATIVE_METHOD(escapeDb);

    StackSlot requestDbBase(ByteCodeRunner*, QString queryString,  StackSlot* params);
    DECLARE_NATIVE_METHOD(requestDb);
    DECLARE_NATIVE_METHOD(requestDbWithQueryParams);
    DECLARE_NATIVE_METHOD(requestExceptionDb);

    DECLARE_NATIVE_METHOD(requestDbMulti);

    DECLARE_NATIVE_METHOD(lastInsertIdDb);

    DECLARE_NATIVE_METHOD(startTransactionDb);
    DECLARE_NATIVE_METHOD(commitDb);
    DECLARE_NATIVE_METHOD(rollbackDb);
};

class DatabaseResult : public FlowNativeObject {
    friend class DatabaseSupport;
    friend class DatabaseConnection;

    DatabaseConnection *owner;
    QSqlQuery *query;
    int index;

private:
    StackSlot getRecord(RUNNER_VAR);

protected:
    void flowGCObject(GarbageCollectorFn fn);
    void flowFinalizeObject();

    void destroy(bool fromConn = false);
    void releaseLast();

public:
    DatabaseResult(DatabaseConnection *conn, QSqlQuery *query);
    ~DatabaseResult();

    DEFINE_FLOW_NATIVE_OBJECT(DatabaseResult, FlowNativeObject);

public:
    DECLARE_NATIVE_METHOD(resultLengthDb);
    DECLARE_NATIVE_METHOD(hasNextResultDb);
    DECLARE_NATIVE_METHOD(nextResultDb);

    DECLARE_NATIVE_METHOD(getIntResultDb);
    DECLARE_NATIVE_METHOD(getFloatResultDb);
    DECLARE_NATIVE_METHOD(getResultDb);
};

class DatabaseSupport : public QObject, public NativeMethodHost
{
    Q_OBJECT

    friend class DatabaseConnection;

    std::set<DatabaseConnection*> connections;

    int next_conn_id;

public:
    DatabaseSupport(ByteCodeRunner *Runner);
    virtual ~DatabaseSupport();

protected:
    NativeFunction *MakeNativeFunction(const char *name, int num_args);

    void OnRunnerReset(bool inDestructor);

private:
    DECLARE_NATIVE_METHOD(connectDb);
};


#endif // DATABASESUPPORT_H
