import { spawn, ChildProcess, spawnSync } from 'child_process';
import * as vscode from 'vscode';
import * as fs from "fs";
import { Server } from 'net';

export function run_cmd(cmd: string, wd: string, args: string[], outputProc: (string) => void, childProcesses: ChildProcess[]): ChildProcess {
    const options = wd && wd.length > 0 ? { cwd: wd, shell: true } : { shell : true};
    let child = spawn(cmd, args, options);
    child.stdout.setEncoding('utf8');
    child.stdout.on("data", outputProc);
    child.stderr.on("data", outputProc);
    childProcesses.push(child);
    child.on("close", (code) => {
        console.log(`child process exited with code ${code}`);
        let index = childProcesses.indexOf(child);
        if (index >= 0)
            childProcesses.splice(index, 1);
    });
    return child;
}

export function run_cmd_sync(cmd: string, wd: string, args: string[]) {
	const options = wd && wd.length > 0 ?
		{ cwd: wd, shell: true, encoding: "utf8" as BufferEncoding } :
        { shell: true, encoding: "utf8" as BufferEncoding };
    return spawnSync(cmd, args, options);
}

export function shutdownFlowcHttpServerSync() {
	return run_cmd_sync("flowc1", "", ["server-shutdown=1"]);
}

export function shutdownFlowcHttpServer() {
    return run_cmd("flowc1", "", ["server-shutdown=1"], (s) => { console.log(s); }, []);
}

export function launchFlowcHttpServer(projectRoot: string, on_start : () => void, on_stop : () => void, on_msg : (any) => void) {
	on_start();
	on_msg((new Date()).toString() + " Flow Http server started");
	let httpServer = run_cmd("flowc1", projectRoot, ["server-mode=http"], (s) => { console.log(s); }, []);
	httpServer.addListener("close", (code: number, signal: string) => {
		on_msg(
			(new Date()).toString() + " Flow Http server closed" +
			(code == 0 ? "" : " code: " + code) +
			(signal ? " signal: " + signal : "")
		);
		on_stop()
	});
	httpServer.addListener("disconnect", () => {
		on_msg((new Date()).toString() + " Flow Http server disconnected");
		on_stop()
	});
	httpServer.addListener("exit", (code: number, signal: string) => {
		on_msg(
			(new Date()).toString() + " Flow Http server exited" +
			(code == 0 ? "" : " code: " + code) +
			(signal ? " signal: " + signal : "")
		);
		on_stop()
	});
	httpServer.addListener("message", (msg, __) => on_msg(msg.toString()));
	httpServer.addListener("error", (err) => on_msg(err.toString()));
    return httpServer
}

export function getFlowRoot(): string {
    const config = vscode.workspace.getConfiguration("flow");
	let root: string = config.get("root");
	if (!fs.existsSync(root)) {
		root = run_cmd_sync("flowc1", ".", ["print-flow-dir=1"]).stdout.toString().trim();
		config.update("root", root, vscode.ConfigurationTarget.Global);
	}
	return root;
}

export function isPortAvailable(port: number): Promise<boolean> {
	return new Promise((resolve) => {
		const server = new Server();
		server.once('error', function (err: any) {
			if (err.code === 'EADDRINUSE') {
			  resolve(false);
			}
		});
		server.once('listening', function () {
			server.close();
			resolve(true);
		});
		server.listen(port);
	});
}

export function getVerboseParam(): string {
	let verbose: string = vscode.workspace.getConfiguration("flow").get("compilerVerbose")
	return verbose ? verbose : "0";
}
