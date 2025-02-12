import * as vscode from 'vscode';
import { FlowFormatter } from './formatter';

export function activate(context: vscode.ExtensionContext) {
	console.log('Flow formatter is now active');

	let formatter = new FlowFormatter();
	let disposable = vscode.languages.registerDocumentFormattingEditProvider(
		{ scheme: 'file', language: 'flow' },
		formatter
	);

	context.subscriptions.push(disposable);
}

export function deactivate() {}