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
		return new vscode.NotebookData(cells);
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
				const is_repl_command = this.isAReplCommand(cell);
				//const js_opts = "readable=1";
				const flow_dir = tools.getFlowRoot();
				const html_opts = 
					"verbose=1 bin-dir=" + flow_dir + "/bin/ readable=1 js-call-main=1 repl-compile-output=1 repl-no-quit=1";
				const request = should_be_rendered ? 
					"compile html=www/cell_" + cell.index  + ".html " + html_opts + "\n" + code + "\n\n":
					(is_repl_command ? code + "\n\n" : "add cell_" + cell.index + " force\n" + code + "\n\n"); 
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
	/*cancelCellExecution(cell: vscode.NotebookCell): void {
		cell.metadata.runState = "vscode.NotebookCellRunState.Error";
		cell.metadata.lastRunDuration = +new Date() - this.start;
		this.callback("Error: interrupted");
	}*/
	/*async executeAllCells(document: vscode.NotebookDocument): Promise<void> {
		const deferred = document.cells.map((cell) => this.executeCellDeferred(document, cell));
		deferred.reduce(
			(chained, curr, i) => {
				return () => chained().then(() => curr());
			},
			() => Promise.resolve()
		)();
	}*/
	/*cancelAllCellsExecution(document: vscode.NotebookDocument): void {
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
	}*/
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
		execution.replaceOutput(new vscode.NotebookCellOutput([
			vscode.NotebookCellOutputItem.text(result)
		]));
	
		execution.end(true, Date.now());
	}
	private setCellHtmlSuccess(cell: vscode.NotebookCell, result: string, execution: vscode.NotebookCellExecution): void {
		const js_file = readFileSync("www/cell_" + cell.index  + ".html.js").toString();
		const html_file = readFileSync("www/cell_" + cell.index  + ".html").toString();
		const test_html_file = readFileSync("www/test.html").toString();
		execution.replaceOutput(new vscode.NotebookCellOutput([
			vscode.NotebookCellOutputItem.text("output: '" + result + "'", 'text/plain'),
			vscode.NotebookCellOutputItem.text(js_file, 'application/javascript'),
			vscode.NotebookCellOutputItem.text(js_file, 'text/x-javascript'),
			vscode.NotebookCellOutputItem.text("<!DOCTYPE html>\n" + html_file, 'text/html'),
		]));
	
		execution.end(true, Date.now());
	}
	private setCellFail(cell: vscode.NotebookCell, message: string, execution: vscode.NotebookCellExecution): void {
		execution.replaceOutput(new vscode.NotebookCellOutput([
			vscode.NotebookCellOutputItem.error(Error(message))
		]));
		execution.end(true, Date.now());
	}
	private cellShouldBeRendered(cell: vscode.NotebookCell): boolean {
		const code = cell.document.getText();
		return code.indexOf('render') != -1 || code.indexOf('material') != -1;
	}
	private isAReplCommand(cell: vscode.NotebookCell): boolean {
		const words = cell.document.getText().split(" ").filter((w) => w != '');
		if (words.length == 0) {
			return false;
		} else {
			const command = words[0];
			return ["exit", "config", "help", "show", "del", "save"].findIndex((comm, ind, obj) => comm == command) != -1;
		}
	}
}

export function killExecutor(): void {
	if (executor) {
		executor.stdin.write("exit");
		executor.kill("SIGKILL");
		executor = null;
	}
}

export function startExecutor(): void {
	if (!executor) {
		const flow_dir = tools.getFlowRoot();
		executor = spawn("flowc1", ["repl=1", "repl-debug=1"]);
	} else {
		executor.removeAllListeners();
	}
}

let executor : ChildProcess = null;
let kernelChannel: vscode.OutputChannel = vscode.window.createOutputChannel("Flow Notebook kernel");
