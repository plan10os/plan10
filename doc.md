## STEP 0
This is an attempt to document the (re)building of a Clang-built Musl Linux from Scratch as an effort to try and better understand how to implement the OS.

To do this I have cloned the repository and ran the following command to get a detailed commit log in reverse chronology:

git clone https://github.com/dslm4515/cmlfs
git log --reverse --raw --patch > git_log_--reverse_--raw_--patch.txt

Note! Be careful doing this on very large repos as it will create a VERY large txt file ;)

Reviewing the generated file we see the first commit made consists of 11 files added:

* 0-Preparation
* 1-cgnutools/1-libunwind
* 1-cgnutools/2-libcxxabi
* 1-cgnutools/3-libcxx
* 1-cgnutools/4-clang
* 2-llvmtools/1-libunwind
* 2-llvmtools/2-libcxxabi
* 2-llvmtools/3-libcxx
* 2-llvmtools/4-clang
* README.md
* sources.list

To begin, let's create a file to hold our project. I like to keep mine in a `Projects` directory in my home directory so that's what we'll use in this example...

`$ mkdir -pv ~/Projects/MyCMLFS`

and cd into that...

`$ cd ~/Projects/MyCMLFS`

Next, we'll create two directories and the files that go into them as well as the files that reside in the top level directory...

`$ mkdir -pv ~/Projects/MyCMLFS/{00-prep,01-cgnutools,02-llvmtools}`
`$ touch sources.list README.md 00-prep/00-prep \
    1-cgnutools/{00-libunwind,01-libcxxabi,02-libcxx,03-clang} \
    2-llvmtools/{00-libunwind,01-libcxxabi,02-libcxx,03-clang}`

This will give us an initial directory structure as follows...

`~/Projects/MyCMLFS
    |__/00-prep
    |       |__/00-prep
    |
    |__/01-cgnutools
    |       |__/01-libunwind
    |       |__/02-libcxxabi
    |       |__/03-libcxx
    |       |__/04-clang
    |
    |__/02-llvmtools
    |       |__/01-libunwind
    |       |__/02-libcxxabi
    |       |__/03-libcxx
    |       |__/04-clang
    |
    README.md
    sources.list`

Next, we'll get started fleshing out the files we've touched so we can make our 
initial commit. 

1. First up is 00-prep/00-prep. Add the following to that file...

```
#!/bin/sh bash

# $TOP/00-prep/00-prep

# Prequisites
# Required for host:
#     * cmake
#     * ninja
#     * python3 (linked as 'python' if python2 not installed)
#     * wget

# Base Development tools
#     * GCC
#     * Kernel Headers
#     * make

# Create a directory to hold sources and stage area, as root:
mkdir -pv /mnt/plan10
export PLAN10=/mnt/plan10

# Create directories to build clang with GCC libraries (cgnutools) 
# and the final toolchain without GCC libraries. 
mkdir -v $PLAN10/cgnutools
mkdir -v $PLAN10/llvmtools

# As root, Link them to host's root directory:
ln -sv   $PLAN10/cgnutools /
ln -sv   $PLAN10/llvmtools /

# As root, create directories to hold patches, files, packages, 
# and build area:
mkdir -pv $PLAN10/sources/{patches,files,pkgs}

# Download sources. The provided `sources.list` can be used with wget:
wget --input-file=source.list --continue --directory-prefix=$PLAN10/sources/pkgs

# Create user and group:
groupadd plan10
useradd -s /bin/bash -g plan10 -m -k /dev/null plan10
passwd plan10

# As root, change ownership to allow installation of tools
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
export LLVMSRC="/mnt/plan10/sources/llvm-project-llvmorg-15.0.0"
EOF

export PLAN10_TARGET="x86_64-plan10-linux-musl"
export PLAN10_ARCH="x86"
export PLAN10_CPU="x86-64"
export HOST="$(echo $MACHTYPE | \
    sed "s/$(echo $MACHTYPE | cut -d- -f2)/cross/")"

cat >> ~/.bashrc << EOF
export PLAN10_HOST="${PLAN10_HOST}"
export PLAN10_TARGET="${PLAN10_TARGET}"
export PLAN10_ARCH="${PLAN10_ARCH}"
export PLAN10_CPU="${PLAN10_CPU}"
EOF
source ~/.bashrc
```

2. 01-cgnutools/01-libunwind

```
#!/bin/sh bash
cd libunwind  

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBUNWIND_GNU_INSTALL_PATH} \
      -DLIBUNWIND_ENABLE_SHARED=ON \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed"  \
      -DBUILD_SHARED_LIBS=OFF && \

ninja -C build         && \
ninja -C build install && \

# Link libunwind to final toolchain. Libraries will be replaced once
# libunwind is rebuilt with clang
mkdir -pv /llvmtools/lib/ \
ln -sv ${LIBUNWIND_GNU_INSTALL_PATH}/lib/* /llvmtools/lib/ &&\

rm -rf build
```

3. 01-cgnutools/02-libcxxabi

```
#!/bin/sh bash
cd libcxxabi

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBCXXABI_GNU_INSTALL_PATH} \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DLIBCXXABI_LIBUNWIND_PATH="${LLVMSRC}libunwind" \
      -DLIBCXXABI_LIBCXX_INCLUDES="${LLVMSRC}/libcxx/include" \
      -DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed" && \


ninja -C build         && \
ninja -C build install && \
rm -rf build           && \

# Link libcxxabi to final toolchain. Libraries will be replaced once
# libcxxabi is rebuilt with clang
ln -vs ${LIBCXXABI_GNU_INSTALL_PATH}/lib/* /llvmtools/lib/
```

4. 01-cgnutools/03-libcxx

```
#!/bin/sh bash
cd libcxx

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBCXX_GNU_INSTALL_PATH} \
      -DLIBCXX_ENABLE_SHARED=ON \
      -DLIBCXX_ENABLE_STATIC=ON  \
      -DLIBCXX_HAS_MUSL_LIBC=ON \
      -DLIBCXX_HAS_GCC_S_LIB=OFF \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DLIBCXX_CXX_ABI=libcxxabi \
      -DLIBCXX_CXX_ABI_INCLUDE_PATHS="${LLVMSRC}/libcxxabi/include" \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed" && \

ninja -C build         && \
ninja -C build install && \
rm -rf build           && \

# Link libcxx to final toolchain. Libraries will be replaced once
# libcxx is rebuilt with clang
ln -s ${LIBCXX_GNU_INSTALL_PATH}/lib/*      /llvmtools/lib/
ln -s ${LIBCXX_GNU_INSTALL_PATH}/include/*  /llvmtools/include/
```

5. 01-cgnutools/04-clang

```
#!/bin/sh bash
cd clang
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
      -DCLANG_DEFAULT_RTLIB=compiler-rt \
      -DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed" && \

ninja -C build         && \
ninja -C build install && \ 
rm -rf build
```

6. 02-llvmtools/01-libunwind

```
#!/bin/sh bash
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib 
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd libunwind

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBUNWIND_INSTALL_PATH} \
      -DLIBUNWIND_ENABLE_SHARED=ON \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
-DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed"
ninja -C build 
ninja -C build install
rm -rf build
```

7. 02-llvmtools/02-libcxxabi

```
#!/bin/sh bash
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib 
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd libcxxabi

cmake -B build -G Ninja \
      -DCMAKE_INSTALL_PREFIX=${LIBCXXABI_INSTALL_PATH} \
      -DLIBCXXABI_ENABLE_STATIC=ON \
      -DLIBCXXABI_USE_COMPILER_RT=ON \
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DLIBCXXABI_LIBUNWIND_PATH="${LLVMSRC}/libunwind" \
      -DLIBCXXABI_LIBCXX_INCLUDES="${LLVMSRC}/libcxx/include" \
      -DLLVM_PATH="${LLVMSRC}/llvm" \
      -DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed"
ninja -C build 
ninja -C build install
rm -rf build       
```

8. 02-llvmtools/03-libcxx

```
#!/bin/sh bash
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib 
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd libcxx

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
      -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
      -DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed"

ninja -C build 
ninja -C build install
rm -rf build       
```

9. 02-llvmtools/04-clang

```
#!/bin/sh bash
# Set CC and CXX compiler with recently built clang (cgnutools)
export CXX=/cgnutools/bin/clang++
export  CC=/cgnutools/bin/clang

export  LIBUNWIND_INSTALL_PATH=/llvmtools/lib
export  LIBCXXABI_INSTALL_PATH=/llvmtools/lib
export  LIBCXX_INSTALL_PATH=/llvmtools/lib

cd clang
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
      -DCLANG_DEFAULT_RTLIB=compiler-rt \
      -DCMAKE_C_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \
      -DCMAKE_CXX_FLAGS="-march=amd64 -arch x86_64 -g -O2 -fPIC -pie -fPIE -fstack-protector-all -Wstack-protector --param ssp-buffer-size=4 -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security"  \ 
      -DLLDFLAGS="-Wl,-z,now -Wl,-z,relro -Wl,-pie -Wl,--hash-style=both -Wl,--no-copy-dt-needed-entries -Wl,--as-needed"

ninja -C build         && \
ninja -C build install && \ 
rm -rf build

```

10. README.md

```
# Plan10 Linux - an Independent, next-generation, LLVM/Clang built, Musl-libc 
# distribution based on Linux From Scratch...with Package Management

This is based on Linux From Scratch (www.linuxfromscratch.org) but with the goal 
of building a system with clang & friends from LLVM and Musl Libc while using the 
highest degree of hardening possible along with other measures to ensure a solid, 
stable, performant, and secure, privacy respecting linux distribution

## LLVM Version: 15.0.0

## Supported Architectures

AMD64/x86_64

Other arches will be supported after first successive build.

## Goals

<ul>
<li> [ ] Build a toolchain with LLVM but without GCC</li>
<li> [ ] Build final root filesystem with LLVM</li>
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
```

11. sources.list

```
https://github.com/llvm/llvm-project/archive/llvmorg-11.0.0.tar.gz
```

Finally, we are ready for our first commit. This is assuming we will be using 
github, and in my case the repo will be:

https://github.com/plan10linux/mycmlfs

`$ git init`
`$ git add .`
`$ git commit -m "Initial commit: First upload, based on dslm4515's CMLFS and Genshen's docker-clang-toolchain"`
`$ git push`



## STEP 1

Continuing on, let's update iur README.md with some more information. Add the following 
lines such that the README.md file looks like...

(the `+`'s indecate additions, as any `-`'s would indicate removals of the line, 
i.e. they aren't meant to be included in your final document)
README.md
```
 <ul>
 <li> [ ] Build a toolchain with LLVM but without GCC</li>
 <li> [ ] Build final root filesystem with LLVM</li>
+<li> [ ] Set default linker as lld(LLVM)</li>
+<li> [ ] Set default C++ standard library as libcxx(LLVM)</li>
+<li> [ ] Set default C++ ABI library as libcxxabi(LLVM)</li>
+<li> [ ] Set default stack unwinding library as libunwind(LLVM)</li>
+<li> [ ] Eliminate dependacy on GCC's libgcc_s</li>
 </ul>
 ```

 and also ...
 ```
 ## Current Method
 <li>DEV-01(Pending): Build cross-tools with GCC to build stage 1 clang</li>
 <li>DEV-00: First attempt, modeled afer Genshen's repo: Stage 2 clang fails to build.</li>
 </ul>
+
+## Projects of Interest
+<ul>
+<li>Genshen's docker-clang-toolchain - https://github.com/genshen/docker-clang-toolchain</li>
+<li>Build a freestanding libc++ - https://blogs.gentoo.org/gsoc2016-native-clang/2016/05/05/build-a-freestanding-libcxx/ </li>
+</ul>
```

`$ git add .`
`$ git commit -m "Modify README.md"`
`$ git push`


## STEP 1.1 Another README.md Modification

README.md
```
This is based on Linux From Scratch (www.linuxfromscratch.org) but with the goal 
of building a system with clang & friends from LLVM and Musl Libc while using the 
highest degree of hardening possible along with other measures to ensure a solid, 
stable, performant, and secure, privacy respecting linux distribution
 
-## LLVM Version: 11.0.0
+## Specification
+<ul>
+<li>C Runtime Library (system libc): Musl </li>
+<li>Default C Compiler: clang (LLVM)</li>
+<li>Default C++ compiler: clang++ (LLVM)</li>
+<li>Default linker: lld (LLVM)</li>
+<li>C++ standard library: libcxx (LLVM)</li>
+<li>C++ ABI library: libcxxabi (LLVM)</li>
+<li>Unwinding Library: libunwind (LLVM)</li>
+<li>Init system: skarnet's S6 & S6-rc</li>
+<li>Device manager: Udev </li>
+<li>TLS Implementaion: LibreSSL</li>
+<li>System Shell: Bash </li>
+<li>System Gettext: gettext-tiny</li>
+</ul>
 
 ## Supported Architectures
 
 AMD64/x86_64

_Other arches will be supported after first successive build._
 
## Goals
```

$ git add .
$ git commit -m "Added repo's system specs"
$ git push


## STEP 2 Modify sources.list

sources.list
```
 https://github.com/llvm/llvm-project/archive/llvmorg-11.0.0.tar.gz
+https://ftp.gnu.org/gnu/binutils/binutils-2.36.1.tar.xz
+https://dev.alpinelinux.org/~nenolod/gcc-10.2.1_pre2.tar.xz
+https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz
+https://ftp.gnu.org/gnu/mpc/mpc-1.2.1.tar.gz
+https://www.mpfr.org/mpfr-4.1.0/mpfr-4.1.0.tar.xz
+ftp://ftp.astron.com/pub/file/file-5.39.tar.gz
```


$ git add .
$ git commit -m "Adds sources to list for cross-tools"
$ git push


## STEP 3 Adding cross-tools from dslm4515/Musl-LFS and Alpine's GCC-10.2.1p2
This commit takes a script (build-scripts/build-cross-tools.sh) from 
dslm4515/Musl-LFS and breaks it up into smaller scripts which it puts inside of 
the 00-cross-tools directory. In addition, it provider us with a number of patches 
for gcc 10.2.1p2 from Alpine

The following is a list of files added in this commit:
    00-cross-tools/00-Kernel-headers
    00-cross-tools/01-Binutils
    00-cross-tools/02-GCC-static
    00-cross-tools/03-Musl
    00-cross-tools/04-GCC-final
    00-cross-tools/05-File
    patches/gcc-alpine-10.2.1p2/0001-posix_memalign.patch
    patches/gcc-alpine-10.2.1p2/0002-gcc-poison-system-directories.patch
    patches/gcc-alpine-10.2.1p2/0003-Turn-on-Wl-z-relro-z-now-by-default.patch
    patches/gcc-alpine-10.2.1p2/0004-Turn-on-D_FORTIFY_SOURCE-2-by-default-for-C-C-ObjC-O.patch
    patches/gcc-alpine-10.2.1p2/0005-On-linux-targets-pass-as-needed-by-default-to-the-li.patch
    patches/gcc-alpine-10.2.1p2/0006-Enable-Wformat-and-Wformat-security-by-default.patch
    patches/gcc-alpine-10.2.1p2/0007-Enable-Wtrampolines-by-default.patch
    patches/gcc-alpine-10.2.1p2/0008-Disable-ssp-on-nostdlib-nodefaultlibs-and-ffreestand.patch
    patches/gcc-alpine-10.2.1p2/0009-Ensure-that-msgfmt-doesn-t-encounter-problems-during.patch
    patches/gcc-alpine-10.2.1p2/0010-Don-t-declare-asprintf-if-defined-as-a-macro.patch
    patches/gcc-alpine-10.2.1p2/0011-libiberty-copy-PIC-objects-during-build-process.patch
    patches/gcc-alpine-10.2.1p2/0012-libitm-disable-FORTIFY.patch
    patches/gcc-alpine-10.2.1p2/0013-libgcc_s.patch
    patches/gcc-alpine-10.2.1p2/0014-nopie.patch
    patches/gcc-alpine-10.2.1p2/0015-libffi-use-__linux__-instead-of-__gnu_linux__-for-mu.patch
    patches/gcc-alpine-10.2.1p2/0016-dlang-update-zlib-binding.patch
    patches/gcc-alpine-10.2.1p2/0017-dlang-fix-fcntl-on-mips-add-libucontext-dep.patch
    patches/gcc-alpine-10.2.1p2/0018-ada-fix-shared-linking.patch
    patches/gcc-alpine-10.2.1p2/0019-build-fix-CXXFLAGS_FOR_BUILD-passing.patch
    patches/gcc-alpine-10.2.1p2/0020-add-fortify-headers-paths.patch
    patches/gcc-alpine-10.2.1p2/0021-Alpine-musl-package-provides-libssp_nonshared.a.-We-.patch
    patches/gcc-alpine-10.2.1p2/0022-DP-Use-push-state-pop-state-for-gold-as-well-when-li.patch
    patches/gcc-alpine-10.2.1p2/0023-Pure-64-bit-MIPS.patch
    patches/gcc-alpine-10.2.1p2/0024-use-pure-64-bit-configuration-where-appropriate.patch
    patches/gcc-alpine-10.2.1p2/0025-always-build-libgcc_eh.a.patch
    patches/gcc-alpine-10.2.1p2/0026-ada-libgnarl-compatibility-for-musl.patch
    patches/gcc-alpine-10.2.1p2/0027-ada-musl-support-fixes.patch
    patches/gcc-alpine-10.2.1p2/0028-gcc-go-Use-_off_t-type-instead-of-_loff_t.patch
    patches/gcc-alpine-10.2.1p2/0029-gcc-go-Don-t-include-sys-user.h.patch
    patches/gcc-alpine-10.2.1p2/0030-gcc-go-Fix-ucontext_t-on-PPC64.patch
    patches/gcc-alpine-10.2.1p2/0031-gcc-go-Fix-handling-of-signal-34-on-musl.patch
    patches/gcc-alpine-10.2.1p2/0032-gcc-go-Use-int64-type-as-offset-argument-for-mmap.patch
    patches/gcc-alpine-10.2.1p2/0033-gcc-go-Fix-st_-a-m-c-tim-fields-in-generated-sysinfo.patch
    patches/gcc-alpine-10.2.1p2/0034-gcc-go-signal-34-is-special-on-musl-libc.patch
    patches/gcc-alpine-10.2.1p2/0035-gcc-go-Prefer-_off_t-over-_off64_t.patch
    patches/gcc-alpine-10.2.1p2/0036-gcc-go-undef-SETCONTEXT_CLOBBERS_TLS-in-proc.c.patch
    patches/gcc-alpine-10.2.1p2/0037-gcc-go-link-to-libucontext.patch
    patches/gcc-alpine-10.2.1p2/0038-gcc-go-Disable-printing-of-unaccessible-ppc64-struct.patch
    patches/gcc-alpine-10.2.1p2/0039-CRuntime_Musl-Support-v1.2.0-for-32-bits.patch
    patches/gcc-alpine-10.2.1p2/0040-configure-Add-enable-autolink-libatomic-use-in-LINK_.patch

00-cross-tools/00-Kernel-headers
```
# Cross-Tools: Kernel Headers
# Build & install as user cmlfs

# Clean sources
make mrproper

# Build Headers
make ARCH=${CMLFS_ARCH} headers_check

# Install
# For kernel up to 5.2.x:
# make ARCH=${CMLFS_ARCH} INSTALL_HDR_PATH=/cross-tools/${CMLFS_TARGET} headers_install
# For kernels 5.3.x:
make ARCH=${CMLFS_ARCH} headers
mkdir -pv /cross-tools/${CMLFS_TARGET}/include
cp -rv usr/include/* /cross-tools/${CMLFS_TARGET}/include
rm -v /cross-tools/${CMLFS_TARGET}/include/Makefile
```

00-cross-tools/01-Binutils
```
# Cross-Tools: Binutils
# Build and install as cmlfs

# Create build directory in-tree
mkdir -v build && cd build

# configure source
../configure \
   --prefix=/cross-tools \
   --target=${CMLFS_TARGET} \
   --with-sysroot=/cross-tools/${CMLFS_TARGET} \
   --disable-nls \
   --disable-multilib \
   --disable-werror \
   --enable-deterministic-archives \
   --disable-compressed-debug-sections 

# build to check host can build
make configure-host

# Build and install
make && make install
```

00-cross-tools/02-GCC-static
```
# Cross-Tools: GCC STATIC
# Build and install as cmlfs

# GCC now requires the GMP, MPFR and MPC packages to build.
# Unpack them in-tree.
tar -xf ../pkgs/mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../pkgs/gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../pkgs/mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc

# The GCC documentation recommends building GCC in 
# a dedicated build directory
mkdir -v build && cd  build

# Configure source 
CFLAGS='-g0 -O0' \
CXXFLAGS='-g0 -O0' \
../configure \
  --prefix=/cross-tools --build=${CMLFS_HOST} \
  --host=${CMLFS_HOST}   --target=${CMLFS_TARGET} \
  --with-sysroot=/cross-tools/${CMLFS_TARGET} \
  --disable-nls         --with-newlib  \
  --disable-libitm     --disable-libvtv \
  --disable-libssp     --disable-shared \
  --disable-libgomp    --without-headers \
  --disable-threads    --disable-multilib \
  --disable-libatomic  --disable-libstdcxx \
  --enable-languages=c --disable-libquadmath \
  --disable-libsanitizer --with-arch=${CMLFS_CPU} \
  --disable-decimal-float --enable-clocale=generic 

# Build only the mininum 
make all-gcc all-target-libgcc

# Install
make install-gcc install-target-libgcc
```

00-cross-tools/03-Musl
```
# Cross-Tools: Musl
# Build and install as cmlfs

# Configure source for cross build
./configure \
  CROSS_COMPILE=${CMLFS_TARGET}- \
  --prefix=/ \
  --target=${CMLFS_TARGET} 

# Build and install
make && DESTDIR=/cross-tools make install

# Add missing directory and link
mkdir -v /cross-tools/usr
ln -sv ../include  /cross-tools/usr/include

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
ln -sv ../lib/ld-musl-$ARCH.so.1 /cross-tools/bin/ldd

# Create config for dynamic library loading:
mkdir -v /cross-tools/etc
cat > /cross-tools/etc/ld-musl-$ARCH.path << "EOF"
/cross-tools/lib
/tools/lib
EOF

unset ARCH
```

00-cross-tools/04-GCC-final
```
# Cross-Tools: GCC Final
# Build and install as cmlfs

# Additional sources to add as GCC requires them 
tar -xf ../pkgs/mpfr-4.1.0.tar.xz
mv -v mpfr-4.1.0 mpfr
tar -xf ../pkgs/gmp-6.2.1.tar.xz
mv -v gmp-6.2.1 gmp
tar -xf ../pkgs/mpc-1.2.1.tar.gz
mv -v mpc-1.2.1 mpc

# Apply patches [from Alpine-linux]
or p in 0001-posix_memalign.patch \
        0002-gcc-poison-system-directories.patch \
        0003-Turn-on-Wl-z-relro-z-now-by-default.patch \
        0004-Turn-on-D_FORTIFY_SOURCE-2-by-default-for-C-C-ObjC-O.patch \
        0005-On-linux-targets-pass-as-needed-by-default-to-the-li.patch \
        0006-Enable-Wformat-and-Wformat-security-by-default.patch \
        0007-Enable-Wtrampolines-by-default.patch \
        0008-Disable-ssp-on-nostdlib-nodefaultlibs-and-ffreestand.patch \
        0009-Ensure-that-msgfmt-doesn-t-encounter-problems-during.patch \
        0010-Don-t-declare-asprintf-if-defined-as-a-macro.patch \
        0011-libiberty-copy-PIC-objects-during-build-process.patch \
        0012-libitm-disable-FORTIFY.patch \
        0013-libgcc_s.patch \
        0014-nopie.patch \
        0015-libffi-use-__linux__-instead-of-__gnu_linux__-for-mu.patch \
        0016-dlang-update-zlib-binding.patch \
        0017-dlang-fix-fcntl-on-mips-add-libucontext-dep.patch \
        0018-ada-fix-shared-linking.patch \
        0019-build-fix-CXXFLAGS_FOR_BUILD-passing.patch \
        0020-add-fortify-headers-paths.patch \
        0022-DP-Use-push-state-pop-state-for-gold-as-well-when-li.patch \
        0023-Pure-64-bit-MIPS.patch \
        0024-use-pure-64-bit-configuration-where-appropriate.patch \
        0025-always-build-libgcc_eh.a.patch \
        0026-ada-libgnarl-compatibility-for-musl.patch \
        0027-ada-musl-support-fixes.patch \
        0028-gcc-go-Use-_off_t-type-instead-of-_loff_t.patch \
        0029-gcc-go-Don-t-include-sys-user.h.patch \
        0030-gcc-go-Fix-ucontext_t-on-PPC64.patch \
        0031-gcc-go-Fix-handling-of-signal-34-on-musl.patch \
        0032-gcc-go-Use-int64-type-as-offset-argument-for-mmap.patch \
        0033-gcc-go-Fix-st_-a-m-c-tim-fields-in-generated-sysinfo.patch \
        0034-gcc-go-signal-34-is-special-on-musl-libc.patch \
        0035-gcc-go-Prefer-_off_t-over-_off64_t.patch \
        0036-gcc-go-undef-SETCONTEXT_CLOBBERS_TLS-in-proc.c.patch \
        0037-gcc-go-link-to-libucontext.patch \
        0038-gcc-go-Disable-printing-of-unaccessible-ppc64-struct.patch \
        0039-CRuntime_Musl-Support-v1.2.0-for-32-bits.patch \
        0040-configure-Add-enable-autolink-libatomic-use-in-LINK_.patch
do
        patch -Np1 -i ../patches/gcc-alpine-10.2.1p2/$p
done

case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac

# Configure in a dedicated build directory
mkdir build && cd  build
AR=ar LDFLAGS="-Wl,-rpath,/cross-tools/lib" \
../configure \
    --prefix=/cross-tools \
    --build=${CMLFS_HOST} \
    --host=${CMLFS_HOST} \
    --target=${CMLFS_TARGET} \
    --disable-multilib \
    --with-sysroot=/cross-tools \
    --disable-nls \
    --enable-shared \
    --enable-languages=c,c++ \
    --enable-threads=posix \
    --enable-clocale=generic \
    --enable-libstdcxx-time \
    --enable-fully-dynamic-string \
    --disable-symvers \
    --disable-libsanitizer \
    --disable-lto-plugin \
    --disable-libssp 

# Build
make AS_FOR_TARGET="${CMLFS_TARGET}-as" \
    LD_FOR_TARGET="${CMLFS_TARGET}-ld"

# Install
make install
```

00-cross-tools/05-File
```
# Cross-Tools: File
# Build and install as cmlfs

# Configure source
./configure --prefix=/cross-tools --disable-libseccomp

# Build and install
```

The patches can be found in the alpine aports repository at 
[repo](https://git.alpinelinux.org/aports/). From there you can download a tar ball 
or clone it. Look in the file called gcc and you'll see all the patch files. For brevity 
they will not be repeated here. All the patch files however are included in this 
commit inside the patches directory.


$ git add .
$ git commit -m "Adds cross-tools and Algine patches for gcc"
$ git push






$ git add .
$ git commit -m ""
$ git push