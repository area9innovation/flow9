Testing of optimizations
------------------------

To run optimization tests use following command line:

	flowc unittests=optimize outfolder=optimize/out optimize=1 dce=1 remove-dup-strings=1 force-inlining=fun,fun1,fun2,fun3 test-inline-rec-depth=test23-1,test24-2,test25-3,test29-2,test31-2 test-inline-max-nesting=test31-2,test33-4,test40-5,test46-0,test54-0

