#!/bin/bash

# This script packages the VS Code extension for S-expression files

# Create the extensions directory if it doesn't exist
mkdir -p extensions

# Find the generated extension directory
EXT_DIR="extensions/area9.sexpr"

if [ ! -d "$EXT_DIR" ]; then
  echo "Error: Could not find the extension directory at $EXT_DIR."
  echo "Please make sure you've compiled the grammar first."
  exit 1
fi

# Copy our custom README to the extension directory
cp vscode-readme.md "$EXT_DIR/README.md"

# Check if vsce is installed
if ! command -v vsce &> /dev/null; then
  echo "The 'vsce' command is not found. Would you like to install it? (y/n)"
  read -r answer
  if [ "$answer" != "${answer#[Yy]}" ]; then
    npm install -g @vscode/vsce
  else
    echo "Skipping packaging. Please install vsce manually with: npm install -g @vscode/vsce"
    exit 0
  fi
fi

# Navigate to the extension directory and package it
cd "$EXT_DIR" || exit 1
vsce package

# Move the VSIX file to the sexpr directory and rename it
VSIX_FILE=$(find . -name "*.vsix" | head -n 1)
if [ -n "$VSIX_FILE" ]; then
  mv "$VSIX_FILE" "../../sexpr.vsix"
  echo "Moved VSIX file to sexpr.vsix in the sexpr directory"
fi

# Return to the sexpr directory
cd ../.. || exit 1

# Find latest vsix
VSIX_FILE="sexpr.vsix"
if [ ! -f "$VSIX_FILE" ]; then
    echo "No .vsix file found"
    exit 1
fi

# Check if VS Code is installed and available
if command -v code &> /dev/null; then
  # Uninstall existing extension
  code --uninstall-extension Area9Lyceum.sexpr || true

  # Install new version
  code --install-extension "$VSIX_FILE" --force
  
  echo "VS Code S-expression extension installed successfully"
else
  echo "VS Code command-line tool not found. You'll need to install the extension manually."
fi

echo "VS Code S-expression extension packaged successfully."