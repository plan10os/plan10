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
mkdir -pv /mnt/plan10
export PLAN10=/mnt/plan10

# Create directories to build clang with GCC libraries (cgnutools) 
# and the final toolchain without GCC libraries. As root, Link them
# to host's root directory:
mkdir -v $PLAN10/cgnutools
mkdir -v $PLAN10/llvmtools
ln -sv   $PLAN10/cgnutools /
ln -sv   $PLAN10/llvmtools /

# As root, create directories to hold patches, files, packages, 
# and build area:
mkdir -pv $PLAN10/sources/{patches,files,pkgsrc,src}

# Download sources. Provided list can be used with wget:
wget --input-file=source.list --continue --directory-prefix=$PLAN10/sources/src
# or use the download_sources.sh script if you have only cURL ;^]
#./download_sources.sh sources.list sources.md5

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
PATH=/cctools/bin:/cgnutools/bin:/llvmtools/bin:/bin:/usr/bin
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
export LLVMSRC="/mnt/plan10/sources/llvm"
EOF

export PLAN10_TARGET="x86_64-plan10-linux-musl" \
    TARGET_TUPLE="x86_64-pc-linux-musl" \
    PLAN10_ARCH="x86" \
    PLAN10_CPU="x86-64" \
    PLAN10_HOST="$(echo $MACHTYPE | \
        sed "s/$(echo $MACHTYPE | cut -d- -f2)/cctools/")"

cat >> ~/.bashrc << EOF
export PLAN10_HOST="${PLAN10_HOST}" \
    PLAN10_TARGET="${PLAN10_TARGET}" \
    PLAN10_ARCH="${PLAN10_ARCH}" \
    PLAN10_CPU="${PLAN10_CPU}" \
    TARGET_TUPLE="${TARGET_TUPLE}"
EOF

source ~/.bashrc