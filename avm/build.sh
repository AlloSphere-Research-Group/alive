#!/bin/bash   

# debugging: 
# set -x

PRODUCT_NAME="avm"
ROOT=`pwd`
PLATFORM=`uname`
ARCH=`uname -m`
echo Building for $PLATFORM $ARCH from $ROOT

ALLOSYSTEMPATH="../../AlloSystem"
function allosystem {
	echo Building AlloSystem from $ALLOSYSTEMPATH
	cd $ALLOSYSTEMPATH
	make allocore -j8
	make alloutil -j8
	cd $ROOT
}

function clean {
	echo Cleaning
	rm -rf build
	rm -f $PRODUCT_NAME
	rm -f *.o
	rm -f *.d
}

function generate_ffi_header {
	
	# make the ffi header:
	echo Making FFI header
	
	luajit h2ffi.lua alive.h ffi/aliveheader.lua 
}

function build {
	
	SOURCES="*.cpp"
	
	echo Building
	if [[ $PLATFORM == 'Darwin' ]]; then
	
		INCLUDEPATHS="-I../externs/libuv/include"
		LINKERPATHS="-L$ALLOSYSTEMPATH/build/lib -L/usr/lib"
		LIBRARIES="-lluajit-5.1 -lportaudio -force_load ../externs/libuv/uv.a"
		FRAMEWORKS="-framework Carbon -framework Cocoa -framework CoreAudio -framework GLUT -framework OpenGL -framework AudioUnit -framework AudioToolbox -framework CoreMidi"
		LINKERFLAGS="-w -rdynamic -pagezero_size 10000 -image_base 100000000 -keep_private_externs"

		g++ -c -x c++ -arch $ARCH -O3 -Wall -fno-stack-protector -DEV_MULTIPLICITY=1 $INCLUDEPATHS $SOURCES

		g++ *.o $LINKERFLAGS $LINKERPATHS $LIBRARIES $FRAMEWORKS -o $PRODUCT_NAME
		
	elif [[ $PLATFORM == 'Linux' ]]; then
	
		INCLUDEPATHS="-I/usr/local/include/luajit-2.0 -I/usr/include/luajit-2.0 -I../externs/libuv/include"
		LINKERPATHS="-L/usr/local/lib -L/usr/lib"
		LIBRARIES="-lluajit-5.1 -lGLEW -lGLU -lGL -lglut -lportaudio -lasound ../externs/libuv/libuv.a -lrt -lpthread"
		LINKERFLAGS="-w -rdynamic"

		g++ -c -O3 -Wall -fPIC -ffast-math -Wno-unknown-pragmas -MMD -DAPR_FAST_COMPAT -DAPR_STRICT -D_GNU_SOURCE -DEV_MULTIPLICITY=1 $INCLUDEPATHS $SOURCES

		g++ $LINKERFLAGS $LINKERPATHS -Wl,-whole-archive *.o -Wl,-no-whole-archive $LIBRARIES -o $PRODUCT_NAME

	else

		echo "unknown platform" $PLATFORM
	
	fi
}


clean
#allosystem
#generate_ffi_header
build



