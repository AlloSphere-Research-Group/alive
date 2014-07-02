/*
	Execute with Node.js
*/

var fs 			= require('fs');
var http 		= require('http');
var url 		= require('url');
var dns			= require('dns');
var os			= require('os');
var net			= require('net');
var util		= require('util');
var path		= require('path');
var exec		= require('child_process').exec;
var spawn		= require('child_process').spawn;

/*
var mime 		= require('mime');
var mdns 		= require('mdns');
var connect 	= require('connect');
var sharejs 	= require('share').server;
*/

var hostname = os.hostname();
// argv[2] is the master name. 
// if no master name is given, assume current machine is the master.
var mastername = process.argv[2] || hostname;

//// THE VM CHILD PROCESS ////
var vm_auto_relaunch = false;
var vm = null;

function vm_launch() {	
	// make sure it is not already running:
	if (vm !== null) { vm.kill(); }
	// run:
	vm = spawn("luajit", ["alive.lua", mastername]);
	// also pipe stdout/stderr back to node's console:
	vm.stdout.pipe(process.stdout, { end: false });
	vm.stderr.pipe(process.stderr, { end: false });

	vm.stdout.on('data', function (text) {
		//fs.writeSync(1, text);
		//console.log("SENDING STDOUT MESSAGE", text.toString);
		/*
		for(var key in editors) {
			editors[key].emit("console", { "msg" : text.toString() } );
		}
		*/
	});
  
	
	vm.stderr.on('data', function (text) {
		//fs.writeSync(2, 'err:' + text);
		//console.log("SENDING STDERR MESSAGE", text.toString);
		/*
		for(var key in editors) {
			editors[key].emit("err", { "msg" : text.toString()  } );
		}
		*/
	});
  
	vm.on('exit', function (code) {
		vm = null;
		console.log('child process exited with code ' + code);
		if (vm_auto_relaunch) {
			vm_launch();
		} else {
			// if vm dies, kill node with it:
			process.exit();
		}
	});
}

// if node.js dies, take VM with it:
process.on('exit', function() {
	if (vm !== null) { vm.kill(); }
});

// start the vm:
vm_launch();
console.log("started");