import * as path from 'path';
import * as vscode from 'vscode';
//import { getNonce } from './util';
import * as fs from "fs";

/**
 * Provider for cat scratch editors.
 * 
 * Cat scratch editors are used for `.cscratch` files, which are just json files.
 * To get started, run this extension and open an empty `.cscratch` file in VS Code.
 * 
 * This provider demonstrates:
 * 
 * - Setting up the initial webview for a custom editor.
 * - Loading scripts and styles in a custom editor.
 * - Synchronizing changes between a text document and a custom editor.
 */
export class TestFlowEditorProvider implements vscode.CustomTextEditorProvider {

	public static register(context: vscode.ExtensionContext): vscode.Disposable {
		const provider = new TestFlowEditorProvider(context);
		const providerRegistration = vscode.window.registerCustomEditorProvider(TestFlowEditorProvider.viewType, provider);
		return providerRegistration;
	}

	private static readonly viewType = 'flow.testEditor';
	constructor(
		private readonly context: vscode.ExtensionContext
	) { }

	public async resolveCustomTextEditor(
		document: vscode.TextDocument,
		webviewPanel: vscode.WebviewPanel,
		_token: vscode.CancellationToken
	): Promise<void> {
		// Setup initial content for the webview
		webviewPanel.webview.options = {
			enableScripts: true,
		};
		webviewPanel.webview.html = this.getHtmlForWebview(webviewPanel.webview);

		function updateWebview() {
			vscode.window.showInformationMessage("document.getText():\n" + document.getText());
			/*webviewPanel.webview.postMessage({
				type: 'update',
				text: document.getText(),
			});*/
			webviewPanel.webview.postMessage(document.getText());
		}

		// Hook up event handlers so that we can synchronize the webview with the text document.
		//
		// The text document acts as our model, so we have to sync change in the document to our
		// editor and sync changes in the editor back to the document.
		// 
		// Remember that a single text document can also be shared between multiple custom
		// editors (this happens for example when you split a custom editor)

		const changeDocumentSubscription = vscode.workspace.onDidChangeTextDocument(e => {
			if (e.document.uri.toString() === document.uri.toString()) {
				updateWebview();
			}
		});

		// Make sure we get rid of the listener when our editor is closed.
		webviewPanel.onDidDispose(() => {
			changeDocumentSubscription.dispose();
		});

		updateWebview();
	}

	private getHtmlForWebview(webview: vscode.Webview): string {
		const editor_path = path.join(this.context.extensionPath, 'editors', 'editor2.html')
		return fs.readFileSync(editor_path).toString();
	}
}
