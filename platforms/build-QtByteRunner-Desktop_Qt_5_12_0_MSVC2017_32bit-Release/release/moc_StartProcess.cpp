/****************************************************************************
** Meta object code from reading C++ file 'StartProcess.h'
**
** Created by: The Qt Meta Object Compiler version 67 (Qt 5.12.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../qt/qt-backend/StartProcess.h"
#include <QtCore/qbytearray.h>
#include <QtCore/qmetatype.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'StartProcess.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 67
#error "This file was generated using the moc from 5.12.0. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

QT_BEGIN_MOC_NAMESPACE
QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
struct qt_meta_stringdata_StartProcess_t {
    QByteArrayData data[11];
    char stringdata0[156];
};
#define QT_MOC_LITERAL(idx, ofs, len) \
    Q_STATIC_BYTE_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(len, \
    qptrdiff(offsetof(qt_meta_stringdata_StartProcess_t, stringdata0) + ofs \
        - idx * sizeof(QByteArrayData)) \
    )
static const qt_meta_stringdata_StartProcess_t qt_meta_stringdata_StartProcess = {
    {
QT_MOC_LITERAL(0, 0, 12), // "StartProcess"
QT_MOC_LITERAL(1, 13, 17), // "processReadyWrite"
QT_MOC_LITERAL(2, 31, 0), // ""
QT_MOC_LITERAL(3, 32, 18), // "processReadyStdout"
QT_MOC_LITERAL(4, 51, 18), // "processReadyStderr"
QT_MOC_LITERAL(5, 70, 15), // "processFinished"
QT_MOC_LITERAL(6, 86, 4), // "code"
QT_MOC_LITERAL(7, 91, 20), // "QProcess::ExitStatus"
QT_MOC_LITERAL(8, 112, 6), // "status"
QT_MOC_LITERAL(9, 119, 13), // "processFailed"
QT_MOC_LITERAL(10, 133, 22) // "QProcess::ProcessError"

    },
    "StartProcess\0processReadyWrite\0\0"
    "processReadyStdout\0processReadyStderr\0"
    "processFinished\0code\0QProcess::ExitStatus\0"
    "status\0processFailed\0QProcess::ProcessError"
};
#undef QT_MOC_LITERAL

static const uint qt_meta_data_StartProcess[] = {

 // content:
       8,       // revision
       0,       // classname
       0,    0, // classinfo
       5,   14, // methods
       0,    0, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       0,       // signalCount

 // slots: name, argc, parameters, tag, flags
       1,    0,   39,    2, 0x08 /* Private */,
       3,    0,   40,    2, 0x08 /* Private */,
       4,    0,   41,    2, 0x08 /* Private */,
       5,    2,   42,    2, 0x08 /* Private */,
       9,    1,   47,    2, 0x08 /* Private */,

 // slots: parameters
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void,
    QMetaType::Void, QMetaType::Int, 0x80000000 | 7,    6,    8,
    QMetaType::Void, 0x80000000 | 10,    2,

       0        // eod
};

void StartProcess::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::InvokeMetaMethod) {
        StartProcess *_t = static_cast<StartProcess *>(_o);
        Q_UNUSED(_t)
        switch (_id) {
        case 0: _t->processReadyWrite(); break;
        case 1: _t->processReadyStdout(); break;
        case 2: _t->processReadyStderr(); break;
        case 3: _t->processFinished((*reinterpret_cast< int(*)>(_a[1])),(*reinterpret_cast< QProcess::ExitStatus(*)>(_a[2]))); break;
        case 4: _t->processFailed((*reinterpret_cast< QProcess::ProcessError(*)>(_a[1]))); break;
        default: ;
        }
    }
}

QT_INIT_METAOBJECT const QMetaObject StartProcess::staticMetaObject = { {
    &QObject::staticMetaObject,
    qt_meta_stringdata_StartProcess.data,
    qt_meta_data_StartProcess,
    qt_static_metacall,
    nullptr,
    nullptr
} };


const QMetaObject *StartProcess::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *StartProcess::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_StartProcess.stringdata0))
        return static_cast<void*>(this);
    if (!strcmp(_clname, "NativeMethodHost"))
        return static_cast< NativeMethodHost*>(this);
    return QObject::qt_metacast(_clname);
}

int StartProcess::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 5)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 5;
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 5)
            *reinterpret_cast<int*>(_a[0]) = -1;
        _id -= 5;
    }
    return _id;
}
QT_WARNING_POP
QT_END_MOC_NAMESPACE
