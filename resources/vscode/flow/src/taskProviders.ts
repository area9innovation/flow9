import * as path from 'path';
import * as vscode from 'vscode';

interface FlowdTaskDefinition extends vscode.TaskDefinition {
	program: string; 
	backend: string;
	options?: string[];
	browser?: string;
	urlPrefix?: string;
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
			let options = def.options? def.options : [];
			let exec = null;
			if (def.backend.toLowerCase() == "jar") {
				exec = new vscode.ShellExecution("flowc1", ["jar=1", def.program].concat(options), { cwd: this.workspaceRoot });
			} else if (def.backend.toLowerCase() == "bc") {
				exec = new vscode.ShellExecution("flowc1", ["bytecode=1", def.program].concat(options), { cwd: this.workspaceRoot });
			} else if (def.backend.toLowerCase() == "js") {
				// call flowc1 js=www2/%1.js %1/%1.flow html=www2/%1.html
				let name = path.basename(path.join(this.workspaceRoot, def.program), ".flow");
				exec = new vscode.ShellExecution("flowc1", ["js=www2/" + name + ".js", "html=www2/" + name + ".html", def.program].concat(options), { cwd: this.workspaceRoot });
			}
			if (!exec) return undefined; else
			return new vscode.Task(def, vscode.TaskScope.Workspace, `build ${def.program} ${def.backend} ${options.join(' ')}`,
					BuildTaskProvider.scriptType, exec, []);
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
			let options = def.options? def.options : [];
			let baseName = path.basename(path.join(this.workspaceRoot, def.program), ".flow");
			let exec = null;
			if (def.backend.toLowerCase() == "jar") {
				exec = new vscode.ShellExecution("java", ["-jar", baseName + ".jar"].concat(options), { cwd: this.workspaceRoot });
			} else if (def.backend.toLowerCase() == "bc") {
				exec = new vscode.ShellExecution(
					"flowcpp", 
					[baseName + ".bytecode"].concat(options == [] ? [] : ["--"].concat(options)), 
					{ cwd: this.workspaceRoot }
				);
			} else if (def.backend.toLowerCase() == "js" && def.browser && def.urlPrefix) {
				// start chrome %2 https:\\localhost\rhapsode\%1.html
				let name = path.basename(path.join(this.workspaceRoot, def.program), ".flow");
				let urlPrefix = def.urlPrefix + (def.urlPrefix.endsWith("/") ? "" : "/");
				exec = new vscode.ShellExecution(
					def.browser, 
					options.concat([urlPrefix + name + ".html"]), 
					{ cwd: this.workspaceRoot }
				);
			}
			if (!exec) return undefined; else
			return new vscode.Task(def, vscode.TaskScope.Workspace, `run ${def.program} ${def.backend} ${options.join(' ')}`,
					RunTaskProvider.scriptType, exec, []);
		} else {
			return undefined;
		}
	}
}