"use strict";
exports.__esModule = true;
exports.deactivate = exports.activate = void 0;
var vscode = require("vscode");
var formatter_1 = require("./formatter");
function activate(context) {
    console.log('Flow formatter is now active');
    var formatter = new formatter_1.FlowFormatter();
    var disposable = vscode.languages.registerDocumentFormattingEditProvider({ scheme: 'file', language: 'flow' }, formatter);
    context.subscriptions.push(disposable);
}
exports.activate = activate;
function deactivate() { }
exports.deactivate = deactivate;
