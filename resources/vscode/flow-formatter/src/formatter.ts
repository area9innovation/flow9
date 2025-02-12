import * as vscode from 'vscode';

export class FlowFormatter implements vscode.DocumentFormattingEditProvider {
	public provideDocumentFormattingEdits(
		document: vscode.TextDocument,
		options: vscode.FormattingOptions,
		token: vscode.CancellationToken
	): Promise<vscode.TextEdit[]> {
		return new Promise((resolve, reject) => {
			try {
				const text = document.getText();
				const formatted = this.formatFlow(text);

				const fullRange = new vscode.Range(
					document.lineAt(0).range.start,
					document.lineAt(document.lineCount - 1).range.end
				);

				resolve([new vscode.TextEdit(fullRange, formatted)]);
			} catch (error) {
				reject(error);
			}
		});
	}

    private formatFlow(text: string): string {
        const indentSize = 4;
        let indentLevel = 0;
        let lines = text.split('\n');
        let result: string[] = [];
        let inExportBlock = false;
        let inComment = false;
        let inString = false;
        let previousNonEmptyLine = '';
    
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            let originalLine = lines[i];
    
            // Preserve empty lines, but limit consecutive empty lines to 1
            if (line.length === 0) {
                if (result.length === 0 || result[result.length - 1] !== '') {
                    result.push('');
                }
                continue;
            }
    
            // Handle comments
            if (line.startsWith('/*')) {
                inComment = true;
                result.push(line);
                continue;
            }
            if (line.endsWith('*/')) {
                inComment = false;
                result.push(line);
                continue;
            }
            if (inComment) {
                result.push(line);
                continue;
            }
            if (line.startsWith('//')) {
                result.push(line);
                continue;
            }
    
            // Handle export block
            if (line === 'export {') {
                inExportBlock = true;
                indentLevel++;
                result.push('export {');
                continue;
            }
            if (inExportBlock && line === '}') {
                inExportBlock = false;
                indentLevel--;
                result.push('}');
                continue;
            }
    
            // Handle struct declarations
            if (line.includes('::=')) {
                line = this.formatStructDeclaration(line);
                if (previousNonEmptyLine && !previousNonEmptyLine.endsWith(';')) {
                    result.push('');
                }
            }
            // Handle function declarations
            else if (line.match(/^\w+\s*\(/)) {
                line = this.formatFunctionDeclaration(line);
                if (previousNonEmptyLine && !previousNonEmptyLine.endsWith(';')) {
                    result.push('');
                }
            }
            // Handle import statements
            else if (line.startsWith('import ')) {
                line = this.formatImport(line);
            }
            // Handle function types
            else if (line.includes('->')) {
                line = this.formatFunctionType(line);
            }
            // Handle general statements
            else {
                line = this.formatLine(line);
            }
    
            // Adjust indent for closing braces
            if (line.startsWith('}') && !line.includes('::=')) {
                indentLevel = Math.max(0, indentLevel - 1);
            }
    
            // Add semicolons where needed
            if (!this.shouldSkipSemicolon(line)) {
                line = line.endsWith(';') ? line : line + ';';
            }
    
            // Add indent
            if (!line.startsWith('//')) {
                line = ' '.repeat(indentLevel * indentSize) + line;
            }
    
            result.push(line);
    
            // Adjust indent for opening braces
            if (line.endsWith('{')) {
                indentLevel++;
            }
    
            if (line.trim().length > 0) {
                previousNonEmptyLine = line;
            }
        }
    
        return result.join('\n');
    }
    
    private formatFunctionDeclaration(line: string): string {
        return line
            .replace(/(\w+)\s*\(\s*/g, '$1(')
            .replace(/\s*\)\s*{/g, ') {')
            .replace(/\s*:\s*/g, ': ')
            .replace(/\s*,\s*/g, ', ')
            .trim();
    }
    
    private formatImport(line: string): string {
        return line.replace(/\s+/g, ' ').trim();
    }
    
    private formatStructDeclaration(line: string): string {
        // Improved struct formatting
        return line
            .replace(/\s*::=\s*/, ' ::= ')
            .replace(/\s*,\s*/g, ', ')
            .replace(/\(\s*/g, '(')
            .replace(/\s*\)/g, ')')
            .replace(/\s*:\s*/g, ' : ')
            .trim();
    }
    
    private formatFunctionType(line: string): string {
        return line
            .replace(/\s*->\s*/g, ' -> ')
            .replace(/\s*:\s*/g, ' : ')
            .replace(/\s*,\s*/g, ', ')
            .replace(/\(\s*/g, '(')
            .replace(/\s*\)/g, ')')
            .trim();
    }
    
    private formatLine(line: string): string {
        
        return line
            // Operators
            .replace(/\s*([-+*/<>=])\s*/g, ' $1 ')
            .replace(/\s*,\s*/g, ', ')
            .replace(/\s*:\s*/g, ' : ')
    
            // Parentheses
            .replace(/\(\s+/g, '(')
            .replace(/\s+\)/g, ')')
    
            // Array syntax
            .replace(/\[\s+/g, '[')
            .replace(/\s+\]/g, ']')
    
            // Switch statements
            .replace(/switch\s*\(\s*/g, 'switch (')
            .replace(/\s*\)\s*{/g, ') {')
    
            // If statements
            .replace(/if\s*\(\s*/g, 'if (')
            .replace(/\s*\)\s*{/g, ') {')
            .replace(/\s*else\s*{/g, ' else {')
    
            // Remove multiple spaces
            .replace(/\s+/g, ' ')
            .trim();
    }
    
    private shouldSkipSemicolon(line: string): boolean {
        return line.endsWith('{') ||
               line.endsWith('}') ||
               line.endsWith(';') ||
               line.startsWith('import ') ||
               line.startsWith('export {') ||
               line.startsWith('//') ||
               line.match(/^[A-Z]\w*\s*::=/) !== null; // Union type declarations
    }
}