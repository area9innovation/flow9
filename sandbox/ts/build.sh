#!/bin/bash

set -e

echo "🏗️  Building Flow9 TypeScript Integration Test"
echo "=============================================="

# Check if Node.js and npm are available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js to continue."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm to continue."
    exit 1
fi

echo "📦 Installing dependencies..."
npm install

echo "🔧 Compiling Flow code..."
if [ -f "compile.sh" ]; then
    ./compile.sh
else
    echo "⚠️  compile.sh not found, assuming Flow code is already compiled"
fi

echo "🔍 Type checking TypeScript code..."
npm run type-check

echo "🔧 Compiling TypeScript..."
npm run compile

echo "📦 Bundling with webpack..."
npm run bundle

echo "🗜️  Minifying bundle..."
npm run minify

echo "✅ Build completed successfully!"
echo ""
echo "Output files:"
echo "  - dist/bundle.js (bundled)"
echo "  - dist/bundle.min.js (minified)"
echo ""
echo "To run the program:"
echo "  node dist/bundle.js"