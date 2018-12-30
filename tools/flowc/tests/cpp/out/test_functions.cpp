#include <cassert>
#include <functional>
#include <stdio.h>

void nop() {
}

void nop1() {
	
}

void prn(void* ptr, int sz) {
	for (int i = 0; i < sz; i++) {
		printf("%02x", ((unsigned char*)ptr)[i]);
		if ((i+1)%4 == 0) printf(" ");
	}
	printf("\n");
}

void prn(const char* tag, std::function<void()>& f) {
	printf("%s ", tag);
	prn(&f, sizeof(f));
}

int main() {
	std::function<void()> f1 = nop;
	std::function<void()> f2 = nop;
	assert(f1.target<void()>() == f2.target<void()>());
	
	// prn("f1", f1);
	// prn("f2", f2);
	// auto f3 = f2;
	// prn("f3", f3);
	// auto f4 = f2;
	// prn("f4", f4);
	// assert(f1 == f2);
	return 0;
}
