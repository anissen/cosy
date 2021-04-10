#include <stdio.h>
#include "cosy/Cosy.h"

// extern "C" void hxcpp_set_top_of_stack();
extern "C" const char *hxRunLibrary();

int main() {
    // hxcpp_set_top_of_stack();
    const char *err = hxRunLibrary();
	if (err) {
		// Unhandled exceptions ...
		fprintf(stderr, "Error %s\n", err);
		return -1;
	}

    cosy::Cosy_obj::run("print 'hello from c++'");
    cosy::Cosy_obj::runFile("test/examples/misc/mandelbrot.cosy");
	return 0;
}