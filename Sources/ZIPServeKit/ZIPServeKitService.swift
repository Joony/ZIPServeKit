import Foundation
import WebKit

/// Main service for managing custom protocol handling
@MainActor
public final class ZIPServeKitService {
    public static let shared = ZIPServeKitService()
    
    private var webView: WKWebView?
    private var schemeHandler: ZIPServeKitURLSchemeHandler?
    private var configuration: ZIPServeKitConfiguration?
    
    private init() {}
    
    /// Initialize the service with configuration
    public func setup(configuration: ZIPServeKitConfiguration) throws {
        self.configuration = configuration
        
        if configuration.enableDebugLogging {
            print("🔧 CustomProtocolService: Setting up with scheme '\(configuration.schemeName)'")
            print("   ZIP file: \(configuration.zipFileURL.path)")
        }
        
        self.schemeHandler = ZIPServeKitURLSchemeHandler(configuration: configuration)
        ZIPServeKitURLSchemeHandler.configure(
            zipFileURL: configuration.zipFileURL,
            enableDebugLogging: configuration.enableDebugLogging
        )
        
        if configuration.enableDebugLogging {
            print("✅ CustomProtocolService: Setup complete")
        }
    }
    
    /// Create a configured WKWebView
    public func createWebView(frame: CGRect) -> WKWebView {
        guard let configuration = configuration,
              let schemeHandler = schemeHandler else {
            fatalError("CustomProtocolService must be configured before creating a WebView. Call setup(configuration:) first.")
        }
        
        if configuration.enableDebugLogging {
            print("🌐 CustomProtocolService: Creating WKWebView")
        }
        
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemeHandler, forURLScheme: configuration.schemeName)
        
        // Enable JavaScript
        config.preferences.javaScriptEnabled = true
        
        // Allow file access
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: frame, configuration: config)
        self.webView = webView
        
        if configuration.enableDebugLogging {
            print("✅ CustomProtocolService: WKWebView created")
        }
        
        return webView
    }
    
    /// Load a file from the custom protocol
    public func loadFile(_ fileName: String) {
        guard let webView = webView,
              let configuration = configuration else {
            print("❌ CustomProtocolService: Not configured or WebView not created")
            return
        }
        
        let urlString = "\(configuration.schemeName)://\(fileName)"
        guard let url = URL(string: urlString) else {
            print("❌ CustomProtocolService: Invalid URL: \(urlString)")
            return
        }
        
        let request = URLRequest(url: url)
        webView.load(request)
    }
    
    /// Load the index file (if configured)
    public func loadIndex() {
        guard let configuration = configuration,
              let indexFileName = configuration.indexFileName else {
            print("❌ CustomProtocolService: No index file configured")
            return
        }
        
        loadFile(indexFileName)
    }
}
