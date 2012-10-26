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
	echo Building
	
	CC="g++"
	SOURCES="*.cpp rtaudio-4.0.11/RtAudio.cpp"
	
	if [[ $PLATFORM == 'Darwin' ]]; then
	
		CFLAGS="-x c++ -arch $ARCH -O3 -Wall -fno-stack-protector"
		DEFINES="-DEV_MULTIPLICITY=1 -DHAVE_GETTIMEOFDAY -D__MACOSX_CORE__"
		INCLUDEPATHS="-I../externs/libuv/include -Irtaudio-4.0.11"
		
		LDFLAGS="-w -rdynamic -pagezero_size 10000 -image_base 100000000 -keep_private_externs"
		LINKERPATHS="-L$ALLOSYSTEMPATH/build/lib -L/usr/lib"
		LIBRARIES="-lluajit-5.1 -lfreeimage -force_load ../externs/libuv/uv.a"
		FRAMEWORKS="-framework Carbon -framework Cocoa -framework OpenGL -framework GLUT -framework CoreAudio"
		
		$CC -c $CFLAGS $DEFINES $INCLUDEPATHS $SOURCES

		$CC $LDFLAGS $LINKERPATHS *.o $LIBRARIES $FRAMEWORKS -o $PRODUCT_NAME
		
	elif [[ $PLATFORM == 'Linux' ]]; then
	
		CFLAGS="-O3 -Wall -fPIC -ffast-math -Wno-unknown-pragmas -MMD"
		DEFINES="-DAPR_FAST_COMPAT -DAPR_STRICT -D_GNU_SOURCE -DEV_MULTIPLICITY=1 -DHAVE_GETTIMEOFDAY -D__LINUX_ALSA__"
		INCLUDEPATHS="-I/usr/local/include/luajit-2.0 -I/usr/include/luajit-2.0 -I../externs/libuv/include -Irtaudio-4.0.11"
		
		LDFLAGS="-w -rdynamic"
		LINKERPATHS="-L/usr/local/lib -L/usr/lib"
		LIBRARIES="-lluajit-5.1 -lfreeimage -lGLEW -lGLU -lGL -lglut -lasound ../externs/libuv/libuv.a -lrt -lpthread"
		
		$CC -c $CFLAGS $DEFINES $INCLUDEPATHS $SOURCES

		$CC $LDFLAGS $LINKERPATHS -Wl,-whole-archive *.o -Wl,-no-whole-archive $LIBRARIES -o $PRODUCT_NAME

	else

		echo "unknown platform" $PLATFORM
	
	fi
}

function install {
	echo Installing
	
	# .so libraries go into /usr/local/lib/lua/5.1/
	# .lua modules go into /usr/local/share/lua/5.1/
	
	#echo Creating symlink in /usr/local/bin
	#sudo ln -svhf $ROOT/$PRODUCT_NAME /usr/local/bin/$PRODUCT_NAME
}

clean
generate_ffi_header && build && install



