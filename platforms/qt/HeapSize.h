#ifndef FLOW_QT_HEAP_SIZE_H
#define FLOW_QT_HEAP_SIZE_H

#include <QString>
#include <climits>
#include <cstdio>
#include <cstdlib>

inline unsigned heapSizeInBytes(const QString &value)
{
    bool ok;
    unsigned mib = value.toUInt(&ok);
    if (!ok || mib > UINT_MAX / 1048576u) {
        std::fputs("Invalid heap size in MiB.\n", stderr);
        std::exit(1);
    }
    return mib * 1048576u;
}

#endif
