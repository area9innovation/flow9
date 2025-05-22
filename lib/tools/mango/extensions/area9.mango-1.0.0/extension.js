// The module 'vscode' contains the VS Code extensibility API
const vscode = require('vscode');
const { exec } = require('node:child_process');

/**
* @param {vscode.ExtensionContext} context
*/
function activate(context) {
	mangoChannel = vscode.window.createOutputChannel("Mango output");
	mangoChannel.show(true);
	context.subscriptions.push(vscode.commands.registerCommand('mango.Mango_check', async function () {
		mangoChannel.clear();
		mangoChannel.show(true);
		const document = vscode.window.activeTextEditor.document;
		document.save().then(() => {
			var folder;
			if (vscode.workspace.workspaceFolders != null && vscode.workspace.workspaceFolders.length > 0) {
				folder = vscode.workspace.workspaceFolders[0].uri.fsPath;
			} else {
				folder = ".";
			}
			const relativeFile = document.uri.fsPath;
			mangoChannel.appendLine("Running '" + `mango grammar=${relativeFile}` + "' in " + folder);
			exec(`mango grammar=${relativeFile}`, {cwd: folder}, (err, stdout, stderr) => {
				mangoChannel.show(true);
				if (err) {
					mangoChannel.append(err);
				}
				if (stdout != "") {
					mangoChannel.append(stdout);
				}
				if (stderr != "") {
					mangoChannel.append(stderr);
				}
			});
		});
	}));

}

// This method is called when your extension is deactivated
function deactivate() {}

module.exports = {
	activate,
	deactivate
}
