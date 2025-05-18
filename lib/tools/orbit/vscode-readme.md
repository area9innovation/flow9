# Orbit VS Code Plugin

## Overview

The Orbit VS Code plugin provides syntax highlighting and F7 compilation support for Orbit files (.orb). It integrates the Orbit mathematical language into VS Code.

## Building and Installing

### Step 1: Generate the extension

```bash
# From the orbit directory
./compile.sh
```

### Step 2: Package and install the extension

```bash
# From the orbit directory
./package-vscode.sh
```

This script will:
1. Package the extension as a .vsix file
2. Uninstall any existing Orbit extension
3. Install the new version automatically

### Alternative: One-step build and install

```bash
# Build and package in one step
./compile.sh --package
```

## Using the Extension

1. Open any .orb file in VS Code
2. The syntax highlighting will be automatically applied
3. Press F7 to compile and run the current file using Orbit

## Features

- Syntax highlighting for Orbit language elements
- F7 key binding to run "flowcpp orbit.flow -- <filename>"
- Bracket matching and comment toggling support
- Special highlighting for Greek letters and mathematical symbols

## Troubleshooting

If the extension isn't working as expected:

1. Check that the .vsix file was successfully generated
2. Verify that it was installed correctly in VS Code
3. Make sure you're using .orb file extension or have selected the Orbit language mode
4. Restart VS Code if needed