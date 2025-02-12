"use strict";
exports.__esModule = true;
exports.FlowFormatter = void 0;
var vscode = require("vscode");
var FlowFormatter = /** @class */ (function () {
    function FlowFormatter() {
    }
    FlowFormatter.prototype.provideDocumentFormattingEdits = function (document, options, token) {
        var _this = this;
        return new Promise(function (resolve, reject) {
            try {
                var text = document.getText();
                var formatted = _this.formatFlow(text);
                var fullRange = new vscode.Range(document.lineAt(0).range.start, document.lineAt(document.lineCount - 1).range.end);
                resolve([new vscode.TextEdit(fullRange, formatted)]);
            }
            catch (error) {
                reject(error);
            }
        });
    };
    FlowFormatter.prototype.formatFlow = function (text) {
        console.log('Formatting flow code...');
        var indentLevel = 0;
        var indentSize = 4;
        var lines = text.split('\n');
        var result = [];
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (line.length === 0) {
                result.push('');
                continue;
            }
            if (line.startsWith('}')) {
                indentLevel = Math.max(0, indentLevel - 1);
            }
            line = line.replace(/(\w+)\s*\(\s*/g, '$1(')
                .replace(/\s*\)/g, ')')
                .replace(/,\s*/g, ', ')
                .replace(/\s*{/g, ' {')
                .replace(/{\s*/g, '{')
                .replace(/\s+/g, ' ')
                .trim();
            if (!line.endsWith('{') &&
                !line.endsWith('}') &&
                !line.endsWith(';') &&
                !line.startsWith('import ')) {
                line += ';';
            }
            line = ' '.repeat(indentLevel * indentSize) + line;
            result.push(line);
            if (line.endsWith('{')) {
                indentLevel++;
            }
        }
        return result.join('\n');
    };
    return FlowFormatter;
}());
exports.FlowFormatter = FlowFormatter;
