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
} from 'vscode-languageclient/node';

import * as tools from "./tools";
import * as updater from "./updater";
import simpleGit from 'simple-git';
import * as notebook from './notebook';
//import { performance } from 'perf_hooks';
import editors from './editors';

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

let childProcesses = [];
let client: LanguageClient = null;
let flowChannel : vscode.OutputChannel = null;
let serverChannel : vscode.OutputChannel = null;
let flowRepoUpdateChannel : vscode.OutputChannel = null;
let counter = 0; // used to silence not finished jobs when new ones got started

let serverStatusBarItem: vscode.StatusBarItem;

let httpServer : ChildProcess;
let httpServerOnline : boolean = false;

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {
    // Use the console to output diagnostic information (console.log) and errors (console.error)
    // This line of code will only be executed once when your extension is activated
    console.log('Flow extension active');
	serverStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
	serverStatusBarItem.command = 'flow.toggleHttpServer';
	const reg_comm = (id: string, comm: any) => vscode.commands.registerCommand(id, comm);
    context.subscriptions.push(
		serverStatusBarItem,
    	reg_comm('flow.compile', compileCurrentFile),
    	reg_comm('flow.GetFlowCompiler', getFlowCompilerFamily),
    	reg_comm('flow.compileNeko', () => compileCurrentFile([], () => { }, "nekocompiler")),
    	reg_comm('flow.run', runCurrentFile),
    	reg_comm('flow.updateFlowRepo', () => updateFlowRepo(context)),
    	reg_comm('flow.startHttpServer', startHttpServer),
		reg_comm('flow.stopHttpServer', stopHttpServer),
		reg_comm('flow.toggleHttpServer', toggleHttpServer),
		reg_comm('flow.flowConsole', flowConsole),
		reg_comm('flow.execCommand', execCommand),
		reg_comm('flow.runUI', runUI),
		reg_comm('flow.restartLspClient', startLspClient),
		vscode.workspace.onDidChangeConfiguration(handleConfigurationUpdates()),
		vscode.workspace.registerNotebookSerializer('flow-notebook', new notebook.FlowNotebookSerializer()),
		new notebook.FlowNotebookController()
	);
	editors.forEach(editor => context.subscriptions.push(editor.register(context)));

    flowChannel = vscode.window.createOutputChannel("Flow output");
	flowChannel.show(true);
	serverChannel = vscode.window.createOutputChannel("Flow Language Server");

	// Create an LSP client
	startLspClient().then(() => {
		updater.checkForUpdate();
		updater.setupUpdateChecker();
		serverStatusBarItem.show();
	});
}

function runUI() {
	const document = vscode.window.activeTextEditor.document;
	const file_path = document.uri.fsPath;
	const file_name = path.basename(file_path, path.extname(file_path));
	const file_dir = path.dirname(file_path);
	const file_conf = findConfigDir();
	const html_file = file_conf ?
		path.join(file_conf, "www2", file_name + ".html") :
		path.join(file_dir, "www2", file_name + ".html");
	compileCurrentFile(["html=" + html_file],
		() => {
			const panel = vscode.window.createWebviewPanel(
				'flowUI',
				file_name + ".html",
				vscode.ViewColumn.One, {
					enableScripts: true
				}
			);
			panel.webview.html = fs.readFileSync(html_file).toString();
		}
	);
}

function checkHttpServerStatus(initial : boolean) {
	const port : number = vscode.workspace.getConfiguration("flow").get("portOfHttpServer");
	tools.isPortAvailable(port).then(
		(free : boolean) => {
			if (!free) {
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
	try {
		client.sendRequest("workspace/executeCommand", {
			command : "command",
			arguments : ["server-mem-info=1", "do_not_log_this=1"]
		}).then(
			(out : string) => {
				const lines = out.split("\n");
				const mem_stats = lines.find((line) => line.indexOf("free") != -1);
				showHttpServerOnline(mem_stats);
			},
			(err : any) => showHttpServerOffline()
		);
	} catch (e) {
		serverChannel.show(true);
		serverChannel.appendLine("Restarting flow LSP server because of error: " + e);
		startLspClient();
	}
}

function flowConsole() {
	let file = getPath(vscode.window.activeTextEditor.document.uri);
	let dir = path.dirname(file);
	let terminal = vscode.window.createTerminal("Flow console");
	terminal.sendText("cd " + dir, true);
	terminal.sendText("flowc1 repl=1 file=" + file, true);
	terminal.show(true);
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
		serverChannel.show(true);
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

async function stopLspClient() {
	if (client) {
		await client.stop().then(() => {
			serverChannel.appendLine("LSP server stopped");
			client = null;
		}, (error) => {
			serverChannel.show(true);
			serverChannel.appendLine("Error stopping LSP server: " + error);
		});
	}
}

async function startLspClient() {
	await stopLspClient();
	serverStatusBarItem.show();
	const serverOptions: ServerOptions = {
		command: process.platform == "win32" ? 'flowc1_lsp.bat' : 'flowc1_lsp',
		args: [],
		options: { detached: false }
	};
	// Options to control the language client
	let clientOptions: LanguageClientOptions = {
		// Register the server for plain text documents
		documentSelector: [{scheme: 'file', language: 'flow'}],
		outputChannel: serverChannel,
		revealOutputChannelOn: RevealOutputChannelOn.Info,
		uriConverters: {
			// FIXME: by default the URI sent over the protocol will be percent encoded (see rfc3986#section-2.1)
			//        the "workaround" below disables temporarily the encoding until decoding
			//        is implemented properly in clangd
			code2Protocol: (uri: vscode.Uri) : string => uri.toString(true),
			protocol2Code: (uri: string) : vscode.Uri => vscode.Uri.parse(uri)
		},
		markdown: {
			isTrusted: true,
			supportHtml: true
		}
	}

	// Create the language client and start the client.
	client = new LanguageClient('flow', 'Flow Language Server', serverOptions, clientOptions);
	// Start the client. This will also launch the server
	client.start();
	sendServerVerbosity();
	checkHttpServerStatus(true);
	setInterval(checkHttpServerStatus, 3000, false);
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
        return client.stop();
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
    const git = simpleGit(flowRoot);
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

    flowRepoUpdateChannel.append("Shutting down flow LSP server... ");
    await stopLspClient().then(() => {
        let startHttp = false;
        if (httpServerOnline) {
            startHttp = true;
            flowRepoUpdateChannel.append("Shutting down HTTP flowc server... ");
            stopHttpServer();
            flowRepoUpdateChannel.appendLine("HTTP server is shutdown.");
        }
        pullAndStartServer(git, context, startHttp);
    });
}

async function pullAndStartServer(git, context : vscode.ExtensionContext, startHttp : boolean) {
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
    flowRepoUpdateChannel.append("Starting flow LSP server... ");
    startLspClient();
}

function sendServerVerbosity() {
	client.sendRequest("workspace/executeCommand", {
		command : "setVerbose",
		arguments: ["verbose=" + tools.getVerboseParam()],
	}).catch((error) => {
		serverChannel.show(true);
		serverChannel.appendLine("Command error: " + error);
	});
}

function handleConfigurationUpdates() {
	return (event) => {
		if (event.affectsConfiguration("flow.compilerVerbose")) {
			sendServerVerbosity();
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

function runCurrentFile(extra_args : string[] = []) {
    processFile(
		function (flowBinPath, flowpath) {
			return {
				cmd : path.join(flowBinPath, "flowcpp"),
				args : [flowpath],
				matcher: 'flowc'
			}
		},
		false, extra_args
	);
}

function compileCurrentFile(extra_args : string[] = [], on_compiled : () => void = () => {}, compilerHint: string = "") {
	const use_lsp = vscode.workspace.getConfiguration("flow").get("lspMode") != "None";
    processFile(
		function(flowBinPath, flowpath) {
        	return getCompilerCommand(compilerHint, flowBinPath, flowpath);
		},
		use_lsp,
		extra_args,
		on_compiled
	);
}

function getFlowRoot(): string {
    const config = vscode.workspace.getConfiguration("flow");
	let root: string = config.get("root");
	if (!fs.existsSync(root)) {
		root = tools.run_cmd_sync("flowc1", ".", ["print-flow-dir=1"]).stdout.toString().trim();
		config.update("root", root, vscode.ConfigurationTarget.Global);
	}
	return root;
}

function processFile(
	getProcessor : (flowBinPath : string, flowpath : string) => CommandWithArgs,
	use_lsp : boolean,
	extra_args : string[] = [],
	on_compiled : () => void = () => { }
) {
	const document = vscode.window.activeTextEditor.document;
	const verbose = tools.getVerboseParam();
	if (verbose != "0") {
		extra_args.push("verbose=" + verbose);
	}
    document.save().then(() => {
        let current = ++counter;
        flowChannel.clear();
        flowChannel.show(true);
        let flowpath: string = getFlowRoot();
        let rootPath = resolveProjectRoot(document.uri);
        let documentPath = path.relative(rootPath, document.uri.fsPath);
        let command = getProcessor(path.join(flowpath, "bin"), documentPath);
		//flowChannel.appendLine("Current directory '" + rootPath + "'");
        let run_separately = () => {
            let proc = tools.run_cmd(command.cmd, rootPath, command.args.concat(extra_args), (s) => {
                // if there is a newer job, ignoring ones pending
                if (counter == current) {
                    flowChannel.append(s.toString());
                }
			}, childProcesses);
			proc.on("exit", on_compiled);
		}
        if (use_lsp) {
            if (!httpServerOnline) {
                flowChannel.appendLine("Caution: you are using a separate instance of flowc LSP server. To improve performance it is recommended to switch HTTP server on. Click the status in the lower right corner. Try \"flowc1 server-mode=http\" on the command line.");
			}
			//flowChannel.appendLine("Compiling '" + getPath(document.uri) + "'");
			//let start = performance.now();
			client.sendRequest("workspace/executeCommand", {
					command : "compile",
					arguments: ["file=" + getPath(document.uri), "working-dir=" + rootPath].concat(extra_args)
				}
			).then(
				(out : any) => {
					// if there is a newer job, ignoring ones pending
					if (counter == current) {
						//flowChannel.appendLine("Execution of a request took " + (performance.now() - start) + " milliseconds.")
						flowChannel.appendLine(out);
					}
					on_compiled();
				}
			);
        } else {
            flowChannel.appendLine("Running '" + command.cmd + " " + command.args.join(" ") + "'");
            run_separately();
        }
    });
}

function getCompilerCommand(compilerHint: string, flowbinpath: string, flowfile: string): CommandWithArgs {
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
	const conf_dir = findConfigDir();
	if (conf_dir) {
		return PropertiesReader(path.join(conf_dir, "flow.config"));
	} else {
		return PropertiesReader(null);
	}
}

// finds a closest flow.config file
function findConfigDir(dir: string = null): string {
	if (!dir) {
		const file_conf_dir = findConfigDir(path.dirname(vscode.window.activeTextEditor.document.uri.fsPath));
		if (file_conf_dir) {
			return file_conf_dir;
		} else if (vscode.workspace.workspaceFolders && vscode.workspace.workspaceFolders.length > 0) {
			return findConfigDir(vscode.workspace.workspaceFolders[0].uri.fsPath);
		} else {
			return null;
		}
	} else if (fs.existsSync(path.join(dir, "flow.config"))) {
		return dir;
	} else {
		const upper = path.dirname(dir);
		if (dir == upper) {
			return null;
		} else {
			return findConfigDir(upper);
		}
	}
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
