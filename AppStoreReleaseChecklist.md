# App Store Release Checklist

## 1) App Store Connect 必填
- Privacy Policy URL: 使用 Notion 外链（示例：`https://www.notion.so/your-team/privacy-policy`）
- Support URL: 建议填写官网/Notion 帮助页
- App Privacy 问卷：按实际数据流填写（包含外部解析服务）

## 2) 审核备注（Review Notes）建议
- 功能说明：用户输入视频链接，调用后端解析接口，返回可预览视频地址。
- 合规说明：仅允许处理用户已获得授权的视频内容。
- 测试步骤：
  1. 打开“提取”页
  2. 输入测试链接
  3. 勾选“已获得授权”
  4. 点击“提取无水印视频”
  5. 验证预览、下载、保存、分享
- 后端可用性：审核期间确保接口可用且返回稳定。

## 3) 合规风险自检
- 已在 App 内加入授权确认开关，未勾选不可提取。
- 已提供隐私政策入口（Notion URL）。
- 若内容来源有版权限制，请准备授权证明材料以备审核沟通。
