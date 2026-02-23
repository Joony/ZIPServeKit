import Foundation
import WebKit
import UniformTypeIdentifiers

final class ZIPServeKitURLSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    
    private static var zipFileURL: URL?
    private static var zipArchive: ZipArchive?
    private static var enableDebugLogging: Bool = false
    
    private let configuration: ZIPServeKitConfiguration
    
    init(configuration: ZIPServeKitConfiguration) {
        self.configuration = configuration
        super.init()
    }
    
    static func configure(zipFileURL: URL, enableDebugLogging: Bool) {
        if enableDebugLogging {
            print("🔧 CustomURLSchemeHandler: Configuring with ZIP: \(zipFileURL.path)")
        }
        
        self.zipFileURL = zipFileURL
        self.enableDebugLogging = enableDebugLogging
        
        do {
            self.zipArchive = try ZipArchive(url: zipFileURL)
            
            if enableDebugLogging {
                print("✅ CustomURLSchemeHandler: ZipArchive created successfully")
                
                // Debug: List files in the archive
                if let archive = self.zipArchive {
                    let files = archive.listFiles().filter { !$0.hasPrefix("__MACOSX") }
                    print("📦 ZIP contains \(files.count) files (excluding __MACOSX):")
                    for (index, file) in files.prefix(20).enumerated() {
                        print("   \(index + 1). \(file)")
                    }
                    if files.count > 20 {
                        print("   ... and \(files.count - 20) more files")
                    }
                }
            }
        } catch {
            print("❌ CustomURLSchemeHandler: Failed to create ZipArchive: \(error)")
        }
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            if Self.enableDebugLogging {
                print("❌ No URL in request")
            }
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        
        if Self.enableDebugLogging {
            print("🌐 Request for: \(url.absoluteString)")
            print("   Path: '\(url.path)'")
            print("   Host: '\(url.host ?? "none")'")
        }
        
        guard let zipArchive = Self.zipArchive else {
            if Self.enableDebugLogging {
                print("❌ No zip archive available")
            }
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        
        // Get the path - url.path includes the leading slash
        var filePath = url.path
        
        // Remove leading slash if present
        if filePath.hasPrefix("/") {
            filePath.removeFirst()
        }
        
        // If the path is empty, try to serve the index file
        if filePath.isEmpty {
            if let indexFileName = configuration.indexFileName {
                filePath = indexFileName
            } else {
                if Self.enableDebugLogging {
                    print("❌ Empty path requested and no index file configured")
                }
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                return
            }
        }
        
        if Self.enableDebugLogging {
            print("📄 Looking for file: '\(filePath)'")
        }
        
        do {
            guard let fileData = try zipArchive.extractFile(at: filePath) else {
                if Self.enableDebugLogging {
                    print("❌ File not found in ZIP: \(filePath)")
                }
                urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
                return
            }
            
            serveFile(fileData, for: filePath, url: url, task: urlSchemeTask)
            
        } catch {
            if Self.enableDebugLogging {
                print("❌ Error extracting file: \(error)")
            }
            urlSchemeTask.didFailWithError(error)
        }
    }
    
    private func serveFile(_ fileData: Data, for filePath: String, url: URL, task: WKURLSchemeTask) {
        if Self.enableDebugLogging {
            print("✅ Extracted \(fileData.count) bytes for \(filePath)")
        }
        
        let mimeType = getMimeType(for: filePath)
        
        if Self.enableDebugLogging {
            print("📋 MIME type: \(mimeType)")
        }
        
        // Create HTTP response with proper headers
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType,
                "Content-Length": "\(fileData.count)",
                "Access-Control-Allow-Origin": "*",
                "Cross-Origin-Embedder-Policy": "require-corp",
                "Cross-Origin-Opener-Policy": "same-origin"
            ]
        )
        
        if let response = httpResponse {
            task.didReceive(response)
        } else {
            // Fallback to URLResponse
            let response = URLResponse(
                url: url,
                mimeType: mimeType,
                expectedContentLength: fileData.count,
                textEncodingName: nil
            )
            task.didReceive(response)
        }
        
        task.didReceive(fileData)
        task.didFinish()
        
        if Self.enableDebugLogging {
            print("✅ Successfully served: \(filePath)")
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        if Self.enableDebugLogging {
            print("⚠️ Request stopped for: \(urlSchemeTask.request.url?.absoluteString ?? "unknown")")
        }
    }
    
    // MARK: - MIME Type Resolution
    
    private func getMimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        
        // First, check user-provided overrides
        if let override = configuration.mimeTypeOverrides[ext] {
            return override
        }
        
        // Critical system overrides that must be exact
        switch ext {
        case "wasm":
            return "application/wasm"
        case "mjs":
            return "application/javascript"
        default:
            break
        }
        
        // Use system UTType for automatic resolution
        if #available(iOS 14.0, macOS 11.0, *) {
            if let utType = UTType(filenameExtension: ext),
               let mimeType = utType.preferredMIMEType {
                return mimeType
            }
        }
        
        // Fallback for older systems or unknown types
        return "application/octet-stream"
    }
}
