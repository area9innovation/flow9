'use strict';

import {
	createConnection, ProposedFeatures, InitializeParams, VersionedTextDocumentIdentifier, WorkspaceFolder, Location, Range, Position, DocumentSymbol, SymbolKind
} from 'vscode-languageserver';
import * as path from 'path';
import * as tools from './tools';
import * as fs from 'fs';
import Uri from 'vscode-uri';
import * as flatten from 'arr-flatten';
import { ChildProcess } from 'child_process';

// Create a connection for the server. The connection uses Node's IPC as a transport.
// Also include all preview / proposed LSP features.
let connection = createConnection(ProposedFeatures.all);
let outlineEnabled = false;
let logging = false;

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
			},
			documentSymbolProvider: true
		}
	}
});

connection.onInitialized(() => {
});

connection.onDidChangeConfiguration((params) => {
})

connection.onNotification("outlineEnabled", enabled => {
	outlineEnabled = enabled;
})

connection.onShutdown(() => {
});

connection.onDidChangeTextDocument(params => {
	validateTextDocument(params.textDocument);	
});

connection.onDidOpenTextDocument(params => {
	validateTextDocument(params.textDocument);
});

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

interface CompilerEntity {
	file : string,
	line : number,
	column : number,
	entity : string
};

function extractEntities(compilerResult): CompilerEntity[]  {
	if (compilerResult.status == 0) {
		const line_regexp = /^(.*):(\d+):(\d+):\s*(.*)\s*$/;
		let lines = flatten(compilerResult.output.filter(x => x != null)
											.map(x => x.split("\n")));
		let results: CompilerEntity[] = []
		for (let l of lines) {
			const matched = l.match(line_regexp);
			if (matched) {
				const line = Number.parseInt(matched[2]) - 1;
				const start = Number.parseInt(matched[3]) - 1;
				const result = { file : matched[1], line : line, column : start, 
					entity : matched.length > 4 ? matched[4] : ""};
				results.push(result);
			}
		}

		return results;
	}

	return [];
}

function entitiesToLocations(results: CompilerEntity[]): Location[] {
	if (results && results.length > 0) {
		return results.map(r => Location.create(Uri.file(r.file).toString(), 
			Range.create(r.line, r.column, r.line, r.column + r.entity.length))
		);
	} else 
		return undefined;
}

function parseSymbolKind(prefix: string, exported : boolean): SymbolKind | undefined {
	switch (prefix) {
		case "struct": return exported ? SymbolKind.Class : SymbolKind.Struct;
		case "union": return SymbolKind.Enum;
		case "fundef": return exported ? SymbolKind.Interface : SymbolKind.Function;
		case "vardef": return SymbolKind.Variable;
		case "natdef": return SymbolKind.Method;
		default: return undefined;
	}
}

function parseSymbol(ent: CompilerEntity) {
	const entity = ent.entity.trim();
	if (entity.length == 0)
		return undefined;
	const components = entity.split(" ");
	if (components.length < 2)
		return undefined;
	
	return { prefix : components[0], name : components[1] };
}

function convertSymbol(ent: CompilerEntity, exportHash : {}): DocumentSymbol | undefined {
	const parsed = parseSymbol(ent);
	if (!parsed)
		return undefined;
	const kind = parseSymbolKind(parsed.prefix, parsed.name in exportHash);
	if (kind) {
		const range = Range.create(ent.line, ent.column + 1, ent.line, ent.column + ent.entity.length + 1);
		return DocumentSymbol.create(parsed.name, "", kind, range, range);
	} else
		return undefined;
}

function entitiesToSymbols(entities: CompilerEntity[]): DocumentSymbol[] {
	if (!entities)
		return [];
	// sort to make sure exports are first
	const sorted = entities.sort((a, b) => (a.entity == b.entity) ? 0 : (a.entity < b.entity ? -1 : 1));
	const hash = sorted.reduce((acc, ent) => {
		const parsed = parseSymbol(ent);
		if (parsed && parsed.prefix == "export")
			acc[parsed.name] = true;
		return acc;
	}, {});
	return sorted.map(e => convertSymbol(e, hash)).filter(t => t != undefined);
}

async function findEntities(fileUri: string, lineNum: number, columnNum: number, operation: string, extra_args: string[]) {
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

	if (logging)
    	console.log(`Looking at position ${columnNum} at line ${lineNum}, token: ${token}\n`);

	let flowcArgs = [paths.documentPath, operation + token].concat(extra_args);
	if (logging)
		connection.console.log("Launching command: flowc1 " + flowcArgs.join(" ") + 
			"\n\t\t in folder: " + paths.projectRoot);

	let result = tools.run_cmd_sync("flowc1", paths.projectRoot, flowcArgs);
	
	return extractEntities(result);
}

connection.onDefinition(async (params) => {
	const results = await findEntities(params.textDocument.uri, params.position.line, params.position.character,
		"find-defdecl=", []);
	const definitions = entitiesToLocations(results);

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

	return entitiesToLocations(extractEntities(result));
});

connection.onReferences(async (params) => {
	const entities = await findEntities(params.textDocument.uri, params.position.line, params.position.character, 
		"find-uses=", []);
	return entitiesToLocations(entities);
});

connection.onImplementation(async (params) => {
	const entities = await findEntities(params.textDocument.uri, params.position.line, params.position.character, 
		"find-definition=", []);
	return entitiesToLocations(entities);
})

connection.onRenameRequest(async (params) => {
	const result = await findEntities(params.textDocument.uri, params.position.line, params.position.character, 
		"rename=", ["to=" + params.newName]);

	return undefined;
})

connection.onDocumentSymbol(async params => {
	if (!outlineEnabled)
		return [];

	const paths = getCompilerPaths(await connection.workspace.getWorkspaceFolders(), params.textDocument.uri);
	const result = tools.run_cmd_sync("flowc1", paths.projectRoot, 
		[paths.documentPath, "print-outline=1"]);
	const entities = extractEntities(result);
	const symbols = entitiesToSymbols(entities);
	return symbols;
});

connection.onCompletion(async (params) => {
	const result = await findEntities(params.textDocument.uri, params.position.line, params.position.character,
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