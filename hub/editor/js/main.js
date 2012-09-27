window.flashMsg = function(_msg) {
	var msg = $("<h3>");
	$(msg).text(_msg);
	$(msg).css({
		position : "absolute",
		width: "10em",
		height: "2em",
		backgroundColor:"#333",
		color:"#ccc",
		left: "40%",
		top: "40%",
		lineHeight:"2em",
		fontFamily: "sans-serif",
		textAlign: "center",
		verticalAlign: "center",
		"-webkit-border-radius": "15px",
	})
	$("body").append(msg);
	$(msg).fadeOut('slow', 'swing', function() { $(msg).remove() } );
};
window.currentFile = "";

$(document).ready( function() {
	cmd		= document.getElementById("command");
	code 	= document.getElementById("code");
	fileBrowser = document.getElementById("fileBrowser");
	
	// remoteIP is provided by the web server when the page is served
	slaveSocket = io.connect("http://" + remoteIP + ":8081/");	

	slaveSocket.on('handshake', function (response) {
		console.log("HANDSHAKE : ", response.data);
	});
				
	slaveSocket.on('ls', function (response) {
		var list = $("#fileBrowser");
		$(list).empty();
		for(var i = 0; i < response.data.length; i++) {
			var r = $("<li>");
			var a = $("<a>");

			if(response.data[i].isDirectory === true) {
              	var img = $("<img src='images/folder.png'>");
                      	
				(function() {
					var name = response.data[i].name;
					$(a).click(function() {
						slaveSocket.emit('cmd', 'cd ' + name);
					});
					$(a).text(name);
				})();
              	$(a).prepend(img);
              $(img).css({ position:"relative", top: "5px", marginRight:"5px", width: "20px", height:"20px" });
				$(a).css({color: "blue", cursor:"pointer"});
			}else{
				(function() {
					var name = response.data[i].name;
					$(a).click(function() {
						slaveSocket.emit('cmd', 'read ' + name);
						currentFile = name;
					});
					$(a).text(name);
                  $(a).css({ display: "block", cursor:"pointer", marginTop:"5px",});
				})();						
			}
			// if(response.data[i].isDirectory) {
			// 	r = "<a href='#' onclick='slaveSocket.emit(\'cmd\', \'cd " + response.data[i].name + "\')'>&#x25BA;" + response.data[i].name + "</a><br>";
			// }else{
			// 	r = response.data[i].name + "<br>";
			// }
			// filenames += r;
			$(r).append(a);
			$(list).append(r);
		}
		//fileBrowser.innerHTML = filenames;
	});
	
	slaveSocket.on('dir', function(dir) {
		$("#dir").text(dir);
	});
			
	slaveSocket.on('read', function (response) {
		$("#filename").text(currentFile);
		window.editor.setValue(response.data);
		//window.editor.refresh();
	});
		
	CodeMirror.modeURL = "js/codemirror/mode/%N/%N.js";
	window.editor = CodeMirror.fromTextArea(document.getElementById("codeEditor"), {
	  	lineNumbers: false,
	  	autofocus: true,
	  	indentUnit : 2,
	  	smartIndent: true,
	});

	window.CodeMirror = CodeMirror;	
	window.editor.setOption("mode", "javascript");
			
	CodeMirror.keyMap.gibber = {
		fallthrough : "default",
		"Cmd-S":function(cm) {
			console.log("SAVING SAVING");
			slaveSocket.emit('save', {filename:currentFile, data:editor.getValue()} );
			flashMsg("SAVED");
		},
	};
		
	window.editor.setOption("keyMap", "gibber");
			
	slaveSocket.emit('cmd', 'ls');
			
	$(window).resize(function() {
		$(".CodeMirror-scroll").height( $(window).height() - 20 );
		window.editor.refresh();
	});
			
	$(".CodeMirror-scroll").height( $(window).height() - 20 );
	window.editor.refresh();
});
