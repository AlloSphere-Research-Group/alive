window.Alive = {
  displayTOC: function() {
      $("#docs").empty();
      for (var key in Alive.toc) {
          var cat = Alive.toc[key];
          if (cat.length > 0) {
              var ul = $("<ul style='list-style:none; padding: 0px 5px;'>");
              var h2 = $("<h2>" + key + "</h2>");
              //var ul = $("<ul>");
              for (var i = 0; i < cat.length; i++) {
                  var li = $("<li>");
                  var a = $("<a style='cursor:pointer'>");
                  (function() {
                      var text = cat[i];
                      a.text(text);
                      a.click(function() {
                          Alive.displayDocs(text);
                      });
                  })();
                  $(li).append(a);
                  $(ul).append(li);
              }
              $("#docs").append(h2);
              $("#docs").append(ul);
          }
      }
  },
  displayDocs: function(obj) {
      console.log("DISPLAYING", obj)
      if (typeof Alive.docs[obj] === "undefined") return;
      $("#docs").html(Alive.docs[obj].text);
      $("#docs").append("<h2>Methods</h2>");
      var count = 0;
      for (var key in Alive.docs[obj].methods) {
          var html = $("<div style='padding-top:5px'>" + Alive.docs[obj].methods[key] + "</div>");
          var bgColor = count++ % 2 === 0 ? "#444" : "#222";
          $(html).css({
              "background-color": bgColor,
              "border-color": "#ccc",
              "border-width": "0px 0px 1px 0px",
              "border-style": "solid",
          });
          $("#docs").append(html);
      }
      $("#docs").append("<h2>Properties</h2>");
      for (var key in Alive.docs[obj].properties) {
          var html = $("<div style='padding-top:5px'>" + Alive.docs[obj].properties[key] + "</div>");
          var bgColor = count++ % 2 === 0 ? "#222" : "#000";
          $(html).css({
              "background-color": bgColor,
              "border-color": "#ccc",
              "border-width": "0px 0px 1px 0px",
              "border-style": "solid",
          });
          $("#docs").append(html);
      }
  },
  toggleSidebar : function() {
    console.log("DOCS");
    $('#sidebar').toggle();
    if ($("#sidebar").css("display") == "none") {
      $('.CodeMirror').css("width", "100%");
      //$('.CodeMirror-scroll').css("width", "100%");
      $('#console').css("width", "100%");
    } else {
      //if (typeof Gibber.codeWidth !== "undefined") { //if docs/editor split has not been resized
        $(".CodeMirror").width(500);
        $("#sidebar").width($("body").width() - $(".CodeMirror").outerWidth() - 8);
        $("#sidebar").height($(".CodeMirror").outerHeight());
        // 
        // $("#resizeButton")
        //     .css({
        //     position: "absolute",
        //     display: "block",
        //     top: $(".header").height(),
        //     left: Gibber.codeWidth,
        // });
        //}
    }
  },
  connected : false,
};

Storage.prototype.setObject = function(key, value) {
    this.setItem(key, JSON.stringify(value));
}

Storage.prototype.getObject = function(key) {
    var value = this.getItem(key);
    return value && JSON.parse(value);
}

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

window.save = function(code) {
    var scripts;
    if (typeof localStorage.scripts === "undefined") {
        scripts = {};
    } else {
        scripts = localStorage.getObject("scripts");
    }
    var name = window.prompt("Enter name for file");
    if(name !== null && name !== "") {
      scripts[name] = code;
      localStorage.setObject("scripts", scripts);
    }
};

window.load = function(fileName) {
    console.log("LOADING ", fileName);
    var scripts = localStorage.getObject("scripts"),
        code = null;

    if (scripts != null) {
        if (typeof scripts[fileName] !== "undefined") {
            code = scripts[fileName];
        }
    }
    if (code != null) {
        window.editor.setValue(code);
    } else {
        console.log("The file " + fileName + " is not found");
    }
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
	
	$("#ip").text(remoteIP);
	
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

		return sharejs.open(docName, "text", function(error, newDoc) {

			if (error) {
				console.error(error);
				return;
			}
			currentFile = "a.l.i.v.e";//newDoc.name;
			console.log("opening: " + currentFile)
			$("#filename").text(currentFile);
			doc = newDoc;
			//if( doc.getLength() == 0 ){
			//	console.log("read: "+currentFile)
			//	slaveSocket.emit('cmd', 'read ' + currentFile);
			//}else{
				doc.attach_codemirror(window.editor);
				console.log("attach: " + currentFile)
			//}
			
		});
	};

	// remoteIP is provided by the web server when the page is served
	slaveSocket = io.connect("http://" + remoteIP + ":8081/");	

	slaveSocket.on('handshake', function (response) {
		console.log("HANDSHAKE : ", response.data);
    
    if(Alive.connected) {
      var text = window.editor.getValue();
      window.editor.setValue('');
      
      setTimeout( function() { window.editor.setValue(text); }, 250);
    }
    
    Alive.connected = true;
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
						//connection = setDoc(name);

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
	
	slaveSocket.on('console', function(msg) {
    console.log("DATA");
    console.log(msg.msg);
    text = msg.msg.replace(/\n/g, "<br>");
		$("#_console").append($("<span style='color:#fff'>"+text+"</span><br>"));
		//$("#consoleContainer").scrollTop($("#consoleContainer")[0].scrollHeight);
    $("#_console").scrollTop($("#_console")[0].scrollHeight);
	});

	slaveSocket.on('err', function(msg) {
		$("#_console").append($("<span style='color:#f00'>"+msg.msg+"</span><br>"));
		$("#_console").scrollTop($("#_console")[0].scrollHeight);
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

    var connection = setDoc('cm');  // Hooking ShareJS and CodeMirror for the first time.

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
	// window.editor.setOption("mode", "javascript");
	// window.editor.setOption("mode", "clike");
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
  
	var flashblock = function(cm, pos1, pos2) {
	
		var sel = editor.markText(pos1, pos2, "highlightLine");
		window.setTimeout(function() { sel.clear(); }, 250);
		
		
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
	
	var executeCode = function(cm) {
		var v = cm.getSelection();
		var pos = null;
		if (v === "") {
			pos = cm.getCursor();
			v = cm.getLine(pos.line);
		}
		flash(cm, pos);
		slaveSocket.emit('execute', {code:v});
	};
	
	var executeCodeBlock = function(cm) {
		var v = cm.getSelection();
		var pos = null;
		if (v === "") {
			// try to select the containing block
			pos = cm.getCursor();
			var startline = pos.line;
			var endline = pos.line;
			while (startline > 0 && cm.getLine(startline) !== "") {
				startline--;
			}
			while (endline < cm.lineCount() && cm.getLine(endline) !== "") {
				endline++;
			}
			var pos1 = { line: startline, ch: 0 }
			var pos2 = { line: endline, ch: 0 }
			v = cm.getRange(pos1, pos2);
			slaveSocket.emit('execute', {code:v});
			flashblock(cm, pos1, pos2);
		} else {
			slaveSocket.emit('execute', {code:v});
			flash(cm, pos);
		}
	};

	var clearDoc = function(cm) {
		console.log("CLEARING DOC");
		var l = cm.getValue().length;
		cm.setValue("");
		doc.del(0, l);
	};
  
	CodeMirror.keyMap.alive = {
		fallthrough : "default",
		"Ctrl-Enter": executeCode,
		"Cmd-Enter": executeCode, 
		"Ctrl-Alt-Enter": executeCodeBlock,
		"Cmd-Alt-Enter": executeCodeBlock,
		"Cmd-Backspace": clearDoc,   
		//"Cmd-S": editor_save,
		//"Ctrl-S": editor_save,
		"Ctrl-S"  : function() { save(window.editor.getValue()) },
		"Cmd-S"   : function() { save(window.editor.getValue()) }, 
		"Ctrl-L"  : load,
		"Cmd-L"   : function(cm) {
			var name = window.prompt("enter name of file to load:")
			load(name);
		},
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
	
	$("#docsBar").mousedown( function(e) {
		$("body").css("-webkit-user-select", "none");
		
		$(window).mousemove(function(e) {
			if(e.pageX < $("body").width()) {
				$("#sidebar").width($("body").width() - e.pageX);
				$(".CodeMirrow").width( $("body").width() - $("#sidebar").width());
				//$("#right").offset({left:e.pageX});
				
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
	
	$("#demo").mousedown( function(e) {
		// paste in a demo script.
		var v = "demo()";
		slaveSocket.emit('execute', {code:v});
	});
	
	$("#panic").mousedown( function(e) {
		// paste in a demo script.
		var v = "panic()";
		slaveSocket.emit('execute', {code:v});
	});
	
	$("#relaunch").mousedown (function(e) {
		slaveSocket.emit('relaunch');
	});
  
	$("#docsButton").mousedown( function(e) {
    Alive.toggleSidebar();
  });
  
  $("#searchButton").click( function(e) {
      Alive.displayDocs($("#docsSearchInput").val());
  });
  $("#tocButton").click( function(e) {
      Alive.displayTOC();
  });
  $("#closeSidebarButton").click( function(e) {
      Alive.toggleSidebar();
  });
  
  $.getJSON("/js/documentation_output.js", function(data, ts, xgr) {
      Alive.docs = data;

      var tags = [];
      Alive.toc = {};
      for (var key in Alive.docs) {
          var obj = Alive.docs[key];
          tags.push({
              text: key,
              obj: key,
              type: "object",
              class: obj.key,
          });
          if (typeof Alive.toc[obj.type] === "undefined") {
              Alive.toc[obj.type] = [];
          }
          Alive.toc[obj.type].push(key);

          if (typeof obj.methods !== "undefined") {
              for (var method in obj.methods) {
                  tags.push({
                      text: method + "( " + key + " )",
                      obj: key,
                      type: "method",
                      name: method,
                  });
              }
          }
          if (typeof obj.properties !== "undefined") {
              for (var prop in obj.properties) {
                  tags.push({
                      text: prop + "( " + key + " )",
                      obj: key,
                      type: "property",
                      name: prop,
                  });
              }
          }
      }

      Alive.tags = tags;
      Alive.displayTOC();
      //Alive.Environment.displayDocs("Seq");
  });
});
