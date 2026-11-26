#include "../core/ReplaceFile.h"

// Run in an empty directory. Both writers see an absent name while preparing
// their stages. The inner writer publishes first; the outer must report failure.
int main()
{
    bool inner = false;
    bool outer = replaceRegularFile("result", [&](FILE *out) {
        inner = replaceRegularFile("result", [](FILE *peer) { return fputs("first", peer) >= 0; });
        return fputs("second", out) >= 0;
    });
    return inner && !outer ? 0 : 1;
}
