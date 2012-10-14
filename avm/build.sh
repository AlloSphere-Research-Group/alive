#!/bin/bash   

# debugging: 
# set -x

PRODUCT_NAME="avm"
ROOT=`pwd`
PLATFORM=`uname`
ARCH=`uname -m`
echo Building for $PLATFORM $ARCH from $ROOT

function clean {
	echo Cleaning
	rm -rf build
	rm -f $PRODUCT_NAME
	rm -f *.o
	rm -f *.d
}

function generate_ffi_header {
	echo Making FFI header
	luajit h2ffi.lua avm.h modules/avm/header.lua 
}

function build {
	
	SOURCES="*.cpp rtaudio-4.0.11/RtAudio.cpp"
	
	echo Building
	if [[ $PLATFORM == 'Darwin' ]]; then
	
		INCLUDEPATHS="-I../externs/libuv/include -Irtaudio-4.0.11"
		LINKERPATHS="-L$ALLOSYSTEMPATH/build/lib -L/usr/lib"
		LIBRARIES="-lluajit-5.1 -force_load ../externs/libuv/uv.a"
		FRAMEWORKS="-framework Carbon -framework CoreAudio -framework GLUT -framework OpenGL"
		LINKERFLAGS="-w -rdynamic -pagezero_size 10000 -image_base 100000000 -keep_private_externs"

		g++ -c -x c++ -arch $ARCH -O3 -Wall -fno-stack-protector -DEV_MULTIPLICITY=1 -DHAVE_GETTIMEOFDAY -D__MACOSX_CORE__ $INCLUDEPATHS $SOURCES

		g++ *.o $LINKERFLAGS $LINKERPATHS $LIBRARIES $FRAMEWORKS -o $PRODUCT_NAME
		
	elif [[ $PLATFORM == 'Linux' ]]; then
	
		INCLUDEPATHS="-I/usr/local/include/luajit-2.0 -I/usr/include/luajit-2.0 -I../externs/libuv/include  -Irtaudio-4.0.11"
		LINKERPATHS="-L/usr/local/lib -L/usr/lib"
		LIBRARIES="-lluajit-5.1 -lGLEW -lGLU -lGL -lglut -lasound ../externs/libuv/libuv.a -lrt -lpthread"
		LINKERFLAGS="-w -rdynamic"

		g++ -c -O3 -Wall -fPIC -ffast-math -Wno-unknown-pragmas -MMD -DAPR_FAST_COMPAT -DAPR_STRICT -D_GNU_SOURCE -DEV_MULTIPLICITY=1 -DHAVE_GETTIMEOFDAY -D__LINUX_ALSA__ $INCLUDEPATHS $SOURCES

		g++ $LINKERFLAGS $LINKERPATHS -Wl,-whole-archive *.o -Wl,-no-whole-archive $LIBRARIES -o $PRODUCT_NAME

	else

		echo "unknown platform" $PLATFORM
	
	fi
}


clean
generate_ffi_header
build



