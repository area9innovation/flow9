Push checkpoints for stack as far into the sequence as possible, so we only do it after parsing prefix strings.
Separate the recovery stacks for position & semantic actions, and then we do not need to worry about MCheckpoint structs, and we can have finegrained scope for each.

Introduce a new AST that represents the flow code we construct in the Blueprint of opcode2code, so we have yet another intermediate represntation we can potentially optimize.
Consider to compile directly to Java code, and expose the entire parser as a native.
Introduce a native List for Java.

# Specification: Fixpoint Algorithm for First-Set Extraction in PEG Grammars

## Overview
This specification describes an algorithm to compute the "first sets" of a PEG grammar through fixpoint iteration, handling mutually recursive rules and PEG-specific operators.

## Definitions

### Types
```
Terminal ::= StringTerminal, RangeTerminal;
	StringTerminal(value: string);
	RangeTerminal(start: string, end: string);

FirstSet = Set<Terminal>;
```

### Data Structures
- `FirstSets: Tree<string, FirstSet>` - Maps rule names to their first sets
- `NullableSet: Set<string>` - Set of rule names that can match empty strings

## Algorithm

### 1. Initialization
1. Initialize `FirstSets` with empty sets for all rules
2. Initialize `NullableSet` as empty

### 2. Fixpoint Iteration
Repeat until no changes are made to `FirstSets` or `NullableSet`:

1. For each rule `R(name, body)` in the grammar:
   a. Compute `nullable(body)` and update `NullableSet` if needed
   b. Compute `first(body)` and update `FirstSets[name]` if different

### 3. First-Set Computation Rules
Define `first(term)` recursively:

- `first(String(s))`:
  - If `s` is empty, return empty set
  - Otherwise, return `{StringTerminal(first_char_of_s)}`

- `first(Range(start, end))`:
  - Return `{RangeTerminal(start, end)}`

- `first(Sequence(t1, t2))`:
  - If `nullable(t1)`, return `first(t1) ∪ first(t2)`
  - Otherwise, return `first(t1)`

- `first(Choice(t1, t2))`:
  - Return `first(t1) ∪ first(t2)`

- `first(Optional(t))`:
  - Return `first(t)`

- `first(Star(t))`:
  - Return `first(t)`

- `first(Plus(t))`:
  - Return `first(t)`

- `first(Negate(t))`:
  - Return special marker indicating "potentially any character not in `first(t)`"
  - Alternatively, approximate with empty set to indicate "match anything"

- `first(Variable(name))`:
  - Return current value of `FirstSets[name]`

- `first(PushMatch(t))`:
  - Return `first(t)`

- `first(Construct(...))`, `first(StackOp(...))`:
  - Return empty set (semantic actions don't consume input)

### 4. Nullable Computation Rules
Define `nullable(term)` recursively:

- `nullable(String(s))`: True if `s` is empty
- `nullable(Range(...))`: False
- `nullable(Sequence(t1, t2))`: True if both `nullable(t1)` and `nullable(t2)`
- `nullable(Choice(t1, t2))`: True if either `nullable(t1)` or `nullable(t2)`
- `nullable(Optional(...))`: True
- `nullable(Star(...))`: True
- `nullable(Plus(t))`: True if `nullable(t)`
- `nullable(Negate(t))`: True if not `nullable(t)`
- `nullable(Variable(name))`: True if `name` in `NullableSet`
- `nullable(PushMatch(t))`: Same as `nullable(t)`
- `nullable(Construct(...))`, `nullable(StackOp(...))`: True

## Optimization Details

### First Set Usage Pattern
- Before attempting to parse a rule, check if the current input position might match any terminal in the rule's first set
- For `Choice` expressions, check first sets of alternatives before attempting to parse

### Special Cases
1. **Left Recursion**: The algorithm assumes PEG grammars don't contain left recursion. If present, the algorithm will still terminate but may not compute correct first sets.

2. **Precedence Operators**: For precedence operators (`|>`, `>`) in the grammar, preprocess them into equivalent `Choice` and `Sequence` expressions.

3. **Epsilon Rules**: Rules that can match empty strings need special handling in sequences.

## Implementation Considerations

1. **Termination**: The algorithm is guaranteed to terminate because:
   - The number of rules is finite
   - Each first set can only grow (never shrink)
   - Each rule can only be added to `NullableSet` once
   - The domain of terminals is finite for a given grammar

2. **Performance Optimization**:
   - Cache intermediate results of `first` and `nullable` computations
   - Process rules in dependency order when possible
   - Use efficient set operations

3. **Memory Usage**:
   - For large grammars, consider set implementations with low memory overhead
   - Only store terminals actually appearing in the grammar

## Integration with Parser
To integrate with the existing parser:

1. Compute first sets once, during grammar initialization
2. Add a "fast path" check before normal parsing:
   ```
	 if (!mightMatch(firstSets[ruleName], input, position))
			 return failure;
```
3. For complex rules, check first sets of alternatives to avoid unnecessary backtracking

---

This specification provides a foundation for implementing fixpoint-based first-set computation for PEG grammars, with a focus on optimizing parser performance for large inputs.
