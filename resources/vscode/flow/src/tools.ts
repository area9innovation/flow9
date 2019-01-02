import { spawn, ChildProcess, spawnSync } from 'child_process';


export function run_cmd(cmd: string, wd: string, args: string[], outputProc: (string) => void, childProcesses: ChildProcess[]):
    ChildProcess {
    let child = spawn(cmd, args, { cwd: wd, shell: true });
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
    return spawnSync(cmd, args, { cwd: wd, shell: true, encoding: 'utf8' });
}
