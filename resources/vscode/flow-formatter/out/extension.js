"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deactivate = exports.activate = void 0;
const vscode = require("vscode");
const formatter_1 = require("./formatter");
function activate(context) {
    console.log('Flow formatter is now active');
    let formatter = new formatter_1.FlowFormatter();
    let disposable = vscode.languages.registerDocumentFormattingEditProvider({ scheme: 'file', language: 'flow' }, formatter);
    context.subscriptions.push(disposable);
}
exports.activate = activate;
function deactivate() { }
exports.deactivate = deactivate;
//# sourceMappingURL=extension.js.map