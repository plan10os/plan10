#!/bin/sh bash
#005-CROSSTOOLS/000-kernel-headers
# Crosstools: Kernel Headers
# Build and install as user plan10

# Clean sources
make mrproper

# Build Headers
make ARCH=${PLAN10_ARCH} headers_check

# Install
# For Linux kernels up to 5.2.x:
# make ARCH=${PLAN10_ARCH} INSTALL_HDR_PATH=/cctools/${PLAN10_TARGET} headers_install
# For kernels 5.3.x:
make ARCH=${PLAN10_ARCH} headers
mkdir -pv /cctools/${PLAN10_TARGET}/include
cp -rv usr/include/* /cctools/${PLAN10_TARGET}/include
rm -v /cctools/${PLAN10_TARGET}/include/Makefile