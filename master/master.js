var fs 			= require('fs');
var http 		= require('http');
var url 		= require('url');
var mime 		= require('mime');
var dns			= require('dns');
var os			= require('os');
var net			= require('net');
var util		= require('util');
var path 		= require('path');
var mdns 		= require('mdns');
var connect 	= require('connect');
var sharejs 	= require('share').server;
var path		= require('path');
var exec		= require('child_process').exec;
var spawn		= require('child_process').spawn;

var editors_in 	 = require('socket.io').listen(8081);
var renderers_in = require('socket.io').listen(8082);

var editors = {};
var renderers = {};

var hostname = os.hostname();
// argv[2] is the master name. 
// if no master name is given, assume current machine is the master.
var mastername = process.argv[2] || hostname;

// am I running as the master node?
var ismaster = (hostname === mastername);

if (!ismaster) {
	console.log("I am not the master node");
}

//// THE VM CHILD PROCESS ////
var auto_relaunch = false;
var vm_name = './main';
var vm = null;

function launch(name) {
	if (vm !== null) {
		vm.kill();
	}
	
	vm = spawn(name);

	vm.stdout.on('data', function (text) {
		process.stdout.write(text);
		process.stdout.flush();
		for(var key in editors) {
			editors[key].emit("console", { "msg" : text.toString() } );
		}
	});
  
	// this never seems to get called...
	vm.stderr.on('data', function (text) {
		process.stdout.write('err:' + text);
		process.stdout.flush();
		console.log("SENDING ERROR MESSAGE", text.toString);
		for(var key in editors) {
			editors[key].emit("err", { "msg" : text.toString()  } );
		}
	});
  
	vm.on('exit', function (code) {
		console.log('child process exited with code ' + code);
		
		if (auto_relaunch) {
			launch(name);
		} else {
			vm = null;
			// if vm dies, kill node with it:
			if (ismaster) {
				process.exit();
			}
		}
	});
}

// if node dies, take VM with it:
process.on('exit', function() {
	if (vm !== null) {
		vm.kill();
	}
});

/*
fs.watch('.', function (event, filename) {
	console.log('event is: ' + event);
	if (filename) {
		console.log('filename provided: ' + filename);
	} else {
		console.log('filename not provided');
	}
	launch(vm_name);
});
*/

//// THE MDNS STUFF ////

if (ismaster) {

	var ad = mdns.createAdvertisement(mdns.tcp('master'), 8082);
	ad.start();

	var pullNumber = 0;
	var cmds = {
		ls : function(_socket) {
			var files = fs.readdirSync(_socket.currentDir);
			var response = [];
			for(var i = 0; i < files.length; i++) {
				var _path = files[i];
				var isDirectory = fs.statSync(_socket.currentDir + "/" + _path).isDirectory();
				response.push( {name:_path, "isDirectory":isDirectory} );
			}
			return response;
		},

		cd : function(_socket, args) {
			_socket.currentDir = path.resolve(_socket.currentDir, args);
		},
	};

	//// THE EDITOR SOCKET ////

	editors_in.sockets.on('connection', function (socket) {
		socket.addr = socket.handshake.address.address;
		socket.port = socket.handshake.address.port;
		socket.currentDir 	= __dirname;
		
		if(editors[socket.addr]) editors[socket.addr].disconnect();
		editors[socket.addr] = socket;
		
		editors[socket.addr].emit("handshake", { "data" : "Handshake received from " + editors[socket.addr].addr } );
	  
		editors[socket.addr].on('execute', function(obj) {
			var code = obj.code.replace(/(\r\n|\n|\r)/gm, "<n>") + "\r\n";
			console.log("CODE", code);
			console.log("sent", vm.stdin.write(code));
		});
		
		/*
		editors[socket.addr].on('save', function(obj) {
			var filename = obj.filename;
			var data = obj.data;
			
			fs.writeFileSync(editors[socket.addr].currentDir + "/" + filename, data, 'utf8');
			exec("git commit " + editors[socket.addr].currentDir + "/" + filename + " -m '"+filename+" changes from alloeditor'", 
				{cwd: editors[socket.addr].currentDir}, 
				function() { 
					console.log("MADE A COMMIT!");
					exec("git push origin master", {cwd: editors[socket.addr].currentDir}, function(err, stdout, stderr) {
						
						console.log("MADE A PUSH");
						console.log(err, stdout, stderr);
						
						console.log(renderers);
						for(var key in renderers) {
							console.log("TELLING RENDERER " + key + ":" + renderers[key].port + " TO PULL");
							renderers[key].emit('pull', { number: pullNumber++} );
						}
					});
				} 
			);
		});
		*/
		
		/*
		editors[socket.addr].on('cmd', function(cmd) {
			cmd = cmd.replace(/(\r\n|\n|\r)/gm,"");
			var tokens = cmd.split(' ');
			var _cmd = tokens[0];
			tokens.splice(0,1);
			var args = tokens.join(" ");
			
			switch(_cmd) {
				case "ls" :
					var files = cmds.ls(editors[socket.addr]);
					editors[socket.addr].emit("ls", { "data" : files} );
					break;
				case "cd" :
					cmds.cd(editors[socket.addr], args);
					var response = cmds.ls(editors[socket.addr]);
					editors[socket.addr].emit("ls", { "data" : response} );
					editors[socket.addr].emit("dir", editors[socket.addr].currentDir );				
					break;
				case "read" :
					try {
						var data = fs.readFileSync(editors[socket.addr].currentDir + "/" + args, 'utf8');///read(args);
						editors[socket.addr].emit("read", { "data" : data } );
					} catch(err){ console.log(err);}
					break;
				default:
					console.log("could not process command");
				break;
			}
		});
		*/
			
		editors[socket.addr].on('disconnect', function () {
			delete editors[socket.addr];
			console.log("DISCONNECT : " + socket.addr);
		});
	});
	
	//// THE REMOTE SOCKET ////

	renderers_in.sockets.on('connection', function (socket) {
		socket.addr = socket.handshake.address.address;
		socket.port = socket.handshake.address.port;
		socket.currentDir 	= __dirname;
		
		renderers[socket.addr] = socket;
		
		for(var key in editors) {
			editors[key].emit("renderer connect", { ip: socket.addr } );
		}
		
		renderers[socket.addr].on('stderr', function(msg) { 
			for(var key in editors) {
				editors[key].emit("stderr", { ip: socket.addr, "msg" : msg } );
			}
		});
		
		renderers[socket.addr].on('stdout', function(msg) {
			console.log("STDOUT", msg);
			/*for(var key in editors) {
				console.log("SENDING STDOUT TO ", socket.addr);
				editors[key].emit("stdout", msg +"<br>" );
				// editors[key].emit("stdout", { ip: socket.addr, "msg" : msg } );
			}*/
		});
		
		renderers[socket.addr].on('message', function(msg) {
			var name = msg.slice(0,3);
			var _msg = msg.slice(4);
			
			_msg.replace('\n', '<br>');
			//console.log("MESSAGE: " + name + " : " + _msg);
			for(var key in editors) {
				editors[key].emit(name, _msg +"<br>" );
			}
			
			/*
			switch(name){
				case "out" :
					console.log("STDOUT " + _msg);
					for(var key in editors) {
						editors[key].emit("stdout", msg +"<br>" );
					}
					break;
				case "err" :
					console.log("ERROR " + _msg);
					for(var key in editors) {
						editors[key].emit("error", msg +"<br>" );
					}
					
					break;
				default:
					console.log("I don't understand thiss shit");
					break;
			}
			*/
		});
		
		renderers[socket.addr].on('disconnect', function () {
			delete renderers[socket.addr];
			for(var key in editors) {
				editors[key].emit("renderer disconnect", { ip: socket.addr } );
			}
		});
		
	});

	//// THE EDITOR HTTP SERVER ////

	var root = __dirname + "/../editor";
	var port = 8080;
	console.log("serving from " + root);

	var connectServer = connect(
		//connect.logger(),			// shut up!!
		function(req, res, next){
			req.uri = url.parse(req.url);
			var pathname = req.uri.pathname;
			if( pathname == "/"){
				req.url = "/index.htm"
			} else if (pathname == "/config.js") {
				console.log("sending config");
				var text = "remoteIP = '" + myIP + "';";
				res.writeHead(200, {
					'Content-Type': 'text/javascript',
					'Content-Length': text.length
				})
				res.end(text);
				console.log("done sending config");
				return;
			}
			return next()
		},
		connect.static(root)
	);

	//// THE SHARE.JS STUFF ////

	//var connectServer = connect.createServer();
	//connectServer.use(server);
	var options = {db: {type: 'none'}}; // See docs for options. {type: 'redis'} to enable persistance.
	//var options = {db: {type: 'redis'}};
	//server.listen(8080);
	// Attach the sharejs REST and Socket.io interfaces to the server
	sharejs.attach(connectServer, options);
	connectServer.listen(port);
	
	//// WHAT IS MY IP? ////

	var myIP = (function() {
		var interfaces = os.networkInterfaces();
		var addresses = [];
		for (k in interfaces) {
			for (k2 in interfaces[k]) {
				var address = interfaces[k][k2];
				if (address.family == 'IPv4' && !address.internal) {
					console.log(address.address);
					addresses.push(address.address)
				}
			}
		}
		return addresses[0];
	})();

	//// STARTUP ////

	console.log('Server running at ' + myIP + ' on port ' + port + '');

	
} // if ismaster

// start the vm:
launch(vm_name);