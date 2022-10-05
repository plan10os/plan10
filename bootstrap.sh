TOP=$(pwd)
PLAN10_PRJ=$TOP/plan10
mkdir -pv $PLAN10_PRJ

PREPDIR=$PLAN10_PRJ/000-prep
CGNUTOOLS=$PLAN10_PRJ/001-cgnutools
LLVMTOOLS=$PLAN10_PRJ/002-llvmtools
mkdir -pv $PLAN10_PRJ/{$PREPDIR,$CGNUTOOLS,$LLVMTOOLS}

LLVMSRC=$PLAN10_PRJ/

# creates basic project directory structure
touch $PREPDIR/00-prep
touch $CGNUTOOLS/{00-libunwind,01-libcxxabi,02-libcxx,03-clang}
touch $LLVMTOOLS/{00-libunwind,01-libcxxabi,02-libcxx,03-clang}

# Creates the cross-tools tirectory and populates it with code from Musl-LFS 
CTDIR= $PLAN10_PRJ/01-cross-tools
mkdir -pv $CTDIR

touch $CTDIR/{00-kernel-headers,01-binutils.}
# along with  40 patches to gcc from alpine
## Create File: 00-prep/00-prep
cd 00-prep
cat << 00-prep >> EOF
# Prequisites
# Required for host:
#   * cmake
#   * ninja
#   * python3 (linked as 'python' if python2 not installed)
#   * wget
#
# Base Development tools
#   * GCC
#   * Kernel Headers
#   * make
#   * ... (if distro is MLFS/LFS, then all development packages are installed)

# Create a directory to hold sources and stage area, as root:
mkdir -pv /mnt/plan10
export PLAN10=/mnt/plan10

# Create directories to build clang with GCC libraries (cgnutools) 
# and the final toolchain without GCC libraries. As root, Link them
# to hosts root directory:
mkdir -v $PLAN10/cgnutools
mkdir -v $PLAN10/llvmtools
ln -sv   $PLAN10/cgnutools /
ln -sv   $PLAN10/llvmtools /

# As root, create directories to hold patches, files, packages, 
# and build area:
mkdir -pv $PLAN10/sources/{patches,files,pkgs,srcpkgs}

# Download sources. Provided list can be used with wget:
wget --input-file=source.list --continue --directory-prefix=$PLAN10/sources/srcpkgs

# Create user and group:
# As root, change ownership to allow installation of tools
groupadd plan10
useradd -s /bin/bash -g plan10 -m -k /dev/null plan10
passwd plan10

chown -v  plan10 $PLAN10/cgnutools
chown -v  plan10 $PLAN10/llvmtools
chown -vR plan10 $PLAN10/sources
chmod -v  a+wt  $PLAN10/sources

# Now run as plan10 user. All toolchain software should be built 
# as this user, unless specified.
su - plan10

# Set up the environment.
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\n\$ ' /bin/bash
EOF

cat > ~/.bashrc << "EOF"
set +h
umask 022
PLAN10=/mnt/plan10
LC_ALL=POSIX
PATH=/cgnutools/bin:/llvmtools/bin:/bin:/usr/bin
export PLAN10 LC_ALL PATH
EOF

# Load the stored environment
source ~/.bash_profile

# CFLAGS and CXXFLAGS must not be set during the building of cross-tools. 
unset CFLAGS
unset CXXFLAGS

cat >> ~/.bashrc << EOF
unset CFLAGS
unset CXXFLAGS
EOF

# Set build paths:
cat >> ~/.bashrc << EOF
export CLANG_GNU_INSTALL_PATH=/cgnutools
export LIBUNWIND_GNU_INSTALL_PATH=/cgnutools
export LIBCXXABI_GNU_INSTALL_PATH=/cgnutools
export LIBCXX_GNU_INSTALL_PATH=/cgnutools
export LLVMSRC="/mnt/plan10/sources/llvm-project-llvmorg-11.0.0"
EOF

export PLAN10_TARGET="x86_64-plan10-linux-musl"
export PLAN10_ARCH="x86"
export PLAN10_CPU="x86-64"
export PLAN10_HOST="$(echo $MACHTYPE | \
    sed "s/$(echo $MACHTYPE | cut -d- -f2)/cross/")"

cat >> ~/.bashrc << EOF
export PLAN10_HOST="${PLAN10_HOST}"
export PLAN10_TARGET="${PLAN10_TARGET}"
export PLAN10_ARCH="${PLAN10_ARCH}"
export PLAN10_CPU="${PLAN10_CPU}"
EOF

EOF

source $HOME/.bashrc


## Create File: 01-cgnutools/01-cgnutools
cd $CGNUTOOLS

cat << 01-cgnutools >> EOF
cd $LLVMSRC/libunwind

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBUNWIND_GNU_INSTALL_PATH} \
      -DLIBUNWIND_ENABLE_SHARED=ON \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DCMAKE_C_FLAGS="-fPIC"  \
      -DCMAKE_CXX_FLAGS="-fPIC" && \

ninja -C build         && \
ninja -C build install && \

# Link libunwind to final toolchain. Libraries will be replaced once
# libunwind is rebuilt with clang
mkdir -pv /llvmtools/lib/ \
ln -sv ${LIBUNWIND_GNU_INSTALL_PATH}/lib/* /llvmtools/lib/ &&\

rm -rf build

EOF


## Create File: 01-cgnutools/02-libcxxabi
cd $CGNUTOOLS

cat << 02-libcxxabi >> EOF
cd $LLVMSRC/libcxxabi

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBCXXABI_GNU_INSTALL_PATH} \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DLIBCXXABI_LIBUNWIND_PATH="${LLVMSRC}libunwind" \
      -DLIBCXXABI_LIBCXX_INCLUDES="${LLVMSRC}/libcxx/include" && \

ninja -C build         && \
ninja -C build install && \
rm -rf build           && \

# Link libcxxabi to final toolchain. Libraries will be replaced once
# libcxxabi is rebuilt with clang
ln -vs ${LIBCXXABI_GNU_INSTALL_PATH}/lib/* /llvmtools/lib/
EOF


## create File: 01-cgnutools/03-libcxx
cd $CGNUTOOLS

cat << 03-libcxx > EOF
cd $LLVMSRC/libcxx
cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBCXX_GNU_INSTALL_PATH} \
      -DLIBCXX_ENABLE_SHARED=ON \
      -DLIBCXX_ENABLE_STATIC=ON  \
      -DLIBCXX_HAS_MUSL_LIBC=ON \
      -DLIBCXX_HAS_GCC_S_LIB=OFF \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DLIBCXX_CXX_ABI=libcxxabi \
      -DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMSRC}/libcxxabi/include"
      -DLLVM_PATH="${LLVMSRC}/llvm"

ninja -C build         && \
ninja -C build install && \
rm -rf build           && \

# Link libcxx to final toolchain. Libraries will be replaced once
# libcxx is rebuilt with clang
ln -s ${LIBCXX_GNU_INSTALL_PATH}/lib/*      /llvmtools/lib/
ln -s ${LIBCXX_GNU_INSTALL_PATH}/include/*  /llvmtools/include/


EOF


## create File: 01-cgnutools/4-clang
cd $CGNUTOOLS

cat << 04-clang > EOF
cd $LLVMSRC/clang
cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DCMAKE_INSTALL_PREFIX=${CLANG_GNU_INSTALL_PATH} \
      -DLLVM_ENABLE_PROJECTS="clang;compiler-rt" \
      -DLLVM_BUILD_TESTS=OFF \
      -DLLVM_ENABLE_LIBEDIT=OFF \
      -DLLVM_ENABLE_LIBXML2=OFF \
      -DLLVM_INCLUDE_GO_TESTS=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-pc-linux-musl \
      -DLLVM_HOST_TRIPLE="x86_64-pc-linux-musl" 
      -DLLVM_TARGET_ARCH="X86" \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DCOMPILER_RT_DEFAULT_TARGET_TRIPLE="x86_64-pc-linux-musl" \
      -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
      -DCOMPILER_RT_BUILD_XRAY=OFF \
      -DCOMPILER_RT_BUILD_PROFILE=OFF \
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
      -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
      -DCLANG_DEFAULT_CXX_STDLIB=libc++ \ 
      -DCLANG_DEFAULT_UNWINDLIB=libunwind \
      -DCLANG_DEFAULT_RTLIB=compiler-rt

ninja -C build         && \
ninja -C build install && \
rm -rf build

EOF


## Create File: 2-llvmtools/01-libunwind
cd $LLVMTOOLS

cat << 01-libunwind >> EOF
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib 
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd $LLVMSRC/libunwind

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBUNWIND_INSTALL_PATH} \
      -DLIBUNWIND_ENABLE_SHARED=ON \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DCMAKE_C_FLAGS="-fPIC" \
      -DCMAKE_CXX_FLAGS="-fPIC"
ninja -C build 
ninja -C build install
rm -rf build

EOF


## Create File: 2-llvmtools/2-libcxxabi
cd $LLVMTOOLS

cat << 2-libcxxabi >> EOF
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib 
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd $LLVMSRC/libcxxabi

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBCXXABI_INSTALL_PATH} \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_USE_COMPILER_RT=ON \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DLIBCXXABI_LIBUNWIND_PATH="${LLVMSRC}/libunwind" \
      -DLIBCXXABI_LIBCXX_INCLUDES="${LLVMSRC}/libcxx/include" \
      -DLLVM_PATH="${LLVMSRC}/llvm" 
ninja -C build 
ninja -C build install
rm -rf build
EOF

## Create File: 2-llvmtools/3-libcxx
cd $LLVMTOOLS

cat << 3-libcxx >> EOF
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib 
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd $LLVMSRC/libcxx

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBCXX_INSTALL_PATH} \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DLIBCXX_ENABLE_SHARED=ON \
      -DLIBCXX_ENABLE_STATIC=ON  \
      -DLIBCXX_HAS_GCC_S_LIB=OFF \
      -DLIBCXX_HAS_MUSL_LIBC=ON \
      -DLIBCXX_USE_COMPILER_RT=ON \
      -DLIBCXX_CXX_ABI=libcxxabi \
      -DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMSRC}/libcxxabi/include" \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON 
ninja -C build 
ninja -C build install
rm -rf build

EOF





## Create File: 2-llvmtools/4-clang
cd $LLVMTOOLS

cat << 4-clang >> EOF
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd $LLVMSRC/clang

cmake -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=MinSizeRel \
      -DCMAKE_INSTALL_PREFIX=/llvmtools \
      -DLLVM_ENABLE_PROJECTS="clang;compiler-rt" \
      -DLLVM_INSTALL_TOOLCHAIN_ONLY=ON \
      -DLLVM_LINK_LLVM_DYLIB=ON \
      -DLLVM_BUILD_LLVM_DYLIB=ON \
      -DLLVM_BUILD_TESTS=OFF \
      -DLLVM_ENABLE_LIBEDIT=OFF \
      -DLLVM_ENABLE_LIBXML2=OFF \
      -DLLVM_ENABLE_LIBCXX=ON \
      -DLLVM_INCLUDE_GO_TESTS=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_INCLUDE_BENCHMARKS=OFF \
      -DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-pc-linux-musl \
      -DLLVM_HOST_TRIPLE="x86_64-pc-linux-musl" 
      -DLLVM_TARGET_ARCH="X86" \
      -DLLVM_TARGETS_TO_BUILD="X86" \
      -DCOMPILER_RT_DEFAULT_TARGET_TRIPLE="x86_64-pc-linux-musl" \
      -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
      -DCOMPILER_RT_BUILD_XRAY=OFF \
      -DCOMPILER_RT_BUILD_PROFILE=OFF \
      -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
      -DCOMPILER_RT_USE_BUILTINS_LIBRARY=ON \
      -DCLANG_DEFAULT_CXX_STDLIB=libc++ \ 
      -DCLANG_DEFAULT_UNWINDLIB=libunwind \
      -DCLANG_DEFAULT_RTLIB=compiler-rt

ninja -C build         && \
ninja -C build install && \
rm -rf build
EOF

## Create File: README.md
cd $PLAN10_PRJ
cat << 'README.md' >> EOF
# CMLFS - Clang Musl Linux From Scratch

This is based on Linux From Scratch (www.linuxfromscratch.org) but with the goal of building a system with clang & friends from LLVM and Musl Libc.

## LLVM Version: 11.0.0
## Specification
<ul>
<li>C Runtime Library (system libc): Musl </li>
<li>Default C Compiler: clang (LLVM)</li>
<li>Default C++ compiler: clang++ (LLVM)</li>
<li>Default linker: lld (LLVM)</li>
<li>C++ standard library: libcxx (LLVM)</li>
<li>C++ ABI library: libcxxabi (LLVM)</li>
<li>Unwinding Library: libunwind (LLVM)</li>
<li>Init system: skarnet's S6 & S6-rc</li>
<li>Device manager: Udev </li>
<li>TLS Implementaion: LibreSSL</li>
<li>System Shell: Bash </li>
<li>System Gettext: gettext-tiny</li>
</ul>
## Supported Architectures

AMD64/x86_64

Other arches will be supported after first successive build.

## Goals

<ul>
<li> [ ] Build a toolchain with LLVM but without GCC</li>
<li> [ ] Build final root filesystem with LLVM</li>
<li> [ ] Set default linker as lld(LLVM)</li>
<li> [ ] Set default C++ standard library as libcxx(LLVM)</li>
<li> [ ] Set default C++ ABI library as libcxxabi(LLVM)</li>
<li> [ ] Set default stack unwinding library as libunwind(LLVM)</li>
<li> [ ] Eliminate dependency on GCC's libgcc_s</li>
</ul>

## Current Method
Based on Genshen's repo(github.com/genshen/docker-clang-toolchain)
Uses the large source archive that includes all LLVM source like clang, 
compiler-rt, lld, libunwind, libcxxabi, and libcxx.
<ol>
<li>Stage 1: Build clang with GCC libraries</li>
<li>Stage 2: Build new clang with old clang. This clang will not have GCC libraries</li>
<li>Stage 3: Build final root filesystem in chroot</li>
</ol>

## Issues
<ul>
<li>Stage 2 Clang fails to build</li>
<li>Binaries built are still linked to host's libc</li>
<li>LLVM's lld is not used, but wanted.</li>
</ul>

## Change log

<ul>
<li>DEV-01(Pending): Build cross-tools with GCC to build stage 1 clang</li>
<li>DEV-00: First attempt, modeled afer Genshen's repo: Stage 2 clang fails to build.</li>
</ul>

## Projects of Interest
<ul>
<li>Genshen's docker-clang-toolchain - https://github.com/genshen/docker-clang-toolchain</li>
<li>Build a freestanding libc++ - https://blogs.gentoo.org/gsoc2016-native-clang/2016/05/05/build-a-freestanding-libcxx/ </li>
</ul>
EOF

## Create File: sources.list
cd $PLAN10_PRJ
cat << 'sources.list' >> EOF
https://github.com/llvm/llvm-project/archive/llvmorg-11.0.0.tar.gz
https://ftp.gnu.org/gnu/binutils/binutils-2.36.1.tar.xz
https://dev.alpinelinux.org/~nenolod/gcc-10.2.1_pre2.tar.xz
https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz
https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz
https://www.mpfr.org/mpfr-4.1.0/mpfr-4.1.0.tar.xz
ftp://ftp.astron.com/pub/file/file-5.39.tar.gz
EOF

CTOOLS_DIR=$PLAN10_PRJ/01-cross-tools
mkdir -pv $CTOOLS_DIR

touch $CTOOLS_DIR/{00-Kernel-headers,01-binutils,02-gcc-static,03-musl,04-gcc-final,05-file}

cat << 00-kernel-headers >> EOF
+# Cross-Tools: Kernel Headers
+# Build & install as user cmlfs
+
+# Clean sources
+make mrproper
+
+# Build Headers
+make ARCH=${CMLFS_ARCH} headers_check
+
+# Install
+# For kernel up to 5.2.x:
+# make ARCH=${CMLFS_ARCH} INSTALL_HDR_PATH=/cross-tools/${CMLFS_TARGET} headers_install
+# For kernels 5.3.x:
+make ARCH=${CMLFS_ARCH} headers
+mkdir -pv /cross-tools/${CMLFS_TARGET}/include
+cp -rv usr/include/* /cross-tools/${CMLFS_TARGET}/include
+rm -v /cross-tools/${CMLFS_TARGET}/include/Makefile
+
EOF

cat << 01-binutils >> EOF
+# Cross-Tools: Binutils
+# Build and install as cmlfs
+
+# Create build directory in-tree
+mkdir -v build && cd build
+
+# configure source
+../configure \
+   --prefix=/cross-tools \
+   --target=${CMLFS_TARGET} \
+   --with-sysroot=/cross-tools/${CMLFS_TARGET} \
+   --disable-nls \
+   --disable-multilib \
+   --disable-werror \
+   --enable-deterministic-archives \
+   --disable-compressed-debug-sections 
+
+# build to check host can build
+make configure-host
+
+# Build and install
+make && make install

EOF

cat << 02-gcc-static >> EOF
+# Cross-Tools: GCC STATIC
+# Build and install as cmlfs
+
+# GCC now requires the GMP, MPFR and MPC packages to build.
+# Unpack them in-tree.
+tar -xf ../pkgs/mpfr-4.1.0.tar.xz
+mv -v mpfr-4.1.0 mpfr
+tar -xf ../pkgs/gmp-6.2.1.tar.xz
+mv -v gmp-6.2.1 gmp
+tar -xf ../pkgs/mpc-1.2.1.tar.gz
+mv -v mpc-1.2.1 mpc
+
+# The GCC documentation recommends building GCC in 
+# a dedicated build directory
+mkdir -v build && cd  build
+
+# Configure source 
+CFLAGS='-g0 -O0' \
+CXXFLAGS='-g0 -O0' \
+../configure \
+  --prefix=/cross-tools --build=${CMLFS_HOST} \
+  --host=${CMLFS_HOST}   --target=${CMLFS_TARGET} \
+  --with-sysroot=/cross-tools/${CMLFS_TARGET} \
+  --disable-nls         --with-newlib  \
+  --disable-libitm     --disable-libvtv \
+  --disable-libssp     --disable-shared \
+  --disable-libgomp    --without-headers \
+  --disable-threads    --disable-multilib \
+  --disable-libatomic  --disable-libstdcxx \
+  --enable-languages=c --disable-libquadmath \
+  --disable-libsanitizer --with-arch=${CMLFS_CPU} \
+  --disable-decimal-float --enable-clocale=generic 
+
+# Build only the mininum 
+make all-gcc all-target-libgcc
+
+# Install
+make install-gcc install-target-libgcc
+
EOF

cat << 03-musl >> EOF
+# Cross-Tools: Musl
+# Build and install as cmlfs
+
+# Configure source for cross build
+./configure \
+  CROSS_COMPILE=${CMLFS_TARGET}- \
+  --prefix=/ \
+  --target=${CMLFS_TARGET} 
+
+# Build and install
+make && DESTDIR=/cross-tools make install
+
+# Add missing directory and link
+mkdir -v /cross-tools/usr
+ln -sv ../include  /cross-tools/usr/include
+
+case $(uname -m) in
+  x86_64) export ARCH="x86_64"
+          ;;
+  i686)   export ARCH="i386"
+          ;;
+  arm*)   export ARCH="arm"
+          ;;
+  aarch64) export ARCH="aarch64"
+          ;;
+esac
+
+# Create link for ldd:
+ln -sv ../lib/ld-musl-$ARCH.so.1 /cross-tools/bin/ldd
+
+# Create config for dynamic library loading:
+mkdir -v /cross-tools/etc
+cat > /cross-tools/etc/ld-musl-$ARCH.path << "EOF"
+/cross-tools/lib
+/tools/lib
+EOF
+
+unset ARCH
EOF

cat << 04-gcc-final >> EOF
+# Cross-Tools: GCC Final
+# Build and install as cmlfs
+
+# Additional sources to add as GCC requires them 
+tar -xf ../pkgs/mpfr-4.1.0.tar.xz
+mv -v mpfr-4.1.0 mpfr
+tar -xf ../pkgs/gmp-6.2.1.tar.xz
+mv -v gmp-6.2.1 gmp
+tar -xf ../pkgs/mpc-1.2.1.tar.gz
+mv -v mpc-1.2.1 mpc
+
+# Apply patches [from Alpine-linux]
+or p in 0001-posix_memalign.patch \
+        0002-gcc-poison-system-directories.patch \
+        0003-Turn-on-Wl-z-relro-z-now-by-default.patch \
+        0004-Turn-on-D_FORTIFY_SOURCE-2-by-default-for-C-C-ObjC-O.patch \
+        0005-On-linux-targets-pass-as-needed-by-default-to-the-li.patch \
+        0006-Enable-Wformat-and-Wformat-security-by-default.patch \
+        0007-Enable-Wtrampolines-by-default.patch \
+        0008-Disable-ssp-on-nostdlib-nodefaultlibs-and-ffreestand.patch \
+        0009-Ensure-that-msgfmt-doesn-t-encounter-problems-during.patch \
+        0010-Don-t-declare-asprintf-if-defined-as-a-macro.patch \
+        0011-libiberty-copy-PIC-objects-during-build-process.patch \
+        0012-libitm-disable-FORTIFY.patch \
+        0013-libgcc_s.patch \
+        0014-nopie.patch \
+        0015-libffi-use-__linux__-instead-of-__gnu_linux__-for-mu.patch \
+        0016-dlang-update-zlib-binding.patch \
+        0017-dlang-fix-fcntl-on-mips-add-libucontext-dep.patch \
+        0018-ada-fix-shared-linking.patch \
+        0019-build-fix-CXXFLAGS_FOR_BUILD-passing.patch \
+        0020-add-fortify-headers-paths.patch \
+        0022-DP-Use-push-state-pop-state-for-gold-as-well-when-li.patch \
+        0023-Pure-64-bit-MIPS.patch \
+        0024-use-pure-64-bit-configuration-where-appropriate.patch \
+        0025-always-build-libgcc_eh.a.patch \
+        0026-ada-libgnarl-compatibility-for-musl.patch \
+        0027-ada-musl-support-fixes.patch \
+        0028-gcc-go-Use-_off_t-type-instead-of-_loff_t.patch \
+        0029-gcc-go-Don-t-include-sys-user.h.patch \
+        0030-gcc-go-Fix-ucontext_t-on-PPC64.patch \
+        0031-gcc-go-Fix-handling-of-signal-34-on-musl.patch \
+        0032-gcc-go-Use-int64-type-as-offset-argument-for-mmap.patch \
+        0033-gcc-go-Fix-st_-a-m-c-tim-fields-in-generated-sysinfo.patch \
+        0034-gcc-go-signal-34-is-special-on-musl-libc.patch \
+        0035-gcc-go-Prefer-_off_t-over-_off64_t.patch \
+        0036-gcc-go-undef-SETCONTEXT_CLOBBERS_TLS-in-proc.c.patch \
+        0037-gcc-go-link-to-libucontext.patch \
+        0038-gcc-go-Disable-printing-of-unaccessible-ppc64-struct.patch \
+        0039-CRuntime_Musl-Support-v1.2.0-for-32-bits.patch \
+        0040-configure-Add-enable-autolink-libatomic-use-in-LINK_.patch
+do
+        patch -Np1 -i ../patches/gcc-alpine-10.2.1p2/$p
+done
+
+case $(uname -m) in
+  x86_64)
+    sed -e '/m64=/s/lib64/lib/' \
+        -i.orig gcc/config/i386/t-linux64
+ ;;
+esac
+
+# Configure in a dedicated build directory
+mkdir build && cd  build
+AR=ar LDFLAGS="-Wl,-rpath,/cross-tools/lib" \
+../configure \
+    --prefix=/cross-tools \
+    --build=${CMLFS_HOST} \
+    --host=${CMLFS_HOST} \
+    --target=${CMLFS_TARGET} \
+    --disable-multilib \
+    --with-sysroot=/cross-tools \
+    --disable-nls \
+    --enable-shared \
+    --enable-languages=c,c++ \
+    --enable-threads=posix \
+    --enable-clocale=generic \
+    --enable-libstdcxx-time \
+    --enable-fully-dynamic-string \
+    --disable-symvers \
+    --disable-libsanitizer \
+    --disable-lto-plugin \
+    --disable-libssp 
+
+# Build
+make AS_FOR_TARGET="${CMLFS_TARGET}-as" \
+    LD_FOR_TARGET="${CMLFS_TARGET}-ld"
+
+# Install
+make install

EOF

cat << 05-file >> EOF
```
+# Cross-Tools: File
+# Build and install as cmlfs
+
+# Configure source
+./configure --prefix=/cross-tools --disable-libseccomp
+
+# Build and install
EOF

wget -i gcc-alpine-patches.list -C $PLAN10_PRJ/patches
