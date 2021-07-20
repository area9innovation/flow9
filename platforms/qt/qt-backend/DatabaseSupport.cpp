#include "DatabaseSupport.h"

#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QSqlField>
#include <QDateTime>

IMPLEMENT_FLOW_NATIVE_OBJECT(DatabaseConnection, FlowNativeObject);
IMPLEMENT_FLOW_NATIVE_OBJECT(DatabaseResult, FlowNativeObject);

DatabaseSupport::DatabaseSupport(ByteCodeRunner *Runner) : NativeMethodHost(Runner)
{
    next_conn_id = 1;
}

DatabaseSupport::~DatabaseSupport()
{
    for (std::set<DatabaseConnection*>::iterator it = connections.begin(); it != connections.end(); ++it)
        (*it)->destroy(true);
}

void DatabaseSupport::OnRunnerReset(bool inDestructor)
{
    NativeMethodHost::OnRunnerReset(inDestructor);

    connections.clear();
}

NativeFunction * DatabaseSupport::MakeNativeFunction(const char *name, int num_args)
{
    #undef NATIVE_NAME_PREFIX
    #define NATIVE_NAME_PREFIX "Database."
    TRY_USE_NATIVE_METHOD(DatabaseSupport, connectDb, 6);

    TRY_USE_OBJECT_METHOD(DatabaseConnection, connectExceptionDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, closeDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, escapeDb, 2);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, requestDb, 2);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, requestDbWithQueryParams, 3);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, requestExceptionDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, requestDbMulti, 2);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, lastInsertIdDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, startTransactionDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, commitDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseConnection, rollbackDb, 1);

    TRY_USE_OBJECT_METHOD(DatabaseResult, resultLengthDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseResult, hasNextResultDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseResult, nextResultDb, 1);
    TRY_USE_OBJECT_METHOD(DatabaseResult, getIntResultDb, 2);
    TRY_USE_OBJECT_METHOD(DatabaseResult, getFloatResultDb, 2);
    TRY_USE_OBJECT_METHOD(DatabaseResult, getResultDb, 2);

    return NULL;
}

StackSlot DatabaseSupport::connectDb(RUNNER_ARGS) {
    RUNNER_PopArgs6(host, port, rawsocket, user, password, database);
    RUNNER_CheckTag5(TString, host, rawsocket, user, password, database);
    RUNNER_CheckTag(TInt, port);
    RUNNER_DefSlots1(retval);

    DatabaseConnection *conn = new DatabaseConnection(this, next_conn_id++);
    connections.insert(conn);
    retval = RUNNER->AllocNative(conn);

    QSqlDatabase &connection = conn->db;

    connection.setHostName(RUNNER->GetQString(host));
    connection.setPort(port.GetInt());
    connection.setUserName(RUNNER->GetQString(user));
    connection.setPassword(RUNNER->GetQString(password));
    connection.setDatabaseName(RUNNER->GetQString(database));

    QString socket = RUNNER->GetQString(rawsocket);
    if (socket.length() > 0) {
        connection.setConnectOptions("UNIX_SOCKET=" + socket);
    }

    connection.open();

    return retval;
}

/*********** CONNECTION ************/

DatabaseConnection::DatabaseConnection(DatabaseSupport *phost, int id)
    : FlowNativeObject(phost->getFlowRunner()), host(phost), last_result(NULL), last_error(QString())
{
    name = QString(stl_sprintf("flow_conn_%d", id).c_str());
    db = QSqlDatabase::addDatabase("QMYSQL", name);
}

void DatabaseConnection::flowFinalizeObject()
{
    destroy();
}

void DatabaseConnection::destroy(bool fromHost)
{
    for (std::set<DatabaseResult*>::iterator it = results.begin(); it != results.end(); ++it)
        (*it)->destroy(true);

    results.clear();
    last_result = NULL;

    if (host) {
        if (db.isValid())
            db.close();

        db = QSqlDatabase();

        QSqlDatabase::removeDatabase(name);

        if (!fromHost)
            host->connections.erase(this);
        host = NULL;
    }
}

StackSlot DatabaseConnection::connectExceptionDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    return RUNNER->AllocateString(db.lastError().text().trimmed());
}

StackSlot DatabaseConnection::closeDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    destroy();
    RETVOID;
}

StackSlot DatabaseConnection::escapeDb(RUNNER_ARGS) {
    RUNNER_PopArgs1(value);
    RUNNER_CheckTag(TString, value);

    QString val = RUNNER->GetQString(value);
    QString retval = "";

    // there is no escape method in QT SQL, so emulating it manually
    for (QString::const_iterator it = val.begin(); it != val.end(); ++it) {
           if (*it == '\"') {
               retval += "\\\"";
           } else if (*it == '\'') {
               retval += "\\'";
           } else if (*it == '\\') {
               retval += "\\\\";
           } else if (*it == '%') {
               retval += "\\%";
           } else {
               retval += *it;
           }
       }

    return RUNNER->AllocateString(retval);
}

StackSlot DatabaseConnection::requestDb(RUNNER_ARGS) {
    RUNNER_PopArgs1(rawquery);
    RUNNER_CheckTag(TString, rawquery);

    QString queryString = RUNNER->GetQString(rawquery);

    return requestDbBase(RUNNER, queryString, NULL);
}

StackSlot DatabaseConnection::requestDbWithQueryParams(RUNNER_ARGS) {
    RUNNER_PopArgs2(rawquery, params);
    RUNNER_CheckTag(TString, rawquery);
    RUNNER_CheckTag(TArray, params);

    QString queryString = RUNNER->GetQString(rawquery);

    return requestDbBase(RUNNER, queryString, &params);
}

StackSlot DatabaseConnection::requestDbBase(ByteCodeRunner *const RUNNER, QString queryString,  StackSlot* params) {
    QSqlQuery *query = new QSqlQuery(db);

    // Tell last result it's not last anymore
    if (last_result)
        last_result->releaseLast();

    if (params) {
        int nParams = RUNNER->GetArraySize(*params);
        for (int i = 0; i < nParams; i++) {
            StackSlot querySlot = RUNNER->GetArraySlot(*params, i);
            QString param = RUNNER->GetQString(querySlot);
            query->addBindValue(param);
        }
    }

    DatabaseResult *result = new DatabaseResult(this, query);
    results.insert(result);
    last_result = result;

    query->exec(queryString);
    last_error = query->lastError().text().trimmed();

    return RUNNER->AllocNative(result);
}

StackSlot DatabaseConnection::requestExceptionDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;

    QString msg;
    if (last_error.length()) {
        msg = last_error;
    } else {
        msg = db.lastError().text().trimmed();
    }

    return RUNNER->AllocateString(msg);
}

StackSlot DatabaseConnection::requestDbMulti(RUNNER_ARGS) {
    RUNNER_PopArgs1(rawqueries);
    RUNNER_CheckTag(TArray, rawqueries);
    RUNNER_DefSlots5(
        resultArr,          // the filal result
        queriesResults,     // (array of arrays) the results for each query (query can include several sqls and results)
        queryResults,       // the results of a sigle query
        queryResults2,      // it's used for resizing queryResults
        resultRows          // result of a single sql from a query
    );

    last_error = "";
    // Tell last result it's not last anymore
    if (last_result)
        last_result->releaseLast();

    int nqueries = RUNNER->GetArraySize(rawqueries);
    queriesResults = RUNNER->AllocateArray(nqueries);
    int nresults = 0;
    int validQueries = 0;
    for (int i = 0; i < nqueries; i++) {
        StackSlot querySlot = RUNNER->GetArraySlot(rawqueries, i);
        QString queryString = RUNNER->GetQString(querySlot);

        QSqlQuery *query = new QSqlQuery(db);

        DatabaseResult *databaseResult = new DatabaseResult(this, query);
        query->exec(queryString);

        QString err_msg = query->lastError().text().trimmed();
        if (err_msg.length()) {
            last_error = err_msg;
            break;
        } else {
            validQueries++;
        }

        int resultsCnt = 0;
        int realCapacity = 1;
        queryResults = RUNNER->AllocateArray(realCapacity);
        do {
            int nRows = query->size();
            nRows = nRows == 0 ? 1 : nRows;
            resultRows = RUNNER->AllocateArray(nRows);
            for (int j = 0; j < nRows; j++) {
                query->next();
                StackSlot requestResult = databaseResult->getRecord(RUNNER);
                RUNNER->SetArraySlot(resultRows, j, requestResult);
            }
            resultsCnt++;
            if (realCapacity == resultsCnt) {
                queryResults2 = RUNNER->AllocateArray(realCapacity * 2);
                for (int k = 0; k < realCapacity; k++ ) {
                    RUNNER->SetArraySlot(queryResults2, k, RUNNER->GetArraySlot(queryResults, k));
                }
                queryResults = queryResults2;
                realCapacity *= 2;
            }
            RUNNER->SetArraySlot(queryResults , resultsCnt - 1, resultRows);
        } while (query->nextResult());
        if (resultsCnt < realCapacity) {
            queryResults2 = RUNNER->AllocateArray(resultsCnt);
            for (int k = 0; k < resultsCnt; k++ ) {
                RUNNER->SetArraySlot(queryResults2, k, RUNNER->GetArraySlot(queryResults, k));
            }
            queryResults = queryResults2;
        }
        nresults += resultsCnt;
        RUNNER->SetArraySlot(queriesResults, i, queryResults);
    }

    resultArr = RUNNER->AllocateArray(nresults);
    for (int i = 0, n = 0; i < validQueries; i++) {
        StackSlot qResults = RUNNER->GetArraySlot(queriesResults, i);
        for (unsigned int c = 0; c < RUNNER->GetArraySize(qResults); c++, n++) {
            RUNNER->SetArraySlot(resultArr, n, RUNNER->GetArraySlot(qResults, c));
        }
    }
    return resultArr;
}

StackSlot DatabaseConnection::lastInsertIdDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    QSqlQuery *query = last_result ? last_result->query : NULL;
    return StackSlot::MakeInt(query ? query->lastInsertId().toInt() : 0);
}

// Transaction support
StackSlot DatabaseConnection::startTransactionDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    db.transaction();
    RETVOID;
}

StackSlot DatabaseConnection::commitDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    db.commit();
    RETVOID;
}

StackSlot DatabaseConnection::rollbackDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    db.rollback();
    RETVOID;
}

/*********** RESULT ************/

DatabaseResult::DatabaseResult(DatabaseConnection *conn, QSqlQuery *query)
    : FlowNativeObject(conn->getFlowRunner()), owner(conn), query(query), index(0)
{

}

DatabaseResult::~DatabaseResult()
{
    delete query;
}

void DatabaseResult::flowGCObject(GarbageCollectorFn fn)
{
    fn << owner;
}

void DatabaseResult::flowFinalizeObject()
{
    destroy();
}

void DatabaseResult::destroy(bool fromConn)
{
    if (owner && !fromConn) {
        owner->results.erase(this);
        if (owner->last_result == this)
            owner->last_result = NULL;
    }

    delete query;
    query = NULL;
}

void DatabaseResult::releaseLast()
{
    if (query && !query->size())
        destroy();
}

// Management of the result sets from queries
StackSlot DatabaseResult::resultLengthDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeInt(query ? query->size() : 0);
}

// Do we have more results?
StackSlot DatabaseResult::hasNextResultDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;
    return StackSlot::MakeBool(query && index < query->size());
}

// Get all fields and values of the next result as an array
StackSlot DatabaseResult::nextResultDb(RUNNER_ARGS) {
    IGNORE_RUNNER_ARGS;

    if (!query) {
        return RUNNER->AllocateArray(0);
    }

    query->next();
    StackSlot result = getRecord(RUNNER);


    if (++index >= query->size())
        destroy();

    return result;
}

StackSlot DatabaseResult::getRecord(RUNNER_VAR) {
    RUNNER_DefSlots3(result, value, element);

    QSqlRecord record = query->record();
    result = RUNNER->AllocateArray(record.count());

    for (int i = 0; i < record.count(); ++i) {
        QSqlField field = record.field(i);

        if (field.isNull()) {
            element = RUNNER->AllocateStruct("DbNullField", 1);
        } else {
            // converting from QT type to Flow type
            switch (field.type()) {
            case QVariant::Bool:
                value = StackSlot::MakeInt(field.value().toBool() ? 1 : 0);
                break;
            case QVariant::Int:
                value = StackSlot::MakeInt(field.value().toInt());
                break;
            case QVariant::Char:    // it's tinyint
                value = StackSlot::MakeInt(field.value().toInt());
                break;
            case QVariant::UInt:
                value = StackSlot::MakeInt(field.value().toUInt());
                break;
            case QVariant::Double:
                value = StackSlot::MakeDouble(field.value().toDouble());
                break;
            case QVariant::Time:
            case QVariant::DateTime:
                value = RUNNER->AllocateString(field.value().toDateTime().toString("yyyy-MM-dd'T'HH:mm:ss'Z'"));
                break;
            default:
                value = RUNNER->AllocateString(field.value().toString());
                break;
            }

            // now choosing the correct struct name depending on flow type and whether we are null
            switch (value.GetType()) {
            case TInt:
                element = RUNNER->AllocateStruct("DbIntField", 2);
                break;
            case TDouble:
                element = RUNNER->AllocateStruct("DbDoubleField", 2);
                break;
            default:
                element = RUNNER->AllocateStruct("DbStringField", 2);
            }

            RUNNER->SetStructSlot(element, 1, value);
        }

        RUNNER->SetStructSlot(element, 0, RUNNER->AllocateString(field.name()));
        RUNNER->SetArraySlot(result, i, element);
    }

    return result;
}

// Get field #n as int in next result
StackSlot DatabaseResult::getIntResultDb(RUNNER_ARGS) {
    RUNNER_PopArgs1(rawindex);
    RUNNER_CheckTag(TInt, rawindex);
    int index = rawindex.GetInt();
    return StackSlot::MakeInt(query ? query->value(index).toInt() : 0);
}

// Get field #n as double in next result
StackSlot DatabaseResult::getFloatResultDb(RUNNER_ARGS) {
    RUNNER_PopArgs1(rawindex);
    RUNNER_CheckTag(TInt, rawindex);
    int index = rawindex.GetInt();
    return StackSlot::MakeDouble(query ? query->value(index).toDouble() : 0);
}

// Get field #n as string in next result
StackSlot DatabaseResult::getResultDb(RUNNER_ARGS) {
    RUNNER_PopArgs1(rawindex);
    RUNNER_CheckTag(TInt, rawindex);
    int index = rawindex.GetInt();
    return RUNNER->AllocateString(query ? query->value(index).toString() : QString(""));
}
