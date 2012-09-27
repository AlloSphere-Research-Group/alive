var spawn = require('child_process').spawn;

var vm = undefined;

function launch() {

	vm = spawn('./alive');

	vm.stdout.on('data', function (data) {
		console.log('stdout: ' + data);
	});
	vm.stderr.on('data', function (data) {
		console.log('stderr: ' + data);
	});

	vm.on('exit', function (code) {
		console.log('child process exited with code ' + code);
		
		// relaunch:
		//vm = launch();
	});
}

launch();

var fs 		= require('fs');
var path 	= require('path');
var io_in 	= require('socket.io').listen(8083);
var exec 	= require('child_process').exec;
var io	 	= require('socket.io-client');

var currentDir 	= __dirname;

// ideally zeroconf...
var MASTER_ADDRESS 	= "127.0.0.1:8082";

var master = io.connect(MASTER_ADDRESS);

master.on('connect', function(){ console.log("Connected to Master"); });

master.on('message', function(msg){ console.log("Recieved a message: " + msg); });

master.on('disconnect', function(){ console.log("Disconnected from Master"); });

master.on('pull', function(obj) {
	exec("git pull origin master", {cwd: currentDir}, function() { console.log("MADE A PULL!"); } );
});
