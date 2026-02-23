# ZIPServeKit

A Swift Package for serving content from ZIP archives via custom URL protocols in WKWebView.

## Features

- ✅ Serve any content from a ZIP file via custom URL schemes
- ✅ Automatic MIME type detection using system `UTType`
- ✅ Custom MIME type overrides
- ✅ Support for compressed and uncompressed ZIP files
- ✅ Debug logging support
- ✅ Thread-safe and `Sendable` compliant
- ✅ iOS 14+ and macOS 11+ support

## Installation

### Swift Package Manager

Add this to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/joony/ZIPServeKit.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Packages → Enter repository URL

## Usage

### Basic Setup

```swift
import ZIPServeKit

// 1. Create configuration
let config = CustomProtocolConfiguration(
    schemeName: "myapp",
    zipFileURL: Bundle.main.url(forResource: "content", withExtension: "zip")!
)

// 2. Setup the service
try CustomProtocolService.shared.setup(configuration: config)

// 3. Create WebView
let webView = CustomProtocolService.shared.createWebView(frame: view.bounds)
view.addSubview(webView)

// 4. Load content
CustomProtocolService.shared.loadIndex() // Loads index.html
// Or load specific file:
CustomProtocolService.shared.loadFile("page.html")
```

### Advanced Configuration

```swift
let config = CustomProtocolConfiguration(
    schemeName: "docs",
    zipFileURL: zipURL,
    indexFileName: "home.html",
    mimeTypeOverrides: [
        "md": "text/markdown",
        "mdx": "text/markdown"
    ],
    enableDebugLogging: true
)
```

### Custom MIME Types

Override MIME types for specific file extensions:
    
```swift
let config = CustomProtocolConfiguration(
    schemeName: "myapp",
    zipFileURL: zipURL,
    mimeTypeOverrides: [
        "custom": "application/x-custom",
        "data": "application/json"
    ]
)
```

### Creating the ZIP File

Create an uncompressed ZIP for best performance:
    
```swift
# macOS/Linux
zip -0 -r content.zip . -x "*.DS_Store" -x "__MACOSX/*"

# Or use compression (slower loading)
zip -r content.zip .
```

## Requirements

* iOS 14.0+ / macOS 11.0+
* Swift 5.9+
* Xcode 15.0+

## License

MIT License

## Usage Example

Here's how someone would use your package:

```swift
import UIKit
import CustomProtocolKit

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the service
        guard let zipURL = Bundle.main.url(forResource: "webapp", withExtension: "zip") else {
            fatalError("ZIP file not found")
        }
        
        let config = CustomProtocolConfiguration(
            schemeName: "webapp",
            zipFileURL: zipURL,
            indexFileName: "index.html",
            mimeTypeOverrides: [:],
            enableDebugLogging: true
        )
        
        do {
            try CustomProtocolService.shared.setup(configuration: config)
            
            // Create and add WebView
            let webView = CustomProtocolService.shared.createWebView(frame: view.bounds)
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(webView)
            
            // Load the content
            CustomProtocolService.shared.loadIndex()
            
        } catch {
            print("Failed to setup: \(error)")
        }
    }
}
