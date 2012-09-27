var fs 			= require('fs');
var http 		= require('http');
var url 		= require('url');
var mime 		= require('mime');
var dns			= require('dns');
var os			= require('os');
var net			= require('net');
var util		= require('util');
var exec 		= require('child_process').exec;
var path 		= require('path');
var mdns 		= require('mdns');

var editors_in 	 = require('socket.io').listen(8081);
var renderers_in = require('socket.io').listen(8082);

var editors = {};
var renderers = {};

var ad = mdns.createAdvertisement(mdns.tcp('master'), 8082);
ad.start();

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

editors_in.sockets.on('connection', function (socket) {
	socket.addr = socket.handshake.address.address;
	socket.port = socket.handshake.address.port;
	socket.currentDir 	= __dirname;
	
	editors[socket.addr] = socket;
	
	socket.emit("handshake", { "data" : "Handshake received from " + socket.addr } );
	
	socket.on('save', function(obj) {
		var filename = obj.filename;
		var data = obj.data;
		
		fs.writeFileSync(socket.currentDir + "/" + filename, data, 'utf8');
		exec("git commit " + socket.currentDir + "/" + filename + " -m '"+filename+" changes from alloeditor'", 
			{cwd: socket.currentDir}, 
			function() { 
				console.log("MADE A COMMIT!");
				console.log(renderers);
				for(var key in renderers) {
					console.log("TELLING RENDERER " + key + ":" + renderers[key].port + " TO PULL");
					renderers[key].emit('pull');
				}
			} 
		);
	});
	
	socket.on('cmd', function(cmd) {
		cmd = cmd.replace(/(\r\n|\n|\r)/gm,"");
		var tokens = cmd.split(' ');
		var _cmd = tokens[0];
		tokens.splice(0,1);
		var args = tokens.join(" ");
		
		switch(_cmd) {
			case "ls" :
				var files = cmds.ls(socket);
				socket.emit("ls", { "data" : files} );
				break;
			case "cd" :
				cmds.cd(socket, args);
				var response = cmds.ls(socket);
				socket.emit("ls", { "data" : response} );
				socket.emit("dir", socket.currentDir );				
				break;
			case "read" :
				var data = fs.readFileSync(socket.currentDir + "/" + args, 'utf8');///read(args);
				socket.emit("read", { "data" : data } );
				break;
			default:
				console.log("could not process command");
			break;
		}
	});
		
	socket.on('disconnect', function () {
		delete editors[socket.addr];
		console.log("DISCONNECT : " + socket.addr);
	});
});

renderers_in.sockets.on('connection', function (socket) {
	socket.addr = socket.handshake.address.address;
	socket.port = socket.handshake.address.port;
	socket.currentDir 	= __dirname;
	
	renderers[socket.addr] = socket;
	
	for(var key in editors) {
		editors[key].emit("renderer connect", { ip: socket.addr } );
	}
	
	socket.on('error', function(msg) { 
		for(var key in editors) {
			editors[key].emit("renderer error", { ip: socket.addr, "msg" : msg } );
		}
	});
	
	socket.on('disconnect', function () {
		delete renderers[socket.addr];
		for(var key in editors) {
			editors[key].emit("renderer disconnect", { ip: socket.addr } );
		}
	});
	
});

var root = __dirname + "/../editor";
console.log("serving from " + root);

var port = 8080;
var server = http.createServer(function(req, res) {
	req.uri = url.parse(req.url);
	var pathname = req.uri.pathname;
	
	// static file server:
	//console.log(pathname);
	
	if (pathname == "/") {
		pathname = pathname + "index.htm";
	} else if (pathname == "/config.js") {
		console.log("sending config");
		var text = "remoteIP = '" + myIP + "';";
		res.writeHead(200, {
			'Content-Type': 'text/javascript',
			'Content-Length': text.length
		})
		res.end(text);
		return;
	}
	
	req.uri.pathname = root + pathname;
	var filepath = req.uri.pathname;
	//console.log(filepath);
	
	fs.stat(filepath, function (err, stat) {
		if (err || stat == undefined) {
			var reason = "not found: " + filepath;
			res.writeHead(500, {
				'Content-Length': reason.length,
				'Content-Type': "text/plain"
			});
			res.write(reason);
		} else if (!stat.isFile()) {
			var reason = "not a file: " + filepath;
			res.writeHead(500, {
				'Content-Length': reason.length,
				'Content-Type': "text/plain"
			});
			res.write(reason);
		} else {
			fs.readFile(req.uri.pathname, function(err, data) {
				if (err) {
					var reason = "not read: " + filepath;
					res.writeHead(500, {
						'Content-Length': reason.length,
						'Content-Type': "text/plain"
					});
					res.write(reason);
					
				} else {
					var text = data.toString();
					res.writeHead(200, {
						'Content-Type': mime.lookup(filepath),
						'Content-Length': stat.size
					})
					res.end(text);
				}
			})
		}
	})
});
server.listen(port, '0.0.0.0');

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
	
	// fallback for case of no network connection:
	if (addresses.length == 0) {
		addresses.push("127.0.0.1");
	}
	
	return addresses[0];
})();

console.log('Server running at ' + myIP + ':' + port + '');
