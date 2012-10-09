#!/bin/bash   

# debugging: 
# set -x

PRODUCT_NAME="alive"
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

LLVMLIBS="-lLLVMRuntimeDyld -lLLVMObject -lLLVMLinker -lLLVMipo -lLLVMJIT -lLLVMExecutionEngine -lLLVMDebugInfo -lLLVMBitWriter -lLLVMX86Disassembler -lLLVMX86AsmParser -lLLVMX86CodeGen -lLLVMX86Desc -lLLVMX86AsmPrinter -lLLVMX86Utils -lLLVMX86Info -lLLVMArchive -lLLVMBitReader -lLLVMSelectionDAG -lLLVMAsmPrinter -lLLVMMCParser -lLLVMCodeGen -lLLVMScalarOpts -lLLVMInstCombine -lLLVMTransformUtils -lLLVMipa -lLLVMAnalysis -lLLVMTarget -lLLVMCore -lLLVMMC -lLLVMSupport"

function build {
	
	#SOURCES="al_ffi.cpp alive.cpp"
	SOURCES="uvtest.cpp"
	#SOURCES="test.cpp"
	
	echo Building
	if [[ $PLATFORM == 'Darwin' ]]; then
	
		INCLUDEPATHS="-I$ALLOSYSTEMPATH/build/include -I/usr/include/apr-1/ -Iexterns/libuv/include"
		LINKERPATHS="-L$ALLOSYSTEMPATH/build/lib -L/usr/lib"
		LIBRARIES="-lluajit-5.1 -lassimp -lportaudio -lfreeimage -lfreetype -lapr-1 -laprutil-1 -force_load $ALLOSYSTEMPATH/build/lib/liballocore.a -force_load $ALLOSYSTEMPATH/build/lib/liballoutil.a -force_load externs/libuv/uv.a"
		FRAMEWORKS="-framework Carbon -framework Cocoa -framework CoreAudio -framework GLUT -framework OpenGL -framework AudioUnit -framework AudioToolbox -framework CoreMidi"
		LINKERFLAGS="-w -rdynamic -pagezero_size 10000 -image_base 100000000 -keep_private_externs"

		g++ -c -x c++ -arch $ARCH -O3 -Wall -fno-stack-protector -DEV_MULTIPLICITY=1 $INCLUDEPATHS $SOURCES

		g++ *.o $LINKERFLAGS $LINKERPATHS $LIBRARIES $FRAMEWORKS -o $PRODUCT_NAME
		
	elif [[ $PLATFORM == 'Linux' ]]; then
	
		INCLUDEPATHS="-I$ALLOSYSTEMPATH/build/include -I/usr/local/include/luajit-2.0 -I/usr/include/luajit-2.0 -I/usr/include/apr-1.0/ -Iexterns/libuv/include"
		LINKERPATHS="-L$ALLOSYSTEMPATH/build/lib -L/usr/local/lib -L/usr/lib -L/usr/lib/llvm-3.0/lib/ -L/usr/lib"
		LIBRARIES="-lallocore -lalloutil -lluajit-5.1 -lGLEW -lGLU -lGL -lglut -lassimp -lportaudio  -lasound -lfreeimage -lfreetype -lapr-1 -laprutil-1 externs/libuv/uv.a -lrt -lpthread"
		LINKERFLAGS="-w -rdynamic"

		g++ -c -O3 -Wall -fPIC -ffast-math -Wno-unknown-pragmas -MMD -DAPR_FAST_COMPAT -DAPR_STRICT -D_GNU_SOURCE -DEV_MULTIPLICITY=1 $INCLUDEPATHS $SOURCES

		g++ $LINKERFLAGS $LINKERPATHS -Wl,-whole-archive *.o -Wl,-no-whole-archive $LIBRARIES -o $PRODUCT_NAME

	else

		echo "unknown platform" $PLATFORM
	
	fi
}


clean
allosystem
generate_ffi_header
build



