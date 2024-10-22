'use strict';

import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from "fs";
import * as tools from "./tools";

function getFlowExtensionRepo() {
    let flowRoot: string = vscode.workspace.getConfiguration("flow").get("root")
    return path.resolve(flowRoot, "resources", "vscode", "flow")
}

export function setupUpdateChecker() {
    let flowRepo = getFlowExtensionRepo();
    let fw = vscode.workspace.createFileSystemWatcher(path.resolve(flowRepo, "package.json"));
    fw.onDidChange(() => checkForUpdate());
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
                    vscode.window.showInformationMessage(`New version ${repoVersion} of the flow extension mentioned in the repository. Do you want to update?`,
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
	let log = "";
	let proc = tools.run_cmd('"' + codePath + '"', flowRepoPath, ["--install-extension", "flow.vsix"],
		(out) => {
			log += out;
			tools.log(out);
		}
	);
	proc.addListener("exit", (code: number) => {
		if (code == 0 && log.indexOf("successfully") >= 0) {
			vscode.window.showInformationMessage(
				"Flow extension updated successfully. Please reload VSCode to apply changes.",
				"Reload"
			).then(s => {
				if (s) vscode.commands.executeCommand("workbench.action.reloadWindow");
			});
		} else {
			vscode.window.showErrorMessage("Flow extension failed to update. Please update manually - check " + flowRepoPath + " folder.", "OK");
		}
	});
}
