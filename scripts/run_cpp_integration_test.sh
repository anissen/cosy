#!/bin/bash

# Build Cosy as a C++ static library
haxe scripts/cpp_lib.hxml

# Build the C++ file integrating Cosy as a scripting language
make -C test/integrations/c++

# Run the executable
./bin/cpp_lib/cpp_integration