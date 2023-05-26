#!/bin/bash

if [ $# -lt 4 ]; then
    echo "This script is not intended to be called directly. Use the commands in ./b." >&2 && exit 1
fi
if [ "$M3_ISA" != "riscv" ]; then
    echo "Only supported on M3_ISA=riscv." >&2 && exit 1
fi

crossname="$1"
crossdir="$2"
command="$3"
shift 3

crossprefix="$crossdir/$crossname"
root=$(readlink -f "$(dirname "$(dirname "$0")")")
build="build/$M3_TARGET-$M3_ISA-$M3_BUILD"
lxbuild="build/linux"

build_bbl() {
    bblbuild="build/riscv-pk"
    mkdir -p "$bblbuild"

    args=("--with-mem-start=0x10003000")

    (
        cd "$bblbuild" \
            && RISCV="$crossdir/.." "$root/m3lx/riscv-pk/configure" \
                --host=riscv64-linux \
                "--with-payload=$root/$lxbuild/vmlinux" "${args[@]}" \
            && CFLAGS=" -D__riscv_compressed=1" make "-j$(nproc)" "$@"
    )
}

case "$command" in
    mklx)
        lxdeps="$root/m3lx"
        # for some weird reason, the path for O needs to be relative
        makeargs=("O=../../$lxbuild" "-j$(nproc)")
        mkdir -p "$lxbuild"

        export ARCH=riscv
        export CROSS_COMPILE="$crossname"

        # use our config, if not already present
        if [ ! -f "$lxbuild/.config" ]; then
            ( cd "$lxdeps/linux" && \
                make "${makeargs[@]}" defconfig "KBUILD_DEFCONFIG=sifive_defconfig" )
        fi

        if [ "$@" != "" ]; then
            ( cd "$lxdeps/linux" && make "${makeargs[@]}" "$@" ) || exit 1
        else
            ( cd "$lxdeps/linux" && make "${makeargs[@]}" ) || exit 1
        fi

        # bbl includes Linux
        build_bbl
        ;;

    mkbbl)
        build_bbl "$@"
        ;;

    mkrootfs)
        # copy binaries to overlay directory for buildroot and strip them
        mkdir -p "build/lxrootfs"
        for f in "$build"/lxbin/*; do
            "${crossprefix}strip" -o "build/lxrootfs/$(basename "$f")" "$f"
        done
        cp -a m3lx/rootfs/* build/lxrootfs

        # rebuild rootfs image
        if [ "$@" != "" ]; then
            ( cd cross && ./build.sh "$M3_ISA" "$@" )
        else
            ( cd cross && ./build.sh "$M3_ISA" )
        fi

        # now rebuild the dts to include the correct initrd size
        build_bbl
        ;;
esac
