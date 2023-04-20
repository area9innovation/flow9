import std/random

# initialized with current timestamp
var randState = initRand()
proc $F_0(random)*(): float =
    return randState.rand(1.0)
