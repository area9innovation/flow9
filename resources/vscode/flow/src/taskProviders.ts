import * as path from 'path';
import * as vscode from 'vscode';

interface FlowdTaskDefinition extends vscode.TaskDefinition {
	program: string; 
	backend: string;
	options?: string[];
}

export class BuildTaskProvider implements vscode.TaskProvider {
	static scriptType: string = 'flow-build';
	private workspaceRoot: string = "";

	constructor(workspaceRoot: string) { 
		this.workspaceRoot = workspaceRoot;
	}

	public async provideTasks(): Promise<vscode.Task[]> {
		return undefined;
	}

	public resolveTask(_task: vscode.Task): vscode.Task | undefined {
		const program: string = _task.definition.program;
		const backend: string = _task.definition.backend;
		if (backend && program) {
			const definition: FlowdTaskDefinition = <any>_task.definition;
			return this.getTask(program, backend, definition.options ? definition.options : [], definition);
		}
		return undefined;
	}

	private getTask(program: string, backend: string, options: string[], definition?: FlowdTaskDefinition): vscode.Task {
		if (definition === undefined) {
			definition = {
				type: BuildTaskProvider.scriptType,
				program,
				backend,
				options
			};
		}
		let exec = null;
		if (backend == "jar") {
			exec = new vscode.ShellExecution("flowc1", ["jar=1", program].concat(options), { cwd: this.workspaceRoot });
		} else if (backend == "bc") {
			exec = new vscode.ShellExecution("flowc1", ["bytecode=1", program].concat(options), { cwd: this.workspaceRoot });
		}
		if (!exec) return undefined; else
		return new vscode.Task(definition, vscode.TaskScope.Workspace, `${program} ${backend} ${options.join(' ')}`,
				BuildTaskProvider.scriptType, exec);
	}
}

export class RunTaskProvider implements vscode.TaskProvider {
	static scriptType: string = 'flow-run';
	private workspaceRoot: string = "";

	constructor(workspaceRoot: string) { 
		this.workspaceRoot = workspaceRoot;
	}

	public async provideTasks(): Promise<vscode.Task[]> {
		return undefined;
	}

	public resolveTask(_task: vscode.Task): vscode.Task | undefined {
		const program: string = _task.definition.program;
		const backend: string = _task.definition.backend;
		if (backend && program) {
			const definition: FlowdTaskDefinition = <any>_task.definition;
			return this.getTask(program, backend, definition.options ? definition.options : [], definition);
		}
		return undefined;
	}

	private getTask(program: string, backend: string, options: string[], definition?: FlowdTaskDefinition): vscode.Task {
		if (definition === undefined) {
			definition = {
				type: BuildTaskProvider.scriptType,
				program,
				backend,
				options
			};
		}
		let baseName = path.basename(path.join(this.workspaceRoot, program), ".flow");
		let exec = null;
		if (backend == "jar") {
			exec = new vscode.ShellExecution("java", ["-jar", baseName + ".jar"].concat(options), { cwd: this.workspaceRoot });
		} else if (backend == "bc") {
			exec = new vscode.ShellExecution(
				"flowcpp", 
				[baseName + ".bytecode"].concat(options == [] ? [] : ["--"].concat(options)), 
				{ cwd: this.workspaceRoot }
			);
		}
		if (!exec) return undefined; else
		return new vscode.Task(definition, vscode.TaskScope.Workspace, `${program} ${backend} ${options.join(' ')}`,
				BuildTaskProvider.scriptType, exec);
	}
}