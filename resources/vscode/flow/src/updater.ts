'use strict';

import * as vscode from 'vscode';
import * as path from 'path';
import { execFile } from 'child_process';
import * as fs from "fs";

function getFlowExtensionRepo() {
    let flowRoot: string = vscode.workspace.getConfiguration("flow").get("root")
    return path.resolve(flowRoot, "resources", "vscode", "flow")
}

export function setupUpdateChecker() {
    let flowRepo = getFlowExtensionRepo();
    // disable if developing flow extension itself
    if (!vscode.workspace.workspaceFolders || 
        !vscode.workspace.workspaceFolders.find((v) => v.uri.fsPath == flowRepo)) {
        let fw = vscode.workspace.createFileSystemWatcher(path.resolve(flowRepo, "package.json"));
        fw.onDidChange(() => checkForUpdate());
    }
}

export function checkForUpdate() {
    let repoJson = path.resolve(getFlowExtensionRepo(), "package.json");
    let flowRoot = vscode.workspace.getConfiguration("flow").get("root");
    if (fs.existsSync(repoJson)) {
        fs.readFile(repoJson, 'utf8', (err, data) => {
            if (!err) {
                var repoData = JSON.parse(data);
                var repoVersion = repoData.version;
                var currentData = vscode.extensions.getExtension("area9.flow").packageJSON;
                var currentVersion = currentData.version;
                if (repoVersion != currentVersion) {
                    vscode.window.showInformationMessage("An update might be available for the flow extension. Do you want to update?", 
                        "Yes", "No").then(result => {
                            if ("Yes" == result) {
                                updateExtension(flowRoot);
                            }
                        });
                }
            }
        });
    }
}

function updateExtension(flowRoot) {
    let flowRepoPath = path.resolve(flowRoot, "resources", "vscode");
    // full path to vscode
    let codeFn = process.platform == "win32" ? "code.cmd" : "code";
    let codePath = path.resolve(vscode.env.appRoot, "..", "..", "bin", codeFn);
    execFile(codePath, ["--install-extension", "flow.vsix"], { cwd: flowRepoPath }, 
         (error, stdout) => {
            console.log(stdout);
            if (!error && stdout.indexOf("successfully") >= 0)
                vscode.window.showInformationMessage("Flow extension updated successfully. Please reload VSCode to apply changes.",
                    "Reload").then(s => { if (s) vscode.commands.executeCommand("workbench.action.reloadWindow"); });
            else
                vscode.window.showErrorMessage("Flow extension failed to update. Please update manually - check " + flowRepoPath + " folder.", "OK");
        });
}
