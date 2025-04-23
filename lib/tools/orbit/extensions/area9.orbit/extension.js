// The module 'vscode' contains the VS Code extensibility API
const vscode = require('vscode');
const { spawn } = require('child_process');

/**
* @param {vscode.ExtensionContext} context
*/
function activate(context) {
	orbitChannel = vscode.window.createOutputChannel("Orbit output");
	orbitChannel.show(true);
	context.subscriptions.push(vscode.commands.registerCommand('orbit.Compile_Orbit', function () {
		orbitChannel.clear();
		orbitChannel.show(true);
		const document = vscode.window.activeTextEditor.document;
		document.save().then(() => {
			var folder;
			if (vscode.workspace.workspaceFolders != null && vscode.workspace.workspaceFolders.length > 0) {
				folder = vscode.workspace.workspaceFolders[0].uri.fsPath;
			} else {
				folder = ".";
			}
			const relativeFile = document.uri.fsPath;
			orbitChannel.appendLine("Running '" + `flowcpp orbit.flow -- ${relativeFile}` + "' in " + folder);
			const process = spawn(`flowcpp orbit.flow -- ${relativeFile}`, [relativeFile], { cwd: folder, shell: true });

			process.stdout.on('data', (data) => {
				orbitChannel.append(data.toString().trim());
			});

			process.stderr.on('data', (data) => {
				orbitChannel.append(data.toString().trim());
			});

			process.on('close', (code) => {
				orbitChannel.appendLine(`\nProcess exited with code ${code}`);
			});

			process.on('error', (err) => {
				orbitChannel.appendLine(`Error: ${err.message}`);
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
