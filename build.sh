#!/bin/bash

# Build script for mrc1bcp Swift CLI application

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCES_DIR="$PROJECT_DIR/Sources"
BUILD_DIR="$PROJECT_DIR/build"
OUTPUT_NAME="mrc1bcp"

echo "🔨 Building mrc1bcp..."
echo "Project directory: $PROJECT_DIR"

# Create build directory
mkdir -p "$BUILD_DIR"

# List of source files in compilation order
SOURCE_FILES=(
    "$SOURCES_DIR/Utils.swift"
    "$SOURCES_DIR/Configuration.swift"
    "$SOURCES_DIR/Models.swift"
    "$SOURCES_DIR/FileOperations.swift"
    "$SOURCES_DIR/ImportModule.swift"
    "$SOURCES_DIR/ConversionModule.swift"
    "$SOURCES_DIR/ArchiveModule.swift"
    "$SOURCES_DIR/TimestampUtilities.swift"
    "$SOURCES_DIR/InteractiveWorkflow.swift"
    "$SOURCES_DIR/AutopilotCommand.swift"
    "$SOURCES_DIR/main.swift"
)

# Compile
echo "📦 Compiling Swift sources..."
swiftc \
    -O \
    -whole-module-optimization \
    -o "$BUILD_DIR/$OUTPUT_NAME" \
    "${SOURCE_FILES[@]}"

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📍 Executable location: $BUILD_DIR/$OUTPUT_NAME"
    echo ""
    echo "To install globally, run:"
    echo "  sudo cp $BUILD_DIR/$OUTPUT_NAME /usr/local/bin/"
    echo ""
    echo "To test, run:"
    echo "  $BUILD_DIR/$OUTPUT_NAME --help"
else
    echo "❌ Build failed!"
    exit 1
fi
