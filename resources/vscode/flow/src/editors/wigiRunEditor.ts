import * as path from 'path';
import * as vscode from 'vscode';
import * as fs from "fs";

export class WigiRunEditorProvider implements vscode.CustomTextEditorProvider {

	public static register(context: vscode.ExtensionContext): vscode.Disposable {
		const provider = new WigiRunEditorProvider(context);
		const providerRegistration = vscode.window.registerCustomEditorProvider(WigiRunEditorProvider.viewType, provider);
		return providerRegistration;
	}

	private static readonly viewType = 'flow.wigiRunEditor';
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
			webviewPanel.webview.postMessage(JSON.stringify({
				type: 'update',
				data: document.getText()
			}));
		}

		const changeDocumentSubscription = vscode.workspace.onDidChangeTextDocument(e => {
			if (e.document.uri.toString() === document.uri.toString()) {
				updateWebview();
			}
		});

		// Make sure we get rid of the listener when our editor is closed.
		webviewPanel.onDidDispose(() => {
			changeDocumentSubscription.dispose();
		});

		// Receive message from the webview.
		webviewPanel.webview.onDidReceiveMessage(e => {
			const msg = JSON.parse(e);
			if (msg.type == 'ready') {
				updateWebview();
			} else if (msg.type == 'save') {
				this.updateTextDocument(document, msg.text);
			}
		});
	}

	private getHtmlForWebview(webview: vscode.Webview): string {
		const editor_path = path.join(this.context.extensionPath, 'editors', 'wigiRunEditor.html')
		return fs.readFileSync(editor_path).toString();
	}

	private updateTextDocument(document: vscode.TextDocument, txt: string): void {
		const edit = new vscode.WorkspaceEdit();

		// Just replace the entire document every time for this example extension.
		// A more complete extension should compute minimal edits instead.
		edit.replace(
			document.uri,
			new vscode.Range(0, 0, document.lineCount, 0),
			txt
		);
		vscode.workspace.applyEdit(edit);
	}
}
