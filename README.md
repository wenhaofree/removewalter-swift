# removewalter-swift

一个基于 SwiftUI + SwiftData 的 iOS 应用，用于从链接提取视频、预览、下载、保存到相册、分享，并记录历史。

## 当前功能
- 链接输入、粘贴、清空。
- 点击提取后调用解析接口获取视频地址。
- 展示提取进度与视频预览。
- 预览区支持下载、保存到相册、系统分享。
- 历史记录支持列表/网格切换。
- 历史记录支持点击预览与下载导出。
- 本地缓存视频路径与基础元数据（时长、大小、时间）。

## 技术栈
- SwiftUI
- SwiftData
- AVKit / AVFoundation
- Photos

## 运行环境
- Xcode 26+
- iOS 17.0+（当前工程部署目标）
- 支持 iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`）

## 接口说明
- 视频解析接口：
  - `POST https://api-doubaonomark.wenhaofree.com/parse-video`
  - 请求体示例：
    - `{"url":"<视频分享链接>","return_raw":false}`
- 说明：
  - 审核和上线期间必须保证接口可用与稳定。
  - 若接口不可用，提取流程将失败并提示错误。

## 合规与隐私
- 已增加“双重合规确认”开关（授权确认 + 合法用途承诺），未勾选不可提取。
- App 内隐私政策入口：`https://www.notion.so/wenhaofree/31228842492280ff9798de7fb8e99593?source=copy_link`
- 已加入 `PrivacyInfo.xcprivacy`。

## 项目结构
- `removewalter-swift/ContentView.swift`：主业务与页面逻辑。
- `removewalter-swift/Item.swift`：`HistoryRecord` 数据模型。
- `removewalter-swift/removewalter_swiftApp.swift`：应用入口与容器初始化。
- `removewalter-swift/PrivacyInfo.xcprivacy`：隐私清单。
- `AppStoreReleaseChecklist.md`：上架发布清单。

## 本地构建
```bash
xcodebuild -project removewalter-swift.xcodeproj -scheme removewalter-swift -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## TODO（发布前必须）
1. 在 App Store Connect 填写 Privacy Policy URL（使用同一 Notion 链接）。
2. 在 App Store Connect 完成 App Privacy 问卷（含第三方解析服务数据流）。
3. 在 App Store Connect 完成 Support URL 与审核备注（可参考 `AppStoreReleaseChecklist.md` 与 `AppStoreReviewNotesTemplate.md`）。
4. 准备内容版权/授权证明材料，避免审核因 5.2.2/5.2.3 被拒。

## TODO（上线建议）
1. 补充更多单元测试与 UI 冒烟测试（提取、预览、下载、保存、分享、历史）。
2. 增加解析服务降级策略（当前已支持请求重试与退避）。
3. 增加埋点与崩溃监控（例如提取成功率、下载失败率）。
4. 优化 iPad 横屏布局适配与交互细节。
5. 增加本地化资源（中文/英文）与应用商店文案一致性校验。

## TODO（后续优化）
1. 抽离网络层与存储层，降低 `ContentView.swift` 复杂度。
2. 增加批量历史管理能力（删除、筛选、搜索）。
3. 增加离线缓存管理（容量上限、自动清理策略）。
4. 完善错误码映射与用户可理解提示。
5. 引入 CI 自动化构建与基础质量门禁。

## 备注
- 当前代码已去除启动阶段 `fatalError`，改为失败时展示错误页，避免直接崩溃。
- 若要提交 TestFlight / App Store，请先完成“发布前必须”项。
