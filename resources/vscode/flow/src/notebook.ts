import * as vscode from 'vscode';
import * as tools from './tools';
import { spawn, ChildProcess, spawnSync } from 'child_process';
import { readFileSync } from 'fs';

let encoder = new TextEncoder();

export class FlowNotebookProvider implements vscode.NotebookContentProvider {
    async openNotebook(uri: vscode.Uri): Promise<vscode.NotebookData> {
        const cells = <vscode.NotebookCellData[]>JSON.parse((await vscode.workspace.fs.readFile(uri)).toString());
        const languages = ['markdown', 'flow'];
        const metadata: vscode.NotebookDocumentMetadata = { 
            editable: true, 
            cellEditable: true, 
            cellHasExecutionOrder: false, 
            cellRunnable: true, 
            runnable: true 
        };
        return {
			languages,
			metadata,
			cells
		};
    }
    onDidChangeNotebook = new vscode.EventEmitter<vscode.NotebookDocumentEditEvent>().event;
    async resolveNotebook(document: vscode.NotebookDocument, webview: vscode.NotebookCommunication): Promise<void> { }
    async saveNotebook(document: vscode.NotebookDocument, cancellation: vscode.CancellationToken): Promise<void> { 
        this._save(document, document.uri);
    }
    async saveNotebookAs(targetResource: vscode.Uri, document: vscode.NotebookDocument, cancellation: vscode.CancellationToken): Promise<void> { 
        this._save(document, targetResource);
    }
    async backupNotebook(document: vscode.NotebookDocument, context: vscode.NotebookDocumentBackupContext, cancellation: vscode.CancellationToken): Promise<vscode.NotebookDocumentBackup> { 
        await this._save(document, context.destination);
		return {
			id: context.destination.toString(),
			delete: () => vscode.workspace.fs.delete(context.destination)
		}; 
    }
    private async _save(document: vscode.NotebookDocument, targetResource: vscode.Uri): Promise<void> {
        let contents = document.cells.map((cell: any, i : number) => {
            return {
                cellKind: cell.cellKind,
                language: cell.language,
                source: cell.document.getText(),
                outputs: cell.outputs,
                metadata: cell.metadata
            }
        });
		await vscode.workspace.fs.writeFile(targetResource, encoder.encode(JSON.stringify(contents)));
    }
}

export class FlowNotebookKernelProvider implements vscode.NotebookKernelProvider {
    async provideKernels(document: vscode.NotebookDocument, token: vscode.CancellationToken): Promise<[FlowNotebookKernel]> {
        return new Promise((resolve, reject) => {
            if (document.fileName.endsWith(".noteflow")) {
                resolve([new FlowNotebookKernel()]);
            } else {
                return reject();
            }
        });
    }
}

export function killExecutor(): void {
	if (executor) {
		executor.stdin.write("exit");
		executor.kill("SIGKILL");
		executor = null;
	}
}

// run_cmd(cmd: string, wd: string, args: string[], outputProc: (string) => void, childProcesses: ChildProcess[]):

export function startExecutor(): void {
	if (!executor) {
		executor = spawn("flowc1", ["repl=1", "repl-compile-output=1", "bin-dir=/home/dmitry/area9/flow9/bin/"]);
		//executor = run_cmd("flowc1", null, ["repl=1", "repl-compile-output=1"])
	} else {
		executor.removeAllListeners();
	}
}

let executor : ChildProcess = null;
let kernelChannel: vscode.OutputChannel = vscode.window.createOutputChannel("Flow Notebook kernel");

class FlowNotebookKernel implements vscode.NotebookKernel {
    label: "flow";
    private runIndex: number = 0;
    private start: number = 0;
    private callback = (arg: string) => { };

    private setupExecutorCallbacks(): void {
		let buffer: string = "";
		executor.stdout.on("data", (buf : string) => {
			let out = buf.toString();
			kernelChannel.append(out);
			buffer += out;
			if (buffer.endsWith("> ")) {
				this.callback(buffer.slice(0, buffer.length - 2));
				buffer = "";
			}
		});
		executor.stderr.on("data", (out : string) => kernelChannel.append(out.toString()));
		executor.stdout.on("error", (out : string) => kernelChannel.append(out.toString()));
		executor.stderr.on("error", (out : string) => kernelChannel.append(out.toString()));
		executor.stderr.on("error", (out : string) => kernelChannel.append(out.toString()));
		// Exit callbacks for executor
		executor.on("close", (code : number, signal : string) => executor = null);
		executor.on("disconnect", () => executor = null);
		executor.on("error", (err : Error) => executor = null);
		executor.on("exit", (code : number, signal : string) => executor = null);
    }

    constructor() {
		startExecutor();
        this.setupExecutorCallbacks();
    }

    async executeCell(document: vscode.NotebookDocument, cell: vscode.NotebookCell): Promise<void> {
        return this.executeCellDeferred(document, cell)();
    }
    executeCellDeferred(document: vscode.NotebookDocument, cell: vscode.NotebookCell): () => Promise<void> {
        if (cell.cellKind == vscode.CellKind.Code && cell.language == "flow") {
            return () => new Promise((resolve, reject) => {
                this.setCellRunning(cell);
                const code = this.prepareCellCode(cell);
                const should_be_rendered = this.cellShouldBeRendered(cell);
				//const js_opts = "readable=1";
				const html_opts = 
					"verbose=1 bin-dir=/home/dmitry/area9/flow9/bin/ readable=1 js-call-main=1 repl-compile-output=1 repl-no-quit=1";
                const request = should_be_rendered ? 
                    "compile html=www/cell_" + cell.index  + ".html " + html_opts + "\n" + code + "\n\n":
                    //"compile js=www/cell_" + cell.index  + ".js readable=1 js-call-main=1\n" + code + "\n\n":
                    "add cell_" + cell.index + " force\n" + code + "\n\n"; 
                kernelChannel.append(request);
                if (!executor || !executor.stdin.write(request)) {
                    reject("Error while writing: \n" + request);
                } else {
                    const wrap_resolve = () => { this.callback = (s: string) => { }; resolve(); }
                    const wrap_reject  = () => { this.callback = (s: string) => { }; reject(); }
                    if (should_be_rendered) {
                        this.callback = this.makeHtmlOutCallback(wrap_resolve, wrap_reject, cell);
                    } else {
                        this.callback = this.makeTextOutCallback(wrap_resolve, wrap_reject, cell);
                    }
                }
            });
        } else {
            return () => Promise.resolve();
        }
    }
    cancelCellExecution(document: vscode.NotebookDocument, cell: vscode.NotebookCell): void {
        cell.metadata.runState = vscode.NotebookCellRunState.Error;
        cell.metadata.lastRunDuration = +new Date() - this.start;
        this.callback("Error: interrupted");
    }
    async executeAllCells(document: vscode.NotebookDocument): Promise<void> {
        const deferred = document.cells.map((cell) => this.executeCellDeferred(document, cell));
        deferred.reduce(
            (chained, curr, i) => {
                return () => chained().then(() => curr());
            },
            () => Promise.resolve()
        )();
    }
    cancelAllCellsExecution(document: vscode.NotebookDocument): void {
        //this.callback("Error: interrapted");
        document.cells.forEach((cell) => {
            if (cell.metadata.runState == vscode.NotebookCellRunState.Running) {
                cell.metadata.runState = vscode.NotebookCellRunState.Error;
                cell.metadata.lastRunDuration = +new Date() - this.start;
            }
        });
		killExecutor();
		startExecutor();
        this.setupExecutorCallbacks();
    }
    private makeTextOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell): (a : string) => void { 
        let first_try = true;
        return (buffer : string) => {
            buffer = buffer.replace("\"No carrier\"", "");
            if (first_try) {
                if (buffer.indexOf('Error:') == -1) {
                    this.setCellTextSuccess(cell, buffer);
                    resolve();
                } else if (buffer == "Error: interrupted") {
                    this.setCellFail(cell, buffer);
                    reject(buffer);
                } else {
                    const code = this.prepareCellCode(cell);
                    const request = "exec\n" + code + "\n\n";
                    first_try = false;
                    kernelChannel.append(request);
                    if (!executor.stdin.write(request)) {
                        reject("Error while writing: \n" + request);
                    }
                }
            } else {
                if (buffer.indexOf('Error:') == -1) {
                    this.setCellTextSuccess(cell, buffer);
                    resolve();
                } else {
                    this.setCellFail(cell, buffer);
                    reject(buffer);
                }
            }
        }
    }
    private makeHtmlOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell): (a : string) => void { 
        return (buffer : string) => {
            buffer = buffer.replace("\"No carrier\"", "");
            if (buffer.indexOf('Error:') == -1) {
                //if (buffer.length > 10000) {
                //    kernelChannel.appendLine("buffer.length: " + buffer.length);
                //}
                this.setCellHtmlSuccess(cell, buffer);
                resolve();
            } else {
                this.setCellFail(cell, buffer);
                reject(buffer);
            }
        }
    }
    private prepareCellCode(cell: vscode.NotebookCell): string {
        const code = cell.document.getText();
        // Leave only one new line after a line of code (remove extra newlines)
        return code.replace(/(\r\n|\r|\n){2,}/g, '\n').trim();
    }
    private setCellRunning(cell: vscode.NotebookCell): void {
        cell.metadata.runState = vscode.NotebookCellRunState.Running;
        this.start = +new Date();
        cell.metadata.runStartTime = this.start;
        cell.metadata.executionOrder = ++this.runIndex;
    }
    private setCellTextSuccess(cell: vscode.NotebookCell, result: string): void {
        cell.outputs = [{outputKind: vscode.CellOutputKind.Text, text: result}];
        cell.metadata.runState = vscode.NotebookCellRunState.Success;
        cell.metadata.lastRunDuration = +new Date() - this.start;
    }
    private setCellHtmlSuccess(cell: vscode.NotebookCell, result: string): void {
		const js_file = readFileSync("www/cell_" + cell.index  + ".html.js").toString();
		const html_file = readFileSync("www/cell_" + cell.index  + ".html").toString();
		const test_html_file = readFileSync("www/test.html").toString();
		
		//kernelChannel.appendLine("js_file.length: " + js_file.length);
		//kernelChannel.appendLine("html_file.length: " + html_file.length);

        cell.outputs = [{
            outputKind: vscode.CellOutputKind.Rich, 
            data: {
                "text/plain": [
					"output: '" + result + "'"
					//, html_file
				],
                "application/javascript": [js_file],
				"text/x-javascript": [js_file],
                "text/html": [
					"<!DOCTYPE html>\n" + html_file
					//, test_html_file
				]
            }
        }];
        cell.metadata.runState = vscode.NotebookCellRunState.Success;
        cell.metadata.lastRunDuration = +new Date() - this.start;
    }
    private setCellFail(cell: vscode.NotebookCell, message: string): void {
        cell.outputs = [{
            outputKind: vscode.CellOutputKind.Error,
            ename: "flow kernel",
            evalue: message,
            traceback: []
        }];
        cell.metadata.runState = vscode.NotebookCellRunState.Error;
        cell.metadata.lastRunDuration = undefined;
    }
    private cellShouldBeRendered(cell: vscode.NotebookCell): boolean {
        const code = cell.document.getText();
        code.search('render');
        return code.indexOf('render') != -1 || code.indexOf('material') != -1;
    }
}

export function createNotebook(): void {
    let ask: vscode.InputBoxOptions = { prompt: "Notebook file: ", placeHolder: "" };
	vscode.window.showInputBox(ask).then(file => {
        let content : [vscode.NotebookCellData] = [{
                cellKind: vscode.CellKind.Markdown,
                source: "Put your markdown text here",
                language: "markdown",
                outputs: [],
                metadata: {}
        }];
        let json = JSON.stringify(content);

        const nb_edit = new vscode.WorkspaceEdit();
        const nb_uri = vscode.Uri.joinPath(vscode.Uri.file(vscode.workspace.workspaceFolders[0].uri.fsPath), file);

        //vscode.window.showInformationMessage("Creating Notebook file: '" + nb_uri.path + "'");
        nb_edit.createFile(nb_uri, { ignoreIfExists: true });
        vscode.workspace.fs.writeFile(nb_uri, encoder.encode(json)).then(
            (__?:any) => vscode.window.showInformationMessage("Notebook file: '" + nb_uri.path + "' is saved")
        );
        vscode.workspace.applyEdit(nb_edit);
    });
}

