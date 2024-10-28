import { spawn, ChildProcess, spawnSync } from 'child_process';
import * as vscode from 'vscode';
import { Socket } from 'net';

export function run_cmd(cmd: string, wd: string, args: string[], outputProc: (string) => void, childProcesses: ChildProcess[] = []): ChildProcess {
    const options = wd && wd.length > 0 ? { cwd: wd, shell: true } : { shell : true};
    let child = spawn(cmd, args, options);
    child.stdout.setEncoding('utf8');
    child.stdout.on("data", outputProc);
    child.stderr.on("data", outputProc);
    childProcesses.push(child);
    child.on("close", (code) => {
        log(`child process exited with code ${code}`);
        let index = childProcesses.indexOf(child);
        if (index >= 0)
            childProcesses.splice(index, 1);
    });
    return child;
}

export function log(msg: string) {
	console.log("[flow] " + msg);
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
    return run_cmd("flowc1", "", ["server-shutdown=1"], log, []);
}

export function launchFlowcHttpServer(compiler: string, on_start : () => void, on_stop : () => void, on_msg : (msg : string) => void) {
	on_start();
	on_msg((new Date()).toString() + " Flow Http server started");
	// Only two variants are supported currently: flowc1 or flowc2. Default server is flowc1
	compiler = (compiler === "flowc2") ? compiler : "flowc1";
	let httpServer = run_cmd(compiler, "", ["server-mode=http"], log);
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

var flowRoot : string = null;
export function getFlowRoot(): string {
	if (!flowRoot) {
		flowRoot = run_cmd_sync("flowc1", ".", ["print-flow-dir=1"]).stdout.toString().trim();
	}
	return flowRoot
}

export function isPortAvailable(port: number): Promise<boolean> {
	return new Promise((resolve) => {
		const socket = new Socket();
		const resolve2 = (val : boolean) => {
			resolve(val);
			socket.destroy();
		}
		socket.setTimeout(100, () => resolve2(true));
		socket.on("connect", () => resolve2(false));
		socket.on("error", () => resolve2(true));
		socket.connect(port, "0.0.0.0");
	});
}

export function getVerboseParam(): string {
	let verbose: string = vscode.workspace.getConfiguration("flow").get("compilerVerbose")
	return verbose ? verbose : "0";
}
