import * as vscode from 'vscode';
import * as tools from './tools';
import { spawn, ChildProcess, spawnSync } from 'child_process';
import { readFileSync } from 'fs';

let encoder = new TextEncoder();

interface RawNotebookData {
	cells: RawNotebookCell[]
}
  
interface RawNotebookCell {
	language: string;
	value: string;
	kind: vscode.NotebookCellKind;
	editable?: boolean;
}
  
export class FlowNotebookSerializer implements vscode.NotebookSerializer {
	public readonly label: string = 'My Sample Content Serializer';
  
	public async deserializeNotebook(data: Uint8Array, token: vscode.CancellationToken): Promise<vscode.NotebookData> {
	  var contents = new TextDecoder().decode(data);    // convert to String to make JSON object
  
	  // Read file contents
	  let raw: RawNotebookData;
	  try {
		raw = <RawNotebookData>JSON.parse(contents);
	  } catch {
		raw = { cells: [] };
	  }
  
	  // Create array of Notebook cells for the VS Code API from file contents
	  const cells = raw.cells.map(item => new vscode.NotebookCellData(
		item.kind,
		item.value,
		item.language
	  ));
  
	  // Pass read and formatted Notebook Data to VS Code to display Notebook with saved cells
	  return new vscode.NotebookData(
		cells
	  );
	}
  
	public async serializeNotebook(data: vscode.NotebookData, token: vscode.CancellationToken): Promise<Uint8Array> {
	  // Map the Notebook data into the format we want to save the Notebook data as
	  let contents: RawNotebookData = { cells: []};
  
	  for (const cell of data.cells) {
		contents.cells.push({
		  kind: cell.kind,
		  language: cell.languageId,
		  value: cell.value
		});
	  }
  
	  // Give a string of all the data to save and VS Code will handle the rest
	  return new TextEncoder().encode(JSON.stringify(contents));
	}
}

export class FlowNotebookController {
	readonly id = 'flow-notebook';
	public readonly label = 'Flow9 Notebook Controller';
	readonly supportedLanguages = ['flow'];
  
	private _executionOrder = 0;
	private readonly _controller: vscode.NotebookController;

	private runIndex: number = 0;
    private start: number = 0;
    private callback = (arg: string) => { };

  
	constructor() {
        startExecutor();
        this.setupExecutorCallbacks();
        this._controller = vscode.notebooks.createNotebookController(this.id, 'flow-notebook', this.label);
        this._controller.supportedLanguages = this.supportedLanguages;
        this._controller.supportsExecutionOrder = true;
        this._controller.executeHandler = this._executeAll.bind(this);
	}
  
	dispose(): void {
		  this._controller.dispose();
	}
  
	private _executeAll(cells: vscode.NotebookCell[], _notebook: vscode.NotebookDocument, _controller: vscode.NotebookController): void {
		  for (let cell of cells) {
			  this._doExecution(cell);
		  }
	  }
  
	private async _doExecution(cell: vscode.NotebookCell): Promise<void> {
	  const execution = this._controller.createNotebookCellExecution(cell);
  
	  execution.executionOrder = ++this._executionOrder;
	  execution.start(Date.now());
      this.executeCell(cell, execution);
  
	  /*try {
		execution.replaceOutput([new vscode.NotebookCellOutput([
		  vscode.NotebookCellOutputItem.json(JSON.parse(cell.document.getText()), "x-application/sample-json-renderer"),
		  vscode.NotebookCellOutputItem.json(JSON.parse(cell.document.getText()))
		])]);
  
		execution.end(true, Date.now());
	  } catch (err) {
		execution.replaceOutput([new vscode.NotebookCellOutput([
		  vscode.NotebookCellOutputItem.error(err)
		])]);
		execution.end(false, Date.now());
	  }*/
	}




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

	async executeCell(cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): Promise<void> {
        return this.executeCellDeferred(cell)(execution);
    }
    executeCellDeferred(cell: vscode.NotebookCell): (execution: vscode.NotebookCellExecution) => Promise<void> {
        if (cell.kind == vscode.NotebookCellKind.Code /*&& cell.document.languageId == "flow"*/) {
            return (execution: vscode.NotebookCellExecution) => new Promise((resolve, reject) => {
                this.setCellRunning(cell, execution);
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
                        this.callback = this.makeHtmlOutCallback(wrap_resolve, wrap_reject, cell, execution);
                    } else {
                        this.callback = this.makeTextOutCallback(wrap_resolve, wrap_reject, cell, execution);
                    }
                }
            });
        } else {
            return () => Promise.resolve();
        }
    }
    cancelCellExecution(cell: vscode.NotebookCell): void {
        cell.metadata.runState = "vscode.NotebookCellRunState.Error";
        cell.metadata.lastRunDuration = +new Date() - this.start;
        this.callback("Error: interrupted");
    }
    /*async executeAllCells(document: vscode.NotebookDocument): Promise<void> {
        const deferred = document.cells.map((cell) => this.executeCellDeferred(document, cell));
        deferred.reduce(
            (chained, curr, i) => {
                return () => chained().then(() => curr());
            },
            () => Promise.resolve()
        )();
    }*/
    cancelAllCellsExecution(document: vscode.NotebookDocument): void {
        //this.callback("Error: interrapted");
        document.getCells().forEach((cell) => {
            if (cell.metadata.runState == "vscode.NotebookCellRunState.Running") {
                cell.metadata.runState = "vscode.NotebookCellRunState.Error";
                cell.metadata.lastRunDuration = +new Date() - this.start;
            }
        });
		killExecutor();
		startExecutor();
        this.setupExecutorCallbacks();
    }
    private makeTextOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): (a : string) => void { 
        let first_try = true;
        return (buffer : string) => {
            buffer = buffer.replace("\"No carrier\"", "");
            if (first_try) {
                if (buffer.indexOf('Error:') == -1) {
                    this.setCellTextSuccess(cell, buffer, execution);
                    resolve();
                } else if (buffer == "Error: interrupted") {
                    this.setCellFail(cell, buffer, execution);
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
                    this.setCellTextSuccess(cell, buffer, execution);
                    resolve();
                } else {
                    this.setCellFail(cell, buffer, execution);
                    reject(buffer);
                }
            }
        }
    }
    private makeHtmlOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): (a : string) => void { 
        return (buffer : string) => {
            buffer = buffer.replace("\"No carrier\"", "");
            if (buffer.indexOf('Error:') == -1) {
                //if (buffer.length > 10000) {
                //    kernelChannel.appendLine("buffer.length: " + buffer.length);
                //}
                this.setCellHtmlSuccess(cell, buffer, execution);
                resolve();
            } else {
                this.setCellFail(cell, buffer, execution);
                reject(buffer);
            }
        }
    }
    private prepareCellCode(cell: vscode.NotebookCell): string {
        const code = cell.document.getText();
        // Leave only one new line after a line of code (remove extra newlines)
        return code.replace(/(\r\n|\r|\n){2,}/g, '\n').trim();
    }
    private setCellRunning(cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): void {
        cell.metadata.runState = "vscode.NotebookCellRunState.Running";
        this.start = +new Date();
        cell.metadata.runStartTime = this.start;
        cell.metadata.executionOrder = ++this.runIndex;
    }
    private setCellTextSuccess(cell: vscode.NotebookCell, result: string, execution: vscode.NotebookCellExecution): void {

        //cell.outputs = [{outputKind: vscode.CellOutputKind.Text, text: result}];
		//cell.executionSummary.success = true;
        //cell.metadata.runState = vscode.NotebookCellRunState.Success;
        //cell.metadata.lastRunDuration = +new Date() - this.start;

        execution.replaceOutput(new vscode.NotebookCellOutput([
            //vscode.NotebookCellOutputItem.json(JSON.parse(cell.document.getText()), "x-application/sample-json-renderer"),
            //vscode.NotebookCellOutputItem.json(JSON.parse(cell.document.getText()))
            vscode.NotebookCellOutputItem.text(result)
        ]));
    
        execution.end(true, Date.now());
    }
    private setCellHtmlSuccess(cell: vscode.NotebookCell, result: string, execution: vscode.NotebookCellExecution): void {
		const js_file = readFileSync("www/cell_" + cell.index  + ".html.js").toString();
		const html_file = readFileSync("www/cell_" + cell.index  + ".html").toString();
		const test_html_file = readFileSync("www/test.html").toString();
		
		//kernelChannel.appendLine("js_file.length: " + js_file.length);
		//kernelChannel.appendLine("html_file.length: " + html_file.length);

        /*cell.outputs = [{
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
        cell.metadata.lastRunDuration = +new Date() - this.start;*/


        execution.replaceOutput(new vscode.NotebookCellOutput([
            //vscode.NotebookCellOutputItem.json(JSON.parse(cell.document.getText()), "x-application/sample-json-renderer"),
            //vscode.NotebookCellOutputItem.json(JSON.parse(cell.document.getText()))
            vscode.NotebookCellOutputItem.text(result, 'text/plain'),
            vscode.NotebookCellOutputItem.text(js_file, 'application/javascript'),
            vscode.NotebookCellOutputItem.text(js_file, 'text/x-javascript'),
            vscode.NotebookCellOutputItem.text("<!DOCTYPE html>\n" + html_file, 'text/html'),
        ]));
    
        execution.end(true, Date.now());
    }
    private setCellFail(cell: vscode.NotebookCell, message: string, execution: vscode.NotebookCellExecution): void {
        /*cell.outputs = [{
            outputKind: vscode.CellOutputKind.Error,
            ename: "flow kernel",
            evalue: message,
            traceback: []
        }];
        cell.metadata.runState = vscode.NotebookCellRunState.Error;
        cell.metadata.lastRunDuration = undefined;*/

        execution.replaceOutput(new vscode.NotebookCellOutput([
            vscode.NotebookCellOutputItem.error(Error(message))
        ]));
        execution.end(true, Date.now());
    }
    private cellShouldBeRendered(cell: vscode.NotebookCell): boolean {
        const code = cell.document.getText();
        code.search('render');
        return code.indexOf('render') != -1 || code.indexOf('material') != -1;
    }
}
  
  
/*
export class FlowNotebookProvider implements vscode.NotebookContentProvider {
    async openNotebook(uri: vscode.Uri): Promise<vscode.NotebookData> {
        const cells = <vscode.NotebookCellData[]>JSON.parse((await vscode.workspace.fs.readFile(uri)).toString());
        const languages = ['markdown', 'flow'];
        const metadata: vscode.NotebookDocumentContentOptions
		 NotebookDocumentMetadata = { 
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
*/
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

/*
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
        document.getCells().forEach((cell) => {
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
		cell.executionSummary.success = true;
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
*/

export function createNotebook(): void {
    let ask: vscode.InputBoxOptions = { prompt: "Notebook file: ", placeHolder: "" };
	vscode.window.showInputBox(ask).then(file => {
        let content : [vscode.NotebookCellData] = [{
                kind: vscode.NotebookCellKind.Markup,
                value: "Put your markdown text here",
                languageId: "markdown",
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

