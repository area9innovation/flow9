/****************************************************************************
** Meta object code from reading C++ file 'HttpSupport.h'
**
** Created by: The Qt Meta Object Compiler version 67 (Qt 5.12.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../qt/qt-backend/HttpSupport.h"
#include <QtCore/qbytearray.h>
#include <QtCore/qmetatype.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'HttpSupport.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 67
#error "This file was generated using the moc from 5.12.0. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

QT_BEGIN_MOC_NAMESPACE
QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
struct qt_meta_stringdata_QtHttpSupport_t {
    QByteArrayData data[10];
    char stringdata0[123];
};
#define QT_MOC_LITERAL(idx, ofs, len) \
    Q_STATIC_BYTE_ARRAY_DATA_HEADER_INITIALIZER_WITH_OFFSET(len, \
    qptrdiff(offsetof(qt_meta_stringdata_QtHttpSupport_t, stringdata0) + ofs \
        - idx * sizeof(QByteArrayData)) \
    )
static const qt_meta_stringdata_QtHttpSupport_t qt_meta_stringdata_QtHttpSupport = {
    {
QT_MOC_LITERAL(0, 0, 13), // "QtHttpSupport"
QT_MOC_LITERAL(1, 14, 14), // "handleFinished"
QT_MOC_LITERAL(2, 29, 0), // ""
QT_MOC_LITERAL(3, 30, 14), // "QNetworkReply*"
QT_MOC_LITERAL(4, 45, 5), // "reply"
QT_MOC_LITERAL(5, 51, 16), // "downloadProgress"
QT_MOC_LITERAL(6, 68, 13), // "bytesReceived"
QT_MOC_LITERAL(7, 82, 10), // "bytesTotal"
QT_MOC_LITERAL(8, 93, 14), // "selectAccepted"
QT_MOC_LITERAL(9, 108, 14) // "selectRejected"

    },
    "QtHttpSupport\0handleFinished\0\0"
    "QNetworkReply*\0reply\0downloadProgress\0"
    "bytesReceived\0bytesTotal\0selectAccepted\0"
    "selectRejected"
};
#undef QT_MOC_LITERAL

static const uint qt_meta_data_QtHttpSupport[] = {

 // content:
       8,       // revision
       0,       // classname
       0,    0, // classinfo
       4,   14, // methods
       0,    0, // properties
       0,    0, // enums/sets
       0,    0, // constructors
       0,       // flags
       0,       // signalCount

 // slots: name, argc, parameters, tag, flags
       1,    1,   34,    2, 0x08 /* Private */,
       5,    2,   37,    2, 0x08 /* Private */,
       8,    0,   42,    2, 0x08 /* Private */,
       9,    0,   43,    2, 0x08 /* Private */,

 // slots: parameters
    QMetaType::Void, 0x80000000 | 3,    4,
    QMetaType::Void, QMetaType::LongLong, QMetaType::LongLong,    6,    7,
    QMetaType::Void,
    QMetaType::Void,

       0        // eod
};

void QtHttpSupport::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    if (_c == QMetaObject::InvokeMetaMethod) {
        QtHttpSupport *_t = static_cast<QtHttpSupport *>(_o);
        Q_UNUSED(_t)
        switch (_id) {
        case 0: _t->handleFinished((*reinterpret_cast< QNetworkReply*(*)>(_a[1]))); break;
        case 1: _t->downloadProgress((*reinterpret_cast< qint64(*)>(_a[1])),(*reinterpret_cast< qint64(*)>(_a[2]))); break;
        case 2: _t->selectAccepted(); break;
        case 3: _t->selectRejected(); break;
        default: ;
        }
    }
}

QT_INIT_METAOBJECT const QMetaObject QtHttpSupport::staticMetaObject = { {
    &QObject::staticMetaObject,
    qt_meta_stringdata_QtHttpSupport.data,
    qt_meta_data_QtHttpSupport,
    qt_static_metacall,
    nullptr,
    nullptr
} };


const QMetaObject *QtHttpSupport::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *QtHttpSupport::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_meta_stringdata_QtHttpSupport.stringdata0))
        return static_cast<void*>(this);
    if (!strcmp(_clname, "AbstractHttpSupport"))
        return static_cast< AbstractHttpSupport*>(this);
    return QObject::qt_metacast(_clname);
}

int QtHttpSupport::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 4)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 4;
    } else if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 4)
            *reinterpret_cast<int*>(_a[0]) = -1;
        _id -= 4;
    }
    return _id;
}
QT_WARNING_POP
QT_END_MOC_NAMESPACE
