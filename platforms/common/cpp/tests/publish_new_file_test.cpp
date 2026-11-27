#include "../core/ReplaceFile.h"

// Run in an empty directory. Both writers see an absent name while preparing
// their stages. The inner writer publishes first; the outer must report failure.
int main()
{
    bool inner = false;
    auto prepare = [](int, const struct stat &) { return false; }; // no existing entry
    auto outer = replaceRegularFile(AT_FDCWD, "result", NULL, [&](FILE *out) {
        inner = replaceRegularFile(AT_FDCWD, "result", NULL, [](FILE *peer) { return fputs("first", peer) >= 0; }, prepare) == StageResult::Published;
        return fputs("second", out) >= 0;
    }, prepare);
    return inner && outer == StageResult::Failed ? 0 : 1;
}
