'use strict';
// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';
import * as path from 'path';
import { spawn, ChildProcess } from 'child_process';
import * as fs from "fs";
import * as os from "os";
import * as PropertiesReader from 'properties-reader';
import {
    LanguageClient, LanguageClientOptions, ServerOptions, TransportKind, RevealOutputChannelOn,
} from 'vscode-languageclient';
import * as tools from "./tools";
import * as updater from "./updater";
import * as simplegit from 'simple-git/promise';
import * as notebook from './notebook';
//import { performance } from 'perf_hooks';
const isPortReachable = require('is-port-reachable');

interface ProblemMatcher {
    name: string,
    pattern: {
        regexp: string,
        file: number,
        line: number,
        column: number,
        message: number
    }
}

enum LspKind { Flow = 1, JS = 2, Flow_lsp = 3, None = 4 }

let childProcesses = [];
let client: LanguageClient = null;
let flowChannel : vscode.OutputChannel = null;
let serverChannel : vscode.OutputChannel = null;
let flowRepoUpdateChannel : vscode.OutputChannel = null;
let counter = 0; // used to silence not finished jobs when new ones got started

let serverStatusBarItem: vscode.StatusBarItem;

let httpServer : ChildProcess;
let httpServerOnline : boolean = false;
let clientKind = LspKind.None;

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {
    // Use the console to output diagnostic information (console.log) and errors (console.error)
    // This line of code will only be executed once when your extension is activated
    console.log('Flow extension active');
	serverStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
	serverStatusBarItem.command = 'flow.toggleHttpServer';
	let reg_com = (name, com) => vscode.commands.registerCommand(name, com);
    context.subscriptions.push(
        serverStatusBarItem,
		reg_com('flow.compile', compile),
		reg_com('flow.GetFlowCompiler', getFlowCompilerFamily),
		reg_com('flow.compileNeko', compileNeko),
		reg_com('flow.run', runCurrentFile),
		reg_com('flow.updateFlowRepo', () => { updateFlowRepo(context); }),
		reg_com('flow.startHttpServer', startHttpServer),
		reg_com('flow.stopHttpServer', stopHttpServer),
		reg_com('flow.toggleHttpServer', toggleHttpServer),
		reg_com('flow.flowConsole', flowConsole),
		reg_com('flow.execCommand', execCommand),
		reg_com('flow.createNotebook', notebook.createNotebook),
		vscode.workspace.onDidChangeConfiguration(handleConfigurationUpdates(context)),
		vscode.notebook.registerNotebookContentProvider('flow-notebook', new notebook.FlowNotebookProvider()),
		vscode.notebook.registerNotebookKernelProvider({filenamePattern: "*.{noteflow,flow}"}, new notebook.FlowNotebookKernelProvider())
	);
	notebook.startExecutor();

    flowChannel = vscode.window.createOutputChannel("Flow output");
	flowChannel.show();

	checkHttpServerStatus(true);
	setInterval(checkHttpServerStatus, 3000, false);

	// Create an LSP client
	updateLspClient(context);

    updater.checkForUpdate();
    updater.setupUpdateChecker();
    serverStatusBarItem.show();
}

function checkHttpServerStatus(initial : boolean) {
	const port = vscode.workspace.getConfiguration("flow").get("portOfHttpServer");
	isPortReachable(port, {host: 'localhost'}).then(
		(reacheable : boolean) => {
			if (reacheable) {
				outputHttpServerMemStats();
				httpServerOnline = true;
			} else {
				httpServer = null;
				httpServerOnline = false;
				showHttpServerOffline();
				if (initial) {
					// launch flowc server at startup
					let autostart = vscode.workspace.getConfiguration("flow").get("autostartHttpServer");
					if (autostart) {
						startHttpServer();
					}
				}
			}
		}
	);
}

function outputHttpServerMemStats() {
	client.sendRequest("workspace/executeCommand", { 
		command : "command", 
		arguments : ["server-mem-info=1", "do_not_log_this=1"]
	}).then(
		(out : string) => {
			let msg_start = out.indexOf("Used:");
			let msg_end = out.indexOf("\n", msg_start);
			let mem_stats = out.substr(msg_start, msg_end - msg_start);
			showHttpServerOnline(mem_stats);
		},
		(err : any) => showHttpServerOffline()
	);
}

function flowConsole() {
	let file = getPath(vscode.window.activeTextEditor.document.uri);
	let dir = path.dirname(file);
	let terminal = vscode.window.createTerminal("Flow console");
	terminal.sendText("cd " + dir, true);
	terminal.sendText("flowc1 repl=1 file=" + file, true);
	terminal.show();
}

function toggleHttpServer() {
    if (!httpServerOnline) {
		startHttpServer();
    } else {
		stopHttpServer();
	}
}

function startHttpServer() {
    if (!httpServerOnline) {
		if (!serverChannel) {
			serverChannel = vscode.window.createOutputChannel("Flow server");
			serverChannel.show();
		}
		httpServer = tools.launchFlowcHttpServer(
			getFlowRoot(), 
			showHttpServerOnline, 
			showHttpServerOffline,
			(msg : any) => serverChannel.appendLine(msg)
		);
		httpServerOnline = true;
    }
}

function stopHttpServer() {
	if (httpServerOnline) {
		tools.shutdownFlowcHttpServer().on("exit", (code, msg) => httpServer = null);
		httpServerOnline = false;
	}
}

function updateLspClient(context: vscode.ExtensionContext) {
	let kind = LspKind[vscode.workspace.getConfiguration("flow").get("lspMode") as keyof typeof LspKind];
	setLspClient(context, kind);
}

function setLspClient(context: vscode.ExtensionContext, kind : LspKind) {
    if (clientKind != kind) {
        if (client) {
            client.sendNotification("exit");
            client.stop();
        }
		client = null;
		clientKind = kind;
		if (clientKind != LspKind.None) {
			// The debug options for the server
			let debugOptions = { execArgv: ["--nolazy", "--inspect=6009"] };

			// If the extension is launched in debug mode then the debug server options are used
			// Otherwise the run options are used
			let serverOptions: ServerOptions;
			switch (clientKind) {
				case LspKind.Flow: {
					serverStatusBarItem.show();
					serverOptions = {
						command: process.platform == "win32" ? 'flowc1.bat' : 'flowc1',
						args: ['server-mode=console'],
						options: { detached: false }
					}
					break;
				}
				case LspKind.Flow_lsp: {
					serverStatusBarItem.show();
					serverOptions = {
						command: process.platform == "win32" ? 'flowc1_lsp.bat' : 'flowc1_lsp',
						args: [],
						options: { detached: false }
					}
					break;
				}
				case LspKind.JS: {
					// The server is implemented in node
					let serverModule = context.asAbsolutePath(path.join('out', 'flow_language_server.js'));
					serverOptions = {
						run : { module: serverModule, transport: TransportKind.ipc },
						debug: { module: serverModule, transport: TransportKind.ipc, options: debugOptions }
					}
					break;
				}
			}
			// Options to control the language client
			let clientOptions: LanguageClientOptions = {
				// Register the server for plain text documents
				documentSelector: [{scheme: 'file', language: 'flow'}],
				outputChannel: flowChannel,
				revealOutputChannelOn: RevealOutputChannelOn.Info,
				uriConverters: {
					// FIXME: by default the URI sent over the protocol will be percent encoded (see rfc3986#section-2.1)
					//        the "workaround" below disables temporarily the encoding until decoding
					//        is implemented properly in clangd
					code2Protocol: (uri: vscode.Uri) : string => uri.toString(true),
					protocol2Code: (uri: string) : vscode.Uri => vscode.Uri.parse(uri)
				}
			}

			// Create the language client and start the client.
			client = new LanguageClient('flow', 'Flow Language Server', serverOptions, clientOptions);
			// Start the client. This will also launch the server
			client.start();
			client.onReady().then(() => {
				sendOutlineEnabledUpdate();
			});
		}
    }
}

function showHttpServerOnline(mem_stats : string = null) {
	if (mem_stats) {
		serverStatusBarItem.text = `$(vm-active) flow http server: online (` + mem_stats + ")"; 
	} else {
		serverStatusBarItem.text = `$(vm-active) flow http server: online`; 
	}
}

function showHttpServerOffline() {
    serverStatusBarItem.text = `$(vm-outline) flow: http server: offline`;
}

// this method is called when your extension is deactivated
export function deactivate() {
	// First, shutdown Flowc server, if it is owned by current vscode instance
	if (httpServer) {
		tools.shutdownFlowcHttpServer().on("exit", (code, msg) => httpServer = null);
	}
	notebook.killExecutor();
    // kill all child processed we launched
    childProcesses.forEach(child => { 
        child.kill('SIGKILL'); 
        if (os.platform() == "win32")
            spawn("taskkill", ["/pid", child.pid, '/f', '/t']);
    });
    if (!client) {
        return undefined;
    } else {
        client.sendNotification("exit");
        return client.stop()
    }
}

export async function updateFlowRepo(context: vscode.ExtensionContext) {
    if (null == flowRepoUpdateChannel) {
        flowRepoUpdateChannel = vscode.window.createOutputChannel("Flow Update");
    }
    const flowRoot = getFlowRoot();
    if (!fs.existsSync(flowRoot)) {
        await vscode.window.showErrorMessage("Flow repository not found. Make sure flow.root parameter is set up correctly");
        return;
    }
    const git = simplegit(flowRoot);
    let status = await git.status();
    if (status.current != "master") {
        await vscode.window.showErrorMessage("Flow repository is not on master branch. Please switch to master to proceed.");
        return;
    }
    if (status.modified.length > 0 || status.created.length > 0 || status.deleted.length > 0) {
        await vscode.window.showErrorMessage("Flow repository has local changes. Please push or stash those before proceeding");
        return;
    }
    flowRepoUpdateChannel.show(true);
    flowRepoUpdateChannel.appendLine("Updating flow repository at " + flowRoot);

    let shutdown_http_and_pull = (kind : LspKind) => {
        let startHttp = false;
        if (httpServerOnline) {
            startHttp = true;
            flowRepoUpdateChannel.append("Shutting down HTTP flowc server... ");
            stopHttpServer();
            flowRepoUpdateChannel.appendLine("HTTP server is shutdown.");
        }
        pullAndStartServer(git, context, kind, startHttp);
    }

    if (clientKind == LspKind.Flow) {
        flowRepoUpdateChannel.append("Shutting down flow LSP server... ");
        setLspClient(context, LspKind.None);
        shutdown_http_and_pull(LspKind.Flow);
    } else {
        shutdown_http_and_pull(clientKind);
    }
}

async function pullAndStartServer(git, context : vscode.ExtensionContext, kind : LspKind, startHttp : boolean) {
    flowRepoUpdateChannel.appendLine("Starting git pull --rebase... ");
    try {
        const pullResult = await git.pull('origin', 'master', {'--rebase' : 'true'});
        flowRepoUpdateChannel.appendLine(JSON.stringify(pullResult.summary));
    } catch (e) {
        flowRepoUpdateChannel.appendLine("Git pull failed:");
        flowRepoUpdateChannel.appendLine(e);
        vscode.window.showInformationMessage("Flow repository pull failed.");
    }

    if (startHttp) {
        flowRepoUpdateChannel.append("Starting HTTP flowc server... ");
        startHttpServer();
        flowRepoUpdateChannel.appendLine("HTTP server is started.");
    }
    if (kind == LspKind.Flow) {
        flowRepoUpdateChannel.append("Starting flow LSP server... ");
        setLspClient(context, LspKind.Flow);
    }
}

function sendOutlineEnabledUpdate() {
	let config = vscode.workspace.getConfiguration("flow");
	const outlineEnabled = config.get("outline");
	client.sendNotification("outlineEnabled", outlineEnabled);
}

function handleConfigurationUpdates(context) {
    return (e) => {
        if (e.affectsConfiguration("flow.outline")) {
            sendOutlineEnabledUpdate();
        }
        if (e.affectsConfiguration("flow.lspMode")) {
			updateLspClient(context);
        }
    }
}

const homedir = process.env[(process.platform == "win32") ? "USERPROFILE" : "HOME"];

function expandHomeDir(p : string) : string {
	if (!p) return p;
	if (p == "~") return homedir;
	if (p.slice(0, 2) != "~/") return p;
	return path.join(homedir, p.slice(2));
}

function getPath(uri : string | vscode.Uri) : string {
	return expandHomeDir(uri instanceof vscode.Uri ? uri.fsPath : uri.startsWith("file://") ? vscode.Uri.parse(uri).fsPath : uri);
}

function resolveProjectRoot(uri : string | vscode.Uri) : string {
	const config = vscode.workspace.getConfiguration("flow");

	if (uri != null) {
		let dir = uri != null ? getPath(uri) : path.resolve(getPath(config.get("projectRoot")), "flow.config");

		while (dir != path.resolve(dir, "..")) {
			dir = path.resolve(dir, "..");

			if (fs.existsSync(path.resolve(dir, "flow.config"))) {
				return dir;
			}
		}
	}

	return getPath(config.get("root"));
}

interface CommandWithArgs { 
    cmd: string, 
    args: string[], 
    matcher: string
}

function compile() {
    compileCurrentFile("", ["verbose=1"]); // empty means default compiler
}

function compileNeko() {
    compileCurrentFile("nekocompiler");
}

function runCurrentFile() {
    processFile(function (flowBinPath, flowpath) {
        return { 
            cmd : path.join(flowBinPath, "flowcpp"), 
            args : [flowpath],
            matcher: 'flowc'
        }
    }, false);
}

function compileCurrentFile(compilerHint: string, extra_args : string[] = []) {
	let use_lsp = vscode.workspace.getConfiguration("flow").get("lspMode") != "None";
    processFile(
		function(flowBinPath, flowpath) { 
        	return getCompilerCommand(compilerHint, flowBinPath, flowpath);
		}, 
		use_lsp, extra_args
	);
}

function getFlowRoot(): string {
    let config = vscode.workspace.getConfiguration("flow");
    return config.get("root");
}

function processFile(getProcessor : (flowBinPath : string, flowpath : string) => CommandWithArgs, use_lsp : boolean, extra_args : string[] = []) {
    let document = vscode.window.activeTextEditor.document;
    document.save().then(() => {
        let current = ++counter;
        flowChannel.clear();
        flowChannel.show(true);
        let flowpath: string = getFlowRoot();
        let rootPath = resolveProjectRoot(document.uri);
        let documentPath = path.relative(rootPath, document.uri.fsPath);
        let command = getProcessor(path.join(flowpath, "bin"), documentPath);
        flowChannel.appendLine("Current directory '" + rootPath + "'");
        let run_separately = () => {
            tools.run_cmd(command.cmd, rootPath, command.args, (s) => {
                // if there is a newer job, ignoring ones pending
                if (counter == current) {
                    flowChannel.append(s.toString());
                }
            }, childProcesses);
		}
		let kind2s = (kind : LspKind) => {
			switch (clientKind) {
				case LspKind.Flow:     return "flowc";
				case LspKind.Flow_lsp: return "flowc_lsp";
				case LspKind.JS:       return "Nodejs";
				case LspKind.None:     return "None";
			}
		}
		let run_on_server = (kind : LspKind) => {
			flowChannel.appendLine("Compiling '" + getPath(document.uri) + "' using " + kind2s(kind) + " server");
			//let start = performance.now();
			client.sendRequest("workspace/executeCommand", {
					command : "compile", 
					arguments: ["file=" + getPath(document.uri), "working_dir=" + rootPath].concat(extra_args)
				}
			).then(
				(out : any) => {
					// if there is a newer job, ignoring ones pending
					if (counter == current) {
						//flowChannel.appendLine("Execution of a request took " + (performance.now() - start) + " milliseconds.")
						flowChannel.appendLine(out);
					}
				}
			);
		}
        if (use_lsp) {
            if (!httpServerOnline) {
                flowChannel.appendLine("Caution: you are using a separate instance of flowc LSP server. To improve performance it is recommended to switch HTTP server on. Click the status in the lower right corner. Try \"flowc1 server-mode=http\" on the command line.");
            }
            switch (clientKind) {
                case LspKind.Flow: {
					run_on_server(clientKind);
					break;
				}
                case LspKind.Flow_lsp: {
					run_on_server(clientKind);
					break;
				}
                case LspKind.JS: {
                    flowChannel.appendLine("Compiling '" + getPath(document.uri) + "' using legacy " + kind2s(clientKind) + " server");
                    run_separately();
                    break;
                }
            }
        } else {
            flowChannel.appendLine("Running '" + command.cmd + " " + command.args.join(" ") + "'");
            run_separately();
        }
    });
}

function getCompilerCommand(compilerHint: string, flowbinpath: string, flowfile: string): 
    CommandWithArgs
{
    let compiler = compilerHint ? compilerHint : getFlowCompiler();
    let serverArgs = (compiler.startsWith("flowc") && !httpServerOnline) ? ["server=0"] : [];
    if (compiler == "nekocompiler") {
        return { cmd: "neko", args: [
            path.join(flowbinpath, "flow.n"), flowfile, "--dontlink"
        ], matcher: "flowc"};
    } else {
        // use 'flowc1' and 'flowcompiler1'
        return { cmd: path.join(flowbinpath, compiler), args: serverArgs.concat([
            "file=" + flowfile
        ]), matcher: compiler.startsWith("flowcompiler") ? "flowcompiler" : "flowc"};
    }
}

function getFlowCompiler(): string {
    let compilerBare = getFlowCompilerFamily();
    let backendOption: string = vscode.workspace.getConfiguration("flow").get("compilerBackend");
    if (compilerBare == "flowcompiler" || compilerBare == "flowc") {
        switch (backendOption) {
            case "auto": return compilerBare + "1";
            case "flowcpp": return compilerBare;
            case "java": return compilerBare + "1";
            case "manual":
            default: return compilerBare;
        }
    } else
        return compilerBare;
}

function getFlowCompilerFamily(): string {
    let flowConfig = readConfiguration();
    let config = vscode.workspace.getConfiguration("flow");
    // flow.config takes priority
    let flowcompiler = flowConfig.get("flowcompiler");
    // it can be '0' or 'false' which are valued values
    if (flowcompiler == null || typeof flowcompiler === 'undefined')
        flowcompiler = config.get("compiler") || "flowc";

    if (flowcompiler == "0" || flowcompiler == "false" || flowcompiler == "nekocompiler")
        return "nekocompiler";
    if (flowcompiler == "1" || flowcompiler == "true")
        return "flowcompiler";
    if (flowcompiler == "2")
        return "flowc";
    else 
        return flowcompiler.toString();
}

// reads configuration, defaults to global plugin configuration
function readConfiguration(): PropertiesReader.Reader {
    let configFile = path.join(vscode.workspace.rootPath, "flow.config");
    var reader = PropertiesReader(undefined);
    if (fs.existsSync(configFile))
        reader.append(configFile);
   
    return reader;
}

function execCommand() {
	flowChannel.show(true);
	let options: vscode.InputBoxOptions = { prompt: "Command and args: ", placeHolder: "" };
	vscode.window.showInputBox(options).then(value => {
		let val_arr = value.split(" ");
		if (val_arr.length > 0) {
			let file_arg = Array("file=" + vscode.window.activeTextEditor.document.uri.fsPath);
			let args = file_arg.concat(val_arr);
			client.sendRequest("workspace/executeCommand", { command : "command", arguments: args }).then(
				(out : string) => {
					flowChannel.appendLine(out);
				},
				(err : any) => {
					vscode.window.showErrorMessage(`command ${value} failed: ${err}`);
				}
			);
		}
	});
}
