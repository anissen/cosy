#include <stdio.h>
#include "cosy/Cosy.h"

// extern "C" void hxcpp_set_top_of_stack();
extern "C" const char *hxRunLibrary();

static void func() {
	printf("func()\n");
}

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

	// Foreign variable works somewhat (int and bool works, string does not)
    // cosy::Cosy_obj::setVariable("x", 42);
    // cosy::Cosy_obj::setVariable("x", "asdf".c_str());
    // cosy::Cosy_obj::run("foreign var x\nprint 'foreign variable: {x}'");
	
	// Foreign function callbacks do not work:
    // cosy::Cosy_obj::setFunction("f", &func);
    // cosy::Cosy_obj::run("foreign fn f()\nprint 'calling foreign func:'\nf()\nprint 'done'");
	
	return 0;
}