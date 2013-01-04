#!/bin/bash   

# debugging: 
# set -x

PRODUCT_NAME="main"
ROOT=`pwd`
PLATFORM=`uname`
ARCH=`uname -m`
echo Building for $PLATFORM $ARCH from $ROOT

ALLOSYSTEMPATH="../../AlloSystem"

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
	
	luajit h2ffi.lua main.h header.lua 
}

function build {
	
	echo Building $PRODUCT_NAME
	
	SOURCES="*.cpp"
	
	if [[ $PLATFORM == 'Darwin' ]]; then
	
		INCLUDEPATHS="-I$ALLOSYSTEMPATH/build/include -I/usr/include/apr-1/ -I../externs/libuv/include -I/usr/local/opt/freetype/include"
		LINKERPATHS="-L$ALLOSYSTEMPATH/build/lib -L/usr/lib -L/opt/local/lib -L/usr/local/lib -L/usr/local/opt/freetype/lib"
		LIBRARIES="-lluajit-5.1 -lev -lassimp -lportaudio -lfreeimage -lapr-1 -lfreetype -laprutil-1 -force_load $ALLOSYSTEMPATH/build/lib/liballocore.a -force_load $ALLOSYSTEMPATH/build/lib/liballoutil.a"

		FRAMEWORKS="-framework Carbon -framework Cocoa -framework CoreAudio -framework GLUT -framework OpenGL -framework AudioUnit -framework AudioToolbox -framework CoreMidi"
		LINKERFLAGS="-w -rdynamic -pagezero_size 10000 -image_base 100000000 -keep_private_externs"

		g++ -c -x c++ -arch $ARCH -O3 -Wall -fno-stack-protector -DEV_MULTIPLICITY=1 $INCLUDEPATHS $SOURCES

		g++ *.o $LINKERFLAGS $LINKERPATHS $LIBRARIES $FRAMEWORKS -o $PRODUCT_NAME
		
	elif [[ $PLATFORM == 'Linux' ]]; then
	
		INCLUDEPATHS="-I$ALLOSYSTEMPATH/build/include -I/usr/local/include/luajit-2.0 -I/usr/include/luajit-2.0 -I/usr/include/apr-1.0/ -I../externs/libuv/include"
		LINKERPATHS="-L$ALLOSYSTEMPATH/build/lib -L/usr/local/lib -L/usr/lib -L/usr/lib/llvm-3.0/lib/ -L/usr/lib"
		LIBRARIES="-lalloutil -lallocore -lluajit-5.1 -lGLEW -lGLU -lGL -lglut -lassimp -lportaudio  -lasound -lfreeimage -lfreetype -lapr-1 -laprutil-1 -lrt -lpthread /usr/lib/libev.a"
		LINKERFLAGS="-w -rdynamic"

		g++ -c -O3 -Wall -fPIC -ffast-math -Wno-unknown-pragmas -MMD -DAPR_FAST_COMPAT -DAPR_STRICT -D_GNU_SOURCE -DEV_MULTIPLICITY=1 $INCLUDEPATHS $SOURCES

		g++ -Wl,-E $LINKERFLAGS $LINKERPATHS -Wl,-whole-archive *.o -Wl,-no-whole-archive -Wl,-E $LIBRARIES -o $PRODUCT_NAME

	else

		echo "unknown platform" $PLATFORM
	
	fi
}

function run {
	echo running $PRODUCT_NAME
	./$PRODUCT_NAME
	#node master.js
}

clean && generate_ffi_header && build && run


