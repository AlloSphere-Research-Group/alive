var fs 			= require('fs');
var http 		= require('http');
var url 		= require('url');
var mime 		= require('mime');
var dns			= require('dns');
var os			= require('os');
var net			= require('net');
var util		= require('util');

var path 		= require('path');
var io 			= require('socket.io-client');
var socket_in 	= require('socket.io').listen(8081);
var exec 		= require('child_process').exec;
var osc 		= require('./omgosc.js');

var OSC_IN 		= 8010;

var client 		= null;
var receiver 	= new osc.UdpReceiver(OSC_IN);

console.log("hostname " + os.hostname());

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

var myIP = addresses[0];


/*
NOGOOD (RETURNS 127.0.1.1):
exec("hostname -i", function(err, stdout, stderr) {
	util.puts(stdout);
});
dns.lookup(os.hostname(), function(err, add, fam) {
	console.log("addr" + add);
	console.log("fam" + fam);
});
*/

receiver.on('/print', function(e) {
	client.emit("print", e.params[0]);
	console.log(e.params[0]);
});

receiver.on('/error', function(e) {
	client.emit("error", e.params[0]);
	console.error(e.params[0]);
});

process.stdin.resume();

process.stdin.setEncoding('utf8');

process.stdin.on('data', function (chunk) {
	chunk = chunk.replace(/(\r\n|\n|\r)/gm,"");
	var tokens = chunk.split(' ');
	var cmd = tokens[0];
	var args = tokens[1]
	switch(cmd) {
		case "ls" :
			ls();
			break;
		case "cd" :
			cd(args);
			break;
		case "read" :
			read(args);
			break;
		default:
			console.log("could not process command");
		break;
	}
	process.stdout.write('data: ' + chunk);
});

var socketURL = 'http://127.0.0.1:8082';
sock = io.connect(socketURL);

var ls = function() {
	//console.log("CURRENT DIR ON LS", currentDir);
	var files = fs.readdirSync(currentDir);
	var response = [];
	for(var i = 0; i < files.length; i++) {
		var _path = files[i];
		//console.log("PATH", _path);
		var isDirectory = fs.statSync(currentDir + "/" + _path).isDirectory();
		response.push( {name:_path, "isDirectory":isDirectory} );
	}
	return response;
	//return fs.readdirSync(currentDir);
		//console.log("RETURNING FILES", files);
		//return files;
		/*for(var i = 0; i < files.length; i++) {
			console.log(files[i]);
		}*/
		//});
};


var read = function(file) {
	return fs.readFileSync(currentDir + "/" + file, 'utf8');
};

socket_in.sockets.on('connection', function (socket) {
	socket.addr = socket.handshake.address.address;
	socket.port = socket.handshake.address.port;
	socket.currentDir 	= __dirname;
	//client = socket;
	socket.emit("handshake", { "data" : "Handshake received from " + socket.addr } );
	
	socket.on('save', function(obj) {
		var filename = obj.filename;
		var data = obj.data;
		
		fs.writeFileSync(socket.currentDir + "/" + filename, data, 'utf8');
		exec("git commit -a -m '"+filename+" changes from alloeditor'", 
			{cwd: socket.currentDir}, 
			function() { 
				console.log("MADE A COMMIT!");
				sock.emit("pull");
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
				var files = fs.readdirSync(socket.currentDir);
				var response = [];
				for(var i = 0; i < files.length; i++) {
					var _path = files[i];
					//console.log("PATH", path);
					var isDirectory = fs.statSync(socket.currentDir + "/" + _path).isDirectory();
					response.push( {name:_path, "isDirectory":isDirectory} );
				}
				console.log("FILES", response);
				socket.emit("ls", { "data" : response} );
				break;
			case "cd" :
				//var cd = function(dir) {
				//	currentDir = path.resolve(currentDir, dir);
					//console.log(currentDir);
				//};
				//cd(args);
				socket.currentDir = path.resolve(socket.currentDir, args);
				var files = fs.readdirSync(socket.currentDir);
				var response = [];
				for(var i = 0; i < files.length; i++) {
					var _path = files[i];
					//console.log("PATH", path);
					var isDirectory = fs.statSync(socket.currentDir + "/" + _path).isDirectory();
					response.push( {name:_path, "isDirectory":isDirectory} );
				}
				//console.log("FILES", files);
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
		console.log("DISCONNECT : " + this.addr);
		//if(client === this) {
		//	console.log("DISCONNECTING CLIENT");
		//	client = null;
		//}
	});
});

var root = __dirname + "/../editor";
console.log("serving from " + root);
var port = 8080;
var server = http.createServer(function(req, res) {
	req.uri = url.parse(req.url);
	var pathname = req.uri.pathname;
	
	// static file server:
	console.log(pathname);
	
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
	console.log(filepath);
	
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
console.log('Server running at ' + myIP + ' on port ' + port + '');












