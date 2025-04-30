// The module 'vscode' contains the VS Code extensibility API
const vscode = require('vscode');
const { spawn } = require('child_process');

/**
* @param {vscode.ExtensionContext} context
*/
function activate(context) {
	sexprChannel = vscode.window.createOutputChannel("Sexpr output");
	sexprChannel.show(true);
	context.subscriptions.push(vscode.commands.registerCommand('sexpr.Compile_S-Expression', function () {
		sexprChannel.clear();
		sexprChannel.show(true);
		const document = vscode.window.activeTextEditor.document;
		document.save().then(() => {
			var folder;
			if (vscode.workspace.workspaceFolders != null && vscode.workspace.workspaceFolders.length > 0) {
				folder = vscode.workspace.workspaceFolders[0].uri.fsPath;
			} else {
				folder = ".";
			}
			const relativeFile = document.uri.fsPath;
			sexprChannel.appendLine("Running '" + `sexpr ${relativeFile}` + "' in " + folder);
			const process = spawn(`sexpr ${relativeFile}`, [relativeFile], { cwd: folder, shell: true });

			process.stdout.on('data', (data) => {
				sexprChannel.append(data.toString().trim());
			});

			process.stderr.on('data', (data) => {
				sexprChannel.append(data.toString().trim());
			});

			process.on('close', (code) => {
				sexprChannel.appendLine(`\nProcess exited with code ${code}`);
			});

			process.on('error', (err) => {
				sexprChannel.appendLine(`Error: ${err.message}`);
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
