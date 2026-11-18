#include "core/StringRange.h"

#include <cassert>

int main()
{
    assert(stringRangeFits(0, 0, 0));
    assert(stringRangeFits(3, 3, 0));
    assert(!stringRangeFits(3, 3, 1));
    assert(stringRangeFits(2, 5, 2));
    assert(stringRangeFits(2, 5, 3));
    assert(!stringRangeFits(2, 5, 4));
    assert(!stringRangeFits(5, 2, 0));
    assert(!stringRangeFits(5, 2, 1));
}
