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
		
	window.editor = CodeMirror.fromTextArea(document.getElementById("codeEditor"), {
	  	autofocus: true,
	  	indentUnit : 4,
		indentWithTabs: true,
		lineNumbers: true,
		lineWrapping: true,
	  	smartIndent: true,
		undoDepth: 400,
		
		theme: "vibrant-ink",	
	});
	

	window.CodeMirror = CodeMirror;	
	
	CodeMirror.modeURL = "js/codemirror/mode/%N/%N.js";
	// this should depend on the type of file being displayed
	//window.editor.setOption("mode", "javascript");
	//window.editor.setOption("mode", "clike");
	window.editor.setOption("mode", "lua");
	
	var hlLine = window.editor.setLineClass(0, "activeline");
	window.editor.setOption("onCursorActivity", function() {
		window.editor.setLineClass(hlLine, null, null);
		hlLine = window.editor.setLineClass(window.editor.getCursor().line, null, "activeline");
		
		// highlight matching words:
		// not working for some reason
		window.editor.matchHighlight("CodeMirror-matchhighlight");
		
		// super annoying:
		// window.setTimeout(function() { autocomplete(editor); }, 1000);
	});
			
	var editor_save = function(cm) {
		slaveSocket.emit('save', {filename:currentFile, data:editor.getValue()} );
		flashMsg("SAVED");
	};
	
	CodeMirror.keyMap.alive = {
		fallthrough : "default",
		"Cmd-S": editor_save,
		"Ctrl-S": editor_save,
	};
		
	window.editor.setOption("keyMap", "alive");
	
	slaveSocket.emit('cmd', 'ls');
			
	$(window).resize(function() {
		$(".CodeMirror-scroll").height( $(window).height() - $("#filename").outerHeight() - $("#console").outerHeight() );
		window.editor.refresh();
	});
			
	$(".CodeMirror-scroll").height( $(window).height() - $("#filename").outerHeight() - $("#console").outerHeight() );
	window.editor.refresh();
	
	$("#consoleBar").mousedown( function(e) {
		$("body").css("-webkit-user-select", "none");
		
		$(window).mousemove(function(e) {
			if(e.pageY < $("body").height() - $("#filename").outerHeight()) {
				$(".CodeMirror-scroll").height(e.pageY - $("#filename").outerHeight());
				$("#console").height($("body").height() - $(".CodeMirror").outerHeight() - $("#filename").outerHeight());
				window.editor.refresh();
			}
		});
		
		$(window).mouseup( function(e) {
			$(window).unbind("mousemove");
			$(window).unbind("mouseup");
			$("body").css("-webkit-user-select", "text");
			//Gibber.codeWidth = $(".CodeMirror").width();
		});
	});
	
});
