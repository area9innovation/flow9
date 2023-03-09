import std/random

# initialized with current timestamp
var randState = initRand()
proc random*(): float =
    # is 1 included?
    # randomize(234) // add to main ?
    # var r = initRand()
    # return r.rand(1.0)
    return randState.rand(1.0)
