#!/bin/bash  

if [[ $PLATFORM == 'Darwin' ]]; then

	echo install node.js

elif [[ $PLATFORM == 'Linux' ]]; then

	sudo apt-get install nodejs
	
fi

npm install socket.io
npm install socket.io-client
npm install mime
