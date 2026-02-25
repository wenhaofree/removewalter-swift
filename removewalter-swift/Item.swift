//
//  Item.swift
//  removewalter-swift
//
//  Created by wenhao on 2026/2/25.
//

import Foundation
import SwiftData

@Model
final class HistoryRecord {
    var id: UUID
    var title: String
    var sourceLink: String
    var remoteVideoURL: String
    var posterURL: String?
    var localVideoPath: String?
    var createdAt: Date
    var fileSizeBytes: Int64?
    var durationSeconds: Double?

    init(
        id: UUID = UUID(),
        title: String,
        sourceLink: String,
        remoteVideoURL: String,
        posterURL: String? = nil,
        localVideoPath: String? = nil,
        createdAt: Date = .now,
        fileSizeBytes: Int64? = nil,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceLink = sourceLink
        self.remoteVideoURL = remoteVideoURL
        self.posterURL = posterURL
        self.localVideoPath = localVideoPath
        self.createdAt = createdAt
        self.fileSizeBytes = fileSizeBytes
        self.durationSeconds = durationSeconds
    }
}
