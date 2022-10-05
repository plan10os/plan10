#!/bin/sh bash
# 005-CCTOOLS/200-GCC-static.sh
# CC Tools: GCC STATIC
# Build and install as plan10

# GCC now requires the GMP, MPFR and MPC packages to build.
# Unpack them in-tree.
tar -xf ../pkgsrc/mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../pkgsrc/gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../pkgsrc/mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc

# The GCC documentation recommends building GCC in 
# a dedicated build directory
mkdir -v build && cd  build

# Configure source 
CFLAGS='-g0 -O0' \
CXXFLAGS='-g0 -O0' \
../configure \
  --build=${PLAN10_HOST} \
  --disable-decimal-float \
  --disable-libatomic \
  --disable-libgomp   \
  --disable-libitm    \
  --disable-libquadmath \
  --disable-libsanitizer\
  --disable-libssp    \
  --disable-libstdcxx \
  --disable-libvtv \
  --disable-multilib \
  --disable-nls        \
  --disable-shared \
  --disable-threads   \
  --enable-clocale=generic\
  --enable-languages=c\
  --host=${PLAN10_HOST}  \
  --prefix=/cctools\
  --target=${PLAN10_TARGET} \
  --with-arch=${PLAN10_CPU} \
  --with-newlib  \
  --with-sysroot=/cctools/${PLAN10_TARGET} \
  --without-headers

# Build only the mininum 
make all-gcc all-target-libgcc

# Install
make install-gcc install-target-libgcc
