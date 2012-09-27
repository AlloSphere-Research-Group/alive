var spawn = require('child_process').spawn;

var vm = undefined;

function launch() {

	if (vm != undefined) {
		vm.kill();
		//vm.disconnect();
	}
	
	vm = spawn('./alive');

	vm.stdout.on('data', function (data) {
		console.log('stdout: ' + data);
	});
	vm.stderr.on('data', function (data) {
		console.log('stderr: ' + data);
	});

	vm.on('exit', function (code) {
		console.log('child process exited with code ' + code);
		
		// relaunch?:
		//vm = launch();
		//vm = undefined;
	});
}

launch();

process.on('exit', function() {
	if (vm != undefined) {
		vm.kill();
	}
});

var fs 		= require('fs');
var path 	= require('path');
var io_in 	= require('socket.io').listen(8083);
var exec 	= require('child_process').exec;
var io	 	= require('socket.io-client');
var mdns 	= require('mdns');

var currentDir 	= __dirname;
var MASTER_ADDRESS 	= null; //"127.0.0.1:8082";
var master = null;

var browser = mdns.createBrowser(mdns.tcp('master'));

var pullNumber = 0;

var connectMaster = function(service) {
   if(master === null) {
  	  console.log("service up: ", service);
  	  master = io.connect(service.host+":8082");

  	  master.on('connect', function(){ console.log("Connected to Master");  browser.on('serviceUp', function() {}); } );

  	  master.on('message', function(msg){ console.log("Recieved a message: " + msg); });

  	  master.on('disconnect', function(){ console.log("Disconnected from Master"); browser.on('serviceUp', connectMaster); master.disconnect(); master = null; });

  	  master.on('pull', function(obj) {
  		if(pullNumber <= obj.number) {
  	  	  exec("git pull origin master", {cwd: currentDir}, function() { console.log("MADE A PULL!"); } );
  		  if (vm != undefined) vm.kill();
  		  launch();
  		  pullNumber++;
  	    }
  	  });
    }
}

browser.on('serviceUp', connectMaster);

browser.on('serviceDown', function(service) {
  console.log("service down: ", service);
  if(master !== null) {
	  master.disconnect();
	  master = null;
  }
});
browser.start();

