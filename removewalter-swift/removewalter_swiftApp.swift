//
//  removewalter_swiftApp.swift
//  removewalter-swift
//
//  Created by wenhao on 2026/2/25.
//

import SwiftUI
import SwiftData

@main
struct removewalter_swiftApp: App {
    private let sharedModelContainer: ModelContainer?
    private let startupErrorMessage: String?

    init() {
        let schema = Schema([
            HistoryRecord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            startupErrorMessage = nil
        } catch {
            sharedModelContainer = nil
            startupErrorMessage = "本地数据初始化失败，请重启应用后重试。"
        }
    }

    var body: some Scene {
        WindowGroup {
            if let sharedModelContainer {
                ContentView()
                    .modelContainer(sharedModelContainer)
            } else {
                StartupFailureView(message: startupErrorMessage ?? "应用初始化失败")
            }
        }
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.orange)

            Text("启动失败")
                .font(.system(size: 24, weight: .bold))

            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
