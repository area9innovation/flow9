import * as vscode from 'vscode';
import * as tools from './tools';
import { spawn, ChildProcess, spawnSync } from 'child_process';
import { readFileSync } from 'fs';
import { integer } from 'vscode-languageclient';

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
  
	constructor() {
		this.startExecutor();
		this._controller = vscode.notebooks.createNotebookController(this.id, 'flow-notebook', this.label);
		this._controller.supportedLanguages = this.supportedLanguages;
		this._controller.supportsExecutionOrder = true;
		this._controller.executeHandler = this._executeAll.bind(this);
	}
  
	dispose(): void {
		this.killExecutor()
		this._controller.dispose();
	}
  
	private execChainOfPromises(promises: (() => Promise<void>)[], i : integer): void {
		if (i < promises.length) {
			promises[i]().then( 
				() => this.execChainOfPromises(promises, i + 1),
				(x : string) => {
					vscode.window.showErrorMessage("CHAIN OF PROMISES FAILED", x);
				}
			);
		} else {
			vscode.window.showInformationMessage("CHAIN OF PROMISES COMPLETED");
		}
	}

	private _executeAll(cells: vscode.NotebookCell[], _notebook: vscode.NotebookDocument, _controller: vscode.NotebookController): void {
		//for (let cell of cells) {
		//	this.executeCell(cell);
		//}
		//const promises = cells.map(this.executeCell.bind(this));
		this.execChainOfPromises(cells.map(this.executeCell.bind(this)), 0);
		//Promise.all().then(() => vscode.window.showInformationMessage("PROMISE COMPLETED"));
	}
  
	/*private async _doExecution(cell: vscode.NotebookCell): Promise<void> {
		if (!this.executor) {
			this.startExecutor();
		}
		const execution = this._controller.createNotebookCellExecution(cell);	
		execution.executionOrder = ++this._executionOrder;
		execution.start(Date.now());
		this.executeCell(cell, execution);
	}*/

	private executeCell(cell: vscode.NotebookCell): () => Promise<void> {
		return () => new Promise((resolve, reject) => {
			if (!this.executor) {
				this.startExecutor();
			}
			const execution = this._controller.createNotebookCellExecution(cell);	
			execution.executionOrder = ++this._executionOrder;
			execution.start(Date.now());
			const code = this.prepareCellCode(cell);
			const should_be_rendered = this.cellShouldBeRendered(cell);
			const is_repl_command = this.isAReplCommand(cell);
			const flow_dir = tools.getFlowRoot();
			const html_opts = 
				"verbose=1 bin-dir=" + flow_dir + "/bin/ js-call-main=1 repl-compile-output=1 repl-no-quit=1 repl-save-tmp=1";
			const request = should_be_rendered ? 
				"compile html=www/cell_" + cell.index  + ".html " + html_opts + "\n" + code + "\n\n":
				(is_repl_command ? code + "\n" : "add cell_" + cell.index + " force\n" + code + "\n\nexec cell_" + cell.index + "\n"); 
			vscode.window.showInformationMessage("REQ1: " + escape(request));
			this.kernelChannel.append(request);
			if (!this.executor || !this.executor.stdin.write(request)) {
				reject("Error while writing: \n" + request);
			} else {
				const wrap_resolve = () => { this.callback = (s: string) => { }; resolve(); }
				const wrap_reject  = () => { this.callback = (s: string) => { }; reject(); }
				if (is_repl_command) {
					this.callback = this.makeTextOutCallback(wrap_resolve, wrap_reject, cell, execution);
				} else if (should_be_rendered) {
					vscode.window.showInformationMessage("shouldbe rendered" + escape(request));
					this.callback = this.makeHtmlOutCallback(wrap_resolve, wrap_reject, cell, execution);
				} else {
					this.callback = (s: string) => { 
						this.callback = this.makeTextOutCallback(wrap_resolve, wrap_reject, cell, execution);
					};
				}
			}
		});
	}
	private makeTextOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): (a : string) => void { 
		return (buffer : string) => {
			if (buffer.indexOf('Error:') == -1) {
				this.setCellTextSuccess(cell, buffer, execution);
				resolve();
			} else {
				this.setCellFail(cell, buffer, execution);
				reject(buffer);
			}
		}
	}
	private makeHtmlOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): (a : string) => void { 
		return (buffer : string) => {
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
	private setCellTextSuccess(cell: vscode.NotebookCell, result: string, execution: vscode.NotebookCellExecution): void {
		execution.replaceOutput(new vscode.NotebookCellOutput([
			vscode.NotebookCellOutputItem.text(result)
		]));
		execution.end(true, Date.now());
	}
	private setCellHtmlSuccess(cell: vscode.NotebookCell, result: string, execution: vscode.NotebookCellExecution): void {
		const js_file = readFileSync("www/cell_" + cell.index  + ".html.js").toString();
		const html_file = readFileSync("www/cell_" + cell.index  + ".html").toString();
		vscode.window.showInformationMessage("html_file: '" + html_file.slice(0, 128) + "'");
		execution.replaceOutput(new vscode.NotebookCellOutput(
			[
				vscode.NotebookCellOutputItem.text("<!DOCTYPE html>\n" + html_file, 'text/html'),
				vscode.NotebookCellOutputItem.text(result, 'text/plain'),
				//vscode.NotebookCellOutputItem.text(js_file, 'application/javascript'),
				//vscode.NotebookCellOutputItem.text(js_file, 'text/x-javascript'),
			], 
			{'enableScripts': true}
		));
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
			const REPL_commands = ["exit", "config", "help", "show", "del", "save"];
			return REPL_commands.findIndex((comm, ind, obj) => comm == command) != -1;
		}
	}
	private killExecutor(): void {
		if (this.executor) {
			this.executor.stdin.write("exit\n");
			this.executor = null;
		}
	}
	private startExecutor(): void {
		if (!this.executor) {
			const flow_dir = tools.getFlowRoot();
			this.executor = spawn("flowc1", ["repl=1", "repl-debug=1"]);
			let buffer: string = "";
			this.executor.stdout.on("data", (buf : any) => {
				let out = buf.toString();
				this.kernelChannel.append(out);
				buffer += out;
				// Check the end of execution of a previous command
				if (buffer.endsWith("> ") || buffer.trim().endsWith("Bye.")) {
					// remove terminating '> '
					if (buffer.endsWith("> ")) {
						buffer = buffer.slice(0, buffer.length - 2);
					} else if (buffer.trim().endsWith("Bye.")) {
						buffer = buffer.trim();
					}
					// remove grabage messages '"No carrier"'
					buffer.replace("\"No carrier\"", "");
					vscode.window.showInformationMessage("BUFFER: " + buffer);
					this.callback(buffer);
					buffer = "";
				}
			});
			this.executor.stdout.on("error", (out : string) => this.kernelChannel.append(out.toString()));
			this.executor.stderr.on("data", (out : string) => this.kernelChannel.append(out.toString()));
			this.executor.stderr.on("error", (out : string) => this.kernelChannel.append(out.toString()));
			// Exit callbacks for executor
			this.executor.on("close", (code : number, signal : string) => this.executor = null);
			this.executor.on("disconnect", () => this.executor = null);
			this.executor.on("error", (err : Error) => vscode.window.showErrorMessage(err.message));
			this.executor.on("exit", (code : number, signal : string) => this.executor = null);
		}
	}
	private callback = (arg: string) => { };
	private executor : ChildProcess = null;
	private kernelChannel: vscode.OutputChannel = vscode.window.createOutputChannel("Flow Notebook");
}

