#!/bin/bash
# fetch and build arm-none-eabi-gdb
version=12.1

# exit on error
set -e

# auto set job number
JNUM=$(lscpu | grep "^CPU(s):" | sed 's/^CPU(s):\ *//g')
echo "Detected $JNUM logical CPUs. Building with -j$JNUM".

extracted="gdb-${version}"
tarball="gdb-${version}.tar.xz"
if [ ! -f $tarball ]; then
    wget "https://ftp.gnu.org/gnu/gdb/${tarball}"
fi
checksum="0e1793bf8f2b54d53f46dea84ccfd446f48f81b297b28c4f7fc017b818d69fed"
echo "${checksum} ${tarball}" | sha256sum -c
rm -rf $extracted
tar xvf $tarball

# mpfr is necessary to emulate target floating point behavior
# babeltrace is necessary for Common Trace Format support
makedepends=" \
expat-devel \
gmp-devel \
libbabeltrace-devel \
mpfr-devel \
ncurses-devel \
readline-devel \
zlib-devel"

sudo dnf install -y $makedepends

configure_args=" \
--target=arm-none-eabi \
--disable-werror \
--disable-nls \
--with-system-readline \
--with-system-gdbinit=/etc/gdb/gdbinit \
--with-system-zlib \
--without-isl"

cd gdb-$version
./configure $configure_args

make -j$JNUM

cd ..
cp $extracted/gdb/gdb arm-none-eabi-gdb
rm -rf $extracted

