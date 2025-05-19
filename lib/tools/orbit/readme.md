# Orbit: Domain-Unified Rewriting Engine: Bridging Mathematical Formalism and Practical Programming

## Introduction

We present a novel approach to program transformation and optimization that unifies three powerful technologies: equivalence graphs (e-graphs), a domain-unified rewriting system based on group theory, and Orbit, a functional programming language with native AST capabilities. This synthesis creates a powerful rewriting engine capable of applying formal mathematical theorems directly to program code.

## Orbit: A Functional Programming Language

Orbit is a functional programming language that integrates generalized e-graphs (called ographs) to enable advanced rewriting and optimization capabilities. The language provides a native interface to ographs, allowing direct manipulation of abstract syntax trees (ASTs) and application of rewrite rules.

### Running Orbit

You run Orbit like this:

```
.../tools/orbit> orbit tests/pattern.orb
```

### Enabling Tracing

Orbit provides a detailed tracing feature that shows all steps of interpretation, which is useful for debugging and understanding program execution. To enable tracing, use the `trace=1` URL parameter:

```
orbit trace=1 tests/pattern.orb
```

With tracing enabled, you'll see detailed output for each interpretation step, including:
- Expression types being processed
- Variable lookups and bindings
- Function calls and their arguments
- Evaluation of sub-expressions

Without tracing (the default), only the final result will be displayed, making the output cleaner and more concise for normal usage.

### Using the Test Suite

Orbit includes a comprehensive test suite to verify correct behavior and prevent regressions. The test suite automatically runs all .orb files in a specified directory and captures their outputs.

#### Running the Test Suite

To run the test suite on all tests in the default 'tests' directory:

```
flow9/lib/tools/orbit> ./run_orbit_tests.sh
```

This script executes all .orb files in the 'tests' directory and saves the outputs to the 'test_output' directory, and compares against the expected output in the 'expected_output/' directory.

#### Test Suite Options

The test script supports several command-line parameters:

```
flow9/lib/tools/orbit> ./run_orbit_tests.sh --test-dir=custom_tests --output-dir=results --trace --verbose
```

- `--test-dir=DIR`: Specifies the directory containing test files (default: 'tests')
- `--output-dir=DIR`: Specifies the directory to save test outputs (default: 'test_output')
- `--timeout=SECONDS`: Maximum time to allow a test to run before timing out (default: 10 seconds)
- `--trace`: Enables detailed tracing during test execution
- `--verbose`: Shows detailed output for each test while running
- `--help`: Displays usage information

#### Test Suite Output

The test suite generates:

1. Individual output files for each test in the output directory
2. A summary file (_summary.txt) with test results and statistics
3. Console output showing which tests passed or failed

#### Using for Regression Testing

The test suite is designed to work with version control systems like git for regression testing:

1. Run the test suite to generate baseline outputs
2. Commit these outputs to your repository
3. After making changes, run the test suite again
4. Use `git diff` to see if any test outputs have changed

This workflow makes it easy to identify unintended changes in behavior during development.

#### Examples

Run all tests in the default directory:
```
./run_orbit_tests.sh
```

Run a specific set of tests with detailed output:
```
./run_orbit_tests.sh --test-dir=tests/math --verbose
```

Turn on tracing for step-by-step execution details:
```
./run_orbit_tests.sh --trace
```

## Orbit Documentation Guide

- **[index.md](docs/index.md)**: Lists all the documentation files and their purposes.

## Implementation

We evaluate Orbit by converting it to a Scheme variant `SExpr`. See [sexpr/readme.md](./sexpr/readme.md) for details.
