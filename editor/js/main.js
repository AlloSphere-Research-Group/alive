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

window.connect = function(name, span) {
	$(span).css("color", "#0f0");
	console.log("NAME = " + name);
};

/*var doc = null, editor = null;

function setDoc(docName) {
  document.title = docName;

  sharejs.open(docName, function(error, newDoc) {
      if (doc !== null) {
          doc.close();
          doc.detach_ace();
      }

      doc = newDoc;

      if (error) {
          console.error(error);
          return;
      }
      doc.attach_cm(editor);
  });
};*/

$(document).ready( function() {
	$('#tabs').tabs();
	cmd		= document.getElementById("command");
	code 	= document.getElementById("code");
	fileBrowser = document.getElementById("fileBrowser");
	
	var doc = null;

	var setDoc = function(docName) {
		if( doc !== null){
			doc.close();
			if( doc.detach_cm ){
				doc.detach_cm();
				console.log("detach: " + currentFile)
			}
		}
		doc = null;

		return sharejs.open(docName, function(error, newDoc) {

			if (error) {
				console.error(error);
				return;
			}
			currentFile = newDoc.name;
			console.log("opening: " + currentFile)
			$("#filename").text(currentFile);
			doc = newDoc;
			//if( doc.getLength() == 0 ){
			//	console.log("read: "+currentFile)
			//	slaveSocket.emit('cmd', 'read ' + currentFile);
			//}else{
				doc.attach_cm(window.editor);
				console.log("attach: " + currentFile)
			//}
			
		});
	};

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
              	var img = $("<img>");
				img.attr('src','../images/folder.png');
                      	
				(function() {
					var name = response.data[i].name;
					$(a).click(function() {
						slaveSocket.emit('cmd', 'cd ' + name);
					});
					$(a).text(name);
				})();
              	$(a).prepend(img);
              	$(img).css({ position:"relative", top: "5px", marginRight:"5px", width: "20px", height:"20px" });
				$(a).css({ cursor:"pointer" });
			}else{
				(function() {
					var name = response.data[i].name;
					$(a).click(function() {
						connection = setDoc(name);

						//slaveSocket.emit('cmd', 'read ' + name);
						//currentFile = name;
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
	
	slaveSocket.on('out', function(msg) {
		$("#console-all").append(msg+"<br>");
		$("#consoleContainer").scrollTop($("#consoleContainer")[0].scrollHeight);
	});

	slaveSocket.on('err', function(msg) {
		$("#console-all").append($("<span style='color:#f00'>"+msg+"</span><br>"));
		$("#consoleContainer").scrollTop($("#consoleContainer")[0].scrollHeight);
	});
	
	slaveSocket.on('read', function (response) {
		//$("#filename").text(currentFile);
		console.log("red and attach: "+currentFile)
		window.editor.setValue(response.data);
		//doc.del(0,doc.getLength());
		//doc.insert(0, response.data);
		doc.attach_cm(window.editor, true);
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
	
    //editor = CodeMirror(document.body, { mode: "coffeescript", tabSize: 2 });

    var connection = setDoc('a.l.i.v.e.');  // Hooking ShareJS and CodeMirror for the first time.

    /*var namefield = document.getElementById('namefield');
    function fn() {
        var docName = namefield.value;
        if (docName) setDoc(docName);
    }

    if (namefield.addEventListener) {
        namefield.addEventListener('input', fn, false);
    } else {
        namefield.attachEvent('oninput', fn);
    }*/

	// *** Connection status display
	var status = document.getElementById('sharejs_status');
	var register = function(state, klass, text) {
	connection.on(state, function() {
	  status.className = 'label ' + klass;
	  status.innerHTML = text;
	});
	};

	register('ok', 'success', 'Online');
	register('connecting', 'warning', 'Connecting...');
	register('disconnected', 'important', 'Offline');
	register('stopped', 'important', 'Error');

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
  
  var flash = function(cm, pos) {
      if (pos !== null) {
          v = cm.getLine(pos.line);

          cm.setLineClass(pos.line, null, "highlightLine")

          var cb = (function() {
              cm.setLineClass(pos.line, null, null);
          });

          window.setTimeout(cb, 250);

      } else {
          var sel = cm.markText(cm.getCursor(true), cm.getCursor(false), "highlightLine");

          var cb = (function() {
              sel.clear();
          });

          window.setTimeout(cb, 250);
      }
  };
	
	CodeMirror.keyMap.alive = {
		fallthrough : "default",
    "Ctrl-Enter": function(cm) {
        var v = cm.getSelection();
        var pos = null;
        if (v === "") {
            pos = cm.getCursor();
            v = cm.getLine(pos.line);
        }
        flash(cm, pos);
        slaveSocket.emit('execute', {code:v});
    },
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
	
	$("#consoleContainer").height($("#console").height() - $("#tabs:first-child").outerHeight());
	
	$("#consoleBar").mousedown( function(e) {
		$("body").css("-webkit-user-select", "none");
		
		$(window).mousemove(function(e) {
			if(e.pageY < $(window).height() - $("#filename").outerHeight()) {
				$(".CodeMirror-scroll").height(e.pageY - $("#filename").height());
				$("#console").height($("body").height() - $(".CodeMirror-scroll").height() - $("#filename").outerHeight());
				window.editor.refresh();
				//$("#consoleContainer").height($("#console").outerHeight() - $("#tabs:first-child").height());
			}
			$("#consoleContainer").height($("#console").height());
			
		});
		
		$(window).mouseup( function(e) {
			$(window).unbind("mousemove");
			$(window).unbind("mouseup");
			$("body").css("-webkit-user-select", "text");
			//Gibber.codeWidth = $(".CodeMirror").width();
		});
	});
	
	$("#fileBar").mousedown( function(e) {
		$("body").css("-webkit-user-select", "none");
		
		$(window).mousemove(function(e) {
			if(e.pageX > 0) {
				$("#right").width($("body").width() - e.pageX);
				$("#left").width( $("body").width() - $("#right").width());
				$("#right").offset({left:e.pageX});
				
				window.editor.refresh();
				//$("#consoleContainer").height($("#console").outerHeight() - $("#tabs:first-child").height());
			}
			//$("#consoleContainer").height($("#console").height());
			
		});
		
		$(window).mouseup( function(e) {
			$(window).unbind("mousemove");
			$(window).unbind("mouseup");
			$("body").css("-webkit-user-select", "text");
			//Gibber.codeWidth = $(".CodeMirror").width();
		});
	});
	

});
