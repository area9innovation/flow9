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

	public resolveTask(task: vscode.Task): vscode.Task | undefined {
		const def: FlowdTaskDefinition = <any>task.definition;
		if (def && def.program && def.backend) {
			const def: FlowdTaskDefinition = <any>task.definition;
			let exec = null;
			if (def.backend == "jar") {
				exec = new vscode.ShellExecution("flowc1", ["jar=1", def.program].concat(def.options), { cwd: this.workspaceRoot });
			} else if (def.backend == "bc") {
				exec = new vscode.ShellExecution("flowc1", ["bytecode=1", def.program].concat(def.options), { cwd: this.workspaceRoot });
			}
			if (!exec) return undefined; else
			return new vscode.Task(def, vscode.TaskScope.Workspace, `build ${def.program} ${def.backend} ${def.options.join(' ')}`,
					BuildTaskProvider.scriptType, exec);
		} else {
			return undefined;
		}
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

	public resolveTask(task: vscode.Task): vscode.Task | undefined {
		const def: FlowdTaskDefinition = <any>task.definition;
		if (def && def.program && def.backend) {
			let baseName = path.basename(path.join(this.workspaceRoot, def.program), ".flow");
			let exec = null;
			if (def.backend == "jar") {
				exec = new vscode.ShellExecution("java", ["-jar", baseName + ".jar"].concat(def.options), { cwd: this.workspaceRoot });
			} else if (def.backend == "bc") {
				exec = new vscode.ShellExecution(
					"flowcpp", 
					[baseName + ".bytecode"].concat(def.options == [] ? [] : ["--"].concat(def.options)), 
					{ cwd: this.workspaceRoot }
				);
			}
			if (!exec) return undefined; else
			return new vscode.Task(def, vscode.TaskScope.Workspace, `run ${def.program} ${def.backend} ${def.options.join(' ')}`,
					RunTaskProvider.scriptType, exec);
		} else {
			return undefined;
		}
	}
}