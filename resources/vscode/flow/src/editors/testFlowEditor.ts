import * as path from 'path';
import * as vscode from 'vscode';
import * as fs from "fs";

/* 
To compile the editor run

	flowc1 html=testFlowEditor.html testFlowEditor.flow 

in editors folder
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
			webviewPanel.webview.postMessage(JSON.stringify({
				type: 'update',
				text: document.getText()
			}));
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

		// Receive message from the webview.
		webviewPanel.webview.onDidReceiveMessage(e => {
			//vscode.window.showInformationMessage("GOT MESSAGE: " + JSON.stringify(e));
			const msg = JSON.parse(e);
			//vscode.window.showInformationMessage("GOT MESSAGE: " + e);
			if (msg.type == 'ready') {
				updateWebview();		
			} else if (msg.type == 'apply') {
				//vscode.window.showInformationMessage("TO APPLY: " + msg.text);
				this.updateTextDocument(document, msg.text);
			}
		});
	}

	private getHtmlForWebview(webview: vscode.Webview): string {
		const editor_path = path.join(this.context.extensionPath, 'editors', 'testFlowEditor.html')
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
