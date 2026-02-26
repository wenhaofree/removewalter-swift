import Foundation

enum VideoFileNaming {
    static func normalizedVideoFileExtension(sourceURL: URL, suggestedFilename: String?, mimeType: String?) -> String {
        let sourceExtension = sourceURL.pathExtension.lowercased()
        if !sourceExtension.isEmpty {
            return sourceExtension
        }

        if let suggestedFilename {
            let suggestedExtension = URL(fileURLWithPath: suggestedFilename).pathExtension.lowercased()
            if !suggestedExtension.isEmpty {
                return suggestedExtension
            }
        }

        if let mimeType {
            let normalizedMime = mimeType.lowercased()
            if normalizedMime.contains("mp4") {
                return "mp4"
            }
            if normalizedMime.contains("quicktime") || normalizedMime.contains("mov") {
                return "mov"
            }
        }

        return "mp4"
    }
}

enum NetworkRetryPolicy {
    static let maxParseAttempts = 3
    static let maxDownloadAttempts = 3

    static func shouldRetry(statusCode: Int) -> Bool {
        statusCode == 408 || statusCode == 429 || (500 ... 599).contains(statusCode)
    }

    static func shouldRetry(error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain != NSURLErrorDomain {
            return false
        }

        let retryableCodes: Set<Int> = [
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
            NSURLErrorDNSLookupFailed
        ]
        return retryableCodes.contains(nsError.code)
    }

    static func backoffNanoseconds(forAttempt attempt: Int) -> UInt64 {
        let clampedAttempt = max(1, attempt)
        let milliseconds = 300 * clampedAttempt
        return UInt64(milliseconds) * 1_000_000
    }
}
