Error diagnistics testing
-------------------------

Some tests need certain options:

* error20.flow:
	flowc find-unused-locals=2 tests/errors/error20.flow

* error21.flow:
	flowc find-unused-exports=2 tests/errors/error21.flow
