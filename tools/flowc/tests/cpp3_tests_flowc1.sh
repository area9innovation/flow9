#!/bin/bash

## flowc1 tests:
flowc1 run=btester back=cpp3 compiler=flowc1 test=cpp3 valgrind=1 exclude=test_runner,test_concur,sizeof,test_clone    test-opts=determ #cpp3-back-opts=cpp-debug
flowc1 run=btester back=cpp3 compiler=flowc1 test=nim  valgrind=1 exclude=gc,http,test_local2utc,users_tree test-opts=determ #cpp3-back-opts=cpp-debug

#flowc1 run=btester back=cpp3                          test=cpp3 valgrind=1 exclude=test_runner,int_array test-opts=determ

## flowc2 tests:
	#flowc1 run=btester back=cpp3 compiler=../flowc2 test=cpp3 valgrind=1 exclude=test_runner,test_concur,sizeof    test-opts=determ #cpp3-back-opts=cpp-debug
	#flowc1 run=btester back=cpp3 compiler=../flowc2 test=nim  valgrind=1 exclude=gc,http,test_local2utc,users_tree test-opts=determ #cpp3-back-opts=cpp-debug
