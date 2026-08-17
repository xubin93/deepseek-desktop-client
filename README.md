# DeepSeek Desktop Client（DeepSeek Harness 桌面客户端）

把 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)（`dsh`）打包成 Windows 桌面客户端的源码与安装包构建套件。

## 功能特性

- **原生客户端窗口**：WebView2 窗口承载 dsh Web GUI，无浏览器界面
- **关闭行为设置**：托盘菜单三选一（每次询问 / 后台运行托盘 / 退出并停止），持久化保存
- **托盘后台运行**：窗口隐藏到系统托盘，服务器继续运行；再次双击图标自动唤醒窗口
- **自动管理服务端**：启动时自动拉起/复用 `dsh web` 服务器，退出时自动停止
- **黑色鲸鱼图标**：任务栏/托盘/快捷方式（图标来自 DeepSeek 官方 favicon，见下方声明）
- **单实例 + 跨进程唤醒**、故障日志、WebView2 缺失时回退 Edge 应用窗口

## 目录结构

```
client/        可重定位客户端源码（任意路径可用）
installer/     安装器配置（postinstall 流程、profile 模板、SFX 配置）
build/         安装包构建脚本
```

## 构建安装包（setup.exe）

前置：Node 22.19+/24、pnpm 11、Windows 10/11 x64、7-Zip（7zr + 7zS2.sfx，脚本会自动下载）。

1. 构建 DeepSeek Harness 并打包发布 tarball：
   ```sh
   # 在 deepseek-harness 仓库内
   npm run build
   pnpm tsx scripts/release/pack.ts --family dsh --out dist/npm
   pnpm tsx scripts/release/pack.ts --family vendor --out dist/npm-vendor
   ```
2. 运行构建脚本：
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File build\build-setup.ps1 `
     -TarballDir C:\path\to\deepseek-harness\dist
   ```
3. 产物：`DeepSeek-Setup.exe`（自解压安装包，约 31 MB）

## 目标机器安装

双击 setup.exe → 复制到 `%LOCALAPPDATA%\Programs\DeepSeek` → 离线安装 harness（npm 外部依赖需联网）→ 静默安装 WebView2 运行时（已装则跳过）→ 创建桌面/开始菜单快捷方式。

首次打开后需在 **设置 → 模型** 中填入自己的 DeepSeek API Key（安装包不含任何密钥）。

## 第三方组件与商标声明

- **DeepSeek 鲸鱼图标**：取自 DeepSeek 官方 favicon（`deepseek-harness/apps/web`），版权与商标归 DeepSeek 所有，本项目仅用于个人集成展示，不用于商业分发；如 DeepSeek 方要求将移除
- **Microsoft WebView2 SDK**：`client/WebView2/` 下三个 DLL 按微软 WebView2 SDK 许可证再分发（`Microsoft.Web.WebView2.Core.dll`、`WinForms.dll` 取自 NuGet 包，`WebView2Loader.dll` 为官方分发件）
- **Node.js**：安装包内嵌官方便携版（构建时下载），遵循其自身许可证
- **DeepSeek Harness**：安装包载荷来自官方发布 tarball（MIT）

## 安全说明

- 客户端与服务器均只监听 `127.0.0.1:3080`，不对外网开放
- 所有数据（会话、设置、密钥）保存在本机
- 对话与图片会发送到你所配置的模型服务商（DeepSeek 官方 / 智谱等）

## License

本仓库代码 MIT。第三方组件遵循各自许可证（见 `THIRD-PARTY-NOTICES.md`）。
