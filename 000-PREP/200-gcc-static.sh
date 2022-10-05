#!/bin/sh bash
#
# Filename: /005-cctools/200-gcc-static.sh
# CC Tools: GCC STATIC
# Build and install as plan10

# GCC now requires GMP, MPFR, and MPC packages to build
# Unpack them in-tree
tar -xf ../pkgsrc/mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../pkgsrc/gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../pkgsrc/mpc-1.2.1.tar.xz
mv -v mpc-1.2.1 mpc

# GCC docs recommend building GCC in a dedicated build directory
mkdir -pv build && cd build

# Configure source
CFLAGS='-g0 -O0' \
CXXFLAGS='-g0 -O0' \
../configure \
    --prefix=/cctools \
    --build=${PLAN10_HOST} \
    --host=${PLAN10_HOST} \
    --target=${PLAN10_TARGET} \
    --with-sysroot=/cctools/${PLAN10_TARGET} \
    --disable-nls \
    --with-newlib \
    --disable-libitm \
    --disable-shared \
    --disable-libgomp \
    --disable-libvtv \
    --disable-libssp \
    --without-headers \
    --disable-threads \
    --disable-multilib \
    --disable-libatomic \
    --disable-libstdcxx \
    --disable-quadmath \
    --disable-libsanitizer \
    --disable-decimal-float \
    --enable-clocale=generic \
    --with-arch=${PLAN10_CPU} \
    --enable-languages=c

# Minimal build
make all-gcc all-target-libgcc

# Install
make install-gcc install-target-libgcc