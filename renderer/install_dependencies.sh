#!/bin/bash  

PRODUCT_NAME="alive"
ROOT=`pwd`
PLATFORM=`uname`
ARCH=`uname -m`
echo Installing dependencies for $PLATFORM $ARCH from $ROOT

if [[ $PLATFORM == 'Darwin' ]]; then

	echo install node.js
	#sudo PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" npm install zmq -g
	

elif [[ $PLATFORM == 'Linux' ]]; then

	sudo apt-get install nodejs
	sudo apt-get install libavahi-compat-libndssd-dev
	
fi

npm install socket.io
npm install socket.io-client
npm install mime
npm install mdns
