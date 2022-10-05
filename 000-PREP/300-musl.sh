#!/bin/sh bash
#005-CCTOOLS/300-musl.sh
#
# CC Tools: Musl
# Build and Install as plan10

# Configure for cross building
./configure \
    CROSS_COMPILE=${PLAN10_TARGET}- \
    --prefix=/ \
    --target=${PLAN10_TARGET}

# Build and install
make && DESTDIR=/cctools make install

# Add missing directory and link
mkdir -pv /cctools/usr
ln -sv ../include /cctools/usr/include

export ARCH="x86_64"

# Create link to ldd
ln -sv ../lib/ld-musl-$ARCH.so.1 /cctools/bin/ldd

# Create config for dynamic library loading
mkdir -pv /cctools/etc
cat > /cctools/etc/ld-musl-$ARCH.path << "EOF"
/cctools/lib
/tools/lib
EOF

unset ARCH