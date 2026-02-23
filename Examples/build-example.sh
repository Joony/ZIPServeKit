#!/bin/bash

# Build script for ZIPServeKitExample

echo "🔨 Building ZIPServeKitExample..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Navigate to WebContent directory
cd "$SCRIPT_DIR/ZIPServeKitExample/WebContent"

if [ ! -d "$SCRIPT_DIR/ZIPServeKitExample/WebContent" ]; then
    echo "❌ WebContent directory not found!"
    echo "Expected: $SCRIPT_DIR/ZIPServeKitExample/WebContent"
    exit 1
fi

echo "📦 Creating ZIP file from web content..."
echo "Working directory: $(pwd)"

# Create Resources directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/ZIPServeKitExample/ZIPServeKitExample/Resources"

# Create ZIP with no compression for faster loading
zip -0 -r "$SCRIPT_DIR/ZIPServeKitExample/ZIPServeKitExample/Resources/example-content.zip" . -x "*.DS_Store" -x "__MACOSX/*"

if [ $? -eq 0 ]; then
    echo "✅ ZIP file created successfully!"
    
    ZIP_PATH="$SCRIPT_DIR/ZIPServeKitExample/ZIPServeKitExample/Resources/example-content.zip"
    
    # Show file size
    FILE_SIZE=$(stat -f%z "$ZIP_PATH" 2>/dev/null || stat -c%s "$ZIP_PATH" 2>/dev/null)
    echo "📊 ZIP file size: $FILE_SIZE bytes"
    
    # Show ZIP contents
    echo ""
    echo "📋 ZIP contents:"
    unzip -l "$ZIP_PATH"
    
    echo ""
    echo "✅ Build complete!"
    echo "📁 ZIP location: $ZIP_PATH"
    echo ""
    echo "Next steps:"
    echo "1. Open ZIPServeKitExample.xcodeproj in Xcode"
    echo "2. Make sure example-content.zip is added to the project target"
    echo "3. Build and run!"
else
    echo "❌ Failed to create ZIP file"
    exit 1
fi
