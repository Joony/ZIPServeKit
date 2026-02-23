import SwiftUI
import ZIPServeKit

struct ContentView: View {
    @State private var isLoaded = false
    @State private var errorMessage: String?
    @State private var showingInfo = false
    @State private var setupComplete = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let errorMessage = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)
                        
                        Text("Failed to Load")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(errorMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            setupComplete = false
                            setupProtocol()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else if setupComplete {
                    WebViewContainer()
                        .opacity(isLoaded ? 1 : 0)
                    
                    if !isLoaded {
                        ProgressView("Loading...")
                            .controlSize(.large)
                    }
                } else {
                    ProgressView("Initializing...")
                        .controlSize(.large)
                }
            }
            .navigationTitle("ZIPServeKit Demo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInfo.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .sheet(isPresented: $showingInfo) {
                InfoView()
            }
            .task {
                if !setupComplete {
                    setupProtocol()
                }
            }
        }
    }
    
    private func setupProtocol() {
        print("🔧 Starting protocol setup...")
        errorMessage = nil
        
        // Check if ZIP file exists
        guard let zipURL = Bundle.main.url(forResource: "example-content", withExtension: "zip") else {
            print("❌ ZIP file not found in bundle")
            
            // List all bundle resources to help debug
            if let resourcePath = Bundle.main.resourcePath {
                print("📦 Bundle resource path: \(resourcePath)")
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("📋 Bundle contents: \(contents)")
                } catch {
                    print("❌ Could not list bundle contents: \(error)")
                }
            }
            
            errorMessage = """
            Could not find example-content.zip in bundle.
            
            Please run the build script:
            cd Examples
            ./build-example.sh
            
            Then rebuild the app in Xcode.
            """
            return
        }
        
        print("✅ Found ZIP at: \(zipURL.path)")
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: zipURL.path) else {
            print("❌ ZIP file is not readable")
            errorMessage = "ZIP file exists but is not readable: \(zipURL.path)"
            return
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: zipURL.path)
            if let fileSize = attributes[.size] as? Int64 {
                print("📦 ZIP file size: \(fileSize) bytes")
                
                if fileSize == 0 {
                    errorMessage = "ZIP file is empty. Please run ./build-example.sh"
                    return
                }
            }
        } catch {
            print("⚠️ Could not get file attributes: \(error)")
        }
        
        let config = ZIPServeKitConfiguration(
            schemeName: "demo",
            zipFileURL: zipURL,
            indexFileName: "index.html",
            mimeTypeOverrides: [:],
            enableDebugLogging: true
        )
        
        print("🔧 Calling setup with configuration...")
        
        do {
            try ZIPServeKitService.shared.setup(configuration: config)
            print("✅ Setup completed successfully!")
            
            setupComplete = true
            
            // Delay to show the WebView is loading
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isLoaded = true
                }
            }
        } catch {
            print("❌ Setup failed with error: \(error)")
            errorMessage = "Setup failed: \(error.localizedDescription)\n\nError: \(error)"
        }
    }
}

struct WebViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        print("🌐 Creating WebView...")
        let webView = ZIPServeKitService.shared.createWebView(frame: .zero)
        print("📄 Loading index...")
        ZIPServeKitService.shared.loadIndex()
        return webView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        // No updates needed
    }
}

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("About") {
                    Label("ZIPServeKit Demo", systemImage: "doc.text.fill")
                    Label("Version 1.0", systemImage: "number")
                }
                
                Section("What's Happening") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This app demonstrates ZIPServeKit:")
                            .font(.headline)
                        
                        Text("1. HTML, CSS, and JS files are bundled in a ZIP")
                        Text("2. The ZIP is loaded at app startup")
                        Text("3. Files are served via a custom 'demo://' protocol")
                        Text("4. WKWebView displays the content")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                
                Section("Features Demonstrated") {
                    Label("Custom URL protocol", systemImage: "link")
                    Label("HTML/CSS/JS loading", systemImage: "doc.richtext")
                    Label("Inter-page navigation", systemImage: "arrow.left.arrow.right")
                    Label("Fetch API support", systemImage: "arrow.down.doc")
                    Label("MIME type handling", systemImage: "doc.badge.gearshape")
                }
                
                Section("Try It") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("In the demo page:")
                            .font(.headline)
                        
                        Text("• Click the JavaScript test button")
                        Text("• Navigate to the About page")
                        Text("• Try the Fetch API test")
                        Text("• Check the technical details")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
