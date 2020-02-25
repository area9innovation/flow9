import { spawn, ChildProcess, spawnSync } from 'child_process';


export function run_cmd(cmd: string, wd: string, args: string[], outputProc: (string) => void, childProcesses: ChildProcess[]):
    ChildProcess {
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
    const options = wd && wd.length > 0 ? { cwd: wd, shell: true, encoding: 'utf8' } :
        { shell: true, encoding: 'utf8' };
    return spawnSync(cmd, args, options);
}

export function shutdownFlowcSync() {
    return run_cmd_sync("flowc1", "", ["server-shutdown=1"]);
}

export function shutdownFlowc() {
    run_cmd("flowc1", "", ["server-shutdown=1"], (s) => {
        console.log(s);
    }, []);
}

export function launchFlowc(projectRoot: string) {
    return run_cmd("flowc1", projectRoot, ["server-mode=http"], (s) => {
        console.log(s);
    }, []);
}