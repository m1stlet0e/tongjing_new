# tongjing（同镜）

Flutter 摄影社区客户端。推荐通过**腾讯云 CloudBase** 云函数 `tongjing_api`（Node.js + PostgreSQL + 可选 S3）访问后端；也可在未初始化 CloudBase 时通过 `API_BASE_URL` 直连任意实现相同 `/api/v1/*` 契约的 HTTP 服务。

## CloudBase（推荐）

与本项目对齐的 Agent 技能可安装 `.agents/skills/cloudbase`（`npx skills add tencentcloudbase/cloudbase-skills`）。

1. **IDE 管理云开发**：项目已含 `.cursor/mcp.json` 中的 `@cloudbase/cloudbase-mcp`。在 Cursor 中启用 MCP 后，可用工具管理环境、部署云函数等（需按 MCP 提示完成登录）。
2. **客户端**：使用 `cloudbase_flutter`，勿照搬 Web 的 `js-sdk` 示例。
   - 复制 `dart_defines.example.json` 为 **`dart_defines.json`**（该文件已在 `.gitignore` 中，勿提交），填入环境 ID 与 [Publishable Key](https://tcb.cloud.tencent.com/dev?#/identity/token-management)。
   - 若启用微信开放平台登录，还需填写 `WECHAT_OPEN_APP_ID`、`WECHAT_UNIVERSAL_LINK`。
   - 原生平台占位值需替换：
     - Android：`android/app/src/main/AndroidManifest.xml` 中 `wx_your_app_id`
     - iOS：`ios/Runner/Info.plist` 中 `wx_your_app_id`
   - 命令行：`flutter run --dart-define-from-file=dart_defines.json`
   - 或在 Cursor/VS Code 中选运行配置 **「tongjing (dart_defines.json)」**。
   - 初始化 CloudBase 后，**所有 JSON 接口与图片上传**（base64）均经云函数。
3. **云函数**：`server-cloudbase/functions/tongjing_api` 为**事件型**函数（`exports.main`）。控制台需配置 **`DATABASE_URL`**（及可选 **`DATABASE_USER` / `DATABASE_PASSWORD`**，当 URL 不含口令时）、**S3**：`S3_ENDPOINT`、`S3_BUCKET`、`S3_ACCESS_KEY`、`S3_SECRET_KEY`，可选 `S3_PUBLIC_BASE_URL`、`S3_REGION`（或与历史一致的 `COZE_*` 别名）。可参考 `server-cloudbase/cloudbaserc.example.json` 复制为 `cloudbaserc.json` 后用 CloudBase CLI 部署。

详见：`lib/services/cloudbase_gate.dart`、`lib/services/cloudbase_api_proxy.dart`。

## 临时官网落地页（微信开放平台可用）

- 模板目录：`server-cloudbase/landing/`
- 页面文件：
  - `server-cloudbase/landing/index.html`
  - `server-cloudbase/landing/privacy.html`
- 使用方式：将该目录部署到任意静态托管（CloudBase Hosting、Vercel、Netlify、GitHub Pages 均可），拿到公网 URL 后填写到微信开放平台“应用官网”。

## Getting Started（Flutter）

This project is a starting point for a Flutter application.

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [online documentation](https://docs.flutter.dev/)
