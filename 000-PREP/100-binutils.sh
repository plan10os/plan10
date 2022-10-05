#!/bin/sh bash
# 005-CCTOOLS/100-binutils
#
# CC Tools: Binutils
# Build and install as plan10
#
# Create build directory in-tree
mkdir -v build && cd build

# configure source
../configure \
    --prefix=/cctools \
    --target=${PLAN10_TARGET} \
    --with-sysroot=/cctools/${PLAN10_TARGET} \
    --disable-nls \
    --disable-multilib \
    --disable-werror \
    --enable-deterministic-archives \
    --disable-compressed-debug-sections

# build to check host can build
make configure-host

# build and install
make && make install