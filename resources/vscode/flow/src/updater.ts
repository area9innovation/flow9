'use strict';

import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from "fs";
import * as tools from "./tools";

function getFlowExtensionRepo() {
    let flowRoot = tools.getFlowRoot();
    return path.resolve(flowRoot, "resources", "vscode", "flow")
}

export function setupUpdateChecker() {
    let flowRepo = getFlowExtensionRepo();
    let fw = vscode.workspace.createFileSystemWatcher(path.resolve(flowRepo, "package.json"));
    fw.onDidChange(() => checkForUpdate());
}

export function checkForUpdate() {
    let repoJson = path.resolve(getFlowExtensionRepo(), "package.json");
    let flowRoot : string = tools.getFlowRoot();
    if (fs.existsSync(repoJson)) {
        fs.readFile(repoJson, 'utf8', (err, data) => {
            if (!err) {
                var repoData = JSON.parse(data);
                var repoVersion = repoData.version;
                var currentData = vscode.extensions.getExtension("area9.flow").packageJSON;
                var currentVersion = currentData.version;
				tools.log(`currentVersion: ${currentVersion}, repoVersion: ${repoVersion}`);
                if (repoVersion != currentVersion) {
                    vscode.window.showInformationMessage(`New version ${repoVersion} of the flow extension mentioned in the repository. Do you want to update?`,
                        "Yes", "No").then(result => {
                            if ("Yes" == result) {
                                updateExtension(flowRoot);
                            }
                        });
                }
            } else {
				tools.log("Error reading " + repoJson + ": " + err);
			}
        });
    } else {
		tools.log("Missing file: " + repoJson);
	}
}

function updateExtension(flowRoot : string) {
	let vsixFile = path.resolve(flowRoot, "resources", "vscode", "flow.vsix");
	if (fs.existsSync(vsixFile)) {
		vscode.commands.executeCommand("workbench.extensions.command.installFromVSIX", vscode.Uri.file(vsixFile)).then(() => {
			vscode.window.showInformationMessage(
				"Flow extension updated successfully. Please reload VSCode to apply changes.",
				"Reload"
			).then(s => {
				if (s) vscode.commands.executeCommand("workbench.action.reloadWindow");
			});
		});
	} else {
		vscode.window.showInformationMessage("Cannot update Flow extension. Missing file: " + vsixFile);
	}
}
