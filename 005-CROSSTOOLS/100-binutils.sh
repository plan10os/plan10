#!/bin/sh bash
#005-CCTOOLS/100-Binutils.sh

# CC Tools: Binutils
# Build and install as cmlfs

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

# Build and install
make && make install