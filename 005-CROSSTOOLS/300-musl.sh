#!/bin/sh bash

# 005-CCTOOLS/300-Musl

# CC Tools: Musl
# Build and install as plan10

# Configure source for cross build
./configure \
  CROSS_COMPILE=${PLAN10_TARGET}- \
  --prefix=/ \
  --target=${PLAN10_TARGET} 

# Build and install
make && DESTDIR=/cctools make install

# Add missing directory and link
mkdir -v /cctools/usr
ln -sv ../include  /cctools/usr/include

case $(uname -m) in
  x86_64) export ARCH="x86_64"
          ;;
  i686)   export ARCH="i386"
          ;;
  arm*)   export ARCH="arm"
          ;;
  aarch64) export ARCH="aarch64"
          ;;
esac

# Create link for ldd:
ln -sv ../lib/ld-musl-$ARCH.so.1 /cctools/bin/ldd

# Create config for dynamic library loading:
mkdir -v /cctools/etc
cat > /cctools/etc/ld-musl-$ARCH.path << "EOF"
/cctools/lib
/tools/lib
EOF

unset ARCH