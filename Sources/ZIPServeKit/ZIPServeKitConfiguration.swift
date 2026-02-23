import Foundation

/// Configuration for the custom protocol service
public struct ZIPServeKitConfiguration {
    /// The custom URL scheme name (e.g., "myapp" for "myapp://")
    public let schemeName: String
    
    /// URL to the ZIP file containing content to serve
    public let zipFileURL: URL
    
    /// Default file to serve when path is empty (optional)
    public let indexFileName: String?
    
    /// Custom MIME type mappings (file extension -> MIME type)
    /// These override the default system mappings
    public let mimeTypeOverrides: [String: String]
    
    /// Enable debug logging
    public let enableDebugLogging: Bool
    
    public init(
        schemeName: String,
        zipFileURL: URL,
        indexFileName: String? = "index.html",
        mimeTypeOverrides: [String: String] = [:],
        enableDebugLogging: Bool = false
    ) {
        self.schemeName = schemeName
        self.zipFileURL = zipFileURL
        self.indexFileName = indexFileName
        self.mimeTypeOverrides = mimeTypeOverrides
        self.enableDebugLogging = enableDebugLogging
    }
}
