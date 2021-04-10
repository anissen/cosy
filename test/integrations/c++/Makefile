.PHONY = build clean
.DEFAULT_GOAL := build

SHARED_FLAGS := \
	cpp_integration.cpp \
	-o ../../../bin/cpp_lib/cpp_integration \
	-g \
	-std=c++17 \
	-pedantic \
	-Wshadow \
	-I/Users/anders/haxe/haxe_libraries/hxcpp/4.2.1/haxelib/include \
	-L../../../bin/cpp_lib -I../../../bin/cpp_lib/include -lCosy

build:
	mkdir -p ../../../bin
	clang++ ${SHARED_FLAGS}

clean:
	rm ../../../bin/cpp_lib/cpp_integration