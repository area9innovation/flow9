#ifndef FLOW_STRING_RANGE_H
#define FLOW_STRING_RANGE_H

inline bool stringRangeFits(unsigned start, unsigned end, unsigned length)
{
    return start <= end && length <= end - start;
}

#endif
