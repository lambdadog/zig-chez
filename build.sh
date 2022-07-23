#!/bin/sh

gnumake=$1
zigtarget=$2
cheztarget=$3

build_dir="$(pwd)"

build_uuid () {
    cd ossp-uuid;
    mkdir -p include/ossp
    mkdir -p fakepath

    # Cursed workaround to get libtool to use zig cc
    #
    # There may be a better way to do this, but I don't know it.
    echo "#!/bin/sh" > fakepath/gcc
    echo "exec zig cc -target ${zigtarget}" '$@' >> fakepath/gcc
    chmod +x fakepath/gcc
    echo "#!/bin/sh" > fakepath/ar
    echo "exec zig ar" '$@' >> fakepath/ar
    chmod +x fakepath/ar
    echo "#!/bin/sh" > fakepath/ranlib
    echo "exec zig ranlib" '$@' >> fakepath/ranlib
    chmod +x fakepath/ranlib

    PATH="$PWD/fakepath:$PATH" ./configure --disable-shared --enable-static --disable-libtool-lock
    PATH="$PWD/fakepath:$PATH" "${gnumake}" libuuid.la
    cp --force uuid.h include/ossp/uuid.h
    cp .libs/libuuid.a "${build_dir}/out"
    cd "${build_dir}"
}

build_chez () {
    cd ChezScheme
    ./configure \
	-m=${cheztarget} \
	--threads \
	--disable-x11 \
	--disable-curses \
	--kernelobj
    # TODO: replace once we can build for more than linux
    sed -e 's/TARGET_OS ?= $(shell uname)/TARGET_OS = Linux/' --in-place lz4/Makefile.inc
    cd ${cheztarget}/c
    "${gnumake}" \
	CC="zig cc -target ${zigtarget} -DUSE_OSSP_UUID -I\"${build_dir}/ossp-uuid/include\"" \
	AR="zig ar" \
	RANLIB="zig ranlib" \
	../boot/${cheztarget}/kernel.o
    cp ../boot/${cheztarget}/kernel.o "${build_dir}/out"
    cp ../boot/${cheztarget}/petite.boot "${build_dir}/out"
    cp ../boot/${cheztarget}/scheme.boot "${build_dir}/out"
    cp ../boot/${cheztarget}/scheme.h "${build_dir}/out"
    cd "${build_dir}"
}

build_uuid
build_chez
