#!/usr/bin/env bash
set -e

readonly BUILD_DIR="${1}"
readonly PLUGIN_VERSION="2023.06.05"
readonly OUTPUT_DIR="/output/pkg"
readonly TARGET_KERNEL="${2:-"6.1.34-Unraid"}"
readonly BZROOT="/usr/src/stock/${UNRAID_VERSION}/root"
readonly PKG_BASE="/ite"
readonly PLUGIN_NAME="asustor-it87-driver"

function clean(){
    # Clean Package Base
    rm -rfv "${PKG_BASE}"
    mkdir -p "${PKG_BASE}"
}

function build_module(){
    CPU_COUNT="${CPU_COUNT:-all}"

    ## Set build variables
    if [ "$CPU_COUNT" == "all" ];then
        export CPU_COUNT="$(grep -c ^processor /proc/cpuinfo)"
        echo "Setting compile cores to $CPU_COUNT"
    else
        echo "Setting compile cores to $CPU_COUNT"
    fi

    # Compile module and copy it over to destination
    make -j${CPU_COUNT} TARGET="${TARGET_KERNEL}"

    # Run make install with noop depmod (dummy)
    PATH="${BUILD_DIR}/dummy:${PATH}" make install -j${CPU_COUNT} KERNEL_MODULES="${PKG_BASE}/lib/modules/${TARGET_KERNEL}"
}

function compress_module(){
    # Compress module
    while read -r line
    do
        xz --check=crc32 --lzma2 $line
    done < <(find "${PKG_BASE}/lib/modules/${TARGET_KERNEL}/" -name "*.ko")
}

function build_package(){
    mkdir -p "${OUTPUT_DIR}"
    # Download icon
    cd ${DATA_DIR}
    mkdir -p "${PKG_BASE}/usr/local/emhttp/plugins/${PLUGIN_NAME}/images"
    wget -O "${PKG_BASE}/usr/local/emhttp/plugins/${PLUGIN_NAME}/images/${PLUGIN_NAME}.png" "https://raw.githubusercontent.com/mrmstn/unraid-asustor-it87-driver/master/${PLUGIN_NAME}.png"

    # Create Slackware Package
    TMP_DIR="/tmp/${PLUGIN_NAME}_"$(echo $RANDOM)""
    VERSION="$(date +'%Y.%m.%d')"

    mkdir -p $TMP_DIR/$VERSION
    cd $TMP_DIR/$VERSION
    cp -R ${PKG_BASE}/* $TMP_DIR/$VERSION/
    mkdir $TMP_DIR/$VERSION/install
tee $TMP_DIR/$VERSION/install/slack-desc <<EOF
       |-----handy-ruler------------------------------------------------------|
$PLUGIN_NAME: $PLUGIN_NAME
$PLUGIN_NAME:
$PLUGIN_NAME:
$PLUGIN_NAME: Custom $PLUGIN_NAME package for Unraid Kernel v${TARGET_KERNEL%%-*}
$PLUGIN_NAME: Source: https://github.com/mafredri/asustor-platform-driver.git
$PLUGIN_NAME:
EOF
    "${BZROOT}/sbin/makepkg" -l n -c n $OUTPUT_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$TARGET_KERNEL-1.txz
    md5sum $OUTPUT_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$TARGET_KERNEL-1.txz | awk '{print $1}' > $OUTPUT_DIR/$PLUGIN_NAME-$PLUGIN_VERSION-$TARGET_KERNEL-1.txz.md5
}

function main(){
    cd "${BUILD_DIR}"
    clean
    build_module
    compress_module
    build_package
}

main