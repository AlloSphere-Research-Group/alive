var fs 		= require('fs');
var path 	= require('path');
var exec 	= require('child_process').exec;
var spawn	= require('child_process').spawn;
var io_in 	= require('socket.io').listen(8083);
var io	 	= require('socket.io-client');
var mdns 	= require('mdns');

var currentDir 	= __dirname;
var vm = null;
var master = null;
var browser = mdns.createBrowser(mdns.tcp('master'));
var MASTER_ADDRESS 	= null; //"127.0.0.1:8082";
var pullNumber = 0;
var auto_relaunch = false;

function checkdir(files, p, cb) {
	fs.stat(p, function(err, stats) {
		if (err !== null) {
			console.log(err);
		} else if (stats.isDirectory()) {
			fs.readdir(p, function(err, filenames) {
				for (var i = 0; i < filenames.length; i++) {
					var p1 = path.join(p, filenames[i]);
					checkfile(files, p1, cb);
				}
			});
		} else if (stats.mtime > files[p]) {
			console.log("expected directory, got file: " + p);
		}
	});
}

function checkfile(files, p, cb) {
	fs.stat(p, function(err, stats) {
		if (err !== null) {
			console.log(err);
		} else if (stats.isDirectory()) {
			// this case should be handled by a separate watcher
		} else if (stats.mtime > files[p]) {
			files[p] = stats.mtime;
			cb(p);
		}
	});
}

function initfiles(dirpath) {
	var files = {};
	var filenames = fs.readdirSync(dirpath);
	for (var i = 0; i < filenames.length; i++) {
		var p = path.join(dirpath, filenames[i]);
		var stats = fs.statSync(p);
		if (stats.isDirectory()) {
			//console.log("watching subdirectory " + p);
			// this was causing problems (maybe too deeply nested folders?)
			//files[p] = watchdir(p);
		} else {
			files[p] = stats.mtime;
		}
	}
	return files;
}

function watchdir(dirpath, cb) {
	// initialize files:
	var files = initfiles(dirpath);
	// start watching:
	fs.watch(dirpath, function(event, filename) {
		checkdir(files, dirpath, cb); 
	});
	return files;
}

watchdir(".", function(p) {
	console.log("modified file: " + p);
	
	if (vm !== null) {
		console.log("sent to vm");
		vm.stdin.write(p + "\n");
	}
});

function launch(name) {
	if (vm !== null) {
		vm.kill();
	}
	
	vm = spawn(name);

	vm.stdout.on('data', function (text) {
		process.stdout.write(text);
		if (master !== null) {
			master.send("out:" + text);
		}
	});
	vm.stderr.on('data', function (text) {
		process.stdout.write('err:' + text);
		if (master !== null) {
			master.send("err:" + text);
		}
	});

	vm.on('exit', function (code) {
		console.log('child process exited with code ' + code);
		
		if (auto_relaunch) {
			launch(name);
		} else {
			vm.kill();
			vm = null;
		}
	});
}

var connectMaster = function(service) {
	if(master === null) {
		console.log("service up: ", service);
		master = io.connect(service.host+":8082");

		master.on('connect', function() { 
			console.log("Connected to Master");  
			browser.on('serviceUp', function() {
				
			}); 
		});

		master.on('message', function(msg){ 
			console.log("Recieved a message: " + msg); 
		});

		master.on('disconnect', function(){ 
			console.log("Disconnected from Master"); 
			browser.on('serviceUp', connectMaster); 
			if(master !== null) {
				master.disconnect();
			}
		});

		master.on('pull', function(obj) {
			if(pullNumber <= obj.number) {
				exec("git pull origin master", {cwd: currentDir}, function() { console.log("MADE A PULL!"); } );
				if (vm != undefined) vm.kill();
				launch();
				pullNumber++;
			}
		});
		
		master.emit('stdout', "vm connected to master");
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



process.on('exit', function() {
	if (vm !== null) {
		vm.kill();
	}
});



launch('./alive');

