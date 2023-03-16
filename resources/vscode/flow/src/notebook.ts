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
		const cells = raw.cells.map(item => {
			let value : any = item.value
			if (Array.isArray(value)) {
				value = value.join("\n")
			}
			return new vscode.NotebookCellData(
				item.kind,
				value,
				item.language
			)
		});
		// Pass read and formatted Notebook Data to VS Code to display Notebook with saved cells
		return new vscode.NotebookData(cells);
	}
	public async serializeNotebook(data: vscode.NotebookData, token: vscode.CancellationToken): Promise<Uint8Array> {
		// Map the Notebook data into the format we want to save the Notebook data as
		let contents: RawNotebookData = { cells: []};

		for (const cell of data.cells) {
			let value : any = cell.value
			if (value.includes("\n")) {
				value = value.split("\n")
			}
			contents.cells.push({
				kind: cell.kind,
				language: cell.languageId,
				value: value
			});
		}

		// Give a string of all the data to save and VS Code will handle the rest
		return new TextEncoder().encode(JSON.stringify(contents, null, 4));
	}
}

export class FlowNotebookController {
	readonly id = 'flow-notebook';
	public readonly label = 'Flow9 Notebook Controller';
	readonly supportedLanguages = ['flow'];

	private _executionOrder = 0;
	private readonly _controller: vscode.NotebookController;

	constructor() {
		this._controller = vscode.notebooks.createNotebookController(this.id, 'flow-notebook', this.label);
		this._controller.supportedLanguages = this.supportedLanguages;
		this._controller.supportsExecutionOrder = true;
		this._controller.executeHandler = this._executeAll.bind(this);
	}
	dispose(): void {
		this._killExecutor();
		this._controller.dispose();
	}
	private _execChainOfPromises(promises: (() => Promise<void>)[], i : integer): void {
		if (i < promises.length) {
			promises[i]().then(
				() => this._execChainOfPromises(promises, i + 1),
				(x : string) => { }
			);
		}
	}
	private _executeAll(cells: vscode.NotebookCell[], _notebook: vscode.NotebookDocument, _controller: vscode.NotebookController): void {
		this._execChainOfPromises(cells.map(this._executeCell.bind(this)), 0);
	}
	private _executeCell(cell: vscode.NotebookCell): () => Promise<void> {
		return () => new Promise((resolve, reject) => {
			const exec = () => {
				const execution = this._controller.createNotebookCellExecution(cell);
				execution.executionOrder = ++this._executionOrder;
				execution.start(Date.now());
				execution.token.onCancellationRequested(() => {
					// In case the execution is aborted, we shut down the executor.
					this._killExecutor();
					execution.replaceOutput(new vscode.NotebookCellOutput([
						vscode.NotebookCellOutputItem.text("Execution interrupted.")
					]));
					execution.end(false, Date.now());
					reject("Execution interrupted.");
				});
				const code = this._prepareCellCode(cell);
				const should_be_rendered = this._cellShouldBeRendered(cell);
				const is_repl_command = this._isAReplCommand(cell);
				const flow_dir = tools.getFlowRoot();
				// Possible options, passed to 'compile' command:
				//   readable=1
				//   "bin-dir=" + flow_dir + "/bin/"
				//   repl-compile-output=1
				//   repl-save-tmp=1

				// TODO: fix 'readable=1' so that the obtained code is working.
				//const html_opts = "js-call-main=1 repl-no-quit=1 readable=1";
				const html_opts = "js-call-main=1 repl-no-quit=1";
				const request = should_be_rendered ?
					"compile html=www/cell_" + cell.index  + ".html " + html_opts + "\n" + code + "\n\n":
					(is_repl_command ? code + "\n" : "add cell_" + cell.index + " force exec\n" + code + "\n\n");
				this._output(request);
				if (!this._executor || !this._executor.stdin.write(request)) {
					reject("Error while writing: \n" + request);
				} else {
					// Wrappers, which clear the callback.
					const wrap_resolve = () => { this._callback = (s: string) => { }; resolve(); }
					const wrap_reject  = () => { this._callback = (s: string) => { }; reject(); }
					if (is_repl_command) {
						// Just perform a REPL command and print its output as plain text.
						this._callback = this._makeTextOutCallback(wrap_resolve, wrap_reject, cell, execution);
					} else if (should_be_rendered) {
						// REPL interpreter will compile the code to html, so a callback will pick it up.
						this._callback = this._makeHtmlOutCallback(wrap_resolve, wrap_reject, cell, execution);
					} else {
						// This first message is comming from 'add cell_<i>', thus is not an output yet.
						// So we pass it to the 'makeTextOutCallback' - it may be used as an error message,
						// if current cell code contains errors.
						this._callback = this._makeTextOutCallback(wrap_resolve, wrap_reject, cell, execution);
					}
				}
			}
			if (!this._executor) {
				// Delay the execution util the executor is ready
				this._startExecutor(exec);
			} else {
				exec();
			}
		});
	}
	// Here 'msg' is a message from a previuos command (i.e. 'add cell_<i>' with a piece of code)
	private _makeTextOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): (a : string) => void {
		return (buffer : string) => {
			if (!buffer.startsWith('Error:')) {
				this._setCellTextSuccess(cell, buffer, execution);
				resolve();
			} else {
				this._setCellFail(cell, buffer, execution);
				reject(buffer);
			}
		}
	}
	private _makeHtmlOutCallback(resolve : () => void, reject : (x : any) => void, cell: vscode.NotebookCell, execution: vscode.NotebookCellExecution): (a : string) => void {
		return (buffer : string) => {
			if (!buffer.startsWith('Error:')) {
				this._setCellHtmlSuccess(cell, buffer, execution);
				resolve();
			} else {
				this._setCellFail(cell, buffer, execution);
				reject(buffer);
			}
		}
	}
	private _prepareCellCode(cell: vscode.NotebookCell): string {
		const code = cell.document.getText();
		// Leave only one new line after a line of code (remove extra newlines)
		return code.replace(/(\r\n|\r|\n){2,}/g, '\n').trim();
	}
	private _setCellTextSuccess(cell: vscode.NotebookCell, result: string, execution: vscode.NotebookCellExecution): void {
		execution.replaceOutput(new vscode.NotebookCellOutput([
			vscode.NotebookCellOutputItem.text(result)
		]));
		execution.end(true, Date.now());
	}
	private _setCellHtmlSuccess(cell: vscode.NotebookCell, result: string, execution: vscode.NotebookCellExecution): void {
		const html_file = readFileSync("www/cell_" + cell.index  + ".html").toString();
		execution.replaceOutput(new vscode.NotebookCellOutput([
			vscode.NotebookCellOutputItem.text("<!DOCTYPE html>\n" + html_file, 'text/html'),
			vscode.NotebookCellOutputItem.text(result, 'text/plain')
		]));
		execution.end(true, Date.now());
	}
	private _setCellFail(cell: vscode.NotebookCell, message: string, execution: vscode.NotebookCellExecution): void {
		execution.replaceOutput(new vscode.NotebookCellOutput([
			vscode.NotebookCellOutputItem.text(message)
		]));
		execution.end(false, Date.now());
	}
	private _cellShouldBeRendered(cell: vscode.NotebookCell): boolean {
		const code = cell.document.getText();
		return code.indexOf('render') != -1 || code.indexOf('material') != -1;
	}
	private _isAReplCommand(cell: vscode.NotebookCell): boolean {
		const words = cell.document.getText().split(" ").filter((w) => w != '');
		if (words.length == 0) {
			return false;
		} else {
			const command = words[0];
			const REPL_commands = ["exit", "config", "help", "show", "del", "save"];
			return REPL_commands.findIndex((comm, ind, obj) => comm == command) != -1;
		}
	}
	private _killExecutor(): void {
		if (this._executor) {
			this._executor.stdin.write("exit\n");
			this._executor = null;
		}
		// reset the callback, just in case.
		this._callback = (arg: string) => { };
	}
	private _startExecutor(after_start : () => void): void {
		if (!this._executor) {
			const flow_dir = tools.getFlowRoot();
			// Skip the first message from REPL interpreter.
			// This callback will be called just after the initial '> ' with
			// a greeting message from REPL interpreter is shown.
			this._callback = (arg: string) => {
				// Clear the callback.
				this._callback = (arg: string) => { };
				// Call a function after '> ' is read from stdout.
				after_start();
			};
			this._executor = spawn("flowc1", ["repl=1"], { shell : true });
			let buffer: string = "";
			this._executor.stdout.on("data", (buf : any) => {
				let out = buf.toString();
				this._output(out);
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
					buffer = buffer.replace("\"No carrier\"", "");
					this._callback(buffer);
					buffer = "";
				}
			});
			this._executor.stdout.on("error", (out : string) => this._output(out));
			this._executor.stderr.on("data", (out : string) => this._output(out));
			this._executor.stderr.on("error", (out : string) => this._output(out));
			// Exit callbacks for executor
			this._executor.on("close", (code : number, signal : string) => this._executor = null);
			this._executor.on("disconnect", () => this._executor = null);
			this._executor.on("error", (err : Error) => vscode.window.showErrorMessage(err.message));
			this._executor.on("exit", (code : number, signal : string) => this._executor = null);
		}
	}
	// The callback, which is called when a new message is received from the REPL interpreter.
	private _callback = (arg: string) => { };
	// REPL interpreter process.
	private _executor : ChildProcess = null;
	private _kernelChannel: vscode.OutputChannel = null;
	private _output(msg: string): void {
		if (!this._kernelChannel) {
			this._kernelChannel = vscode.window.createOutputChannel("Flow Notebook");
		}
		this._kernelChannel.show(true);
		this._kernelChannel.append(msg);
	}
}
