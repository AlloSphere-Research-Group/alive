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