import { LoggingDebugSession, Logger, logger, InitializedEvent, TerminatedEvent, StoppedEvent, OutputEvent, Thread, StackFrame, Scope, Source, Handles, DebugSession, Breakpoint } from 'vscode-debugadapter';
import { DebugProtocol } from 'vscode-debugprotocol';
import { Variable, Stack, VariableObject, MIError } from './backend/backend';
import { MINode } from './backend/mi_parse';
import { expandValue } from './backend/gdb_expansion';
import { MI2 } from './backend/flowcpp_runtime';
import { posix } from "path";


logger.setup(Logger.LogLevel.Verbose, true);

class ExtendedVariable {
	constructor(public name, public options) {
	}
}

export interface LaunchRequestArguments extends DebugProtocol.LaunchRequestArguments {
	cwd: string;
	target: string;
	runner_path: string;
	env: any;
	debugger_args: string;
	arguments: string;
	autorun: string[];
	print_calls: boolean;
	showDevDebugOutput: boolean;
	compiler: string;
}

const STACK_HANDLES_START = 1000;
const VAR_HANDLES_START = 2000;

export class FlowDebugSession extends LoggingDebugSession {
	protected variableHandles = new Handles<string | VariableObject | ExtendedVariable>(VAR_HANDLES_START);
	protected variableHandlesReverse: { [id: string]: number } = {};
	protected StackFrames: Stack[] = [];
	protected useVarObjects: boolean = false;
	protected quit: boolean;
	protected needContinue: boolean;
	protected started: boolean;
	protected crashed: boolean;
	protected debugReady: boolean;
	protected miDebugger: MI2;
	protected threadID: number = 1;
	protected debug : boolean;

	public constructor(debuggerLinesStartAt1: boolean, isServer: boolean = false, threadID: number = 1) {
		super("flow-debug.txt", debuggerLinesStartAt1, isServer);
		this.threadID = threadID;
	}

	protected initializeRequest(response: DebugProtocol.InitializeResponse, args: DebugProtocol.InitializeRequestArguments): void {
		response.body.supportsHitConditionalBreakpoints = true;
		response.body.supportsConfigurationDoneRequest = true;
		response.body.supportsConditionalBreakpoints = true;
		response.body.supportsFunctionBreakpoints = true;
		response.body.supportsEvaluateForHovers = true;
		//response.body.supportsSetVariable = true;
		this.sendResponse(response);
	}

	protected initDebugger(debug : boolean) {
		this.miDebugger.on("launcherror", this.launchError.bind(this));
		this.miDebugger.on("quit", this.quitEvent.bind(this));
		this.miDebugger.on("exited-normally", this.quitEvent.bind(this));
		this.miDebugger.on("stopped", this.stopEvent.bind(this));
		this.miDebugger.on("msg", this.handleMsg.bind(this));
		if (debug) {
			this.miDebugger.on("breakpoint", this.handleBreakpoint.bind(this));
			this.miDebugger.on("step-end", this.handleBreak.bind(this));
			this.miDebugger.on("step-out-end", this.handleBreak.bind(this));
			this.miDebugger.on("signal-stop", this.handlePause.bind(this));
		}
	}

	protected handleMsg(type: string, msg: string) {
		if (type == "target")
			type = "stdout";
		if (type == "log")
			type = "stderr";
		this.sendEvent(new OutputEvent(msg, type));
	}

	protected handleBreakpoint() {
		this.sendEvent(new StoppedEvent("breakpoint", this.threadID));
	}

	protected handleBreak() {
		this.sendEvent(new StoppedEvent("step", this.threadID));
	}

	protected handlePause() {
		this.sendEvent(new StoppedEvent("user request", this.threadID));
	}

	protected stopEvent() {
		if (!this.started)
			this.crashed = true;
		if (!this.quit)
			this.sendEvent(new StoppedEvent("exception", this.threadID));
	}

	protected quitEvent() {
		this.quit = true;
		this.sendEvent(new TerminatedEvent());
	}

	private getCompilerSwitch(compiler: string): string {
		return "--" + compiler;
	}

	protected launchRequest(response: DebugProtocol.LaunchResponse, args: LaunchRequestArguments): void {

		// make sure to 'Stop' the buffered logging if 'trace' is not set
		//logger.setup(args.trace ? Logger.LogLevel.Verbose : Logger.LogLevel.Stop, false);

		this.debug = !args.noDebug;

		let compiler = args.compiler || "flowcompiler";

		this.miDebugger = new MI2(args.runner_path || "flowcpp", this.debug,
			[this.getCompilerSwitch(compiler)], [args.debugger_args], args.env);
		this.initDebugger(this.debug);
		this.quit = false;
		this.needContinue = false;
		this.started = false;
		this.crashed = false;
		this.debugReady = false;
		this.miDebugger.printCalls = !!args.print_calls;
		this.miDebugger.debugOutput = !!args.showDevDebugOutput;

		this.miDebugger.load(args.cwd, args.target, args.arguments).then(() => {
			if (args.autorun)
				args.autorun.forEach(command => {
					this.miDebugger.sendUserInput(command);
				});
			this.sendResponse(response);
			this.sendEvent(new InitializedEvent());
			// start the program in the runtime - in reality wait for configurationDone
			this.miDebugger.start();
		}, err => {
			this.sendErrorResponse(response, 103, `Failed to load MI Debugger: ${err.toString()}`)
		});		
	}

	protected launchError(err: any) {
		this.handleMsg("stderr", "Could not start debugger process, does the program exist in filesystem?\n");
		this.handleMsg("stderr", err.toString() + "\n");
		this.quitEvent();
	}

	protected disconnectRequest(response: DebugProtocol.DisconnectResponse, args: DebugProtocol.DisconnectArguments): void {
		this.miDebugger.stop();

		this.sendResponse(response);
	}

	protected async setVariableRequest(response: DebugProtocol.SetVariableResponse, args: DebugProtocol.SetVariableArguments): Promise<void> {
		try {
			if (this.useVarObjects) {
				let name = args.name;
				if (args.variablesReference >= VAR_HANDLES_START) {
					const parent = this.variableHandles.get(args.variablesReference) as VariableObject;
					name = `${parent.name}.${name}`;
				}

				let res = await this.miDebugger.varAssign(name, args.value);
				response.body = {
					value: res.result("value")
				};
			}
			else {
				await this.miDebugger.changeVariable(args.name, args.value);
				response.body = {
					value: args.value
				};
			}
			this.sendResponse(response);
		}
		catch (err) {
			this.sendErrorResponse(response, 11, `Could not continue: ${err}`);
		};
	}

	protected setFunctionBreakPointsRequest(response: DebugProtocol.SetFunctionBreakpointsResponse, args: DebugProtocol.SetFunctionBreakpointsArguments): void {
		this.debugReady = true;
		let all = args.breakpoints.map(brk => this.miDebugger.addBreakPoint({ raw: brk.name, condition: brk.condition, countCondition: brk.hitCondition }));

		Promise.all(all).then(brkpoints => {
			response.body = {
				breakpoints: brkpoints.map(brkp => new Breakpoint(brkp[0], brkp[1].line))
			};
			this.sendResponse(response);
		}, msg => {
			this.sendErrorResponse(response, 10, msg.toString());
		});
	}

	protected setBreakPointsRequest(response: DebugProtocol.SetBreakpointsResponse, args: DebugProtocol.SetBreakpointsArguments): void {
		this.debugReady = true;
		let running = this.miDebugger.isRunning();
		this.miDebugger.clearBreakPoints().then(async () => {
			let path = args.source.path;
			let all = args.breakpoints.map(brk => this.miDebugger.addBreakPoint({ file: path, line: brk.line, condition: brk.condition, countCondition: brk.hitCondition }));

			let brkpoints = await Promise.all(all);
			if (running)
				await this.miDebugger.continue();
			response.body = {
				breakpoints: brkpoints.map(brkp => new Breakpoint(brkp[0], brkp[1].line))
			};
			this.sendResponse(response);
		}, msg => {
			this.sendErrorResponse(response, 9, msg.toString());
		});
	}

	protected threadsRequest(response: DebugProtocol.ThreadsResponse): void {
		response.body = {
			threads: [
				new Thread(this.threadID, "Thread 1")
			]
		};
		this.sendResponse(response);
	}

	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {
		this.miDebugger.getStack(args.levels).then(stack => {
			this.StackFrames = stack;
			let ret: StackFrame[] = stack.map(element => {
				let file = element.file;
				if (file) {
					if (process.platform === "win32") {
						if (file.startsWith("\\cygdrive\\") || file.startsWith("/cygdrive/")) {
							file = file[10] + ":" + file.substr(11); // replaces /cygdrive/c/foo/bar.txt with c:/foo/bar.txt
						}
					}
					return new StackFrame(element.level, element.function + "@" + element.address, new Source(element.fileName, file), element.line, 0);
				}
				else
					return new StackFrame(element.level, element.function + "@" + element.address, null, element.line, 0);
			});
			response.body = {
				stackFrames: ret
			};
			this.sendResponse(response);
		}, err => {
			this.sendErrorResponse(response, 12, `Failed to get Stack Trace: ${err.toString()}`)
		});
	}

	protected configurationDoneRequest(response: DebugProtocol.ConfigurationDoneResponse, args: DebugProtocol.ConfigurationDoneArguments): void {
		if (this.miDebugger)
			this.miDebugger.emit("ui-break-done");

		this.sendResponse(response);
	}

	protected scopesRequest(response: DebugProtocol.ScopesResponse, args: DebugProtocol.ScopesArguments): void {
		response.body = {
			scopes: [new Scope("Local", STACK_HANDLES_START + (parseInt(args.frameId as any) || 0), false)]
		};
		this.sendResponse(response);
	}

	protected async variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): Promise<void> {
		const variables: DebugProtocol.Variable[] = [];
		let id: number | string | VariableObject | ExtendedVariable;
		if (args.variablesReference < VAR_HANDLES_START) {
			id = args.variablesReference - STACK_HANDLES_START;
		}
		else {
			id = this.variableHandles.get(args.variablesReference);
		}

		let createVariable = (arg, options?) => {
			if (options)
				return this.variableHandles.create(new ExtendedVariable(arg, options));
			else
				return this.variableHandles.create(arg);
		};

		let findOrCreateVariable = (varObj: VariableObject): number => {
			let id: number;
			if (this.variableHandlesReverse.hasOwnProperty(varObj.name)) {
				id = this.variableHandlesReverse[varObj.name];
			}
			else {
				id = createVariable(varObj);
				this.variableHandlesReverse[varObj.name] = id;
			}
			return varObj.isCompound() ? id : 0;
		};

		if (typeof id == "number") {
			let stack: Variable[];
			try {
				stack = await this.miDebugger.getStackVariables(this.threadID, id);
				for (const variable of stack) {
					if (this.useVarObjects) {
						try {
							let varObjName = `var_${variable.name}`;
							let varObj: VariableObject;
							try {
								const changes = await this.miDebugger.varUpdate(variable.name);
								const changelist = changes.result("changelist");
								changelist.forEach((change) => {
									const vId = this.variableHandlesReverse[varObjName];
									const v = this.variableHandles.get(vId) as any;
									v.applyChanges(change);
								});
								const varId = this.variableHandlesReverse[varObjName];
								varObj = this.variableHandles.get(varId) as any;
							}
							catch (err) {
								if (err instanceof MIError && err.message == "Variable object not found") {
									varObj = await this.miDebugger.varCreate(variable.name, varObjName);
									const varId = findOrCreateVariable(varObj);
									varObj.exp = variable.name;
									varObj.id = varId;
								}
								else {
									throw err;
								}
							}
							variables.push(varObj.toProtocolVariable());
						}
						catch (err) {
							variables.push({
								name: variable.name,
								value: `<${err}>`,
								variablesReference: 0
							});
						}
					}
					else {
						if (variable.valueStr !== undefined) {
							let expanded = expandValue(createVariable, `{${variable.name}=${variable.valueStr}}`, "", variable.raw);
							if (expanded) {
								if (typeof expanded[0] == "string")
									expanded = [
										{
											name: "<value>",
											value: prettyStringArray(expanded),
											variablesReference: 0
										}
									];
									expanded[0].presentationHint = { attributes : [ "readOnly" ] };
								variables.push(expanded[0]);
							}
						} else
							variables.push({
								name: variable.name,
								type: variable.type,
								value: "<unknown>",
								presentationHint: { attributes: ["readOnly"]},
								variablesReference: createVariable(variable.name)
							});
					}
				}
				response.body = {
					variables: variables
				};
				this.sendResponse(response);
			}
			catch (err) {
				this.sendErrorResponse(response, 1, `Could not expand variable: ${err}`);
			}
		}
		else if (typeof id == "string") {
			// Variable members
			let variable;
			try {
				variable = await this.miDebugger.evalExpression(JSON.stringify(id));
				try {
					let expanded = expandValue(createVariable, variable.result("value"), id, variable);
					if (!expanded) {
						this.sendErrorResponse(response, 2, `Could not expand variable`);
					}
					else {
						if (typeof expanded[0] == "string")
							expanded = [
								{
									name: "<value>",
									value: prettyStringArray(expanded),
									variablesReference: 0
								}
							];
						expanded[0].presentationHint = { attributes: [ "readOnly" ] };
						response.body = {
							variables: expanded
						};
						this.sendResponse(response);
					}
				}
				catch (e) {
					this.sendErrorResponse(response, 2, `Could not expand variable: ${e}`);
				}
			}
			catch (err) {
				this.sendErrorResponse(response, 1, `Could not expand variable: ${err}`);
			}
		}
		else if (typeof id == "object") {
			if (id instanceof VariableObject) {
				// Variable members
				let children: VariableObject[];
				try {
					children = await this.miDebugger.varListChildren(id.name);
					const vars = children.map(child => {
						const varId = findOrCreateVariable(child);
						child.id = varId;
						return child.toProtocolVariable();
					});

					response.body = {
						variables: vars
					}
					this.sendResponse(response);
				}
				catch (err) {
					this.sendErrorResponse(response, 1, `Could not expand variable: ${err}`);
				}
			}
			else if (id instanceof ExtendedVariable) {
				let varReq = id;
				if (varReq.options.arg) {
					let strArr = [];
					let argsPart = true;
					let arrIndex = 0;
					let submit = () => {
						response.body = {
							variables: strArr
						};
						this.sendResponse(response);
					};
					let addOne = async () => {
						const variable = await this.miDebugger.evalExpression(JSON.stringify(`${varReq.name}+${arrIndex})`));
						try {
							let expanded = expandValue(createVariable, variable.result("value"), varReq.name, variable);
							if (!expanded) {
								this.sendErrorResponse(response, 15, `Could not expand variable`);
							}
							else {
								if (typeof expanded == "string") {
									if (expanded == "<nullptr>") {
										if (argsPart)
											argsPart = false;
										else
											return submit();
									}
									else if (expanded[0] != '"') {
										strArr.push({
											name: "[err]",
											value: expanded,
											variablesReference: 0
										});
										return submit();
									}
									strArr.push({
										name: `[${(arrIndex++)}]`,
										value: expanded,
										variablesReference: 0
									});
									addOne();
								}
								else {
									strArr.push({
										name: "[err]",
										value: expanded,
										variablesReference: 0
									});
									submit();
								}
							}
						}
						catch (e) {
							this.sendErrorResponse(response, 14, `Could not expand variable: ${e}`);
						}
					};
					addOne();
				}
				else
					this.sendErrorResponse(response, 13, `Unimplemented variable request options: ${JSON.stringify(varReq.options)}`);
			}
			else {
				response.body = {
					variables: id
				};
				this.sendResponse(response);
			}
		}
		else {
			response.body = {
				variables: variables
			};
			this.sendResponse(response);
		}
	}

	protected pauseRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {
		this.miDebugger.interrupt().then(() => {
			this.sendResponse(response);
		}, msg => {
			this.sendErrorResponse(response, 3, `Could not pause: ${msg}`);
		});
	}

	protected continueRequest(response: DebugProtocol.ContinueResponse, args: DebugProtocol.ContinueArguments): void {
		this.miDebugger.continue().then(() => {
			this.sendResponse(response);
		}, msg => {
			this.sendErrorResponse(response, 2, `Could not continue: ${msg}`);
		});
	}

	protected stepInRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {
		this.miDebugger.step().then(() => {
			this.sendResponse(response);
		}, msg => {
			this.sendErrorResponse(response, 4, `Could not step in: ${msg}`);
		});
	}

	protected stepOutRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {
		this.miDebugger.stepOut().then(() => {
			this.sendResponse(response);
		}, msg => {
			this.sendErrorResponse(response, 5, `Could not step out: ${msg}`);
		});
	}

	protected nextRequest(response: DebugProtocol.NextResponse, args: DebugProtocol.NextArguments): void {
		this.miDebugger.next().then(() => {
			this.sendResponse(response);
		}, msg => {
			this.sendErrorResponse(response, 6, `Could not step over: ${msg}`);
		});
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {
		if (args.context == "watch" || args.context == "hover")
			this.miDebugger.evalExpression(args.expression).then((res) => {
				response.body = {
					variablesReference: 0,
					result: res.result("value")
				}
				this.sendResponse(response);
			}, msg => {
				this.sendErrorResponse(response, 7, msg.toString());
			});
		else {
			this.miDebugger.sendUserInput(args.expression).then(output => {
				if (typeof output == "undefined")
					response.body = {
						result: "",
						variablesReference: 0
					};
				else
					response.body = {
						result: JSON.stringify(output),
						variablesReference: 0
					};
				this.sendResponse(response);
			}, msg => {
				this.sendErrorResponse(response, 8, msg.toString());
			});
		}
	}
}

function prettyStringArray(strings) {
	if (typeof strings == "object") {
		if (strings.length !== undefined)
			return strings.join(", ");
		else
			return JSON.stringify(strings);
	}
	else return strings;
}

DebugSession.run(FlowDebugSession);