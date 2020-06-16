#!/bin/bash

FILES=./*.flow
for test in $FILES
do
  echo "Processing $test ..."
  bash ./compile-run-js.sh $test
done



#@for %%i in (test*.flow) do call compile-run-js.bat %%i
