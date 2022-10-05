# Prequisites
# Required for host:
# cmake
# ninja
# python3 (linked as 'python' if python2 not installed)
# wget (
# Base Development tools
#  o GCC
#  o Kernel Headers
#  0 make
#  0 ... (if distro is MLFS/LFS, then all development packages are installed)
# Create a directory to hold sources and stage area, as root:
mkdir -pv /mnt/cmlfs
export CMLFS=/mnt/cmlfs
# Create directories to build clang with GCC libraries (cgnutools) 
# and the final toolchain without GCC libraries. As root, Link them
# to host's root directory:
mkdir -v $CMLFS/cgnutools
mkdir -v $CMLFS/llvmtools
ln -sv   $CMLFS/cgnutools /
ln -sv   $CMLFS/llvmtools /
# As root, create directories to hold patches, files, packages, 
# and build area:
mkdir -pv $CMLFS/sources/{patches,files,pkgs}
# Download sources. Provided list can be used with wget:
wget --input-file=source.list --continue --directory-prefix=$CMLFS/sources/pkgs
# Create user and group:
# As root, change ownership to allow installation of tools
groupadd cmlfs
useradd -s /bin/bash -g cmlfs -m -k /dev/null cmlfs
passwd cmlfs
chown -v  cmlfs $CMLFS/cgnutools
chown -v  cmlfs $CMLFS/llvmtools
chown -vR cmlfs $CMLFS/sources
chmod -v  a+wt  $CMLFS/sources
# Now run as cmlfs user. All toolchain software should be built 
# as this user, unless specified.
su - cmlfs
# Set up the environment.
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\n\$ ' /bin/bash
EOF
cat > ~/.bashrc << "EOF"
set +h
umask 022
CMLFS=/mnt/cmlfs
LC_ALL=POSIX
PATH=/cgnutools/bin:/llvmtools/bin:/bin:/usr/bin
export CMLFS LC_ALL PATH
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
export LLVMSRC="/mnt/cmlfs/sources/llvm-project-llvmorg-11.0.0"
EOF
export CMLFS_TARGET="x86_64-cmlfs-linux-musl"
export CMLFS_ARCH="x86"
export CMLFS_CPU="x86-64"
export MLFS_HOST="$(echo $MACHTYPE | \
    sed "s/$(echo $MACHTYPE | cut -d- -f2)/cross/")"
cat >> ~/.bashrc << EOF
export CMLFS_HOST="${CMLFS_HOST}"
export CMLFS_TARGET="${CMLFS_TARGET}"
export CMLFS_ARCH="${CMLFS_ARCH}"
export CMLFS_CPU="${CMLFS_CPU}"
EOF
source ~/.bashrc
ew file
-cgnutools/1-libunwind
cd libunwind  
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
