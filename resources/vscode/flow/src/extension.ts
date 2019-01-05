'use strict';
// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';
import * as path from 'path';
import { spawn } from 'child_process';
import * as fs from "fs";
import * as os from "os";
import * as PropertiesReader from 'properties-reader';
import {
	LanguageClient, LanguageClientOptions, ServerOptions, TransportKind, Diagnostic
} from 'vscode-languageclient';
import * as tools from "./tools";
import * as updater from "./updater";
import * as meta from '../package.json';
import * as simplegit from 'simple-git/promise';

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
let client: LanguageClient;
let flowChannel : vscode.OutputChannel = null;
let counter = 0; // used to silence not finished jobs when new ones got started
let flowDiagnosticCollection : vscode.DiagnosticCollection = null;
let problemMatchers: ProblemMatcher[] = meta['contributes'].problemMatchers;

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed
export function activate(context: vscode.ExtensionContext) {
    // Use the console to output diagnostic information (console.log) and errors (console.error)
    // This line of code will only be executed once when your extension is activated
    console.log('Flow extension active');

    // The command has been defined in the package.json file
    // Now provide the implementation of the command with  registerCommand
    // The commandId parameter must match the command field in package.json
    let flowcpp_command = vscode.commands.registerCommand('flow.flowcpp', () => {
        // The code you place here will be executed every time your command is executed
        compile();
    });

    let compileNeko_command = vscode.commands.registerCommand('flow.compileNeko', () => {
        compileNeko();
    });

    let run_command = vscode.commands.registerCommand('flow.run', () => {
        runCurrentFile();
    })

    flowDiagnosticCollection = vscode.languages.createDiagnosticCollection("Flow");
    
    let getCompiler_command = vscode.commands.registerCommand('flow.GetFlowCompiler', 
        getFlowCompilerFamily);

    let updateFlow_command = vscode.commands.registerCommand('flow.updateFlowRepo', () => {
        updateFlowRepo();
    })

    context.subscriptions.push(flowcpp_command);
    context.subscriptions.push(getCompiler_command);
    context.subscriptions.push(compileNeko_command);
    context.subscriptions.push(run_command);
    context.subscriptions.push(updateFlow_command);

   	// The server is implemented in node
	let serverModule = context.asAbsolutePath(path.join('out', 'flow_language_server.js'));
	// The debug options for the server
	let debugOptions = { execArgv: ["--nolazy", "--inspect=6009"] };

	// If the extension is launched in debug mode then the debug server options are used
	// Otherwise the run options are used
	let serverOptions: ServerOptions = {
		run : { module: serverModule, transport: TransportKind.ipc },
		debug: { module: serverModule, transport: TransportKind.ipc, options: debugOptions }
	}

	// Options to control the language client
	let clientOptions: LanguageClientOptions = {
		// Register the server for plain text documents
		documentSelector: [{scheme: 'file', language: 'flow'}],
	}

	// Create the language client and start the client.
	client = new LanguageClient('flowLanguageServer', 'Flow Language Server', serverOptions, clientOptions);
	// Start the client. This will also launch the server
    client.start();

    updater.checkForUpdate();
    updater.setupUpdateChecker();
}

// this method is called when your extension is deactivated
export function deactivate() {
    // kill all child processed we launched
    childProcesses.forEach(child => { 
        child.kill('SIGKILL'); 
        if (os.platform() == "win32")
            spawn("taskkill", ["/pid", child.pid, '/f', '/t']);
    });
}

export async function updateFlowRepo() {
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
    tools.shutdownFlowc();
    try {
        await git.pull('origin', 'master', {'--rebase' : 'true'});
    } catch (e) {
        vscode.window.showInformationMessage("Flow repository pull failed: " + e);
    }
    tools.launchFlowc(getFlowRoot());
}

function resolveProjectRoot(projectRoot: string, documentUri: vscode.Uri): string {
    if (projectRoot) {
        // first, check if we are asked to use one specific workspace folder
        if (vscode.workspace.workspaceFolders) {
            for (let wf of vscode.workspace.workspaceFolders) 
                if (wf.name == projectRoot)
                    return wf.uri.fsPath;
        }
        // then, see if this is an absolute path
        if (path.isAbsolute(projectRoot))
            return projectRoot;
        // finally, try to resolve path against first wsfolder
        if (vscode.workspace.workspaceFolders) {
            let resolvedPath = path.join(vscode.workspace.rootPath, projectRoot)
            if (fs.existsSync(resolvedPath))
                return resolvedPath;
        }
    }
    // either projectRoot is not set or we did not find a way to use it
    let wsfolder = vscode.workspace.getWorkspaceFolder(documentUri);
    if (wsfolder) 
        return wsfolder.uri.fsPath;
    else
        // rootPath is deprecated but points to first wsFolder, and can be undefined if no 
        // folder is opened
        return vscode.workspace.rootPath ? vscode.workspace.rootPath : 
            path.dirname(documentUri.fsPath);
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
    });
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
    });
}

function getFlowRoot(): string {
    let config = vscode.workspace.getConfiguration("flow");
    return config.get("root");
}

function processFile(getProcessor : (flowBinPath : string, flowpath : string) => CommandWithArgs) {
    let document = vscode.window.activeTextEditor.document;
    document.save().then(() => {
        if (null == flowChannel) {
            flowChannel = vscode.window.createOutputChannel("Flow");
        }
        flowDiagnosticCollection.clear();
        let diagnostics: [vscode.Uri, vscode.Diagnostic[] | undefined][] = [];
        let current = ++counter;
        flowChannel.clear();
        flowChannel.show(true);
        let config = vscode.workspace.getConfiguration("flow");
        let flowpath: string = getFlowRoot();
        let rootPath = resolveProjectRoot(config.get("projectRoot"), document.uri);
        let documentPath = path.relative(rootPath, document.uri.fsPath);
        let command = getProcessor(path.join(flowpath, "bin"), documentPath);
        let matcher = getMatcher(command.matcher);
        flowChannel.appendLine("Current directory: " + rootPath);
        flowChannel.appendLine("Running " + command.cmd + " " + command.args.join(" "));
        tools.run_cmd(command.cmd, rootPath, command.args, (s) => {
            if (counter == current) {// if there is a newer job, ignoring ones pending
                flowChannel.append(s.toString());
                diagnostics = diagnostics.concat(parseAndCollectDiagnostics(s.toString(), matcher));
                flowDiagnosticCollection.set(diagnostics); // update upon every line
            }
        }, childProcesses);
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
    let compilerServer = vscode.workspace.getConfiguration("flow").get("useCompilerServer");
    let serverArgs = (compiler.startsWith("flowc") && !compilerServer) ?
        ["server=0"] : [];
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