'use strict';

import {
	createConnection, ProposedFeatures, InitializeParams, VersionedTextDocumentIdentifier, WorkspaceFolder, Location, Range, Position
} from 'vscode-languageserver';
import * as path from 'path';
import * as tools from './tools';
import * as fs from 'fs';
import Uri from 'vscode-uri';
import * as flatten from 'arr-flatten';
import { ChildProcess } from 'child_process';

interface FlowSettings {
	useCompilerServer : boolean
}

const defaultSettings : FlowSettings = { useCompilerServer : true };
let globalSettings : FlowSettings = defaultSettings;

// Create a connection for the server. The connection uses Node's IPC as a transport.
// Also include all preview / proposed LSP features.
let connection = createConnection(ProposedFeatures.all);

let flowServer : ChildProcess = null;

connection.onInitialize((params: InitializeParams) => {
	return {
		capabilities: {
			textDocumentSync: 2,
            // Tell the client that the server supports definition search
			definitionProvider: true,
			typeDefinitionProvider: true,
			referencesProvider: true,
			implementationProvider: true,
			renameProvider: true,
			completionProvider: {
				resolveProvider: true,
				triggerCharacters: ["."]
			},
			workspace: {
				workspaceFolders : {
					supported : true,
					changeNotifications : true
				}
			}
		}
	}
});

connection.onInitialized(() => {
});

connection.onDidChangeConfiguration((params) => {
	globalSettings = <FlowSettings>(
		params.settings.flow || defaultSettings
	);
})

connection.onShutdown(() => {
	if (null != flowServer) {
		tools.run_cmd("flowc1", "", ["server-shutdown=1"], (s) => {
			console.log(s);
		}, []);
	}
});

connection.onDidChangeTextDocument(params => {
	validateTextDocument(params.textDocument);	
});

connection.onDidOpenTextDocument(params => {
	validateTextDocument(params.textDocument);
});

function spawnFlowcServer(projectRoot: string) {
	if (null == flowServer && globalSettings.useCompilerServer) {
		flowServer = tools.run_cmd("flowc1", projectRoot, ["server-mode=1"], (s) => {
			console.log(s);
		}, []);
	}
}

function getFsPath(uri: string): string {
	return Uri.parse(uri).fsPath;
}

function findClosestFlowConfig(root: string, relativePath: string) {
	if (relativePath.length == 0) {
		return root;
	}
	if (fs.existsSync(path.resolve(root, relativePath, "flow.config"))) {
		return path.resolve(root, relativePath);
	} else {
		let pathComponents = relativePath.split(path.sep);
		pathComponents.pop();
		const parent = path.join(...pathComponents);
		if (parent.length > 0 && parent != relativePath && parent != ".")
			return findClosestFlowConfig(root, parent);
		else 
			return root;
	}
}

function getProjectRoot(wsFolders: WorkspaceFolder[], documentPath: string): string {
	for (let f of wsFolders) {
		const folderRoot = getFsPath(f.uri);
		const relative = path.relative(folderRoot, documentPath);
		const relativePath = path.parse(relative).dir;
		if (!!relative && !relative.startsWith('..') && !path.isAbsolute(relative))
			return findClosestFlowConfig(folderRoot, relativePath);
	}

	// fall to folder containing document
	return path.dirname(documentPath);
}

function getCompilerPaths(wsFolders: WorkspaceFolder[], documentUri: string) {
	let fullPath = getFsPath(documentUri);
	let projectRoot = getProjectRoot(wsFolders, fullPath);
	return { documentPath: path.relative(projectRoot, fullPath), projectRoot: projectRoot }
}

async function validateTextDocument(textDocument: VersionedTextDocumentIdentifier): Promise<void> {
	let paths = getCompilerPaths(await connection.workspace.getWorkspaceFolders(), textDocument.uri);
	//connection.console.log("Analyzing document " + paths.documentPath);
}

function extractToken(line: string, position: number): string {
	let start = position - 1;
	const alnum_regexp = /[0-9a-zA-Z_]/;
	while (start >= 0 && line[start].match(alnum_regexp))
		--start;
	let end = position;
	while (end < line.length && line[end].match(alnum_regexp))
		++end;
		
	return line.substring(start + 1, end);
}

function extractDefinition(compilerResult) {
	if (compilerResult.status == 0) {
		const line_regexp = /^(.*):(\d+):(\d+):\s*(.*)\s*$/;
		let lines = flatten(compilerResult.output.filter(x => x != null)
											.map(x => x.split("\n")));
		let locations: Location[] = []
		for (let l of lines) {
			const matched = l.match(line_regexp);
			if (matched) {
				const line = Number.parseInt(matched[2]) - 1;
				const start = Number.parseInt(matched[3]) - 1;
				locations.push(Location.create(Uri.file(matched[1]).toString(), 
					Range.create(line, start, line, 
						matched.length > 4 ? start + matched[4].length : start)));
			}
		}

		return locations;
	}

	return undefined;
}

async function findObject(fileUri: string, lineNum: number, columnNum: number, operation: string, extra_args: string[]) {
	const paths = getCompilerPaths(await connection.workspace.getWorkspaceFolders(), fileUri);
	const file_lines = fs.readFileSync(path.join(paths.projectRoot, paths.documentPath), 
		{ encoding: 'utf8'}).split("\n");
	if (!file_lines || file_lines.length < lineNum)
		return undefined;
	const line = file_lines[lineNum];
	if (!line || line.length < columnNum)
		return undefined;

	const token = extractToken(line, columnNum);
	if (!token || token.length == 0)
		return undefined;

    console.log(`Looking at position ${columnNum} at line ${lineNum}, token: ${token}\n`);

	// this will spawn a flowc server in the project root unless already spawned
	spawnFlowcServer(paths.projectRoot);

	let serverArgs = !globalSettings.useCompilerServer ? ["server=0"] : [];

	let flowcArgs = serverArgs.concat([paths.documentPath, operation + token]).concat(extra_args);
	connection.console.log("Launching command: flowc1 " + flowcArgs.join(" ") + 
		"\n\t\t in folder: " + paths.projectRoot);

	let result = tools.run_cmd_sync("flowc1", paths.projectRoot, flowcArgs);
	
	return extractDefinition(result);
}

connection.onDefinition(async (params) => {
	var definitions = await findObject(params.textDocument.uri, params.position.line, params.position.character,
		"find-defdecl=", []);

	// if we are already on definition, jump to declaration - allows to use F12 to jump back and forth
	if (definitions && definitions.length > 1) {
		var definition = definitions[0];
		if (definition.uri == params.textDocument.uri && definition.range.start.line == params.position.line)
			return definitions[1];
		else
			return definitions[0];
	} else
		return definitions;
});

connection.onTypeDefinition(async (params) => {
	const paths = getCompilerPaths(await connection.workspace.getWorkspaceFolders(), params.textDocument.uri);
	let result = tools.run_cmd_sync("flowc1", paths.projectRoot, 
		[paths.documentPath, "find-type=1", "exp-line=" + params.position.line, 
			"exp-col=" + params.position.character]);

	return extractDefinition(result);
});

connection.onReferences(async (params) => {
	return await findObject(params.textDocument.uri, params.position.line, params.position.character, 
		"find-uses=", []);
});

connection.onImplementation(async (params) => {
	return await findObject(params.textDocument.uri, params.position.line, params.position.character, 
		"find-definition=", []);
})

connection.onRenameRequest(async (params) => {
	const result = await findObject(params.textDocument.uri, params.position.line, params.position.character, 
		"rename=", ["to=" + params.newName]);

	return undefined;
})

connection.onShutdown(async () => {
	if (null != flowServer)
		flowServer.kill();
});

connection.onCompletion(async (params) => {
	const result = await findObject(params.textDocument.uri, params.position.line, params.position.character,
		"completion=1", []);
	return [];
})

/*
connection.onDidOpenTextDocument((params) => {
	// A text document got opened in VSCode.
	// params.uri uniquely identifies the document. For documents store on disk this is a file URI.
	// params.text the initial full content of the document.
	connection.console.log(`${params.textDocument.uri} opened.`);
});
connection.onDidChangeTextDocument((params) => {
	// The content of a text document did change in VSCode.
	// params.uri uniquely identifies the document.
	// params.contentChanges describe the content changes to the document.
	connection.console.log(`${params.textDocument.uri} changed: ${JSON.stringify(params.contentChanges)}`);
});
connection.onDidCloseTextDocument((params) => {
	// A text document got closed in VSCode.
	// params.uri uniquely identifies the document.
	connection.console.log(`${params.textDocument.uri} closed.`);
});
*/

// Listen on the connection
connection.listen();