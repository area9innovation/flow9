# Koka

Koka is a ML-style language with effects and other goodies.

https://github.com/koka-lang/koka

This backend is intended for an experiment to see if we can
exploit the smart ref-counting behaviour Koka has for great
reduction in memory.

# Testing

To test, compile some program to koka:

	flowcpp plow/plow.flow -- file=demos/euler/euler1.flow koka=koka.kk
	flowcpp plow/plow.flow -- file=tools/gringo/gringo.flow koka=koka.kk

In Ubuntu, then use this to compile with Koka:

	koka /mnt/c/fast/koka.kk

# Options

If you use

	koka-int=1

the code generator will use int, rather than int32 for integers.

# TODO

- Get euler4 to compile and run as Koka
  - Local vars in expression context. Koka is statement-based for let-bindings!
     So
		a || ({
			statement
		})()
	is a workaround.

  - Some effect problems. foldRange needs to pass the effect:
    fun flow_foldRange(flow_start : int32, flow_end : int32, flow_acc : a, flow_fn : (a, int32) -> e a) : e a {

- euler7: enumFromTo, map, bitNot, bitAnd, bitOr

- Improvements:
  - Unions in unions are not handled right
  - Special cases for 
    - Flow type does not exist (flow_flow)
    - Global state: flow_isOWASPLevel1, flow_loggingEnabled
  - Add type arguments to lambdas? to disambiguiate args

- Fix mutable

- New mode: Produce a .kk file for each flow module

- Extend runtime with more stuff
