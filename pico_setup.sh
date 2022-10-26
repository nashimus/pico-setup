#!/bin/bash

# Exit on error
set -e

# Number of cores when running make
JNUM=$(lscpu | grep "^CPU(s):" | sed 's/^CPU(s):\ *//g')
echo "Detected $JNUM logical CPUs. Building with -j$JNUM".

# Where will the output go?
OUTDIR="$HOME/pico"

# Install dependencies
GIT_DEPS="git"
SDK_DEPS="cmake cross-arm-none-eabi-gcc gcc cross-arm-none-eabi-newlib cross-arm-none-eabi-libstdc++"
OPENOCD_DEPS="cross-arm-none-eabi-gdb automake autoconf texinfo libtool libftdi1-devel libusb-devel"

# Build full list of dependencies
DEPS="$GIT_DEPS $SDK_DEPS"

if [[ "$SKIP_OPENOCD" == 1 ]]; then
    echo "Skipping OpenOCD (debug support)"
else
    DEPS="$DEPS $OPENOCD_DEPS"
fi

echo "Installing Dependencies"
sudo xbps-install -Syu $DEPS

echo "Creating $OUTDIR"
# Create pico directory to put everything in
mkdir -p $OUTDIR
cd $OUTDIR

# Clone sw repos
GITHUB_PREFIX="https://github.com/raspberrypi/"
GITHUB_SUFFIX=".git"
SDK_BRANCH="master"

for REPO in sdk examples extras playground
do
    DEST="$OUTDIR/pico-$REPO"

    #rm -rf $DEST # clean up

    if [ -d $DEST ]; then
        echo "$DEST already exists so skipping"
    else
        REPO_URL="${GITHUB_PREFIX}pico-${REPO}${GITHUB_SUFFIX}"
        echo "Cloning $REPO_URL"
        git clone -b $SDK_BRANCH $REPO_URL

        # Any submodules
        cd $DEST
        git submodule update --init
        cd $OUTDIR

        # Define PICO_SDK_PATH in ~/.bashrc
        VARNAME="PICO_${REPO^^}_PATH"
        echo "Adding $VARNAME to ~/.bashrc"
        echo "export $VARNAME=$DEST" >> ~/.bashrc
        export ${VARNAME}=$DEST
    fi
done

cd $OUTDIR

# Pick up new variables we just defined
source ~/.bashrc

# Build a couple of examples
cd "$OUTDIR/pico-examples"
mkdir build
cd build
cmake ../ -DCMAKE_BUILD_TYPE=Debug

for e in blink hello_world
do
    echo "Building $e"
    cd $e
    make -j$JNUM
    cd ..
done

cd $OUTDIR

# Picoprobe and picotool
for REPO in picoprobe picotool
do
    DEST="$OUTDIR/$REPO"
    #rm -rf $DEST # clean up
    REPO_URL="${GITHUB_PREFIX}${REPO}${GITHUB_SUFFIX}"
    git clone $REPO_URL

    # Build both
    cd $DEST
    mkdir build
    cd build
    cmake ../
    make -j$JNUM

    if [[ "$REPO" == "picotool" ]]; then
        echo "Installing picotool to /usr/local/bin/picotool"
        sudo cp picotool /usr/local/bin/
    fi

    cd $OUTDIR
done

if [ -d openocd ]; then
    echo "openocd already exists so skipping"
    SKIP_OPENOCD=1
fi

if [[ "$SKIP_OPENOCD" == 1 ]]; then
    echo "Won't build OpenOCD"
else
    # Build OpenOCD
    echo "Building OpenOCD"
    cd $OUTDIR
    # Should we include picoprobe support (which is a Pico acting as a debugger for another Pico)
    INCLUDE_PICOPROBE=1
    OPENOCD_BRANCH="rp2040"
    OPENOCD_CONFIGURE_ARGS="--enable-ftdi --enable-sysfsgpio --enable-bcm2835gpio"
    if [[ "$INCLUDE_PICOPROBE" == 1 ]]; then
        OPENOCD_CONFIGURE_ARGS="$OPENOCD_CONFIGURE_ARGS --enable-picoprobe"
    fi

    git clone "${GITHUB_PREFIX}openocd${GITHUB_SUFFIX}" -b $OPENOCD_BRANCH --depth=1
    cd openocd
    ./bootstrap
    ./configure $OPENOCD_CONFIGURE_ARGS
    make -j$JNUM
    #sudo make install

    if [ -f /etc/udev/rules.d/60-openocd.rules ]; then
        echo "openocd udev rules exist, skipping"
    else
        echo "generating openocd udev rules"
        sudo tee /etc/udev/rules.d/60-openocd.rules &>/dev/null <<EOF
    # Raspberry Pi Picoprobe
    ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="0004", MODE="660", GROUP="plugdev", TAG+="uaccess"
    EOF
    fi
fi

cd $OUTDIR

# Liam needed to install these to get it working
if [[ "$SKIP_VSCODE" == 1 ]]; then
    echo "Won't include VSCODE"
else
    echo "Installing VSCODE"
    sudo xbps-install -Syu vscode

    # Get extensions
    code-oss --install-extension marus25.cortex-debug
    code-oss --install-extension ms-vscode.cmake-tools
    code-oss --install-extension ms-vscode.cpptools
fi
