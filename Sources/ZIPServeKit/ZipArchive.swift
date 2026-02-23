import Foundation
import Compression

// MARK: - ZIP Archive Handler

final class ZipArchive: Sendable {
    private let fileURL: URL
    private let fileHandle: FileHandle
    private let centralDirectory: [String: ZipEntry]
    
    struct ZipEntry: Sendable {
        let fileName: String
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let compressionMethod: UInt16
        let localHeaderOffset: UInt64
        let crc32: UInt32
    }
    
    init(url: URL) throws {
        self.fileURL = url
        self.fileHandle = try FileHandle(forReadingFrom: url)
        self.centralDirectory = try Self.readCentralDirectory(fileHandle: fileHandle)
    }
    
    deinit {
        try? fileHandle.close()
    }
    
    func extractFile(at path: String) throws -> Data? {
        guard let entry = centralDirectory[path] else {
            return nil
        }
        
        // Seek to local file header
        try fileHandle.seek(toOffset: entry.localHeaderOffset)
        
        // Read local file header
        let localHeader = try fileHandle.read(upToCount: 30)
        guard let localHeader = localHeader, localHeader.count == 30 else {
            throw ZipError.invalidFormat
        }
        
        // Verify local file header signature
        let signature = Self.readUInt32(from: localHeader, offset: 0)
        guard signature == 0x04034b50 else {
            throw ZipError.invalidFormat
        }
        
        // Get file name and extra field lengths
        let fileNameLength = Self.readUInt16(from: localHeader, offset: 26)
        let extraFieldLength = Self.readUInt16(from: localHeader, offset: 28)
        
        // Skip file name and extra field
        try fileHandle.seek(toOffset: entry.localHeaderOffset + 30 + UInt64(fileNameLength) + UInt64(extraFieldLength))
        
        // Read compressed data
        guard let compressedData = try fileHandle.read(upToCount: Int(entry.compressedSize)) else {
            throw ZipError.readError
        }
        
        // Decompress if needed
        if entry.compressionMethod == 0 {
            // Stored (no compression)
            return compressedData
        } else if entry.compressionMethod == 8 {
            // Deflate compression
            return try decompress(compressedData)
        } else {
            throw ZipError.unsupportedCompressionMethod
        }
    }
    
    private static func readCentralDirectory(fileHandle: FileHandle) throws -> [String: ZipEntry] {
        // Find End of Central Directory Record
        try fileHandle.seekToEnd()
        let fileSize = try fileHandle.offset()
        
        // Search for EOCD signature from the end
        let searchSize = min(fileSize, 65536) // Max comment size + EOCD size
        try fileHandle.seek(toOffset: fileSize - searchSize)
        
        guard let searchData = try fileHandle.read(upToCount: Int(searchSize)) else {
            throw ZipError.invalidFormat
        }
        
        // Find EOCD signature (0x06054b50)
        var eocdOffset: Int?
        for i in stride(from: searchData.count - 22, through: 0, by: -1) {
            if i + 3 < searchData.count &&
               searchData[i] == 0x50 && searchData[i+1] == 0x4b &&
               searchData[i+2] == 0x05 && searchData[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }
        
        guard let eocdOffset = eocdOffset else {
            throw ZipError.invalidFormat
        }
        
        // Read EOCD (need at least 22 bytes)
        guard eocdOffset + 22 <= searchData.count else {
            throw ZipError.invalidFormat
        }
        
        let eocdData = Data(searchData[eocdOffset..<min(eocdOffset + 22, searchData.count)])
        let centralDirSize = readUInt32(from: eocdData, offset: 12)
        let centralDirOffset = readUInt32(from: eocdData, offset: 16)
        
        // Read central directory
        try fileHandle.seek(toOffset: UInt64(centralDirOffset))
        guard let centralDirData = try fileHandle.read(upToCount: Int(centralDirSize)) else {
            throw ZipError.invalidFormat
        }
        
        // Parse central directory entries
        var entries: [String: ZipEntry] = [:]
        var offset = 0
        
        while offset + 46 <= centralDirData.count {
            let signature = readUInt32(from: centralDirData, offset: offset)
            
            guard signature == 0x02014b50 else { break }
            
            let compressionMethod = readUInt16(from: centralDirData, offset: offset + 10)
            let crc32 = readUInt32(from: centralDirData, offset: offset + 16)
            let compressedSize = readUInt32(from: centralDirData, offset: offset + 20)
            let uncompressedSize = readUInt32(from: centralDirData, offset: offset + 24)
            let fileNameLength = readUInt16(from: centralDirData, offset: offset + 28)
            let extraFieldLength = readUInt16(from: centralDirData, offset: offset + 30)
            let commentLength = readUInt16(from: centralDirData, offset: offset + 32)
            let localHeaderOffset = readUInt32(from: centralDirData, offset: offset + 42)
            
            // Extract file name
            let fileNameStart = offset + 46
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            
            guard fileNameEnd <= centralDirData.count else {
                break
            }
            
            let fileNameData = centralDirData[fileNameStart..<fileNameEnd]
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                offset += 46 + Int(fileNameLength) + Int(extraFieldLength) + Int(commentLength)
                continue
            }
            
            let entry = ZipEntry(
                fileName: fileName,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                compressionMethod: compressionMethod,
                localHeaderOffset: UInt64(localHeaderOffset),
                crc32: crc32
            )
            
            entries[fileName] = entry
            
            offset += 46 + Int(fileNameLength) + Int(extraFieldLength) + Int(commentLength)
        }
        
        return entries
    }
    
    // MARK: - Safe Unaligned Reading
    
    private static func readUInt16(from data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        
        let bytes = data.withUnsafeBytes { ptr -> [UInt8] in
            guard let baseAddress = ptr.baseAddress else { return [0, 0] }
            let byte1 = baseAddress.load(fromByteOffset: offset, as: UInt8.self)
            let byte2 = baseAddress.load(fromByteOffset: offset + 1, as: UInt8.self)
            return [byte1, byte2]
        }
        
        return UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
    }
    
    private static func readUInt32(from data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        
        let bytes = data.withUnsafeBytes { ptr -> [UInt8] in
            guard let baseAddress = ptr.baseAddress else { return [0, 0, 0, 0] }
            let byte1 = baseAddress.load(fromByteOffset: offset, as: UInt8.self)
            let byte2 = baseAddress.load(fromByteOffset: offset + 1, as: UInt8.self)
            let byte3 = baseAddress.load(fromByteOffset: offset + 2, as: UInt8.self)
            let byte4 = baseAddress.load(fromByteOffset: offset + 3, as: UInt8.self)
            return [byte1, byte2, byte3, byte4]
        }
        
        return UInt32(bytes[0]) |
               (UInt32(bytes[1]) << 8) |
               (UInt32(bytes[2]) << 16) |
               (UInt32(bytes[3]) << 24)
    }
    
    // MARK: - Decompression
    
    private func decompress(_ data: Data) throws -> Data {
        return try data.withUnsafeBytes { (inputPtr: UnsafeRawBufferPointer) -> Data in
            guard let inputBaseAddress = inputPtr.baseAddress else {
                throw ZipError.decompressionError
            }
            
            let outputBufferSize = 32768
            let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: outputBufferSize)
            defer { outputBuffer.deallocate() }
            
            let algorithms: [compression_algorithm] = [COMPRESSION_ZLIB, COMPRESSION_LZMA]
            var lastError: Error?
            
            for algorithm in algorithms {
                var stream = compression_stream(
                    dst_ptr: outputBuffer,
                    dst_size: outputBufferSize,
                    src_ptr: inputBaseAddress.assumingMemoryBound(to: UInt8.self),
                    src_size: data.count,
                    state: nil
                )
                
                var status = compression_stream_init(
                    &stream,
                    COMPRESSION_STREAM_DECODE,
                    algorithm
                )
                
                if status != COMPRESSION_STATUS_OK {
                    continue
                }
                
                defer {
                    compression_stream_destroy(&stream)
                }
                
                var decompressed = Data()
                var iteration = 0
                var success = true
                
                while true {
                    iteration += 1
                    if iteration > 10000 {
                        success = false
                        break
                    }
                    
                    status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))
                    
                    switch status {
                    case COMPRESSION_STATUS_OK:
                        let bytesWritten = outputBufferSize - stream.dst_size
                        decompressed.append(outputBuffer, count: bytesWritten)
                        
                        stream.dst_ptr = outputBuffer
                        stream.dst_size = outputBufferSize
                        
                    case COMPRESSION_STATUS_END:
                        let bytesWritten = outputBufferSize - stream.dst_size
                        decompressed.append(outputBuffer, count: bytesWritten)
                        return decompressed
                        
                    case COMPRESSION_STATUS_ERROR:
                        success = false
                        break
                        
                    default:
                        success = false
                        break
                    }
                    
                    if !success {
                        break
                    }
                }
                
                lastError = ZipError.decompressionError
            }
            
            throw lastError ?? ZipError.decompressionError
        }
    }
    
    func listFiles() -> [String] {
        return Array(centralDirectory.keys).sorted()
    }
}
