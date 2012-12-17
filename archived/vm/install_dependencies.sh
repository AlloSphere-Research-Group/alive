#!/bin/bash  

PRODUCT_NAME="alive"
ROOT=`pwd`
PLATFORM=`uname`
ARCH=`uname -m`
echo Installing dependencies for $PLATFORM $ARCH from $ROOT

mkdir -p ../externs

if [[ $PLATFORM == 'Darwin' ]]; then

	echo TODO: install node.js

elif [[ $PLATFORM == 'Linux' ]]; then

	sudo apt-get install libavahi-compat-libdnssd-dev luarocks
	sudo luarocks install luafilesystem
	
fi


# grab a couple of external dependencies this way:
cd ../
git submodule init && git submodule update

cd $ROOT/modules/luaclang
./lake
sudo ./lake install

cd $ROOT/modules/luaosc
./lake
sudo ./lake install

cd $ROOT
npm install socket.io
npm install socket.io-client
npm install mdns

cd $ROOT/../externs
git clone git://github.com/joyent/libuv.git
cd libuv
make

cd $ROOT
