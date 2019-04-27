class ExtractorCgi {

	public function new(name: String, basepath: String) {
		this.name = name;
		this.basepath = basepath;
	}

	// Extract texts for editing
	function extractTextsHeader() {
		header("Texts in " + name);

		pr(
		'<script>
		function escapeRegexp(text) {
			return text.replace(/[-[\\]{}()*+?.,\\^$|#\\s]/g, "\\\\$&");
		}

		function escapeForPost(s) {
			s = s.replace(new RegExp(escapeRegexp("\\\\\\\\x27"), "g"), "\'");
			s = s.replace(new RegExp(escapeRegexp("\\\\\\\\x22"), "g"), "\\\"");
			s = s.replace("/\\\\\\\\/g", "\\\\");
			s = s.replace(new RegExp(escapeRegexp("\\\\\\\\r\\\\\\\\n"), "g"), "\\\\n");

			return s;
		}

		function noChanges(id) {
			ta = document.getElementById("a" + id);
			t = document.getElementById("f" + id).value;
			return ta.value.replace("\\r\\n", "\\n") == t;
		}

		function starVisibility(id) {
			star = document.getElementById("star" + id);
			star.style.visibility = (noChanges(id) ? "hidden" : "visible");
		}

		function commit(id) {
			if (noChanges(id)) {
				alert("Nothing to commit");
				return;
			}

			var ta = document.getElementById("a" + id);
			var v = escapeForPost(ta.value);
			var t = escapeForPost(document.getElementById("f" + id).value);
			var r = document.getElementById("__revision__").value;

			var request = window.XMLHttpRequest ? new XMLHttpRequest() : new ActiveXObject("MSXML2.XMLHTTP.3.0");
			request.open("POST", "flow.n?operation=settext&name=' + escape(name) + '&id=" + encodeURIComponent(id) + "&v=" + encodeURIComponent(v) + "&t=" + encodeURIComponent(t) + "&r=" + encodeURIComponent(r) , true);
			request.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
			request.onreadystatechange = function() {
				var done = 4, ok = 200;
				if (request.readyState == done && request.status == ok) {
					if (request.responseText != null && request.responseText.substr(0, 2) == "OK") {
						document.getElementById("f" + id).innerHTML = "<font color=#008000>" + df + "</font>";
					} else {
						alert("No luck: " + request.responseText);
					}
				}
			};
			request.send(null);
			document.getElementById("f" + id).value = v;
			starVisibility(id);
		}

		</script>');
	}

	public function prepare(): Bool {
		extractTextsHeader();
		Sys.println("Retrieving texts...<br/><br/>");

		var r = updateSvn(true);
		if (r != "") {
			Sys.println(r);
			return false;
		}

		return true;
	}
	
	public function extractTexts(module : Module) : Bool {
		Errors.get().doTrace = false; // type errors etc. are not interesting when extracting texts for editing
		var interpreter = modules.linkAst(module);
		var extractor = new Extractor(modules, interpreter, new Map());
		var strings = extractor.extractAllStrings();

		var filesToSkip = [ "aspects", "runtime", "transforms", "gui", "fillin", "probes", "diffscheme", "renderform", "debugger", "doublemetaphone", "selfrating" ];

		pr('<input id="__revision__" name="__revision__" type="hidden" value="' + revision + '"/>');
		
		pr('<table><tr>');
		var currentFile = "";
		var i = 0;
		for (s in strings) {
			// Heuristic to filter out irrelevant strings
			if (s.text.length > 2 && s.text.indexOf(" ") != -1 && s.text.charAt(0) != "<" && s.text.charAt(0) != "\"" && s.text.indexOf("&#") == -1) {
				var file = getFile(s.positions[0]);
				if (file != currentFile) {
					currentFile = file;
					for (f in filesToSkip) {
						if (f == file) {
							currentFile = "";
							break;
						}
					}
					
					if (currentFile != "") {
						pr('<tr><th colspan="2">' + escape(file) + '</th></tr>');
					}
				}
				
				if (currentFile != "") {
					pr('<tr><td>');
					printText(i, s);
					pr('</td></tr>');
					/*
					var sep = "";
					for (po in s.positions) {
						pr(sep + modules.positionToString(po));
						sep = ";";
					}
					pr('</td></tr>');
					*/
					pr('</tr>');
				}
			}
			++i;
		}
		pr('</table>');
		return true;
	}

	function getFile(pos : Position) : String {
		var slash = pos.f.lastIndexOf("/") + 1;
		return pos.f.substr(slash, pos.f.length - slash - 5);
	}
	
	function printText(id : Int, s : { text : String, positions : Array<Position> } ) {
		pr(
		'<form>' 
		+ '<input id="f' + id + '" type="hidden" value="' + escapeAttribute(s.text) + '" />'
		+ '<textarea class="resizable" id="a' + id + '" onkeyup="starVisibility(' + id + ')">' 
		+ escape(s.text) 
		+ '</textarea>'
		+ '<span id="star' + id + '" style="visibility:hidden">*</span>'
		+ '<input type="button" value="Submit" class="submit" onclick="commit(' + id + ')" />'
		+ '</form>' 
		);
	}
	
	
	// Change text in code
	
	public function settext(module : Module) : Bool {
		var id = Std.parseInt(FlowCgi.getParam("id", ""));
		var text = unescapePost(FlowCgi.getParam("t", "")); 
		var newText = FlowCgi.getParam("v", "");

		Errors.get().doTrace = false; // type errors etc. are not interesting when extracting texts for editing
		var interpreter = modules.linkAst(module);
		var extractor = new Extractor(modules, interpreter, new Map());
		var strings = extractor.extractAllStrings();
		
		var filesToCommit = new Map();
		var i = 0;
		for (s in strings) {
			if (s.text == text) {
				if (i == id) {
					if (!replaceText(newText, s.positions, filesToCommit)) {
						pr('Someone changed the texts at the same time. Please refresh and make your changes again');
						return true;
					}
					var result = commitFiles(filesToCommit);
					if (result == "") {
						pr('OK');
						return true;
					} else {
						pr('Could not commit:\n' + result);
						return false;
					}
				} else {
					pr('Someone changed the texts at the same time. Please refresh and make your changes again');
					return true;
				}
			}
			++i;
		}			
		pr('Could not find the relevant text. Someone probably changed the text already. Please refresh and make any changes again.');
		return true;
	}
	
	function replaceText(text : String, positions : Array<Position>, filesToCommit : Map<String,Bool>): Bool {
		// Find the positions file by file
		var places = new Map<String,Array<Position>>();
		for (pos in positions) {
			var file = pos.f;
			var ex = places.get(file);
			if (ex == null) {
				ex = [ ];
			}
			ex.push(pos);
			places.set(file, ex);
		}
		
		var escapedText = escapeFlow(text);
		var ok = true;
		
		// Next, sort the positions in reverse
		for (k in places.keys()) {
			var v : Array<Position> = places.get(k);
			v.sort(function(p1, p2) {
				return 
					if (p1.s < p2.s) 1;
					else if (p1.s == p2.s) 0
					else -1;
			});
			

			// Then do the changes
			var filename = basepath + "/" + k;
			filesToCommit.set(filename, true);
			try {
				var contents = sys.io.File.getContent(filename);
				for (p in v) {
					var loc = modules.positionToFileAndBytes(p);
					var before = contents.substr(0, loc.start);
					var after = contents.substr(loc.start + loc.bytes);
					contents = before + "\"" + escapedText + "\"" + after;
				}
				if (true) {
					var save = sys.io.File.write(filename, true);
					save.writeString(contents);
					save.close();

					// now checking for consistency - that file is still parsed
					ok = modules.parseFileAndImports(filename, function (m) { return true; });
				}
			} catch (e : Dynamic) {
				trace(filename);
				trace(e);
			}

			if (!ok) break;
		}

		return ok;
	}

	function revertSvn(): String {
		var args = [ "revert", "-R", basepath ];
		return runSvn(args);
	}
	
	function updateSvn(clean: Bool) : String {
		// revert changes for clean update
		if (clean && isProduction()) {
			revertSvn();
		}
			
		var args = [ "update", "--non-interactive", basepath ];
		var svnResult = runSvn(args);
		grantGroupAccess();
		getRevision();

		return svnResult;
	}

	function getRevision() : String {
		var args = [ "info", "--xml", basepath ];
		var xml = Xml.parse(runSvn(args, true));
		var fast = new haxe.xml.Fast(xml.firstElement());

		revision = fast.node.entry.att.revision;

		return revision;
	}


	function grantGroupAccess() {
		if (isProduction()) {
			runProcess("sudo", ["-u", "picupload", "/bin/bash", "-c", "/var/flow/grant.sh"], false);
		}
	}

	function commitFiles(fileHash : Map<String,Bool>) : String {
		// always update before committing
		updateSvn(false);
		// now proceed with updating
		var commandLine = "svn";
		var files = [ ];
		for (k in fileHash.keys()) {
			files.push(k);
		}
		return commit(files, false);
	}

	function commit(files : Array<String>, allowCleanup: Bool) : String {
		var args = [ "commit", "--non-interactive", "-m", 'Webchanges' ];
		args = args.concat(files);
		var errors = runSvn(args);
		if (errors.indexOf("locked") != -1) {
			if (allowCleanup) {
				var cleanargs =  [ "cleanup", basepath ];
				var cleanresult = runSvn(cleanargs);
				return cleanresult + runSvn(args);
			} else {
				Sys.sleep(20);
				commit(files, true);
			}
		}
		return errors;
	}
	
	function runSvn(args : Array<String>, ?stdout: Bool) : String {
		Sys.setCwd(basepath);
		var svn = "svn";
		if (isDevelopment()) {
			// http://www.sliksvn.com/en/download
			svn = 'C:\\Progra~1\\SlikSvn\\bin\\svn.exe';
			if (!sys.FileSystem.exists(svn)) {
				Sys.println("You need SlikSvn to commit changes on Windows. Download and install from http://www.sliksvn.com/en/download");
			}
			args = [ "--username", "flowprocessor", "--password", "X\\s9)68;l;", "--no-auth-cache" ].concat(args);
		} else {
			svn = "sudo";
			args = [ "-u", "picupload", "svn", "--username=flowprocessor", "--password", "X\\s9)68;l;", "--config-dir=/home/picupload/.subversion" ].concat(args);
		}

		return runProcess(svn, args, true == stdout);
	}

	function runProcess(name: String, args: Array<String>, stdout: Bool) {
		var process = new sys.io.Process(name, args);
		var pid = process.getPid();
		process.stdin.close();
		var result = process.exitCode();
		return readAll(stdout ? process.stdout : process.stderr);
	}
	
	function readAll(i : haxe.io.Input) : String {
		var r = "";
		try {
			while (true) {
				var l = i.readLine();
				if (l == "") {
					return r;
				}
				r += l + "\n";
			}
		} catch (e : Dynamic ) {
		}
		return r;
	}

	function header(title : String) {
		pr("<html><title>" + escape(title) + "</title>");
		pr(
			' <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>\n' +
			' <style type="text/css">body, th, td {font-family: "Arial", "sans";}\n' +
			' body {font-size: 12pt; margin-left: 5%;}\n' +
			' td {font-size: 12pt; padding: 2px 8px 2px 4px;}\n' + // clockwise from top, i.e., top, right, bottom, left
			' th.line { margin: 0px; width:1px; padding: 0px; background-color: #ffffff; }\n' +
			' td.line { margin: 0px; width:1px; padding: 0px; background-color: #ffffff; }\n' +
			' table {border-collapse: collapse; margin: 0px; width:100%; }\n' +
			' th {font-size: 12pt; background-color: #808080; margin: 0px; padding: 4px 8px 4px 8px; color: #ffffff;}\n' +
			' div.grippie { background:#EEEEEE no-repeat scroll center 2px;' +
			' border-color:#DDDDDD; border-style:solid; border-width:0pt 1px 1px;' +
			' cursor:s-resize; height:9px; overflow:hidden; ' +
			' }\n' +
			' .resizable-textarea textarea { display:block; margin-bottom:0pt; width:95%;height: 20%; }\n' +
			' input.submit { width: 5em; float: none; margin-left: 10px; }\n' +
			' </style>'
		);
		// resizable textarea
		pr(
		'<script type="text/javascript" src="http://code.jquery.com/jquery-latest.js"></script>\n' +
		'<script type="text/javascript" src="jquery.textarearesizer.compressed.js"></script>\n' +
		'<script type="text/javascript">
		  $(document).ready(function() {
		    $(\'textarea.resizable:not(.processed)\').TextAreaResizer();
		    });
		</script>');

	}
	
	function pr(s : String) : Void {
		Sys.println(s);
	}
	function escape(s : String) : String {
		s = StringTools.htmlEscape(s);
		s = StringTools.replace(s, "\"", "&quot;");
		return s;
	}
	function escapeAttribute(s: String): String {
		s = escape(s);
		s = StringTools.replace(s, "\n", "\\n");
		s = StringTools.replace(s, "\t", "\\t");

		return s;
	}
	
	function escapeJs(s : String) : String {
		s = StringTools.replace(s, "\'", "\\x27");
		s = StringTools.replace(s, "\"", "\\x22");
		s = StringTools.replace(s, "\\", "\\\\");
		s = StringTools.replace(s, "\n", "\\\\n");
		s = StringTools.replace(s, "\t", "\\\\t");
		return s;
	}
	
	function escapeFlow(s : String) : String {
		s = StringTools.replace(s, "\"", "\\\"");
		return s;
	}

	function unescapePost(s: String): String {
		s = StringTools.replace(s, "\\n", "\n");
		s = StringTools.replace(s, "\\t", "\t");

		return s;
	}
	
	function isProduction() {
		return Sys.systemName() == "Linux";
	}

	function isDevelopment() {
		return Sys.systemName() == "Windows";
	}

	// modules collection
	public var modules: Modules;
	// svn revision from last update
	var revision: String;

	// name of module to process
	var name: String;
	// absolute path to .flow files
	var basepath: String;
}