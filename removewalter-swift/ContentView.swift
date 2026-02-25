import AVFoundation
import AVKit
import Photos
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab: AppTab = .extract

    var body: some View {
        TabView(selection: $selectedTab) {
            ExtractView()
                .tag(AppTab.extract)
                .tabItem {
                    Label("提取", systemImage: "house")
                }

            HistoryView()
                .tag(AppTab.history)
                .tabItem {
                    Label("历史记录", systemImage: "clock")
                }
        }
        .tint(.brandBlue)
    }
}

private enum AppTab {
    case extract
    case history
}

private struct ExtractView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var linkText = ""
    @State private var hasContentAuthorizationConsent = false
    @State private var completedStepCount = 0
    @State private var statusText = "等待开始"
    @State private var isExtracting = false
    @State private var hasTriggeredExtraction = false
    @State private var shouldShowPreview = false
    @State private var extractionErrorText: String?
    @State private var extractedVideoURL: URL?
    @State private var localVideoURL: URL?
    @State private var previewPosterURL: URL?
    @State private var previewPlayer: AVPlayer?
    @State private var shareItems: [Any] = []
    @State private var isShareSheetPresented = false
    @State private var exportFileURL: URL?
    @State private var isFileExporterPresented = false
    @State private var actionAlert: ActionAlert?
    @State private var extractionTask: Task<Void, Never>?
    @State private var currentRecordID: UUID?
    @FocusState private var isLinkFieldFocused: Bool

    private let steps = ["解析链接", "提取视频", "去除水印", "合成处理"]
    private let parseVideoEndpoint = "https://api-doubaonomark.wenhaofree.com/parse-video"
    // Replace with your real Notion privacy policy URL before submitting.
    private let privacyPolicyURLString = "https://www.notion.so/your-team/privacy-policy"

    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(completedStepCount) / Double(steps.count)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                linkInputSection
                complianceSection
                extractButton

                if let extractionErrorText {
                    Text(extractionErrorText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 4)
                }

                if hasTriggeredExtraction {
                    progressCard
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if shouldShowPreview {
                    previewSection
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    previewActions
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .background(Color.screenBackground.ignoresSafeArea())
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityViewController(activityItems: shareItems)
        }
        .sheet(isPresented: $isFileExporterPresented) {
            if let exportFileURL {
                FileExportController(fileURL: exportFileURL) { didExport in
                    if didExport {
                        showActionAlert(title: "下载成功", message: "视频已导出，请在“文件”App中查看。")
                    }
                }
            }
        }
        .alert(item: $actionAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("知道了")))
        }
        .onDisappear {
            extractionTask?.cancel()
            previewPlayer?.pause()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("链接提取")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(Color.primaryText)

            Text("自动获取无水印视频并生成预览")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.secondaryText)
        }
    }

    private var linkInputSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondaryText)

            TextField("请输入视频链接", text: $linkText)
                .font(.system(size: 16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isLinkFieldFocused)

            if !linkText.isEmpty {
                Button(action: clearLinkText) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("清空链接")
            }

            Button(action: pasteFromClipboard) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                    Text("粘贴")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 16))
                .foregroundStyle(Color.brandBlue)
                .frame(minWidth: 86, minHeight: 44)
                .background(Color.actionTint)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("粘贴链接")
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var extractButton: some View {
        Button(action: startExtraction) {
            Text(isExtracting ? "正在处理..." : "提取无水印视频")
                .font(.system(size: 34, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(isExtracting ? Color.brandBlue.opacity(0.75) : Color.brandBlue)
                .clipShape(Capsule())
        }
        .disabled(
            isExtracting ||
            linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !hasContentAuthorizationConsent
        )
    }

    private var complianceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $hasContentAuthorizationConsent) {
                Text("我确认已获得该视频的使用与下载授权")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.primaryText)
            }
            .toggleStyle(.switch)

            if let privacyPolicyURL = URL(string: privacyPolicyURLString) {
                Link("查看隐私政策（Notion）", destination: privacyPolicyURL)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.brandBlue)
            }

            Text("仅支持处理你拥有合法授权的内容。")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.secondaryText)
        }
        .padding(12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("任务进度")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.primaryText)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.brandBlue)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.brandBlue)
                .scaleEffect(y: 1.3)

            Text(statusText)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(extractionErrorText == nil ? Color.secondaryText : Color.red)

            VStack(spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 10) {
                        Image(systemName: stepIconName(for: index))
                            .foregroundStyle(stepIconColor(for: index))
                            .font(.system(size: 20, weight: .semibold))

                        Text(step)
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(Color.primaryText)

                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预览")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(Color.primaryText)

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.black.opacity(0.06))

                if let previewPlayer {
                    VideoPlayer(player: previewPlayer)
                        .onAppear {
                            previewPlayer.seek(to: .zero)
                            previewPlayer.play()
                        }
                } else if let previewPosterURL {
                    AsyncImage(url: previewPosterURL) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            Color.gray.opacity(0.15)
                        }
                    }
                }
            }
            .frame(height: 560)
            .clipShape(RoundedRectangle(cornerRadius: 28))
        }
    }

    private var previewActions: some View {
        HStack(spacing: 12) {
            ForEach(PreviewAction.allCases, id: \.rawValue) { action in
                Button {
                    handlePreviewAction(action)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: action.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.brandBlue)

                        Text(action.rawValue)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 88)
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityLabel(action.rawValue)
            }
        }
    }

    private func pasteFromClipboard() {
        guard let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty else {
            statusText = "剪贴板暂无文本链接"
            return
        }
        linkText = clipboardText
        statusText = "链接已粘贴"
    }

    private func clearLinkText() {
        linkText = ""
        statusText = "链接已清空"
    }

    private func startExtraction() {
        isLinkFieldFocused = false
        let trimmedLink = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else {
            statusText = "请输入有效链接"
            return
        }
        guard hasContentAuthorizationConsent else {
            let message = "请先确认你已获得视频授权"
            statusText = message
            extractionErrorText = message
            return
        }

        extractionTask?.cancel()
        previewPlayer?.pause()
        previewPlayer = nil
        previewPosterURL = nil
        extractedVideoURL = nil
        localVideoURL = nil
        currentRecordID = nil
        extractionErrorText = nil

        withAnimation(.easeInOut(duration: 0.2)) {
            hasTriggeredExtraction = true
            shouldShowPreview = false
        }
        isExtracting = true
        completedStepCount = 0
        statusText = "正在准备请求..."

        extractionTask = Task {
            do {
                let videoInfo = try await requestParsedVideo(for: trimmedLink)
                if Task.isCancelled { throw CancellationError() }

                await MainActor.run {
                    completedStepCount = 1
                    statusText = "链接解析成功，正在处理视频..."
                }

                try await Task.sleep(nanoseconds: 250_000_000)
                if Task.isCancelled { throw CancellationError() }

                let videoURL = try validatedVideoURL(from: videoInfo.url)
                let posterURL = videoInfo.posterURL.flatMap(URL.init(string:))
                let metadata = await loadRemoteVideoMetadata(from: videoURL)

                await MainActor.run {
                    completedStepCount = 2
                    statusText = "视频提取完成，正在去除水印..."
                }

                try await Task.sleep(nanoseconds: 220_000_000)
                if Task.isCancelled { throw CancellationError() }

                await MainActor.run {
                    completedStepCount = 3
                    statusText = "正在生成预览..."
                }

                try await Task.sleep(nanoseconds: 220_000_000)
                if Task.isCancelled { throw CancellationError() }

                await MainActor.run {
                    completedStepCount = steps.count
                    isExtracting = false
                    statusText = "提取完成"
                    extractionErrorText = nil

                    extractedVideoURL = videoURL
                    localVideoURL = nil
                    previewPosterURL = posterURL
                    previewPlayer = AVPlayer(url: videoURL)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        shouldShowPreview = true
                    }

                    let record = HistoryRecord(
                        title: buildTitle(from: videoURL, createdAt: Date()),
                        sourceLink: trimmedLink,
                        remoteVideoURL: videoURL.absoluteString,
                        posterURL: posterURL?.absoluteString,
                        localVideoPath: nil,
                        createdAt: Date(),
                        fileSizeBytes: metadata.fileSizeBytes,
                        durationSeconds: metadata.durationSeconds
                    )
                    modelContext.insert(record)
                    currentRecordID = record.id

                    do {
                        try modelContext.save()
                    } catch {
                        statusText = "提取完成，但历史记录保存失败"
                    }
                }
            } catch is CancellationError {
                return
            } catch {
                handleExtractionFailure(error)
            }
        }
    }

    private func handlePreviewAction(_ action: PreviewAction) {
        isLinkFieldFocused = false
        switch action {
        case .下载:
            Task { await performDownloadAction() }
        case .保存:
            Task { await performSaveToPhotosAction() }
        case .分享:
            Task { await performShareAction() }
        }
    }

    @MainActor
    private func performDownloadAction() async {
        do {
            let localURL = try await ensureLocalVideoFile()
            extractionErrorText = nil
            statusText = "请选择导出位置"
            exportFileURL = localURL
            isFileExporterPresented = true
        } catch {
            showOperationError(error)
        }
    }

    @MainActor
    private func performSaveToPhotosAction() async {
        do {
            let localFileURL = try await ensureLocalVideoFile()
            statusText = "正在保存到相册..."
            try await requestPhotoPermissionIfNeeded()
            try await writeVideoToPhotoLibrary(fileURL: localFileURL)
            extractionErrorText = nil
            statusText = "已保存到系统相册"
            showActionAlert(title: "保存成功", message: "视频已保存到系统相册。")
        } catch {
            showOperationError(error)
        }
    }

    @MainActor
    private func performShareAction() async {
        if let localVideoURL, FileManager.default.fileExists(atPath: localVideoURL.path) {
            shareItems = [localVideoURL]
            isShareSheetPresented = true
            extractionErrorText = nil
            statusText = "已打开分享面板"
            return
        }

        do {
            let localFileURL = try await ensureLocalVideoFile()
            shareItems = [localFileURL]
            isShareSheetPresented = true
            extractionErrorText = nil
            statusText = "已打开分享面板"
        } catch {
            if let extractedVideoURL {
                shareItems = [extractedVideoURL]
                isShareSheetPresented = true
                extractionErrorText = nil
                statusText = "已打开分享面板"
            } else {
                showOperationError(error)
            }
        }
    }

    @MainActor
    private func ensureLocalVideoFile() async throws -> URL {
        if let localVideoURL, FileManager.default.fileExists(atPath: localVideoURL.path) {
            return localVideoURL
        }

        guard let extractedVideoURL else {
            throw ParseVideoError.noVideoAvailable
        }

        statusText = "正在下载视频..."
        let (temporaryURL, response) = try await URLSession.shared.download(from: extractedVideoURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParseVideoError.invalidServerResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ParseVideoError.serverStatus(httpResponse.statusCode)
        }

        let destinationURL = try makeLocalVideoDestinationURL(
            sourceURL: extractedVideoURL,
            suggestedFilename: httpResponse.suggestedFilename,
            mimeType: httpResponse.value(forHTTPHeaderField: "Content-Type")
        )
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            throw ParseVideoError.fileSaveFailed
        }

        let localFileSize = localFileSizeBytes(at: destinationURL)
        guard let localFileSize, localFileSize > 0 else {
            throw ParseVideoError.fileSaveFailed
        }

        localVideoURL = destinationURL
        updateCurrentRecordLocalFile(localURL: destinationURL, fileSizeBytes: localFileSize)
        return destinationURL
    }

    private func makeLocalVideoDestinationURL(sourceURL: URL, suggestedFilename: String?, mimeType: String?) throws -> URL {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ParseVideoError.fileSaveFailed
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = normalizedVideoFileExtension(
            sourceURL: sourceURL,
            suggestedFilename: suggestedFilename,
            mimeType: mimeType
        )
        let normalizedName = "nowatermark_\(timestamp).\(fileExtension)"
        return documentDirectory.appendingPathComponent(normalizedName)
    }

    private func normalizedVideoFileExtension(sourceURL: URL, suggestedFilename: String?, mimeType: String?) -> String {
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

    private func buildTitle(from videoURL: URL, createdAt: Date) -> String {
        let remoteName = videoURL.lastPathComponent
        if !remoteName.isEmpty {
            if URL(fileURLWithPath: remoteName).pathExtension.isEmpty {
                return "\(remoteName).mp4"
            }
            return remoteName
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return "nowatermark_\(formatter.string(from: createdAt)).mp4"
    }

    private func loadRemoteVideoMetadata(from videoURL: URL) async -> VideoMetadata {
        async let durationSeconds = loadDurationSeconds(from: videoURL)
        async let fileSizeBytes = loadRemoteFileSizeBytes(from: videoURL)
        return await VideoMetadata(fileSizeBytes: fileSizeBytes, durationSeconds: durationSeconds)
    }

    private func loadDurationSeconds(from videoURL: URL) async -> Double? {
        let asset = AVURLAsset(url: videoURL)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            guard seconds.isFinite, seconds > 0 else { return nil }
            return seconds
        } catch {
            return nil
        }
    }

    private func loadRemoteFileSizeBytes(from videoURL: URL) async -> Int64? {
        var request = URLRequest(url: videoURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            guard (200 ... 399).contains(httpResponse.statusCode) else { return nil }
            guard let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") else { return nil }
            return Int64(contentLength)
        } catch {
            return nil
        }
    }

    private func localFileSizeBytes(at fileURL: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let bytes = attributes[.size] as? NSNumber {
                return bytes.int64Value
            }
            return nil
        } catch {
            return nil
        }
    }

    private func updateCurrentRecordLocalFile(localURL: URL, fileSizeBytes: Int64?) {
        guard let currentRecordID else { return }

        let recordID = currentRecordID
        let descriptor = FetchDescriptor<HistoryRecord>(
            predicate: #Predicate { record in
                record.id == recordID
            }
        )

        guard let record = try? modelContext.fetch(descriptor).first else { return }
        record.localVideoPath = localURL.path
        if let fileSizeBytes {
            record.fileSizeBytes = fileSizeBytes
        }
        try? modelContext.save()
    }

    private func requestPhotoPermissionIfNeeded() async throws {
        let addOnlyStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch addOnlyStatus {
        case .authorized, .limited:
            return
        case .notDetermined:
            let newAddOnlyStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if newAddOnlyStatus == .authorized || newAddOnlyStatus == .limited {
                return
            }
        default:
            break
        }

        let readWriteStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch readWriteStatus {
        case .authorized, .limited:
            return
        case .notDetermined:
            let newReadWriteStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard newReadWriteStatus == .authorized || newReadWriteStatus == .limited else {
                throw ParseVideoError.photoPermissionDenied
            }
        default:
            throw ParseVideoError.photoPermissionDenied
        }
    }

    private func writeVideoToPhotoLibrary(fileURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = fileURL.lastPathComponent
                options.shouldMoveFile = false
                creationRequest.addResource(with: .video, fileURL: fileURL, options: options)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ParseVideoError.photoSaveFailed)
                }
            }
        }
    }

    @MainActor
    private func showActionAlert(title: String, message: String) {
        actionAlert = ActionAlert(title: title, message: message)
    }

    @MainActor
    private func showOperationError(_ error: Error) {
        let message: String
        if let parseError = error as? ParseVideoError {
            message = parseError.localizedDescription
        } else {
            let nsError = error as NSError
            if nsError.domain == PHPhotosErrorDomain {
                message = "相册保存失败：\(nsError.localizedDescription)"
            } else if nsError.domain == NSURLErrorDomain {
                message = "网络异常：\(nsError.localizedDescription)"
            } else {
                message = error.localizedDescription.isEmpty ? "操作失败，请稍后重试" : error.localizedDescription
            }
        }
        statusText = message
        extractionErrorText = message
        showActionAlert(title: "操作失败", message: message)
    }

    private func requestParsedVideo(for sourceURL: String) async throws -> ParseVideoResponse.VideoPayload {
        guard let endpointURL = URL(string: parseVideoEndpoint) else {
            throw ParseVideoError.invalidEndpoint
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ParseVideoRequest(url: sourceURL, returnRaw: false))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParseVideoError.invalidServerResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if let decodedError = try? JSONDecoder().decode(ParseVideoResponse.self, from: data),
               let message = decodedError.message,
               !message.isEmpty {
                throw ParseVideoError.serverMessage(message)
            }
            throw ParseVideoError.serverStatus(httpResponse.statusCode)
        }

        do {
            let decoded = try JSONDecoder().decode(ParseVideoResponse.self, from: data)
            guard decoded.success else {
                throw ParseVideoError.serverMessage(decoded.message ?? "接口返回失败")
            }
            guard let video = decoded.video else {
                throw ParseVideoError.emptyVideoURL
            }
            return video
        } catch let parseError as ParseVideoError {
            throw parseError
        } catch {
            throw ParseVideoError.invalidPayload
        }
    }

    private func validatedVideoURL(from rawValue: String) throws -> URL {
        guard let url = URL(string: rawValue) else {
            throw ParseVideoError.emptyVideoURL
        }
        return url
    }

    @MainActor
    private func handleExtractionFailure(_ error: Error) {
        isExtracting = false
        completedStepCount = 0
        shouldShowPreview = false

        if let parseError = error as? ParseVideoError {
            statusText = parseError.localizedDescription
            extractionErrorText = parseError.localizedDescription
        } else {
            statusText = "提取失败，请稍后重试"
            extractionErrorText = "提取失败，请稍后重试"
        }
    }

    private func stepIconName(for index: Int) -> String {
        if index < completedStepCount {
            return "checkmark.circle.fill"
        }
        if isExtracting, index == completedStepCount {
            return "clock.arrow.circlepath"
        }
        return "circle"
    }

    private func stepIconColor(for index: Int) -> Color {
        if index < completedStepCount {
            return .green
        }
        if isExtracting, index == completedStepCount {
            return .brandBlue
        }
        return .secondaryText
    }
}

private struct VideoMetadata {
    let fileSizeBytes: Int64?
    let durationSeconds: Double?
}

private struct ParseVideoRequest: Encodable {
    let url: String
    let returnRaw: Bool

    enum CodingKeys: String, CodingKey {
        case url
        case returnRaw = "return_raw"
    }
}

private struct ParseVideoResponse: Decodable {
    struct VideoPayload: Decodable {
        let url: String
        let width: Int?
        let height: Int?
        let definition: String?
        let posterURL: String?

        enum CodingKeys: String, CodingKey {
            case url
            case width
            case height
            case definition
            case posterURL = "poster_url"
        }
    }

    let success: Bool
    let video: VideoPayload?
    let message: String?
}

private enum ParseVideoError: LocalizedError {
    case invalidEndpoint
    case invalidServerResponse
    case serverStatus(Int)
    case serverMessage(String)
    case emptyVideoURL
    case invalidPayload
    case noVideoAvailable
    case fileSaveFailed
    case photoPermissionDenied
    case photoSaveFailed

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "提取服务地址无效"
        case .invalidServerResponse:
            return "服务响应异常，请稍后重试"
        case let .serverStatus(statusCode):
            return "提取服务异常（\(statusCode)）"
        case let .serverMessage(message):
            return message
        case .emptyVideoURL:
            return "未获取到可用视频地址"
        case .invalidPayload:
            return "接口响应解析失败"
        case .noVideoAvailable:
            return "当前没有可下载的视频"
        case .fileSaveFailed:
            return "视频下载失败，请重试"
        case .photoPermissionDenied:
            return "请在系统设置中允许访问相册"
        case .photoSaveFailed:
            return "保存到相册失败，请重试"
        }
    }
}

private enum PreviewAction: String, CaseIterable {
    case 下载
    case 保存
    case 分享

    var icon: String {
        switch self {
        case .下载: return "arrow.down.circle"
        case .保存: return "square.and.arrow.down"
        case .分享: return "square.and.arrow.up"
        }
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct FileExportController: UIViewControllerRepresentable {
    let fileURL: URL
    let onComplete: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onComplete: (Bool) -> Void

        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onComplete(!urls.isEmpty)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onComplete(false)
        }
    }
}

private struct ActionAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum HistoryLayoutMode: String, CaseIterable {
    case list
    case grid

    var title: String {
        switch self {
        case .list: return "列表"
        case .grid: return "网格"
        }
    }

    var icon: String {
        switch self {
        case .list: return "list.bullet.rectangle"
        case .grid: return "square.grid.2x2"
        }
    }
}

private struct HistoryView: View {
    @Query(
        sort: [SortDescriptor(\HistoryRecord.createdAt, order: .reverse)],
        animation: .easeInOut
    ) private var records: [HistoryRecord]
    @State private var layoutMode: HistoryLayoutMode = .list
    @State private var suspendCardInteractions = false

    private let gridColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("历史记录")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .padding(.bottom, 4)

                if records.isEmpty {
                    Text("暂无历史记录")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .background(Color.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    layoutModePicker

                    if layoutMode == .list {
                        LazyVStack(spacing: 12) {
                            ForEach(records, id: \.id) { record in
                                HistoryCard(
                                    record: record,
                                    layoutMode: layoutMode,
                                    isInteractionEnabled: !suspendCardInteractions
                                )
                            }
                        }
                    } else {
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(records, id: \.id) { record in
                                HistoryCard(
                                    record: record,
                                    layoutMode: layoutMode,
                                    isInteractionEnabled: !suspendCardInteractions
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 30)
        }
        .background(Color.screenBackground.ignoresSafeArea())
    }

    private var layoutModePicker: some View {
        HStack(spacing: 8) {
            ForEach(HistoryLayoutMode.allCases, id: \.self) { mode in
                Button {
                    switchLayout(to: mode)
                } label: {
                    Label(mode.title, systemImage: mode.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(layoutMode == mode ? Color.white : Color.primaryText)
                        .background(layoutMode == mode ? Color.brandBlue : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(8)
        .background(Color.cardBackground.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .zIndex(5)
    }

    private func switchLayout(to mode: HistoryLayoutMode) {
        guard layoutMode != mode else { return }
        suspendCardInteractions = true
        layoutMode = mode
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            suspendCardInteractions = false
        }
    }
}

private struct HistoryCard: View {
    @Environment(\.modelContext) private var modelContext
    let record: HistoryRecord
    let layoutMode: HistoryLayoutMode
    let isInteractionEnabled: Bool
    @State private var exportFileURL: URL?
    @State private var isFileExporterPresented = false
    @State private var actionAlert: ActionAlert?
    @State private var isDownloading = false
    @State private var isPreviewPresented = false

    var body: some View {
        Group {
            if layoutMode == .list {
                listCard
            } else {
                gridCard
            }
        }
        .allowsHitTesting(isInteractionEnabled)
        .sheet(isPresented: $isPreviewPresented) {
            HistoryPreviewSheet(record: record)
        }
        .sheet(isPresented: $isFileExporterPresented) {
            if let exportFileURL {
                FileExportController(fileURL: exportFileURL) { didExport in
                    if didExport {
                        actionAlert = ActionAlert(title: "下载成功", message: "视频已导出，请在“文件”App中查看。")
                    }
                }
            }
        }
        .alert(item: $actionAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("知道了")))
        }
    }

    private var listCard: some View {
        HStack(spacing: 12) {
            Button {
                isPreviewPresented = true
            } label: {
                HStack(spacing: 12) {
                    thumbnailContent(cornerRadius: 12, playIconSize: 22)
                        .frame(width: 92, height: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.title)
                            .font(.system(size: 30, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(Color.primaryText)

                        Text(record.subtitleText)
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(Color.secondaryText)
                    }

                    Spacer(minLength: 8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("预览\(record.title)")

            downloadButton(iconSize: 28)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                isPreviewPresented = true
            } label: {
                thumbnailContent(cornerRadius: 14, playIconSize: 30)
                    .frame(maxWidth: .infinity, minHeight: 156, maxHeight: 156)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("预览\(record.title)")

            Text(record.title)
                .font(.system(size: 22, weight: .semibold))
                .lineLimit(2)
                .foregroundStyle(Color.primaryText)

            Text(record.subtitleText)
                .font(.system(size: 16, weight: .regular))
                .lineLimit(1)
                .foregroundStyle(Color.secondaryText)

            HStack {
                Spacer(minLength: 0)
                downloadButton(iconSize: 24)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func thumbnailContent(cornerRadius: CGFloat, playIconSize: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.black.opacity(0.06))
                .overlay {
                    if let posterImageURL = record.posterImageURL {
                        AsyncImage(url: posterImageURL) { phase in
                            switch phase {
                            case let .success(image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            default:
                                LinearGradient(
                                    colors: [Color.gray.opacity(0.28), Color.gray.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    } else {
                        LinearGradient(
                            colors: [Color.gray.opacity(0.28), Color.gray.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            Image(systemName: "play.circle.fill")
                .font(.system(size: playIconSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.2), radius: 6, y: 2)
        }
        .overlay(alignment: .bottomLeading) {
            Text(record.durationText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
                .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private func downloadButton(iconSize: CGFloat) -> some View {
        Button {
            Task { await downloadFromHistory() }
        } label: {
            if isDownloading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: iconSize, weight: .regular))
                    .foregroundStyle(sourceVideoURL == nil ? Color.secondaryText : Color.brandBlue)
                    .frame(width: 44, height: 44)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDownloading || sourceVideoURL == nil)
        .accessibilityLabel("下载\(record.title)")
    }

    private var sourceVideoURL: URL? {
        if let localVideoPath = record.localVideoPath,
           FileManager.default.fileExists(atPath: localVideoPath) {
            return URL(fileURLWithPath: localVideoPath)
        }
        return URL(string: record.remoteVideoURL)
    }

    @MainActor
    private func downloadFromHistory() async {
        guard !isDownloading else { return }
        isDownloading = true
        defer { isDownloading = false }

        do {
            let localURL = try await ensureLocalVideoFile()
            exportFileURL = localURL
            isFileExporterPresented = true
        } catch {
            actionAlert = ActionAlert(title: "下载失败", message: historyErrorMessage(from: error))
        }
    }

    @MainActor
    private func ensureLocalVideoFile() async throws -> URL {
        if let localVideoPath = record.localVideoPath,
           FileManager.default.fileExists(atPath: localVideoPath) {
            return URL(fileURLWithPath: localVideoPath)
        }

        guard let remoteURL = URL(string: record.remoteVideoURL) else {
            throw ParseVideoError.noVideoAvailable
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ParseVideoError.invalidServerResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ParseVideoError.serverStatus(httpResponse.statusCode)
        }

        let destinationURL = try makeHistoryLocalVideoDestinationURL(
            sourceURL: remoteURL,
            suggestedFilename: httpResponse.suggestedFilename,
            mimeType: httpResponse.value(forHTTPHeaderField: "Content-Type")
        )

        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            throw ParseVideoError.fileSaveFailed
        }

        let localFileSizeBytes = localFileSize(at: destinationURL)
        guard let localFileSizeBytes, localFileSizeBytes > 0 else {
            throw ParseVideoError.fileSaveFailed
        }

        record.localVideoPath = destinationURL.path
        record.fileSizeBytes = localFileSizeBytes
        try modelContext.save()

        return destinationURL
    }

    private func makeHistoryLocalVideoDestinationURL(sourceURL: URL, suggestedFilename: String?, mimeType: String?) throws -> URL {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ParseVideoError.fileSaveFailed
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let fileExtension = normalizedVideoFileExtension(
            sourceURL: sourceURL,
            suggestedFilename: suggestedFilename,
            mimeType: mimeType
        )
        return documentDirectory.appendingPathComponent("history_\(record.id.uuidString)_\(timestamp).\(fileExtension)")
    }

    private func normalizedVideoFileExtension(sourceURL: URL, suggestedFilename: String?, mimeType: String?) -> String {
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

    private func localFileSize(at fileURL: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? NSNumber {
                return fileSize.int64Value
            }
            return nil
        } catch {
            return nil
        }
    }

    private func historyErrorMessage(from error: Error) -> String {
        if let parseError = error as? ParseVideoError {
            return parseError.localizedDescription
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "网络异常：\(nsError.localizedDescription)"
        }

        if error.localizedDescription.isEmpty {
            return "下载失败，请稍后重试"
        }

        return error.localizedDescription
    }
}

private struct HistoryPreviewSheet: View {
    let record: HistoryRecord
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.gray.opacity(0.12))
                        .overlay {
                            Text("视频不可用")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.secondaryText)
                        }
                        .frame(height: 320)
                }

                Text(record.title)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(2)

                Text(record.subtitleText)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.secondaryText)

                Spacer()
            }
            .padding(20)
            .navigationTitle("视频预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            guard player == nil else { return }
            guard let playbackURL = record.playbackURL else { return }
            let previewPlayer = AVPlayer(url: playbackURL)
            previewPlayer.play()
            player = previewPlayer
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

private extension HistoryRecord {
    var posterImageURL: URL? {
        guard let posterURL else { return nil }
        return URL(string: posterURL)
    }

    var playbackURL: URL? {
        if let localVideoPath, FileManager.default.fileExists(atPath: localVideoPath) {
            return URL(fileURLWithPath: localVideoPath)
        }
        return URL(string: remoteVideoURL)
    }

    var subtitleText: String {
        let calendar = Calendar.current
        let sizeText = fileSizeText

        if calendar.isDateInToday(createdAt) {
            return "今天 \(createdAt.formatted(date: .omitted, time: .shortened))  •  \(sizeText)"
        }
        if calendar.isDateInYesterday(createdAt) {
            return "昨天 \(createdAt.formatted(date: .omitted, time: .shortened))  •  \(sizeText)"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return "\(formatter.string(from: createdAt))  •  \(sizeText)"
    }

    var durationText: String {
        guard let durationSeconds, durationSeconds > 0 else { return "--:--" }
        let totalSeconds = Int(durationSeconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var fileSizeText: String {
        guard let fileSizeBytes, fileSizeBytes > 0 else { return "大小未知" }
        return ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

private extension Color {
    static let screenBackground = Color(red: 0.93, green: 0.94, blue: 0.97)
    static let cardBackground = Color.white
    static let brandBlue = Color(red: 0.06, green: 0.47, blue: 0.99)
    static let primaryText = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let secondaryText = Color(red: 0.54, green: 0.55, blue: 0.60)
    static let actionTint = Color(red: 0.93, green: 0.95, blue: 0.99)
}

#Preview {
    ContentView()
}
