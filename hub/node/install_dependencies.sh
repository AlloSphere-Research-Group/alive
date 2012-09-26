#!/bin/bash  

PRODUCT_NAME="alive"
ROOT=`pwd`
PLATFORM=`uname`
ARCH=`uname -m`
echo Installing dependencies for $PLATFORM $ARCH from $ROOT

if [[ $PLATFORM == 'Darwin' ]]; then

	echo install node.js
	# sudo PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" npm install zmq -g
	

elif [[ $PLATFORM == 'Linux' ]]; then

	sudo apt-get install pkg-config
	sudo ldconfig
	
	# nodejs package is too old in ubuntu 12.04:
	#sudo apt-get install nodejs
	# get it this way instead:
	sudo apt-get install python-software-properties
	sudo add-apt-repository ppa:chris-lea/node.js
	sudo apt-get update
	sudo apt-get install nodejs npm
	sudo apt-get install libzmq-dev
	npm install zmq
	
fi

npm install socket.io
npm install socket.io-client
npm install mime
