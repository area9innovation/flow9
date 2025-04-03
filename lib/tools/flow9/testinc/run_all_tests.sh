#!/bin/bash

echo "===================================================="
echo "Running incremental compilation tests"
echo "====================================================\n"

echo "\n==== Test 1: Function Name Change ===="
./testinc/test1_runner.sh

echo "\n==== Test 2: Type Structure Change ===="
./testinc/test2_runner.sh

echo "\n==== Test 3: Variable Type Change ===="

./testinc/test3_runner.sh

echo "\n==== Test 4: Multi-level Dependency Chain ===="
./testinc/test4_runner.sh

echo "\n==== Test 5: Polymorphic Type Change ===="
./testinc/test5_runner.sh

echo "\n==== Test 6: Union Type Change ===="
./testinc/test6_runner.sh

echo "\n==== Test 7: Function Parameter Type Change ===="
./testinc/test7_runner.sh

echo "\n==== Test 8: Return Type Change ===="
./testinc/test8_runner.sh

echo "\n==== Test 9: Recursive Type Definition Change ===="
./testinc/test9_runner.sh

echo "\n==== Test 10: Type Alias Change ===="
./testinc/test10_runner.sh

echo "\n==== All tests completed ===="