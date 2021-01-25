import * as path from 'path';
import * as vscode from 'vscode';
import { getNonce } from './util';
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

	private static readonly scratchCharacters = ['😸', '😹', '😺', '😻', '😼', '😽', '😾', '🙀', '😿', '🐱'];

	constructor(
		private readonly context: vscode.ExtensionContext
	) { }

	/**
	 * Called when our custom editor is opened.
	 * 
	 * 
	 */
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
			webviewPanel.webview.postMessage({
				type: 'update',
				text: document.getText(),
			});
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
			switch (e.type) {
				case 'add':
					this.addNewScratch(document);
					return;

				case 'delete':
					this.deleteScratch(document, e.id);
					return;
			}
		});

		updateWebview();
	}

	/**
	 * Get the static html used for the editor webviews.
	 */
	private getHtmlForWebview(webview: vscode.Webview): string {
		// Local path to script and css for the webview
		const scriptUri = webview.asWebviewUri(vscode.Uri.file(
			path.join(this.context.extensionPath, 'media', 'catScratch.js')
		));
		const styleResetUri = webview.asWebviewUri(vscode.Uri.file(
			path.join(this.context.extensionPath, 'media', 'reset.css')
		));
		const styleVSCodeUri = webview.asWebviewUri(vscode.Uri.file(
			path.join(this.context.extensionPath, 'media', 'vscode.css')
		));
		const styleMainUri = webview.asWebviewUri(vscode.Uri.file(
			path.join(this.context.extensionPath, 'media', 'catScratch.css')
		));

		// Use a nonce to whitelist which scripts can be run
		const nonce = getNonce();
		//const html_view = fs.readFileSync("../editors.editor1.html").toString();
		//return html_view;
		return `
			<!DOCTYPE html>
			<html lang="en">
			<head>
				<meta charset="UTF-8">

				<!--
				Use a content security policy to only allow loading images from https or from our extension directory,
				and only allow scripts that have a specific nonce.
				-->
				<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src ${webview.cspSource}; style-src ${webview.cspSource}; script-src 'nonce-${nonce}';">

				<meta name="viewport" content="width=device-width, initial-scale=1.0">

				<link href="${styleResetUri}" rel="stylesheet" />
				<link href="${styleVSCodeUri}" rel="stylesheet" />
				<link href="${styleMainUri}" rel="stylesheet" />

				<title>Cat Scratch</title>
			</head>
			<body>
				<div class="notes">
					<div class="add-button">
						<button>Scratch!</button>
					</div>
				</div>
				
				<script nonce="${nonce}">
					// Script run within the webview itself.
					(function () {
					
						// Get a reference to the VS Code webview api.
						// We use this API to post messages back to our extension.
					
						// @ts-ignore
						const vscode = acquireVsCodeApi();
					
					
						const notesContainer = /** @type {HTMLElement} */ (document.querySelector('.notes'));
					
						const addButtonContainer = document.querySelector('.add-button');
						addButtonContainer.querySelector('button').addEventListener('click', () => {
							vscode.postMessage({
								type: 'add'
							});
						})
					
						const errorContainer = document.createElement('div');
						document.body.appendChild(errorContainer);
						errorContainer.className = 'error'
						errorContainer.style.display = 'none'
					
						/**
						 * Render the document in the webview.
						 */
						function updateContent(/** @type {string} */ text) {
							let json;
							try {
								json = JSON.parse(text);
							} catch {
								notesContainer.style.display = 'none';
								errorContainer.innerText = 'Error: Document is not valid json';
								errorContainer.style.display = '';
								return;
							}
							notesContainer.style.display = '';
							errorContainer.style.display = 'none';
					
							// Render the scratches
							notesContainer.innerHTML = '';
							for (const note of json.scratches || []) {
								const element = document.createElement('div');
								element.className = 'note';
								notesContainer.appendChild(element);
					
								const text = document.createElement('div');
								text.className = 'text';
								const textContent = document.createElement('span');
								textContent.innerText = note.text;
								text.appendChild(textContent);
								element.appendChild(text);
					
								const created = document.createElement('div');
								created.className = 'created';
								created.innerText = new Date(note.created).toUTCString();
								element.appendChild(created);
					
								const deleteButton = document.createElement('button');
								deleteButton.className = 'delete-button';
								deleteButton.addEventListener('click', () => {
									vscode.postMessage({ type: 'delete', id: note.id, });
								});
								element.appendChild(deleteButton);
							}
					
							notesContainer.appendChild(addButtonContainer);
						}
					
						// Handle messages sent from the extension to the webview
						window.addEventListener('message', event => {
							const message = event.data; // The json data that the extension sent
							switch (message.type) {
								case 'update':
									const text = message.text;
					
									// Update our webview's content
									updateContent(text);
					
									// Then persist state information.
									// This state is returned in the call to vscode.getState below when a webview is reloaded.
									vscode.setState({ text });
					
									return;
							}
						});
					
						// Webviews are normally torn down when not visible and re-created when they become visible again.
						// State lets us save information across these re-loads
						const state = vscode.getState();
						if (state) {
							updateContent(state.text);
						}
					}());
				</script>
			</body>
			</html>`;
	}

	/**
	 * Add a new scratch to the current document.
	 */
	private addNewScratch(document: vscode.TextDocument) {
		const json = this.getDocumentAsJson(document);
		const character = TestFlowEditorProvider.scratchCharacters[Math.floor(Math.random() * TestFlowEditorProvider.scratchCharacters.length)];
		json.scratches = [
			...(Array.isArray(json.scratches) ? json.scratches : []),
			{
				id: getNonce(),
				text: character,
				created: Date.now(),
			}
		];

		return this.updateTextDocument(document, json);
	}

	/**
	 * Delete an existing scratch from a document.
	 */
	private deleteScratch(document: vscode.TextDocument, id: string) {
		const json = this.getDocumentAsJson(document);
		if (!Array.isArray(json.scratches)) {
			return;
		}

		json.scratches = json.scratches.filter((note: any) => note.id !== id);

		return this.updateTextDocument(document, json);
	}

	/**
	 * Try to get a current document as json text.
	 */
	private getDocumentAsJson(document: vscode.TextDocument): any {
		const text = document.getText();
		if (text.trim().length === 0) {
			return {};
		}

		try {
			return JSON.parse(text);
		} catch {
			throw new Error('Could not get document as json. Content is not valid json');
		}
	}

	/**
	 * Write out the json to a given document.
	 */
	private updateTextDocument(document: vscode.TextDocument, json: any) {
		const edit = new vscode.WorkspaceEdit();

		// Just replace the entire document every time for this example extension.
		// A more complete extension should compute minimal edits instead.
		edit.replace(
			document.uri,
			new vscode.Range(0, 0, document.lineCount, 0),
			JSON.stringify(json, null, 2));

		return vscode.workspace.applyEdit(edit);
	}
}
