call npm install @vscode/vsce

call node_modules\.bin\vsce package -o ..\flow.vsix
call npm run clean
