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
import * as meta from '../package.json';
import * as simplegit from 'simple-git/promise';
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

enum LspKind { Flow = 1, JS = 2, None = 3 }

let childProcesses = [];
let client: LanguageClient = null;
let flowChannel : vscode.OutputChannel = null;
let flowRepoUpdateChannel : vscode.OutputChannel = null;
let counter = 0; // used to silence not finished jobs when new ones got started
let flowDiagnosticCollection : vscode.DiagnosticCollection = null;
let problemMatchers: ProblemMatcher[] = meta['contributes'].problemMatchers;

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
    context.subscriptions.push(serverStatusBarItem);
    
    context.subscriptions.push(vscode.commands.registerCommand('flow.compile', compile));
    context.subscriptions.push(vscode.commands.registerCommand('flow.GetFlowCompiler', getFlowCompilerFamily));
    context.subscriptions.push(vscode.commands.registerCommand('flow.compileNeko', compileNeko));
    context.subscriptions.push(vscode.commands.registerCommand('flow.run', runCurrentFile));
    context.subscriptions.push(vscode.commands.registerCommand('flow.updateFlowRepo', () => { updateFlowRepo(context); }));
    context.subscriptions.push(vscode.commands.registerCommand('flow.startHttpServer', startHttpServer));
	context.subscriptions.push(vscode.commands.registerCommand('flow.stopHttpServer', stopHttpServer));
	context.subscriptions.push(vscode.commands.registerCommand('flow.toggleHttpServer', toggleHttpServer));
    context.subscriptions.push(vscode.commands.registerCommand('flow.lspFlow', () => { setClient(context, LspKind.Flow); }));
    context.subscriptions.push(vscode.commands.registerCommand('flow.lspJs', () => { setClient(context, LspKind.JS); }));
    context.subscriptions.push(vscode.workspace.onDidChangeConfiguration(handleConfigurationUpdates));

    flowChannel = vscode.window.createOutputChannel("Flow");
	flowChannel.show();

	checkHttpServerStatus(true);
	setInterval(checkHttpServerStatus, 3000, false);

    // Create a client
    if (vscode.workspace.getConfiguration("flow").get("lspFlowServer")) {
        setClient(context, LspKind.Flow);
    } else {
        setClient(context, LspKind.JS);
    }

    updater.checkForUpdate();
    updater.setupUpdateChecker();
    serverStatusBarItem.show();
}

function checkHttpServerStatus(initial : boolean) {
	const port = vscode.workspace.getConfiguration("flow").get("portOfHttpServer");
	isPortReachable(port, {host: 'localhost'}).then(
		(reacheable : boolean) => {
			if (reacheable) {
				showHttpServerOnline();
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

function toggleHttpServer() {
    if (!httpServerOnline) {
		startHttpServer();
    } else {
		stopHttpServer();
	}
}

function startHttpServer() {
    if (httpServer == null) {
        httpServer = tools.launchFlowcHttpServer(getFlowRoot(), showHttpServerOnline, showHttpServerOffline);
    }
}

function stopHttpServer() {
    tools.shutdownFlowcHttpServer();
}

function setClient(context: vscode.ExtensionContext, kind : LspKind) {
    if (clientKind != kind) {
        if (client) {
            client.sendNotification("exit");
            client.stop();
        }
        client = null;
        clientKind = kind;
        if (clientKind != LspKind.None) {
            // The server is implemented in node
            let serverModule = context.asAbsolutePath(path.join('out', 'flow_language_server.js'));
            // The debug options for the server
            let debugOptions = { execArgv: ["--nolazy", "--inspect=6009"] };

            // If the extension is launched in debug mode then the debug server options are used
            // Otherwise the run options are used
            let serverOptions: ServerOptions;
            switch (clientKind) {
                case LspKind.Flow: {
                    if (serverStatusBarItem.text.indexOf("online") != -1) {
                        serverStatusBarItem.text = `$(vm-active) flow http server: online (lsp)`;
                    } else {
                        serverStatusBarItem.text = `$(vm-outline) flow http server: offline (lsp)`;
                    }
                    serverStatusBarItem.show();
                    serverOptions = {
                        command: process.platform == "win32" ? 'flowc1.bat' : 'flowc1',
                        args: ['server-mode=console'],
                        options: { detached: false }
                    }
                    break;
                }
                case LspKind.JS: {
                    if (serverStatusBarItem.text.indexOf("online") != -1) {
                        serverStatusBarItem.text = `$(vm-active) flow http server: online (legacy lsp)`;
                    } else {
                        serverStatusBarItem.text = `$(vm-outline) flow http server: offline (legacy lsp)`;
                    }
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

function showHttpServerOnline() { 
    //'flow http server online (lsp)' vs. 'flow http server online (legacy lsp)'
    if (serverStatusBarItem.text.indexOf("legacy") == -1) {
        serverStatusBarItem.text = `$(vm-active) flow http server: online (lsp)`; 
    } else {
        serverStatusBarItem.text = `$(vm-active) flow http server: online (legacy lsp)`; 
    }
}

function showHttpServerOffline() { 
    //'flow http server online (lsp)' vs. 'flow http server online (legacy lsp)'
    if (serverStatusBarItem.text.indexOf("legacy") == -1) {
        serverStatusBarItem.text = `$(vm-outline) flow: http server: offline (lsp)`; 
    } else {
        serverStatusBarItem.text = `$(vm-outline) flow: http server: offline (legacy lsp)`; 
    }
}

// this method is called when your extension is deactivated
export function deactivate() {
	// First, shutdown Flowc server
    tools.shutdownFlowcHttpServer();
    httpServer = null;
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
        if (httpServer) {
            startHttp = true;
            flowRepoUpdateChannel.append("Shutting down HTTP flowc server... ");
            stopHttpServer();
            flowRepoUpdateChannel.appendLine("HTTP server is shutdown.");
        }
        pullAndStartServer(git, context, kind, startHttp);
    }

    if (clientKind == LspKind.Flow) {
        flowRepoUpdateChannel.append("Shutting down flow LSP server... ");
        setClient(context, LspKind.None);
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
        setClient(context, LspKind.Flow);
    }
}

function sendOutlineEnabledUpdate() {
	let config = vscode.workspace.getConfiguration("flow");
	const outlineEnabled = config.get("outline");
	client.sendNotification("outlineEnabled", outlineEnabled);
}

function handleConfigurationUpdates(e: vscode.ConfigurationChangeEvent) {
	if (e.affectsConfiguration("flow.outline")) {
		sendOutlineEnabledUpdate();
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
    compileCurrentFile(""); // empty means default compiler
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

function getMatcher(name: string) {
    let found = problemMatchers.find((val, idx, obj) => {
        return val.name == name;
    });
    // fallback to flowc matcher if not found
    return found ? found : (name != "flowc" ? getMatcher("flowc") : found);
}

function compileCurrentFile(compilerHint: string) {
    processFile(function(flowBinPath, flowpath) { 
        return getCompilerCommand(compilerHint, flowBinPath, flowpath);
    }, true);
}

function getFlowRoot(): string {
    let config = vscode.workspace.getConfiguration("flow");
    return config.get("root");
}

function processFile(getProcessor : (flowBinPath : string, flowpath : string) => CommandWithArgs, use_lsp : boolean) {
    let document = vscode.window.activeTextEditor.document;
    document.save().then(() => {
        if (flowDiagnosticCollection) {
            flowDiagnosticCollection.clear();
        } else {
            flowDiagnosticCollection = vscode.languages.createDiagnosticCollection("flow");
        }
        let diagnostics: [vscode.Uri, vscode.Diagnostic[] | undefined][] = [];
        let current = ++counter;
        flowChannel.clear();
        flowChannel.show(true);
        let flowpath: string = getFlowRoot();
        let rootPath = resolveProjectRoot(document.uri);
        let documentPath = path.relative(rootPath, document.uri.fsPath);
        let command = getProcessor(path.join(flowpath, "bin"), documentPath);
        let matcher = getMatcher(command.matcher);
        flowChannel.appendLine("Current directory '" + rootPath + "'");
        let run_separately = () => {
            tools.run_cmd(command.cmd, rootPath, command.args, (s) => {
                if (counter == current) {// if there is a newer job, ignoring ones pending
                    flowChannel.append(s.toString());
                    diagnostics = diagnostics.concat(parseAndCollectDiagnostics(s.toString(), matcher));
                    flowDiagnosticCollection.set(diagnostics); // update upon every line
                }
            }, childProcesses);
        }
        if (use_lsp) {
            if (!httpServer) {
                flowChannel.appendLine("Caution: you are using a separate instance of flowc LSP server. To improve performace it is recommended to switch HTTP server on.");
            }
            switch (clientKind) {
                case LspKind.Flow: {
                    flowChannel.appendLine("Compiling '" + getPath(document.uri) + "' using Flow LSP server");
                    //let start = performance.now();
                    client.sendRequest("workspace/executeCommand", {
                            command : "compile", 
                            arguments: ["file=" + getPath(document.uri), "working_dir=" + rootPath]
                        }
                    ).then(
                        (out : any) => {
                            //flowChannel.appendLine("Execution of a request took " + (performance.now() - start) + " milliseconds.")
                            flowChannel.appendLine(out);
                            diagnostics = diagnostics.concat(parseAndCollectDiagnostics(out.toString(), matcher));
                            flowDiagnosticCollection.set(diagnostics); // update upon every line
                        }
                    );
                    break;
                }
                case LspKind.JS: {
                    flowChannel.appendLine("Compiling '" + getPath(document.uri) + "' using legacy JS LSP server");
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

function parseAndCollectDiagnostics(s: string, matcher: ProblemMatcher) {
    const lines = s.split("\n");
    const diags = lines.map((line, index, lns): [vscode.Uri, vscode.Diagnostic[] | undefined] => {
        const matched = line.trim().match(matcher.pattern.regexp);
        if (matched) {
            const col = Number.parseInt(matched[matcher.pattern.column]) - 1;
            const l = Number.parseInt(matched[matcher.pattern.line]) - 1;
            const diagnostic: vscode.Diagnostic = {
                code: '',
                message: matched[matcher.pattern.message],
                range: new vscode.Range(new vscode.Position(l, col), new vscode.Position(l, col)),
                severity: vscode.DiagnosticSeverity.Error,
                source: '',
                relatedInformation: []
            }
            return [vscode.Uri.file(matched[matcher.pattern.file]), [diagnostic]];
        } else
            return [undefined, undefined];
    });
    return diags.filter((v, index, lll) => {
        return v[0] != undefined;
    })
}

function getCompilerCommand(compilerHint: string, flowbinpath: string, flowfile: string): 
    CommandWithArgs
{
    let compiler = compilerHint ? compilerHint : getFlowCompiler();
    let serverArgs = (compiler.startsWith("flowc") && !httpServer) ? ["server=0"] : [];
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