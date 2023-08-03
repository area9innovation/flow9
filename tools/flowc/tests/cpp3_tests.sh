#!/bin/bash

flowc1 run=btester back=cpp3 test=cpp3 valgrind=1 exclude=test_runner                       test-opts=determ #cpp3-back-opts=cpp-debug
flowc1 run=btester back=cpp3 test=nim  valgrind=1 exclude=gc,http,test_local2utc,users_tree test-opts=determ #cpp3-back-opts=cpp-debug
#flowc1 run=btester back=cpp3                          test=cpp3 valgrind=1 exclude=test_runner,int_array test-opts=determ
