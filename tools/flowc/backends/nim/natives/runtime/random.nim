import std/random

# initialized with current timestamp
var randState = initRand()
proc random*(): float =
    return randState.rand(1.0)
