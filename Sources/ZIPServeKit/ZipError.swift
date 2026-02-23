import Foundation

enum ZipError: Error {
    case invalidFormat
    case readError
    case unsupportedCompressionMethod
    case decompressionError
}
