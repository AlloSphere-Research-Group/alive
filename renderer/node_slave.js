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

browser.on('serviceUp', function(service) {
  console.log("service up: ", service);
  //console.log("ADDRESS ", service.addresses[0]);
  // use host instead of ip address... addresses also returns MAC address of port
  master = io.connect(service.host+":8082");

  master.on('connect', function(){ console.log("Connected to Master"); });

  master.on('message', function(msg){ console.log("Recieved a message: " + msg); });

  master.on('disconnect', function(){ console.log("Disconnected from Master"); });

  master.on('pull', function(obj) {
  	exec("git pull origin master", {cwd: currentDir}, function() { console.log("MADE A PULL!"); } );
  });
  
});

browser.on('serviceDown', function(service) {
  console.log("service down: ", service);
});
browser.start();

