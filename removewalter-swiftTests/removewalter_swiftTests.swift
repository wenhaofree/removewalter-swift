//
//  removewalter_swiftTests.swift
//  removewalter-swiftTests
//
//  Created by wenhao on 2026/2/25.
//

import Testing
import Foundation
@testable import removewalter_swift

struct removewalter_swiftTests {

    @Test func normalizedExtensionPrefersSourceURL() {
        let sourceURL = URL(string: "https://example.com/video.mov")!
        let ext = VideoFileNaming.normalizedVideoFileExtension(
            sourceURL: sourceURL,
            suggestedFilename: "fallback.mp4",
            mimeType: "video/mp4"
        )
        #expect(ext == "mov")
    }

    @Test func normalizedExtensionFallsBackToSuggestedFilename() {
        let sourceURL = URL(string: "https://example.com/video")!
        let ext = VideoFileNaming.normalizedVideoFileExtension(
            sourceURL: sourceURL,
            suggestedFilename: "download_name.mp4",
            mimeType: "video/quicktime"
        )
        #expect(ext == "mp4")
    }

    @Test func normalizedExtensionFallsBackToMimeTypeAndDefault() {
        let sourceURL = URL(string: "https://example.com/video")!
        let movExt = VideoFileNaming.normalizedVideoFileExtension(
            sourceURL: sourceURL,
            suggestedFilename: nil,
            mimeType: "video/quicktime"
        )
        #expect(movExt == "mov")

        let defaultExt = VideoFileNaming.normalizedVideoFileExtension(
            sourceURL: sourceURL,
            suggestedFilename: nil,
            mimeType: nil
        )
        #expect(defaultExt == "mp4")
    }

    @Test func retryPolicyHandlesStatusCodes() {
        #expect(NetworkRetryPolicy.shouldRetry(statusCode: 500))
        #expect(NetworkRetryPolicy.shouldRetry(statusCode: 429))
        #expect(NetworkRetryPolicy.shouldRetry(statusCode: 408))
        #expect(!NetworkRetryPolicy.shouldRetry(statusCode: 400))
        #expect(!NetworkRetryPolicy.shouldRetry(statusCode: 404))
    }

    @Test func retryPolicyHandlesNetworkErrors() {
        let timeoutError = URLError(.timedOut)
        let cancelledError = URLError(.cancelled)
        #expect(NetworkRetryPolicy.shouldRetry(error: timeoutError))
        #expect(!NetworkRetryPolicy.shouldRetry(error: cancelledError))
    }

    @Test func retryBackoffGrowsByAttempt() {
        let first = NetworkRetryPolicy.backoffNanoseconds(forAttempt: 1)
        let second = NetworkRetryPolicy.backoffNanoseconds(forAttempt: 2)
        #expect(first == 300_000_000)
        #expect(second == 600_000_000)
        #expect(second > first)
    }

}
