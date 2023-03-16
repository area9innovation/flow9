import { BackendBreakpoint, Stack, Variable, VariableObject, MIError } from "./backend"
import * as ChildProcess from "child_process"
import { EventEmitter } from "events"
import { parseMI, MINode } from './mi_parse';
import * as net from "net"
import * as fs from "fs"
import { posix } from "path"
import * as nativePath from "path"
let path = posix;

export function escape(str: string) {
	return str.replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
}

const nonOutput = /^(?:\d*|undefined)[\*\+\=]|[\~\@\&\^]/;
const gdbMatch = /(?:\d*|undefined)\(gdb\)/;
const numRegex = /\d+/;

function couldBeOutput(line: string) {
	if (nonOutput.exec(line))
		return false;
	return true;
}

const trace = false;

enum ProcessState {
	Stopped,
	Running
};

export class MI2 extends EventEmitter {
	constructor(public application: string, debug : boolean, public preargs: string[], public extraargs: string[], procEnv: any) {
		super();

		this.debug = debug;
		if (procEnv) {
			var env = {};
			// Duplicate process.env so we don't override it
			for (var key in process.env)
				if (process.env.hasOwnProperty(key))
					env[key] = process.env[key];

			// Overwrite with user specified variables
			for (var key in procEnv) {
				if (procEnv.hasOwnProperty(key)) {
					if (procEnv === null)
						delete env[key];
					else
						env[key] = procEnv[key];
				}
			}
			this.procEnv = env;
		}
	}

	load(cwd: string, target: string, procArgs: string): Thenable<any> {
		if (!nativePath.isAbsolute(target))
			target = nativePath.join(cwd, target);
		return new Promise((resolve, reject) => {
			let startDebugArgs = this.debug ? ["--debug-mi"] : [];
			let args = startDebugArgs.concat(this.preargs).concat(this.extraargs || []).concat([target]);
			if (procArgs)
				args = args.concat(["--"]).concat(procArgs);
			this.log("log", "Current directory: " + cwd);
			const msg = this.debug ? "Running debugger: " : "Running: ";
			this.log("log", msg + this.application + " " + args.join(" "));
			this.process = ChildProcess.spawn(this.application, args, { cwd: cwd, env: this.procEnv, shell: true });
			this.process.stdout.setEncoding('utf-8');
			this.process.stderr.setEncoding('utf-8');
			this.process.stdout.on("data", this.stdout.bind(this));
			this.process.stderr.on("data", this.stderr.bind(this));
			this.process.on("exit", (() => { this.emit("quit"); this.process = null; }).bind(this));
			this.process.on("error", ((err) => { this.emit("launcherror", err); }).bind(this));

			this.emit("debug-ready");
			resolve(this);
		});
	}

	stdout(data) {
		if (trace)
			this.log("stderr", "stdout: " + data);
		this.buffer += data;
		let end = this.buffer.lastIndexOf('\n');
		if (end != -1) {
			this.onOutput(this.buffer.substr(0, end));
			this.buffer = this.buffer.substr(end + 1);
		}
		if (this.buffer.length) {
			if (this.onOutputPartial(this.buffer)) {
				this.buffer = "";
			}
		}
	}

	stderr(data) {
		this.errbuf += data;
		let end = this.errbuf.lastIndexOf('\n');
		if (end != -1) {
			this.onOutputStderr(this.errbuf.substr(0, end));
			this.errbuf = this.errbuf.substr(end + 1);
		}
		if (this.errbuf.length) {
			this.logNoNewLine("stderr", this.errbuf);
			this.errbuf = "";
		}
	}

	onOutputStderr(lines) {
		lines = <string[]>lines.split('\n');
		lines.forEach(line => {
			this.log("stderr", line);
		});
	}

	onOutputPartial(line) {
		if (couldBeOutput(line)) {
			this.logNoNewLine("stdout", line);
			return true;
		}
		return false;
	}

	onOutput(lines) {
		lines = <string[]>lines.split('\n');
		lines.forEach(line => {
			if (!this.debug) {
				this.log("stdout", line);
			} else if (couldBeOutput(line)) {
				if (!gdbMatch.exec(line))
					this.log("stdout", line);
			}
			else {
				if (this.debugOutput)
					this.log("log", "GDB -> App [raw]: " + line);
				let parsed = parseMI(line);
				if (this.debugOutput)
					this.log("log", "GDB -> App: " + JSON.stringify(parsed));
				let handled = false;
				if (parsed.token !== undefined) {
					if (this.handlers[parsed.token]) {
						this.handlers[parsed.token](parsed);
						delete this.handlers[parsed.token];
						handled = true;
					}
				}
				if (!handled && parsed.resultRecords && parsed.resultRecords.resultClass == "error") {
					this.log("stderr", parsed.result("msg") || line);
				}
				if (parsed.outOfBandRecord) {
					parsed.outOfBandRecord.forEach(record => {
						if (record.isStream) {
							if (this.debugOutput || record.type != "log")
								this.log(record.type, record.content);
							// detect program existed normally - flowcpp does not supply reason code
							if (record.type == "target" && record.content.trim() == "The program has exited")
								this.exitedNormallyReceived = true;
							// detect program interrupt - again, flowcpp does not supply reason code
							if (record.type == "console" && record.content.startsWith("Interrupt in"))
								this.interruptDetected = true;
						} else {
							if (record.type == "exec") {
								this.emit("exec-async-output", parsed);
								if (record.asyncClass == "running") {
									this.state = ProcessState.Running;
									this.emit("running", parsed);
								} else if (record.asyncClass == "stopped") {
									this.state = ProcessState.Stopped;
									let reason = parsed.record("reason");
									// flowcpp does not return reason - assuming breakpoint-hit unless
									// there was 'exited normally' or 'interrupt' message before (see above)
									if (reason == undefined) {
										if (this.exitedNormallyReceived)
											reason = "exited-normally";
										else if (this.interruptDetected)
											reason = "interrupt-stop";
										else
											reason = "breakpoint-hit";
									}

									this.exitedNormallyReceived = false;
									this.interruptDetected = false;

									if (trace)
										this.log("stderr", "stop: " + reason);
									if (reason == "breakpoint-hit")
										this.emit("breakpoint", parsed);
									else if (reason == "end-stepping-range")
										this.emit("step-end", parsed);
									else if (reason == "function-finished")
										this.emit("step-out-end", parsed);
									else if (reason == "signal-received")
										this.emit("signal-stop", parsed);
									else if (reason == "exited-normally")
										this.emit("exited-normally", parsed);
									else if (reason == "exited") { // exit with error code != 0
										this.log("stderr", "Program exited with code " + parsed.record("exit-code"));
										this.emit("exited-normally", parsed);
									} else if (reason == "interrupt-stop") {
										// do nothing - this is done to stop, change breakpoints, restart the program
									}else {
										this.log("console", "Not implemented stop reason (assuming exception): " + reason);
										this.emit("stopped", parsed);
									}
								} else
									this.log("log", JSON.stringify(parsed));
							}
						}
					});
					handled = true;
				}
				if (parsed.token == undefined && parsed.resultRecords == undefined && parsed.outOfBandRecord.length == 0)
					handled = true;
				if (!handled)
					this.log("log", "Unhandled: " + JSON.stringify(parsed));
			}
		});
	}

	start(): Promise<boolean> {
		return new Promise((resolve, reject) => {
			this.once("ui-break-done", async () => {
				if (this.debug) {
					this.log("console", "Running executable");
					let info = await this.sendCommand("exec-run");
					resolve(info.resultRecords.resultClass == "running");
				} else {
					resolve(true);
				}
			});
		});
	}

	stop() {
		if (this.process) {
			let proc = this.process;
			let to = setTimeout(() => {
				process.kill(-proc.pid);
			}, 1000);
			this.process.on("exit", function (code) {
				clearTimeout(to);
			});
			if (this.debug)
				this.sendRaw("-gdb-exit");
		}
	}

	async interrupt(): Promise<boolean> {
		if (trace)
			this.log("stderr", "interrupt");
		let info = await this.sendCommand("exec-interrupt");
		return info.resultRecords.resultClass == "done";
	}

	async continue(): Promise<boolean> {
		if (trace)
			this.log("stderr", "continue");
		let info = await this.sendCommand("exec-continue");
		return info.resultRecords.resultClass == "running";
	}

	async next(): Promise<boolean> {
		if (trace)
			this.log("stderr", "next");
		let info = await this.sendCommand("exec-next");
		return info.resultRecords.resultClass == "running";
	}

	async step(): Promise<boolean> {
		if (trace)
			this.log("stderr", "step");
		let info = await this.sendCommand("exec-step");
		return info.resultRecords.resultClass == "running";
	}

	async stepOut(): Promise<boolean> {
		if (trace)
			this.log("stderr", "stepOut");
		let info = await this.sendCommand("exec-finish");
		return info.resultRecords.resultClass == "running";
	}

	changeVariable(name: string, rawValue: string): Thenable<any> {
		if (trace)
			this.log("stderr", "changeVariable");
		return this.sendCommand("var-assign " + name + " " + rawValue);
	}

	loadBreakPoints(breakpoints: BackendBreakpoint[]): Thenable<[boolean, BackendBreakpoint][]> {
		if (trace)
			this.log("stderr", "loadBreakPoints");
		let promisses = breakpoints.map(breakpoint => this.addBreakPoint(breakpoint));
		return Promise.all(promisses);
	}

	setBreakPointCondition(bkptNum, condition): Thenable<any> {
		if (trace)
			this.log("stderr", "setBreakPointCondition");
		return this.sendCommand("break-condition " + bkptNum + " " + condition);
	}

	async addBreakPoint(breakpoint: BackendBreakpoint): Promise<[boolean, BackendBreakpoint]> {
		if (trace)
			this.log("stderr", "addBreakPoint");

		if (this.breakpoints.has(breakpoint))
			return [false, undefined];
		let location = "";
		if (breakpoint.countCondition) {
			if (breakpoint.countCondition[0] == ">")
				location += "-i " + numRegex.exec(breakpoint.countCondition.substr(1))[0] + " ";
			else {
				let match = numRegex.exec(breakpoint.countCondition)[0];
				if (match.length != breakpoint.countCondition.length) {
					this.log("stderr", "Unsupported break count expression: '" + breakpoint.countCondition + "'. Only supports 'X' for breaking once after X times or '>X' for ignoring the first X breaks");
					location += "-t ";
				}
				else if (parseInt(match) != 0)
					location += "-t -i " + parseInt(match) + " ";
			}
		}
		if (breakpoint.raw)
			location += '"' + escape(breakpoint.raw) + '"';
		else
			location += '"' + escape(breakpoint.file) + ":" + breakpoint.line + '"';
		try {
			let result = await this.sendCommand("break-insert " + location);
			if (result.resultRecords.resultClass == "done") {
				let bkptNum = parseInt(result.result("bkpt.number"));
				let newBrk = {
					file: result.result("bkpt.file"),
					line: parseInt(result.result("bkpt.line")),
					condition: breakpoint.condition
				};
				if (breakpoint.condition) {
					let result = await this.setBreakPointCondition(bkptNum, breakpoint.condition);
					if (result.resultRecords.resultClass == "done") {
						this.breakpoints.set(newBrk, bkptNum);
						return [true, newBrk];
					} else {
						return [false, null];
					}
				} else {
					this.breakpoints.set(newBrk, bkptNum);
					return [true, newBrk];
				}
			}
			else
				return [false, undefined];
		} catch (e) {
			this.log("stderr", "Error setting breakpoint: " + e);
			return [false, undefined];
		}
	}

	async removeBreakPoint(breakpoint: BackendBreakpoint): Promise<boolean> {
		if (trace)
			this.log("stderr", "removeBreakPoint");
		if (!this.breakpoints.has(breakpoint))
			return false;
		let result = await this.sendCommand("break-delete " + this.breakpoints.get(breakpoint));
		if (result.resultRecords.resultClass == "done") {
			this.breakpoints.delete(breakpoint);
			return true;
		}
		else
			return false;
	}

	async clearBreakPoints(): Promise<boolean> {
		if (trace)
			this.log("stderr", "clearBreakPoints");
		if (this.isRunning()) // stop if we are running
			if (!await this.interrupt())
				return false;
		let breakpointIndices = Array.from(this.breakpoints.values());
		let result = await this.sendCommand("break-delete " +
			breakpointIndices.join(" "));
		if (result.resultRecords.resultClass == "done") {
			this.breakpoints.clear();
			return true;
		} else
			return false;
	}

	async getStack(maxLevels: number): Promise<Stack[]> {
		if (trace)
			this.log("stderr", "getStack");
		let command = "stack-list-frames";
		if (maxLevels) {
			command += " 0 " + maxLevels;
		}
		let result = await this.sendCommand(command);
		let stack = result.result("stack");
		let ret: Stack[] = stack.map(element => {
			let level = MINode.valueOf(element, "@frame.level");
			let addr = MINode.valueOf(element, "@frame.addr");
			let func = MINode.valueOf(element, "@frame.func");
			let filename = MINode.valueOf(element, "@frame.file");
			let isEnd = filename == '--end--'; // marks end of stack, no source provided
			let file = MINode.valueOf(element, "@frame.fullname");
			let line = 0;
			let lnstr = MINode.valueOf(element, "@frame.line");
			if (lnstr)
				line = parseInt(lnstr);
			let from = parseInt(MINode.valueOf(element, "@frame.from"));
			let args = MINode.valueOf(element, "@frame.args");
			return {
				address: addr,
				fileName: isEnd ? null : filename,
				file: isEnd ? null : file,
				function: func || from,
				level: level,
				line: line,
				args: args
			};
		});
		return ret;
	}

	async evalExpression(name: string): Promise<any> {
		if (trace)
			this.log("stderr", "evalExpression");
		return this.sendCommand("data-evaluate-expression " + name);
	}

	async getVarAttrs(name: string): Promise<any> {
		if (trace)
			this.log("stderr", "getVarAttrs");
		return this.sendCommand("var-show-attributes " + name);
	}

	async getStackVariables(thread: number, frame: number, argsOnly : boolean): Promise<Variable[]> {
		if (trace)
			this.log("stderr", "getStackVariables");

		const selectRes = await this.sendCommand(`stack-select-frame ${frame}`);

		if (argsOnly) {
			const stackInfo = await this.sendCommand("stack-info-frame");
			// args - they are returned with values, wrapping into Variable
			const argsRaw: any[] = MINode.valueOf(stackInfo.result("frame"), "args") || [];
			const args = argsRaw.map(a =>
				({name : MINode.valueOf(a, "name"), valueStr : MINode.valueOf(a, "value")}));
			return args;
		} else {
			const localsResult = await this.sendCommand("stack-list-locals");
			const locals: any[] = localsResult.result("locals");
			// locals - we only get names - but we do not actually need values
			const varNamesRaw: any = MINode.valueOf(locals, "name") || [];
			const varNames: string[] = typeof(varNamesRaw) == "string" ? [varNamesRaw] : varNamesRaw;

			return varNames.map(a => ({ name : a}));
		}
	}

	async varCreate(expression: string, frameNum : number | "*", name: string = "-"): Promise<VariableObject> {
		if (trace)
			this.log("stderr", "varCreate");
		const res = await this.sendCommand(`var-create ${name} ${frameNum} "${expression}"`);
		return new VariableObject(res.result(""));
	}

	async varListChildren(name: string): Promise<VariableObject[]> {
		if (trace)
			this.log("stderr", "varListChildren");
		//TODO: add `from` and `to` arguments
		const res = await this.sendCommand(`var-list-children ${name}`);
		const children = res.result("children") || [];
		let omg: VariableObject[] = children.map(child => new VariableObject(child[1]));
		return omg;
	}

	async varUpdate(name: string = "*"): Promise<MINode> {
		if (trace)
			this.log("stderr", "varUpdate");
		return this.sendCommand(`var-update --all-values ${name}`)
	}

	async varAssign(name: string, rawValue: string): Promise<MINode> {
		if (trace)
			this.log("stderr", "varAssign");
		return this.sendCommand(`var-assign ${name} ${rawValue}`);
	}

	async varDelete(name: string): Promise<MINode> {
		if (trace)
			this.log("stderr", "varAssign");
		return this.sendCommand(`var-delete ${name}`);
	}

	logNoNewLine(type: string, msg: string) {
		this.emit("msg", type, msg);
	}

	log(type: string, msg: string) {
		this.emit("msg", type, (msg.length && msg[msg.length - 1] == '\n') ? msg : (msg + "\n"));
	}

	sendUserInput(command: string): Thenable<any> {
		if (command.startsWith("-")) {
			return this.sendCommand(command.substr(1));
		}
		else {
			this.sendRaw(command);
			return Promise.resolve(undefined);
		}
	}

	sendRaw(raw: string) {
		if (this.printCalls)
			this.log("log", raw);

		this.process.stdin.write(raw + "\n");
	}

	sendCommand(command: string, suppressFailure: boolean = false): Thenable<MINode> {
		let sel = this.currentToken++;
		return new Promise((resolve, reject) => {
			this.handlers[sel] = (node: MINode) => {
				if (node && node.resultRecords && node.resultRecords.resultClass === "error") {
					if (suppressFailure) {
						this.log("stderr", `WARNING: Error executing command '${command}'`);
						resolve(node);
					}
					else
						reject(new MIError(node.result("msg") || "Internal error", command));
				}
				else
					resolve(node);
			};
			this.sendRaw(sel + "-" + command);
		});
	}

	isReady(): boolean {
		return !!this.process;
	}

	isRunning(): boolean {
		return this.state == ProcessState.Running;
	}

	printCalls: boolean;
	debugOutput: boolean;
	public procEnv: any;
	protected currentToken: number = 1;
	protected handlers: { [index: number]: (info: MINode) => any } = {};
	protected breakpoints: Map<BackendBreakpoint, Number> = new Map();
	protected buffer: string = "";
	protected errbuf: string = "";
	protected process: ChildProcess.ChildProcess;
	protected stream;
	private exitedNormallyReceived: boolean = false;
	private interruptDetected: boolean = false;
	protected state: ProcessState = ProcessState.Stopped;
	protected debug: boolean;
}
