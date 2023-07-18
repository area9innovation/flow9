#!/bin/bash

flowc1 run=btester back=cpp3 cpp3-back-opts=cpp-debug test=cpp3 valgrind=1 exclude=test_runner,int_array
flowc1 run=btester back=cpp3 cpp3-back-opts=cpp-debug test=nim  valgrind=1 exclude=gc,http,test_local2utc,users_tree test-opts=determ
#flowc1 run=btester back=cpp3                          test=cpp3 valgrind=1 exclude=test_runner,int_array test-opts=determ