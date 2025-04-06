import { LoggingDebugSession, Logger, logger, InitializedEvent, TerminatedEvent, StoppedEvent, OutputEvent, Thread, StackFrame, Scope, Source, Handles, DebugSession, Breakpoint } from '@vscode/debugadapter';
import { DebugProtocol } from '@vscode/debugprotocol';
import { Variable, Stack, VariableObject, MIError } from './backend/backend';
import { MI2 } from './backend/flowcpp_runtime';


logger.setup(Logger.LogLevel.Verbose, true);

process.on("unhandledRejection", (error) => {
	console.error(error); // This prints error with stack included (as for normal errors)
	throw error; // Following best practices re-throw error and let the process exit with error code
});

process.on("uncaughtException", (error) => {
	console.error(error); // This prints error with stack included (as for normal errors)
	throw error; // Following best practices re-throw error and let the process exit with error code
});

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

// this is used to for stack handles - IDs for stack frames are within (0, 1000)
const STACK_HANDLES_START = 1000;
// this is used for variables
const VAR_HANDLES_START = 2000;

export class FlowDebugSession extends LoggingDebugSession {
	protected variableHandles = new Handles<VariableObject>(VAR_HANDLES_START);
	protected variableHandlesReverse: { [id: string]: number } = {};
	protected StackFrames: Stack[] = [];
	protected useVarObjects: boolean = true;
	protected quit: boolean;
	protected needContinue: boolean;
	protected started: boolean;
	protected crashed: boolean;
	protected debugReady: boolean;
	protected miDebugger: MI2;
	protected threadID: number = 1;
	protected debug : boolean;

	private resetHandleMaps() {
		this.variableHandles = new Handles<VariableObject>(VAR_HANDLES_START);
		this.variableHandlesReverse = {};
	}

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
        response.body.supportsDelayedStackTraceLoading = false;
		//TODO: support
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

        // defaults to flowc
		let compiler = args.compiler || "flowc";

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
				breakpoints: brkpoints.map(brkp =>
					new Breakpoint(brkp[0], brkp[0] ? brkp[1].line : undefined))
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

	// performs deep compare of two stacks
	private compareStacks(s1: Stack[], s2: Stack[]) {
		return (null == s1 && null == s2) ||
			(s1 && s2 && s1.length == s2.length && s1.reduce(
				(acc, s, i) => acc && (s.address == s2[i].address),
				true));
	}

	protected stackTraceRequest(response: DebugProtocol.StackTraceResponse, args: DebugProtocol.StackTraceArguments): void {
		// ignore requested stack depth and return the entire stack all the time - flowcpp does not have a way to
		// give the number of stack frames without actually listing them all
		this.miDebugger.getStack(0).then(async stack => {
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
			// if changing stack frames, reset all var handles
			if (!this.compareStacks(this.StackFrames, stack)) {
				for (let varName in this.variableHandlesReverse) {
					try {
						await this.miDebugger.varDelete(varName);
					} catch {
						// it might crash with variable not existing - this is OK
					}
				}
				this.resetHandleMaps();
			}
			this.StackFrames = stack;
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
		// 2 handles - one for args, one for locals
		const stackHandle = STACK_HANDLES_START + (parseInt(args.frameId as any) || 0) * 2;
		response.body = {
			scopes: [
				new Scope("Locals", stackHandle + 1, false),
				new Scope("Arguments",  stackHandle, false),
			]
		};
		this.sendResponse(response);
    }

    private createVariable(arg) {
        return this.variableHandles.create(arg);
    }

    private findOrCreateVariable(varObj: VariableObject): number {
        let id: number;
        if (this.variableHandlesReverse.hasOwnProperty(varObj.name)) {
            id = this.variableHandlesReverse[varObj.name];
        }
        else {
            id = this.createVariable(varObj);
            this.variableHandlesReverse[varObj.name] = id;
        }
        return varObj.isCompound() ? id : 0;
    };

	protected async updateOrCreateVariable(variableName: string, varObjName : string, frameNum): Promise<DebugProtocol.Variable> {
		let varObj: VariableObject;
		try {
			const changes = await this.miDebugger.varUpdate(varObjName);
			const changeList = changes.result("changelist");
			changeList.forEach(change => {
				const vId = this.variableHandlesReverse[varObjName];
				const v = this.variableHandles.get(vId) as any;
				v.applyChanges(change);
			});
			const varId = this.variableHandlesReverse[varObjName];
			varObj = this.variableHandles.get(varId) as any;
		}
		catch (err) {
			if (err instanceof MIError && err.message.startsWith("No such var:")) {
				varObj = await this.miDebugger.varCreate(variableName, frameNum, varObjName);
				const varId = this.findOrCreateVariable(varObj);
				varObj.exp = variableName;
				varObj.id = varId;
			}
			else {
				throw err;
			}
		}
		return varObj.toProtocolVariable();
	}

    protected async variablesRequest(response: DebugProtocol.VariablesResponse, args: DebugProtocol.VariablesArguments): Promise<void> {
		const variables: DebugProtocol.Variable[] = [];

        if (args.variablesReference < VAR_HANDLES_START) {
			const id = args.variablesReference - STACK_HANDLES_START;
			let stack: Variable[];
			try {
				const args = id % 2 == 0;
				const frameNum = Math.floor(id / 2);
				stack = await this.miDebugger.getStackVariables(this.threadID, frameNum, args);
				for (const variable of stack) {
					if (this.useVarObjects) {
						try {
							let varObjName = `var_${frameNum}_${variable.name}`;
							let protocolVar = await this.updateOrCreateVariable(variable.name, varObjName, frameNum);
							variables.push(protocolVar);
						}
						catch (err) {
							variables.push({
								name: variable.name,
								value: `<${err}>`,
								variablesReference: 0
							});
						}
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
		} else {
            const varObj = this.variableHandles.get(args.variablesReference);
            try {
                // Variable members
                const children = await this.miDebugger.varListChildren(varObj.name);
                const vars = children.map(child => {
                    const varId = this.findOrCreateVariable(child);
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

	protected async evaluateExpression(response: DebugProtocol.EvaluateResponse, expression: string): Promise<DebugProtocol.EvaluateResponse> {
		let expressionA: string[] = expression.replace(/\[(\d+)\]/g, '.$1').split(".");
		let currExpression = expressionA[0];
		let varObjName = "var__" + currExpression;
		try {
			await this.updateOrCreateVariable(currExpression, varObjName, "*");
		} catch (err) {
			if (err instanceof MIError && err.message.startsWith("Duplicate variable name:")) {
				// Ignore this error. Multiple watches can refer the same object variable.
				// For example "struct.field1" and "struct.filed2" need only one object variable for "struct",
				// in parallel we can get this exception "Duplicate variable name:" in this case.
			} else {
				throw err;
			}
		}
		if (expressionA.length == 1) {
			try {
				let res: any = await this.miDebugger.evalExpression(expression);
				response.body = {
					variablesReference: this.variableHandlesReverse[varObjName] || 0,
					result: res.result("value")
				}
				return response;
			} catch (err) {
				response.message = err.message;
				response.success = false;
				return response;
			}
		} else {
			for (let j = 1; j < expressionA.length; j++) {
				let name = expressionA[j];
				let children: VariableObject[] = await this.miDebugger.varListChildren(varObjName);
				let childrenIdx = -1;
				for (let i = 0; i < children.length; i++) {
					if (children[i].exp == name) {
						if (j == expressionA.length - 1) {
							response.body = {
								variablesReference: this.findOrCreateVariable(children[i]),
								result: children[i].value
							}
							return response;
						} else {
							childrenIdx = i;
							currExpression += "." + name;
							varObjName = children[i].name;
							break;
						}
					}
				}
				if (childrenIdx == -1) {
					response.message = `No ${name} in ${currExpression}`;
					response.success = false;
					return response;
				}
			}
		}
	}

	protected evaluateRequest(response: DebugProtocol.EvaluateResponse, args: DebugProtocol.EvaluateArguments): void {
		let expression: string = args.expression;
		if (args.context == "watch" || args.context == "hover") {
			if (args.context == "hover" && expression && expression[0] == "\\") {
				expression = expression.substring(1);
			}
			this.evaluateExpression(response, expression).then(response2 => {
				this.sendResponse(response2);
			}, msg => {
				response.message = msg.toString();
				response.success = false;
				this.sendResponse(response);
			});
		} else {
			this.miDebugger.sendUserInput(expression).then(output => {
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
				response.message = msg.toString();
				response.success = false;
				this.sendResponse(response);
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