var fs 			= require('fs');
var path 		= require('path');
var io 			= require('socket.io-client');
var socket_in 	= require('socket.io').listen(8081);
var exec 		= require('child_process').exec;
var osc 		= require('./omgosc.js');

var OSC_IN 		= 8010;
var currentDir 	= __dirname;
var client 		= null;
var receiver 	= new osc.UdpReceiver(OSC_IN);

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
		var path = files[i];
		//console.log("PATH", path);
		var isDirectory = fs.statSync(currentDir + "/" + path).isDirectory();
		response.push( {name:path, "isDirectory":isDirectory} );
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

var cd = function(dir) {
	currentDir = path.resolve(currentDir, dir);
	//console.log(currentDir);
}

var read = function(file) {
	return fs.readFileSync(currentDir + "/" + file, 'utf8');
};

socket_in.sockets.on('connection', function (socket) {
	socket.addr = socket.handshake.address.address;
	socket.port = socket.handshake.address.port;
	
	client = socket;
	client.emit("handshake", { "data" : "Handshake received from " + socket.addr } );
	
	socket.on('save', function(obj) {
		var filename = obj.filename;
		var data = obj.data;
		
		fs.writeFileSync(currentDir + "/" + filename, data, 'utf8');
		exec("git commit -a -m '"+filename+" changes from alloeditor'", 
			{cwd: currentDir}, 
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
				var files = ls();
				console.log("FILES", files);
				client.emit("ls", { "data" : files} );
				break;
			case "cd" :
				cd(args);
				var files = ls();
				//console.log("FILES", files);
				client.emit("ls", { "data" : files} );
				client.emit("dir", currentDir );				
				break;
			case "read" :
				var data = read(args);
				client.emit("read", { "data" : data } );
				break;
			default:
				console.log("could not process command");
			break;
		}
	});
		
	socket.on('disconnect', function () { 
		console.log("DISCONNECT : " + this.addr);
		if(client === this) {
			console.log("DISCONNECTING CLIENT");
			client = null;
		}
	});
});